#!/usr/bin/env bash
set -euo pipefail

# install-codex.sh — Install Codex CLI for Linux amd64 (GitHub Actions runner)
# Downloads the latest release binary from GitHub.

INSTALL_DIR="/usr/local/bin"
BINARY_NAME="codex"
REPO="openai/codex"

# ── Cleanup trap ─────────────────────────────────────────────────────────────
TMPDIR_WORK=""
cleanup() {
  if [[ -n "${TMPDIR_WORK}" && -d "${TMPDIR_WORK}" ]]; then
    rm -rf "${TMPDIR_WORK}"
  fi
}
trap cleanup EXIT

# ── Helper: GitHub Actions log annotations ───────────────────────────────────
gh_group()    { echo "::group::$1"; }
gh_endgroup() { echo "::endgroup::"; }
gh_error()    { echo "::error::$1"; }

# ── 1. Check if already installed ────────────────────────────────────────────
if command -v "${BINARY_NAME}" &>/dev/null; then
  echo "codex is already installed:"
  codex --version
  exit 0
fi

# ── 2. Resolve latest release asset URL ──────────────────────────────────────
gh_group "Resolving latest Codex release for linux/amd64"

API_URL="https://api.github.com/repos/${REPO}/releases/latest"

CURL_HEADERS=(-H "Accept: application/vnd.github+json")
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  CURL_HEADERS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

RELEASE_JSON=$(curl -fsSL "${CURL_HEADERS[@]}" "${API_URL}") || {
  gh_error "Failed to fetch latest release metadata from ${API_URL}"
  exit 1
}

# Look for linux x86_64 tarball (e.g., codex-x86_64-unknown-linux-musl.tar.gz)
ASSET_URL=""
ASSET_NAME=""

ASSET_URL=$(echo "${RELEASE_JSON}" | \
  python3 -c "
import sys, json, re
data = json.load(sys.stdin)
# Match 'codex-<arch>-...-linux-...' but exclude proxy/runner/sandbox variants
for asset in data.get('assets', []):
    name = asset['name']
    if re.match(r'^codex-x86_64.*linux.*\.tar\.gz$', name) \
       and 'responses-api-proxy' not in name \
       and 'command-runner' not in name \
       and 'sandbox' not in name \
       and 'npm' not in name:
        print(asset['browser_download_url'])
        break
" 2>/dev/null) || true

if [[ -n "${ASSET_URL}" ]]; then
  ASSET_NAME=$(basename "${ASSET_URL}")
fi

if [[ -z "${ASSET_URL}" ]]; then
  gh_error "Could not find a linux/amd64 asset in the latest release of ${REPO}"
  exit 1
fi

echo "Asset: ${ASSET_NAME}"
echo "URL:   ${ASSET_URL}"
gh_endgroup

# ── 3. Download ──────────────────────────────────────────────────────────────
gh_group "Downloading ${ASSET_NAME}"

TMPDIR_WORK=$(mktemp -d)
DOWNLOAD_PATH="${TMPDIR_WORK}/${ASSET_NAME}"

curl -fsSL -o "${DOWNLOAD_PATH}" "${ASSET_URL}" || {
  gh_error "Failed to download ${ASSET_URL}"
  exit 1
}

echo "Downloaded to ${DOWNLOAD_PATH} ($(du -h "${DOWNLOAD_PATH}" | cut -f1))"
gh_endgroup

# ── 4. Extract / install ────────────────────────────────────────────────────
gh_group "Installing codex to ${INSTALL_DIR}"

EXTRACT_DIR="${TMPDIR_WORK}/extract"
mkdir -p "${EXTRACT_DIR}"

case "${ASSET_NAME}" in
  *.tar.gz | *.tgz)
    tar -xzf "${DOWNLOAD_PATH}" -C "${EXTRACT_DIR}"
    ;;
  *.zip)
    unzip -qo "${DOWNLOAD_PATH}" -d "${EXTRACT_DIR}"
    ;;
  *)
    cp "${DOWNLOAD_PATH}" "${EXTRACT_DIR}/${BINARY_NAME}"
    chmod +x "${EXTRACT_DIR}/${BINARY_NAME}"
    ;;
esac

# Locate the binary inside the extracted tree
BINARY_PATH=""
if [[ -f "${EXTRACT_DIR}/${BINARY_NAME}" ]]; then
  BINARY_PATH="${EXTRACT_DIR}/${BINARY_NAME}"
else
  BINARY_PATH=$(find "${EXTRACT_DIR}" -type f -name "${BINARY_NAME}" | head -n 1)
fi

# Also try codex-linux-* or similar patterns
if [[ -z "${BINARY_PATH}" || ! -f "${BINARY_PATH}" ]]; then
  BINARY_PATH=$(find "${EXTRACT_DIR}" -type f -executable | head -n 1)
fi

if [[ -z "${BINARY_PATH}" || ! -f "${BINARY_PATH}" ]]; then
  gh_error "Could not locate '${BINARY_NAME}' binary after extraction"
  ls -R "${EXTRACT_DIR}" >&2
  exit 1
fi

chmod +x "${BINARY_PATH}"
sudo install -m 0755 "${BINARY_PATH}" "${INSTALL_DIR}/${BINARY_NAME}"

echo "Installed ${INSTALL_DIR}/${BINARY_NAME}"
gh_endgroup

# ── 5. Verify ────────────────────────────────────────────────────────────────
gh_group "Verifying installation"

if ! command -v "${BINARY_NAME}" &>/dev/null; then
  gh_error "codex not found on PATH after installation"
  exit 1
fi

codex --version
echo "codex installed successfully"
gh_endgroup
