#!/bin/bash
# Detect which features are affected by the current PR diff.
# Usage: ./detect-features.sh <features-input> <base-branch>
#
# If features-input is "auto", uses OpenCode to infer from diff + project docs.
# Otherwise, treats it as a comma-separated list of feature names.
#
# Output: writes one feature per line to /tmp/affected-features.txt
set -euo pipefail

FEATURES_INPUT="${INPUT_FEATURES:-${1:-auto}}"
BASE_BRANCH="${INPUT_BASE_BRANCH:-${2:-origin/main}}"
OUTPUT_FILE="/tmp/affected-features.txt"

echo "::group::Detecting affected features"

if [ "$FEATURES_INPUT" != "auto" ]; then
  # Explicit list: split on commas, trim whitespace
  echo "$FEATURES_INPUT" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' > "$OUTPUT_FILE"
  echo "Using explicit feature list:"
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
  PROJECT_DOCS="No project documentation found. Infer features from file structure."
fi

# Build prompt
PROMPT="You are analyzing a pull request to determine which user-facing features are affected.

Here are the changed files:
${DIFF_FILES}

Here is the diff summary:
${DIFF}

Here are the project docs:
${PROJECT_DOCS}

Based on the changed files and project documentation, identify which user-facing features are affected by this PR.
A 'feature' is a capability exposed to downstream users (e.g., 'authentication', 'REST API', 'CLI commands', 'plugin system').

Return ONLY a JSON array of feature name strings. No explanation, no markdown, just the JSON array.
Example: [\"authentication\", \"REST API\"]
If no user-facing features are affected, return: []"

# Call OpenCode
RESPONSE=$(opencode -p "$PROMPT" -q -f text 2>/dev/null || echo "[]")

# Extract JSON array from response (OpenCode may add extra text)
JSON=$(echo "$RESPONSE" | grep -o '\[.*\]' | head -1)
if [ -z "$JSON" ]; then
  echo "::warning::Could not parse feature list from OpenCode response. No features detected."
  echo -n > "$OUTPUT_FILE"
  echo "::endgroup::"
  exit 0
fi

# Parse JSON array to one-per-line (using python for reliability)
echo "$JSON" | python3 -c "
import sys, json
features = json.load(sys.stdin)
for f in features:
    print(f)
" > "$OUTPUT_FILE"

FEATURE_COUNT=$(wc -l < "$OUTPUT_FILE" | tr -d ' ')
echo "Detected $FEATURE_COUNT affected feature(s):"
cat "$OUTPUT_FILE"
echo "::endgroup::"
