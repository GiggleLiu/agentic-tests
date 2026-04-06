#!/usr/bin/env bash
set -euo pipefail

# run-tests.sh — Run agentic tests for each detected feature or skill.
#
# Env vars (from action.yml):
#   INPUT_RUNNER       — "opencode", "codex", or "claude-code"
#   INPUT_MODE         — "feature", "skill", or "both"
#   INPUT_PROFILES_DIR — profiles directory (default: docs/agent-profiles)
#   INPUT_EXTRA_PROMPT — extra instructions appended to each prompt
#
# Input:
#   /tmp/affected-features.txt — one target per line (written by action.yml)
#
# Output:
#   Test reports written to docs/test-reports/.
#   Sets GitHub Actions outputs via $GITHUB_OUTPUT.

RUNNER="${INPUT_RUNNER:-opencode}"
MODE="${INPUT_MODE:-feature}"
PROFILES_DIR="${INPUT_PROFILES_DIR:-${1:-docs/agent-profiles}}"
EXTRA_PROMPT="${INPUT_EXTRA_PROMPT:-}"
SKILL_REPOS_DIR="${SKILL_REPOS_DIR:-.agentic-skills}"
FEATURES_FILE="/tmp/affected-features.txt"
REPORTS_DIR="docs/test-reports"

# ── Helper: GitHub Actions log annotations ───────────────────────────────────
gh_group()    { echo "::group::$1"; }
gh_endgroup() { echo "::endgroup::"; }
gh_warning()  { echo "::warning::$1"; }

expected_target_type() {
  case "$1" in
    *test-skill) echo "skill" ;;
    *)           echo "feature" ;;
  esac
}

extract_report_verdict() {
  local report="$1"
  sed -n 's/^\*\*Verdict:\*\* //p' "${report}" | head -n 1 | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'
}

extract_critical_issue_count() {
  local report="$1"
  local value
  value=$(sed -n 's/^\*\*Critical Issues:\*\* //p' "${report}" | head -n 1)
  if [[ "${value}" =~ ^[[:space:]]*([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

report_indicates_failure() {
  local report="$1"
  local verdict
  local critical
  local fail_count
  local pass_count
  local fail_pattern='[Ff][Aa][Ii][Ll]|[Bb][Rr][Oo][Kk][Ee][Nn]|[Cc][Rr][Ii][Tt][Ii][Cc][Aa][Ll]|[Bb][Ll][Oo][Cc][Kk][Ee][Rr]'
  local pass_pattern='[Pp][Aa][Ss][Ss]|[Ss][Uu][Cc][Cc][Ee][Ss][Ss]|[Ww][Oo][Rr][Kk][Ii][Nn][Gg]|[Cc][Oo][Mm][Pp][Ll][Ee][Tt][Ee]'

  verdict=$(extract_report_verdict "${report}")
  critical=$(extract_critical_issue_count "${report}")

  if [[ -n "${verdict}" ]]; then
    [[ "${verdict}" == "fail" ]] && return 0
    [[ "${verdict}" == "pass" ]] && [[ -z "${critical}" || "${critical}" == "0" ]] && return 1
  fi

  if [[ -n "${critical}" && "${critical}" != "0" ]]; then
    return 0
  fi

  fail_count=$(grep -cE "${fail_pattern}" "${report}" || true)
  pass_count=$(grep -cE "${pass_pattern}" "${report}" || true)
  [[ ${fail_count} -gt ${pass_count} ]]
}

pick_profile_path() {
  local slug="$1"
  local expected_type="$2"
  local candidate
  local target_type
  local fallback=""

  [[ -d "${PROFILES_DIR}" ]] || return 0

  while IFS= read -r candidate; do
    target_type=$(sed -n '/^## Target Type$/ {n; p; q;}' "${candidate}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    if [[ "${target_type}" == "${expected_type}" ]]; then
      echo "${candidate}"
      return 0
    fi
    if [[ -z "${target_type}" && -z "${fallback}" ]]; then
      fallback="${candidate}"
    fi
  done < <(find "${PROFILES_DIR}" -maxdepth 1 -name "${slug}-*.md" -type f | sort)

  [[ -n "${fallback}" ]] && echo "${fallback}"
}

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

# ── Build skill-repos prompt (if external repos were cloned) ─────────────────
SKILL_REPOS_PROMPT=""
if [[ -d "${SKILL_REPOS_DIR}" ]] && ls -A "${SKILL_REPOS_DIR}" >/dev/null 2>&1; then
  REPO_PATHS=""
  for repo_dir in "${SKILL_REPOS_DIR}"/*/; do
    [[ -d "${repo_dir}" ]] || continue
    REPO_PATHS="${REPO_PATHS}  - ${repo_dir}"$'\n'
  done
  if [[ -n "${REPO_PATHS}" ]]; then
    SKILL_REPOS_PROMPT="Before running tests, read the README of each skill repo below and install all the skills you find:
${REPO_PATHS}
"
  fi
fi

# ── Run tests ────────────────────────────────────────────────────────────────
ALL_PASS=true
TESTED=""

while IFS= read -r feature || [[ -n "${feature}" ]]; do
  # Skip blank lines
  [[ -z "${feature}" ]] && continue

  # ── Determine test command and target based on mode ──────────────────────
  # In "both" mode, items may be prefixed with "feature:" or "skill:"
  # OpenCode and Claude Code use /command syntax, Codex uses $command syntax
  if [[ "${RUNNER}" == "codex" ]]; then
    CMD_PREFIX='$'
  else
    CMD_PREFIX="/"
  fi
  TEST_CMD="${CMD_PREFIX}test-feature"
  TARGET="${feature}"
  if [[ "${MODE}" == "skill" ]]; then
    TEST_CMD="${CMD_PREFIX}test-skill"
  elif [[ "${MODE}" == "both" ]]; then
    if [[ "${feature}" == skill:* ]]; then
      TEST_CMD="${CMD_PREFIX}test-skill"
      TARGET="${feature#skill:}"
    elif [[ "${feature}" == feature:* ]]; then
      TARGET="${feature#feature:}"
    fi
  fi

  # Normalize target name to slug: lowercase, spaces to hyphens
  slug=$(echo "${TARGET}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  target_type=$(expected_target_type "${TEST_CMD}")

  gh_group "Testing: ${TARGET} (${slug})"

  # ── Look for a matching agent profile ────────────────────────────────────
  PROFILE_PATH="$(pick_profile_path "${slug}" "${target_type}")"

  # ── Build the prompt ─────────────────────────────────────────────────────
  if [[ -n "${PROFILE_PATH}" ]]; then
    echo "Using profile: ${PROFILE_PATH}"
    PROMPT="${TEST_CMD} ${PROFILE_PATH}"
  else
    echo "No profile found for '${slug}' — running with ${TEST_CMD}"
    PROMPT="${TEST_CMD} ${TARGET}"
  fi

  # Prepend skill-repos installation instructions if present
  if [[ -n "${SKILL_REPOS_PROMPT}" ]]; then
    PROMPT="${SKILL_REPOS_PROMPT}${PROMPT}"
  fi

  # Append extra instructions if provided
  if [[ -n "${EXTRA_PROMPT}" ]]; then
    PROMPT="${PROMPT}

Additional instructions: ${EXTRA_PROMPT}"
  fi

  # ── Create a timestamp marker for detecting new reports ──────────────────
  MARKER="/tmp/test-marker-${slug}"
  touch "${MARKER}"

  # ── Execute agent runner ─────────────────────────────────────────────────
  LOG_FILE="/tmp/test-${slug}.log"

  set +e
  case "${RUNNER}" in
    codex)
      echo "Running: codex exec \"${PROMPT}\""
      codex exec --full-auto --sandbox workspace-write "${PROMPT}" 2>&1 | tee "${LOG_FILE}"
      ;;
    claude-code)
      echo "Running: claude -p \"${PROMPT}\""
      claude -p "${PROMPT}" --allowedTools "Bash,Read,Write,Edit,Glob,Grep,Agent" --no-session-persistence 2>&1 | tee "${LOG_FILE}"
      ;;
    *)
      echo "Running: opencode -p \"${PROMPT}\" -q"
      opencode -p "${PROMPT}" -q 2>&1 | tee "${LOG_FILE}"
      ;;
  esac
  EXIT_CODE=${PIPESTATUS[0]}
  set -e

  if [[ ${EXIT_CODE} -ne 0 ]]; then
    gh_warning "${RUNNER} exited with code ${EXIT_CODE} for feature '${feature}'"
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
    for rpt in ${NEW_REPORTS}; do
      if report_indicates_failure "${rpt}"; then
        gh_warning "Report ${rpt} indicates failure"
        ALL_PASS=false
      fi
    done
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
