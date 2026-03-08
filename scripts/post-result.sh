#!/usr/bin/env bash
set -euo pipefail

# post-result.sh — Read test reports and post a summary as an issue/PR comment.
# Usage: post-result.sh <ISSUE_NUMBER>
# Requires: GH_TOKEN env var, gh CLI

# ── GitHub Actions log helpers ────────────────────────────────────────────────
gh_group()    { echo "::group::$1"; }
gh_endgroup() { echo "::endgroup::"; }
gh_error()    { echo "::error::$1"; }
gh_warning()  { echo "::warning::$1"; }

# ── Validate arguments & environment ─────────────────────────────────────────
ISSUE_NUMBER="${1:-}"
if [[ -z "${ISSUE_NUMBER}" ]]; then
  gh_error "Usage: post-result.sh <ISSUE_NUMBER>"
  exit 1
fi

if [[ -z "${GH_TOKEN:-}" ]]; then
  gh_error "GH_TOKEN environment variable is required"
  exit 1
fi

if ! command -v gh &>/dev/null; then
  gh_error "gh CLI is required but not found on PATH"
  exit 1
fi

REPORT_DIR="docs/test-reports"
MAX_COMMENT_LENGTH=60000

# ── Collect report files ─────────────────────────────────────────────────────
gh_group "Collecting test reports"

REPORT_FILES=()
if [[ -d "${REPORT_DIR}" ]]; then
  while IFS= read -r -d '' f; do
    REPORT_FILES+=("$f")
  done < <(find "${REPORT_DIR}" -maxdepth 1 -name '*.md' -print0 | sort -z)
fi

echo "Found ${#REPORT_FILES[@]} report(s)"
gh_endgroup

# ── No reports: post "no reports" and exit ───────────────────────────────────
if [[ ${#REPORT_FILES[@]} -eq 0 ]]; then
  gh_group "Posting comment (no reports)"
  COMMENT="## Agentic Test Results

No test reports were generated.

---
Full reports available as [workflow artifacts](../actions)."

  gh issue comment "${ISSUE_NUMBER}" --body "${COMMENT}"
  echo "Posted 'no reports' comment on #${ISSUE_NUMBER}"
  gh_endgroup
  exit 0
fi

# ── Parse each report ────────────────────────────────────────────────────────
gh_group "Parsing reports"

FEATURES_TESTED=0
FEATURES_PASSED=0
FEATURES_WITH_ISSUES=0

TABLE_ROWS=""
ALL_ISSUES=""
ALL_SUGGESTIONS=""

# Failure indicator patterns (case-insensitive matching)
FAIL_PATTERN='[Ff][Aa][Ii][Ll]|[Ee][Rr][Rr][Oo][Rr]|[Bb][Rr][Oo][Kk][Ee][Nn]|[Mm][Ii][Ss][Ss][Ii][Nn][Gg]|[Cc][Rr][Ii][Tt][Ii][Cc][Aa][Ll]|[Bb][Ll][Oo][Cc][Kk][Ee][Rr]'
PASS_PATTERN='[Pp][Aa][Ss][Ss]|[Ss][Uu][Cc][Cc][Ee][Ss][Ss]|[Ww][Oo][Rr][Kk][Ii][Nn][Gg]|[Cc][Oo][Mm][Pp][Ll][Ee][Tt][Ee]'

for report in "${REPORT_FILES[@]}"; do
  FEATURES_TESTED=$((FEATURES_TESTED + 1))
  echo "Processing: ${report}"

  CONTENT=$(cat "${report}")

  # ── Extract feature name from first # heading ──────────────────────────────
  FEATURE_NAME=""
  while IFS= read -r line; do
    if [[ "${line}" =~ ^#[[:space:]]+(.*) ]]; then
      FEATURE_NAME="${BASH_REMATCH[1]}"
      # Strip common prefixes
      FEATURE_NAME="${FEATURE_NAME#Feature Test Report: }"
      FEATURE_NAME="${FEATURE_NAME#Test Report: }"
      break
    fi
  done <<< "${CONTENT}"

  if [[ -z "${FEATURE_NAME}" ]]; then
    # Fallback: derive from filename
    FEATURE_NAME=$(basename "${report}" .md)
  fi

  # ── Detect pass/fail ───────────────────────────────────────────────────────
  FAIL_COUNT=$(echo "${CONTENT}" | grep -cE "${FAIL_PATTERN}" || true)
  PASS_COUNT=$(echo "${CONTENT}" | grep -cE "${PASS_PATTERN}" || true)

  if [[ ${FAIL_COUNT} -gt ${PASS_COUNT} ]]; then
    VERDICT="Fail"
    FEATURES_WITH_ISSUES=$((FEATURES_WITH_ISSUES + 1))
  else
    VERDICT="Pass"
    FEATURES_PASSED=$((FEATURES_PASSED + 1))
  fi

  echo "  Feature: ${FEATURE_NAME} — ${VERDICT} (fail=${FAIL_COUNT}, pass=${PASS_COUNT})"

  # ── Build table row ────────────────────────────────────────────────────────
  if [[ "${VERDICT}" == "Pass" ]]; then
    TABLE_ROWS+="| ${FEATURE_NAME} | :white_check_mark: Pass |"$'\n'
  else
    TABLE_ROWS+="| ${FEATURE_NAME} | :x: Fail |"$'\n'
  fi

  # ── Extract "Issues Found" section ─────────────────────────────────────────
  ISSUES=""
  IN_ISSUES=false
  while IFS= read -r line; do
    if [[ "${line}" =~ ^##[[:space:]]+Issues[[:space:]]+Found ]]; then
      IN_ISSUES=true
      continue
    fi
    if ${IN_ISSUES} && [[ "${line}" =~ ^##[[:space:]] ]]; then
      break
    fi
    if ${IN_ISSUES}; then
      ISSUES+="${line}"$'\n'
    fi
  done <<< "${CONTENT}"

  # Trim leading/trailing blank lines
  ISSUES=$(echo "${ISSUES}" | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba}')

  if [[ -n "${ISSUES}" ]]; then
    ALL_ISSUES+="#### ${FEATURE_NAME}"$'\n'"${ISSUES}"$'\n\n'
  fi

  # ── Extract "Suggestions" section ──────────────────────────────────────────
  SUGGESTIONS=""
  IN_SUGGESTIONS=false
  while IFS= read -r line; do
    if [[ "${line}" =~ ^##[[:space:]]+Suggestions ]]; then
      IN_SUGGESTIONS=true
      continue
    fi
    if ${IN_SUGGESTIONS} && [[ "${line}" =~ ^##[[:space:]] ]]; then
      break
    fi
    if ${IN_SUGGESTIONS}; then
      SUGGESTIONS+="${line}"$'\n'
    fi
  done <<< "${CONTENT}"

  # Trim leading/trailing blank lines
  SUGGESTIONS=$(echo "${SUGGESTIONS}" | sed '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba}')

  if [[ -n "${SUGGESTIONS}" ]]; then
    ALL_SUGGESTIONS+="#### ${FEATURE_NAME}"$'\n'"${SUGGESTIONS}"$'\n\n'
  fi

done

gh_endgroup

# ── Assemble comment ─────────────────────────────────────────────────────────
gh_group "Assembling comment"

COMMENT="## Agentic Test Results

**Features tested:** ${FEATURES_TESTED} | **Passed:** ${FEATURES_PASSED} | **Issues:** ${FEATURES_WITH_ISSUES}

| Feature | Verdict |
|---------|---------|
${TABLE_ROWS}"

if [[ -n "${ALL_ISSUES}" ]]; then
  COMMENT+="
### Issues Found
${ALL_ISSUES}"
fi

if [[ -n "${ALL_SUGGESTIONS}" ]]; then
  COMMENT+="
### Suggestions
${ALL_SUGGESTIONS}"
fi

COMMENT+="---
Full reports available as [workflow artifacts](../actions)."

# ── Truncate if over GitHub's comment size limit ─────────────────────────────
COMMENT_LENGTH=${#COMMENT}
if [[ ${COMMENT_LENGTH} -gt ${MAX_COMMENT_LENGTH} ]]; then
  gh_warning "Comment is ${COMMENT_LENGTH} chars, truncating to ${MAX_COMMENT_LENGTH}"
  TRUNCATION_MSG=$'\n\n> **Note:** This comment was truncated because it exceeded GitHub'\''s size limit. See the full reports in workflow artifacts.'
  TRUNCATED_LENGTH=$((MAX_COMMENT_LENGTH - ${#TRUNCATION_MSG}))
  COMMENT="${COMMENT:0:${TRUNCATED_LENGTH}}${TRUNCATION_MSG}"
fi

echo "Comment length: ${#COMMENT} chars"
gh_endgroup

# ── Post the comment ─────────────────────────────────────────────────────────
gh_group "Posting comment"

gh issue comment "${ISSUE_NUMBER}" --body "${COMMENT}"

echo "Posted agentic test results to #${ISSUE_NUMBER}"
gh_endgroup
