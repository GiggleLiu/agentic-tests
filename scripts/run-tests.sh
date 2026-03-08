#!/usr/bin/env bash
set -euo pipefail

# run-tests.sh — Run agentic tests for each detected feature.
#
# Arguments:
#   $1  profiles directory (default: "docs/agent-profiles")
#
# Input:
#   /tmp/affected-features.txt — one feature name per line (written by detect-features.sh)
#
# Output:
#   Test reports written to docs/test-reports/ by the test-feature skill.
#   Sets GitHub Actions outputs via $GITHUB_OUTPUT.

PROFILES_DIR="${INPUT_PROFILES_DIR:-${1:-docs/agent-profiles}}"
EXTRA_PROMPT="${INPUT_EXTRA_PROMPT:-}"
FEATURES_FILE="/tmp/affected-features.txt"
REPORTS_DIR="docs/test-reports"

# ── Helper: GitHub Actions log annotations ───────────────────────────────────
gh_group()    { echo "::group::$1"; }
gh_endgroup() { echo "::endgroup::"; }
gh_warning()  { echo "::warning::$1"; }

# ── Ensure reports directory exists ──────────────────────────────────────────
mkdir -p "${REPORTS_DIR}"

# ── Handle empty / missing features file ─────────────────────────────────────
if [[ ! -s "${FEATURES_FILE}" ]]; then
  echo "No affected features detected — nothing to test."
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "features-tested=" >> "${GITHUB_OUTPUT}"
    echo "pass=true"        >> "${GITHUB_OUTPUT}"
  fi
  exit 0
fi

# ── Run tests ────────────────────────────────────────────────────────────────
ALL_PASS=true
TESTED=""

while IFS= read -r feature || [[ -n "${feature}" ]]; do
  # Skip blank lines
  [[ -z "${feature}" ]] && continue

  # Normalize feature name to slug: lowercase, spaces to hyphens
  slug=$(echo "${feature}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  gh_group "Testing feature: ${feature} (${slug})"

  # ── Look for a matching agent profile ────────────────────────────────────
  PROFILE_PATH=""
  if [[ -d "${PROFILES_DIR}" ]]; then
    PROFILE_PATH=$(find "${PROFILES_DIR}" -maxdepth 1 -name "${slug}-*.md" -type f | head -1) || true
  fi

  # ── Build the prompt ─────────────────────────────────────────────────────
  if [[ -n "${PROFILE_PATH}" ]]; then
    echo "Using profile: ${PROFILE_PATH}"
    PROMPT="/test-feature ${PROFILE_PATH}"
  else
    echo "No profile found for '${slug}' — running with feature name"
    PROMPT="/test-feature ${feature}"
  fi

  # Append extra instructions if provided
  if [[ -n "${EXTRA_PROMPT}" ]]; then
    PROMPT="${PROMPT}

Additional instructions: ${EXTRA_PROMPT}"
  fi

  # ── Create a timestamp marker for detecting new reports ──────────────────
  MARKER="/tmp/test-marker-${slug}"
  touch "${MARKER}"

  # ── Execute OpenCode ─────────────────────────────────────────────────────
  LOG_FILE="/tmp/test-${slug}.log"
  echo "Running: opencode -p \"${PROMPT}\" -q"

  set +e
  opencode -p "${PROMPT}" -q 2>&1 | tee "${LOG_FILE}"
  EXIT_CODE=${PIPESTATUS[0]}
  set -e

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    gh_warning "opencode exited with code ${EXIT_CODE} for feature '${feature}'"
    ALL_PASS=false
  fi

  # ── Check for new test reports ───────────────────────────────────────────
  NEW_REPORTS=$(find "${REPORTS_DIR}" -maxdepth 1 -type f -name "*.md" -newer "${MARKER}" 2>/dev/null) || true
  if [[ -z "${NEW_REPORTS}" ]]; then
    gh_warning "No new test report found in ${REPORTS_DIR}/ for feature '${feature}'"
    ALL_PASS=false
  else
    echo "New report(s):"
    echo "${NEW_REPORTS}"
  fi

  rm -f "${MARKER}"

  # ── Accumulate tested list ───────────────────────────────────────────────
  if [[ -n "${TESTED}" ]]; then
    TESTED="${TESTED},${feature}"
  else
    TESTED="${feature}"
  fi

  gh_endgroup
done < "${FEATURES_FILE}"

# ── Set GitHub Actions outputs ───────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "Features tested: ${TESTED}"
echo "All passed: ${ALL_PASS}"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "features-tested=${TESTED}" >> "${GITHUB_OUTPUT}"
  echo "pass=${ALL_PASS}"          >> "${GITHUB_OUTPUT}"
fi
