# GitHub Action Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a GitHub Action that downstream projects use to run agentic tests (via OpenCode) on PR-affected features, posting results as PR comments with full reports as artifacts.

**Architecture:** Composite GitHub Action with 4 shell scripts. OpenCode runs headlessly to detect affected features from the PR diff, then runs `/test-feature` for each. Reports are uploaded as artifacts and summarized in a PR comment.

**Tech Stack:** GitHub Actions (composite action), Bash, OpenCode CLI, `gh` CLI

**Design doc:** `docs/plans/2026-03-08-github-action-design.md`

---

### Task 1: action.yml — Action Metadata

**Files:**
- Create: `action.yml`

**Step 1: Write action.yml**

```yaml
name: 'Agentic Tests'
description: 'Run AI-simulated user tests on PR-affected features using OpenCode'
author: 'Jin-Guo Liu'

inputs:
  provider:
    description: 'LLM provider: anthropic, openai, moonshot, etc.'
    required: true
  model:
    description: 'Model to use (e.g. claude-sonnet-4-6). Defaults to provider default.'
    required: false
    default: ''
  features:
    description: '"auto" to AI-detect from diff, or comma-separated feature list'
    required: false
    default: 'auto'
  profiles-dir:
    description: 'Directory containing saved agent profiles'
    required: false
    default: 'docs/agent-profiles'
  base-branch:
    description: 'Base branch for diff comparison'
    required: false
    default: 'origin/main'

outputs:
  features-tested:
    description: 'Comma-separated feature names that were tested'
    value: ${{ steps.test.outputs.features-tested }}
  pass:
    description: 'true if no critical issues found'
    value: ${{ steps.test.outputs.pass }}

runs:
  using: 'composite'
  steps:
    - name: Install OpenCode
      shell: bash
      run: ${{ github.action_path }}/scripts/install-opencode.sh

    - name: Configure OpenCode
      shell: bash
      run: |
        cat > .opencode.json <<EOF
        {
          "provider": "${{ inputs.provider }}",
          "agents": {
            "coder": {
              "model": "${{ inputs.model }}"
            }
          }
        }
        EOF

    - name: Install agentic-tests commands
      shell: bash
      run: |
        CMDS_DIR="${HOME}/.config/opencode/commands"
        mkdir -p "$CMDS_DIR"
        for skill_dir in "${{ github.action_path }}"/skills/*/; do
          skill_name=$(basename "$skill_dir")
          if [ -f "$skill_dir/SKILL.md" ]; then
            cp "$skill_dir/SKILL.md" "$CMDS_DIR/${skill_name}.md"
          fi
        done

    - name: Detect affected features
      id: detect
      shell: bash
      run: |
        ${{ github.action_path }}/scripts/detect-features.sh \
          "${{ inputs.features }}" \
          "${{ inputs.base-branch }}"

    - name: Run agentic tests
      id: test
      shell: bash
      run: |
        ${{ github.action_path }}/scripts/run-tests.sh \
          "${{ inputs.profiles-dir }}"

    - name: Upload test reports
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: agentic-test-reports
        path: docs/test-reports/*.md
        if-no-files-found: ignore

    - name: Post PR comment
      if: always() && github.event_name == 'pull_request'
      shell: bash
      env:
        GH_TOKEN: ${{ github.token }}
      run: |
        ${{ github.action_path }}/scripts/post-comment.sh \
          "${{ github.event.pull_request.number }}"
```

**Step 2: Verify action.yml is valid YAML**

Run: `python3 -c "import yaml; yaml.safe_load(open('action.yml'))"`
Expected: No output (valid YAML)

**Step 3: Commit**

```bash
git add action.yml
git commit -m "feat: add action.yml for GitHub Action metadata"
```

---

### Task 2: scripts/install-opencode.sh

**Files:**
- Create: `scripts/install-opencode.sh`

**Step 1: Write the install script**

```bash
#!/bin/bash
# Install OpenCode CLI for Linux amd64 (GitHub Actions runner)
set -euo pipefail

echo "::group::Installing OpenCode"

# Check if already installed
if command -v opencode &>/dev/null; then
  echo "OpenCode already installed: $(opencode --version)"
  echo "::endgroup::"
  exit 0
fi

# Download latest release
INSTALL_DIR="/usr/local/bin"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Get latest release URL from GitHub API
RELEASE_URL=$(curl -sL "https://api.github.com/repos/opencode-ai/opencode/releases/latest" \
  | grep -o '"browser_download_url":[[:space:]]*"[^"]*linux.*amd64[^"]*"' \
  | head -1 \
  | sed 's/"browser_download_url":[[:space:]]*"//;s/"$//')

if [ -z "$RELEASE_URL" ]; then
  echo "::error::Failed to find OpenCode release for linux-amd64"
  exit 1
fi

echo "Downloading from: $RELEASE_URL"
curl -sL "$RELEASE_URL" -o "$TEMP_DIR/opencode-archive"

# Detect archive type and extract
case "$RELEASE_URL" in
  *.tar.gz) tar -xzf "$TEMP_DIR/opencode-archive" -C "$TEMP_DIR" ;;
  *.zip)    unzip -q "$TEMP_DIR/opencode-archive" -d "$TEMP_DIR" ;;
  *)
    # Might be a raw binary
    chmod +x "$TEMP_DIR/opencode-archive"
    cp "$TEMP_DIR/opencode-archive" "$TEMP_DIR/opencode"
    ;;
esac

# Find and install the binary
BINARY=$(find "$TEMP_DIR" -name "opencode" -type f | head -1)
if [ -z "$BINARY" ]; then
  echo "::error::Could not find opencode binary in release archive"
  exit 1
fi

chmod +x "$BINARY"
sudo mv "$BINARY" "$INSTALL_DIR/opencode"

echo "Installed: $(opencode --version)"
echo "::endgroup::"
```

**Step 2: Make executable**

Run: `chmod +x scripts/install-opencode.sh`

**Step 3: Commit**

```bash
git add scripts/install-opencode.sh
git commit -m "feat: add OpenCode install script for CI"
```

---

### Task 3: scripts/detect-features.sh

**Files:**
- Create: `scripts/detect-features.sh`

**Step 1: Write the feature detection script**

This script either uses an explicit feature list or calls OpenCode to infer affected features from the PR diff.

```bash
#!/bin/bash
# Detect which features are affected by the current PR diff.
# Usage: ./detect-features.sh <features-input> <base-branch>
#
# If features-input is "auto", uses OpenCode to infer from diff + project docs.
# Otherwise, treats it as a comma-separated list of feature names.
#
# Output: writes one feature per line to /tmp/affected-features.txt
set -euo pipefail

FEATURES_INPUT="${1:-auto}"
BASE_BRANCH="${2:-origin/main}"
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
```

**Step 2: Make executable**

Run: `chmod +x scripts/detect-features.sh`

**Step 3: Commit**

```bash
git add scripts/detect-features.sh
git commit -m "feat: add feature detection script (AI-inferred from PR diff)"
```

---

### Task 4: scripts/run-tests.sh

**Files:**
- Create: `scripts/run-tests.sh`

**Step 1: Write the test runner script**

Iterates over detected features, finds matching profiles, runs `/test-feature` for each.

```bash
#!/bin/bash
# Run agentic tests for each detected feature.
# Usage: ./run-tests.sh <profiles-dir>
#
# Reads features from /tmp/affected-features.txt (one per line).
# Writes test reports to docs/test-reports/.
# Sets outputs: features-tested, pass
set -euo pipefail

PROFILES_DIR="${1:-docs/agent-profiles}"
FEATURES_FILE="/tmp/affected-features.txt"
REPORTS_DIR="docs/test-reports"

mkdir -p "$REPORTS_DIR"

if [ ! -s "$FEATURES_FILE" ]; then
  echo "No features to test."
  echo "features-tested=" >> "$GITHUB_OUTPUT"
  echo "pass=true" >> "$GITHUB_OUTPUT"
  exit 0
fi

TESTED=""
ALL_PASS=true

while IFS= read -r feature; do
  [ -z "$feature" ] && continue

  echo "::group::Testing feature: $feature"

  # Normalize feature name for file matching (lowercase, spaces to hyphens)
  FEATURE_SLUG=$(echo "$feature" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')

  # Look for a matching profile
  PROFILE_PATH=""
  if [ -d "$PROFILES_DIR" ]; then
    PROFILE_PATH=$(find "$PROFILES_DIR" -name "${FEATURE_SLUG}-*.md" -type f | head -1)
  fi

  # Build the test-feature invocation
  if [ -n "$PROFILE_PATH" ]; then
    echo "Found profile: $PROFILE_PATH"
    PROMPT="/test-feature $PROFILE_PATH"
  else
    echo "No profile found, using feature name"
    PROMPT="/test-feature $feature"
  fi

  # Run OpenCode
  if opencode -p "$PROMPT" -q 2>&1 | tee "/tmp/test-${FEATURE_SLUG}.log"; then
    echo "Feature '$feature' test completed."
  else
    echo "::warning::Feature '$feature' test exited with error"
    ALL_PASS=false
  fi

  # Check if reports were generated
  NEW_REPORTS=$(find "$REPORTS_DIR" -name "*.md" -newer "$FEATURES_FILE" -type f 2>/dev/null)
  if [ -z "$NEW_REPORTS" ]; then
    echo "::warning::No test report generated for '$feature'"
    ALL_PASS=false
  fi

  # Build tested list
  if [ -n "$TESTED" ]; then
    TESTED="${TESTED},${feature}"
  else
    TESTED="$feature"
  fi

  echo "::endgroup::"
done < "$FEATURES_FILE"

echo "features-tested=$TESTED" >> "$GITHUB_OUTPUT"
echo "pass=$ALL_PASS" >> "$GITHUB_OUTPUT"

echo "Tests complete. Features tested: $TESTED"
echo "All passed: $ALL_PASS"
```

**Step 2: Make executable**

Run: `chmod +x scripts/run-tests.sh`

**Step 3: Commit**

```bash
git add scripts/run-tests.sh
git commit -m "feat: add test runner script for per-feature agentic tests"
```

---

### Task 5: scripts/post-comment.sh

**Files:**
- Create: `scripts/post-comment.sh`

**Step 1: Write the PR comment script**

Reads test reports, assembles a summary comment, posts to the PR.

```bash
#!/bin/bash
# Post agentic test results as a PR comment.
# Usage: ./post-comment.sh <pr-number>
#
# Reads reports from docs/test-reports/.
# Requires GH_TOKEN env var and gh CLI.
set -euo pipefail

PR_NUMBER="${1:?Usage: $0 <pr-number>}"
REPORTS_DIR="docs/test-reports"

echo "::group::Posting PR comment"

# Collect all reports
REPORTS=$(find "$REPORTS_DIR" -name "*.md" -type f 2>/dev/null | sort)

if [ -z "$REPORTS" ]; then
  COMMENT="## Agentic Test Results

No features were affected by this PR, or no test reports were generated.
"
  gh pr comment "$PR_NUMBER" --body "$COMMENT"
  echo "::endgroup::"
  exit 0
fi

# Parse reports and build summary
TOTAL=0
PASSED=0
ISSUES=0
TABLE_ROWS=""
ISSUES_LIST=""
SUGGESTIONS_LIST=""

for report in $REPORTS; do
  TOTAL=$((TOTAL + 1))
  FILENAME=$(basename "$report" .md)

  # Extract feature name from report (first heading after "# ")
  FEATURE_NAME=$(grep -m1 '^# ' "$report" | sed 's/^# //' | sed 's/Feature Test Report: //' | sed 's/Test Report: //')
  [ -z "$FEATURE_NAME" ] && FEATURE_NAME="$FILENAME"

  # Check for failure indicators in the report
  HAS_FAIL=$(grep -ciE 'fail|error|broken|missing|not found|does not|cannot' "$report" || true)
  HAS_PASS=$(grep -ciE 'pass|success|works|correct' "$report" || true)

  if [ "$HAS_FAIL" -gt 2 ]; then
    VERDICT="Fail"
    ISSUES=$((ISSUES + 1))
  else
    VERDICT="Pass"
    PASSED=$((PASSED + 1))
  fi

  TABLE_ROWS="${TABLE_ROWS}| ${FEATURE_NAME} | ${VERDICT} |
"

  # Extract issues section if present
  FEATURE_ISSUES=$(sed -n '/^## Issues Found/,/^## /p' "$report" | head -20 | tail -n +2)
  if [ -n "$FEATURE_ISSUES" ]; then
    ISSUES_LIST="${ISSUES_LIST}
${FEATURE_ISSUES}"
  fi

  # Extract suggestions section if present
  FEATURE_SUGGESTIONS=$(sed -n '/^## Suggestions/,/^## /p' "$report" | head -20 | tail -n +2)
  if [ -n "$FEATURE_SUGGESTIONS" ]; then
    SUGGESTIONS_LIST="${SUGGESTIONS_LIST}
${FEATURE_SUGGESTIONS}"
  fi
done

# Assemble comment
COMMENT="## Agentic Test Results

**Features tested:** ${TOTAL} | **Passed:** ${PASSED} | **Issues:** ${ISSUES}

| Feature | Verdict |
|---------|---------|
${TABLE_ROWS}"

if [ -n "$ISSUES_LIST" ]; then
  COMMENT="${COMMENT}
### Issues Found
${ISSUES_LIST}"
fi

if [ -n "$SUGGESTIONS_LIST" ]; then
  COMMENT="${COMMENT}
### Suggestions
${SUGGESTIONS_LIST}"
fi

COMMENT="${COMMENT}

---
Full reports available as [workflow artifacts](../actions).
"

# GitHub comment size limit is ~65536 chars
COMMENT_LEN=${#COMMENT}
if [ "$COMMENT_LEN" -gt 60000 ]; then
  COMMENT="${COMMENT:0:59900}

...(truncated — download full reports from artifacts)"
fi

gh pr comment "$PR_NUMBER" --body "$COMMENT"

echo "Posted comment to PR #${PR_NUMBER} (${COMMENT_LEN} chars)"
echo "::endgroup::"
```

**Step 2: Make executable**

Run: `chmod +x scripts/post-comment.sh`

**Step 3: Commit**

```bash
git add scripts/post-comment.sh
git commit -m "feat: add PR comment script for test result summary"
```

---

### Task 6: Example Caller Workflow

**Files:**
- Create: `examples/agentic-test.yml`

**Step 1: Write example workflow**

A ready-to-copy workflow file for downstream repos.

```yaml
# Example: .github/workflows/agentic-test.yml
# Copy this file to your repo's .github/workflows/ directory.
#
# Required setup:
#   1. Add your LLM API key as a repository secret
#      (e.g., ANTHROPIC_API_KEY, OPENAI_API_KEY, or MOONSHOT_API_KEY)
#   2. Customize the trigger (on:) to match your workflow
#
# Optional: Add agent profiles to docs/agent-profiles/ for richer testing.
# See: https://github.com/GiggleLiu/agentic-tests#agent-profiles

name: Agentic Tests
on:
  pull_request:
    types: [opened, synchronize]
  workflow_dispatch:

permissions:
  pull-requests: write
  contents: read

jobs:
  agentic-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: GiggleLiu/agentic-tests@v1
        with:
          provider: anthropic
          # model: claude-sonnet-4-6  # optional: override default model
          # features: auto            # optional: "auto" or "auth,api,cli"
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Step 2: Commit**

```bash
git add examples/agentic-test.yml
git commit -m "docs: add example caller workflow for downstream repos"
```

---

### Task 7: Update CLAUDE.md and README

**Files:**
- Modify: `CLAUDE.md`
- Modify: `README.md`

**Step 1: Add CI section to CLAUDE.md**

Add after the Installation section:

```markdown
## GitHub Action (CI)

Downstream projects can run agentic tests in CI via the GitHub Action:

```yaml
- uses: GiggleLiu/agentic-tests@v1
  with:
    provider: anthropic
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

The action:
1. Installs OpenCode and agentic-tests commands
2. Detects features affected by the PR diff (AI-inferred)
3. Runs `/test-feature` for each affected feature
4. Posts results as a PR comment + uploads full reports as artifacts

See `examples/agentic-test.yml` for a ready-to-copy workflow.
```

**Step 2: Add CI section to README.md**

Add a "CI Integration" section with the same example workflow and a brief explanation.

**Step 3: Add new key files to CLAUDE.md**

Update the Key Files section to include:
```markdown
- `action.yml` — GitHub Action metadata (composite action)
- `scripts/` — CI helper scripts (install, detect, test, comment)
- `examples/agentic-test.yml` — Example workflow for downstream repos
```

**Step 4: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: add GitHub Action CI documentation"
```

---

### Task 8: End-to-End Validation

**Step 1: Validate action.yml structure**

Run: `python3 -c "import yaml; d=yaml.safe_load(open('action.yml')); assert 'inputs' in d; assert 'runs' in d; print('action.yml valid')"`
Expected: `action.yml valid`

**Step 2: Validate all scripts are executable**

Run: `ls -la scripts/*.sh | awk '{print $1, $NF}'`
Expected: All scripts show `-rwxr-xr-x`

**Step 3: Shellcheck all scripts**

Run: `shellcheck scripts/*.sh || true`
Expected: No critical errors (warnings are OK)

**Step 4: Verify file structure**

Run: `find . -name "*.sh" -o -name "action.yml" -o -name "*.yml" -path "*/examples/*" | sort`
Expected:
```
./action.yml
./examples/agentic-test.yml
./scripts/detect-features.sh
./scripts/install-opencode.sh
./scripts/post-comment.sh
./scripts/run-tests.sh
```

**Step 5: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: address validation issues"
```
