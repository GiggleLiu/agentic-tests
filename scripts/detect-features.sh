#!/bin/bash
# Detect which features or skills are affected by the current PR diff.
#
# Env vars (from action.yml):
#   INPUT_RUNNER     — "opencode" or "codex"
#   INPUT_MODE       — "feature", "skill", or "both"
#   INPUT_FEATURES   — "auto" or comma-separated list
#   INPUT_BASE_BRANCH — base branch for diff (default: origin/main)
#
# Output: writes one item per line to /tmp/affected-features.txt
set -euo pipefail

RUNNER="${INPUT_RUNNER:-opencode}"
MODE="${INPUT_MODE:-feature}"
FEATURES_INPUT="${INPUT_FEATURES:-${1:-auto}}"
BASE_BRANCH="${INPUT_BASE_BRANCH:-${2:-origin/main}}"
OUTPUT_FILE="/tmp/affected-features.txt"

echo "::group::Detecting affected targets (mode: ${MODE})"

if [ "$FEATURES_INPUT" != "auto" ]; then
  # Explicit list: split on commas, trim whitespace
  echo "$FEATURES_INPUT" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' > "$OUTPUT_FILE"
  echo "Using explicit list:"
  cat "$OUTPUT_FILE"
  echo "::endgroup::"
  exit 0
fi

# Gather context for OpenCode
DIFF=$(git diff "$BASE_BRANCH"...HEAD --stat --unified=3 2>/dev/null || git diff HEAD~1 --stat --unified=3)
DIFF_FILES=$(git diff "$BASE_BRANCH"...HEAD --name-only 2>/dev/null || git diff HEAD~1 --name-only)

# Collect project docs (truncate to keep prompt small)
PROJECT_DOCS=""
for doc in README.md CLAUDE.md AGENTS.md OPENCODE.md; do
  if [ -f "$doc" ]; then
    PROJECT_DOCS="${PROJECT_DOCS}
--- ${doc} ---
$(head -200 "$doc")
"
  fi
done

if [ -z "$PROJECT_DOCS" ]; then
  PROJECT_DOCS="No project documentation found. Infer from file structure."
fi

# Build mode-specific prompt
case "$MODE" in
  feature)
    TARGET_DESC="user-facing features (capabilities exposed to downstream users, e.g., 'authentication', 'REST API', 'CLI commands')"
    ;;
  skill)
    TARGET_DESC="skills (SKILL.md-based interaction protocols, e.g., 'test-skill', 'create-profile'). Look for SKILL.md files in the diff and skill directories."
    ;;
  both)
    TARGET_DESC="both user-facing features AND skills (SKILL.md-based interaction protocols). Label each as 'feature:name' or 'skill:name'."
    ;;
esac

PROMPT="You are analyzing a pull request to determine which ${TARGET_DESC} are affected.

Here are the changed files:
${DIFF_FILES}

Here is the diff summary:
${DIFF}

Here are the project docs:
${PROJECT_DOCS}

Based on the changed files and project documentation, identify which ${TARGET_DESC} are affected by this PR.

Return ONLY a JSON array of name strings. No explanation, no markdown, just the JSON array.
Example: [\"authentication\", \"REST API\"]
If nothing is affected, return: []"

# Call the agent runner
RUNNER_FAILED=false
EXIT_CODE=0
case "$RUNNER" in
  codex)
    RESPONSE=$(codex exec --full-auto --sandbox workspace-write "$PROMPT" 2>&1) || EXIT_CODE=$?
    ;;
  claude-code)
    RESPONSE=$(claude -p "$PROMPT" --allowedTools "Bash,Read,Glob,Grep" --no-session-persistence 2>&1) || EXIT_CODE=$?
    ;;
  *)
    RESPONSE=$(opencode -p "$PROMPT" -q -f text 2>&1) || EXIT_CODE=$?
    ;;
esac

if [ "$EXIT_CODE" -ne 0 ]; then
  RUNNER_FAILED=true
  echo "::warning::${RUNNER} failed (exit code ${EXIT_CODE}). Check API key and runner configuration."
  echo "::warning::Runner output: ${RESPONSE}"
  RESPONSE="[]"
fi

# Extract JSON array from response (runner may add extra text)
JSON=$(echo "$RESPONSE" | grep -o '\[.*\]' | head -1)
if [ -z "$JSON" ]; then
  echo "::warning::Could not parse response from ${RUNNER}. No targets detected."
  echo -n > "$OUTPUT_FILE"
  echo "::endgroup::"
  exit 0
fi

# Parse JSON array to one-per-line
echo "$JSON" | python3 -c "
import sys, json
items = json.load(sys.stdin)
for item in items:
    print(item)
" > "$OUTPUT_FILE"

COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
echo "Detected $COUNT affected target(s):"
cat "$OUTPUT_FILE"
echo "::endgroup::"
