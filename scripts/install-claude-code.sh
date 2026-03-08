#!/usr/bin/env bash
set -euo pipefail

# install-claude-code.sh — Install Claude Code CLI for GitHub Actions runners.
# Uses the official installer from claude.ai.

# ── Helper: GitHub Actions log annotations ───────────────────────────────────
gh_group()    { echo "::group::$1"; }
gh_endgroup() { echo "::endgroup::"; }
gh_error()    { echo "::error::$1"; }

# ── 1. Check if already installed ────────────────────────────────────────────
if command -v claude &>/dev/null; then
  echo "claude is already installed:"
  claude --version
  exit 0
fi

# ── 2. Install via official installer ────────────────────────────────────────
gh_group "Installing Claude Code CLI"

curl -fsSL https://claude.ai/install.sh | bash -s stable

# Add to PATH for current step (installer puts it in ~/.local/bin)
export PATH="${HOME}/.local/bin:${PATH}"
echo "${HOME}/.local/bin" >> "${GITHUB_PATH:-/dev/null}"

echo "Installed $(which claude)"
gh_endgroup

# ── 3. Verify ────────────────────────────────────────────────────────────────
gh_group "Verifying installation"

if ! command -v claude &>/dev/null; then
  gh_error "claude not found on PATH after installation"
  exit 1
fi

claude --version
echo "Claude Code installed successfully"
gh_endgroup
