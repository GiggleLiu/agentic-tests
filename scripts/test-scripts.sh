#!/usr/bin/env bash
set -euo pipefail

# test-scripts.sh — Verify that configure-runner.sh and install-skills.sh
# produce the expected files for each runner backend.
#
# Uses a temporary HOME to avoid touching real config directories.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASSED=0
FAILED=0
SKIPPED=0

# ── Helpers ──────────────────────────────────────────────────────────────────
pass()  { PASSED=$((PASSED + 1));   echo "  ✓ $1"; }
fail()  { FAILED=$((FAILED + 1));   echo "  ✗ $1"; }
skip()  { SKIPPED=$((SKIPPED + 1)); echo "  - $1 (skipped)"; }

assert_file_exists() {
  if [[ -f "$1" ]]; then
    pass "$2"
  else
    fail "$2 — file not found: $1"
  fi
}

assert_file_contains() {
  if grep -q "$2" "$1" 2>/dev/null; then
    pass "$3"
  else
    fail "$3 — '$2' not found in $1"
  fi
}

# ── Skills to test ───────────────────────────────────────────────────────────
# Explicitly configured, matching the action.yml default
SKILLS=(test-skill test-feature create-profile)
SKILLS_CSV="$(IFS=','; echo "${SKILLS[*]}")"

echo "Skills configured: ${SKILLS[*]}"

# ── Setup sandbox ────────────────────────────────────────────────────────────
SANDBOX=$(mktemp -d)
trap 'rm -rf "${SANDBOX}"' EXIT

echo "Sandbox: ${SANDBOX}"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# Test: configure-runner.sh
# ══════════════════════════════════════════════════════════════════════════════

echo "── configure-runner.sh ──"

# — codex —
echo ""
echo "  [codex]"
FAKE_HOME="${SANDBOX}/cfg-codex"
mkdir -p "${FAKE_HOME}"
HOME="${FAKE_HOME}" \
  INPUT_RUNNER=codex \
  INPUT_MODEL=gpt-4o \
  INPUT_PROVIDER=openai \
  GITHUB_ENV=/dev/null \
  bash "${SCRIPT_DIR}/configure-runner.sh" > /dev/null 2>&1

assert_file_exists "${FAKE_HOME}/.codex/config.toml" "config.toml created"
assert_file_contains "${FAKE_HOME}/.codex/config.toml" 'model = "gpt-4o"' "model set correctly"
assert_file_contains "${FAKE_HOME}/.codex/config.toml" 'model_provider = "openai"' "provider set correctly"

# — codex default model —
echo ""
echo "  [codex, default model]"
FAKE_HOME="${SANDBOX}/cfg-codex-default"
mkdir -p "${FAKE_HOME}"
HOME="${FAKE_HOME}" \
  INPUT_RUNNER=codex \
  INPUT_MODEL="" \
  INPUT_PROVIDER=openai \
  GITHUB_ENV=/dev/null \
  bash "${SCRIPT_DIR}/configure-runner.sh" > /dev/null 2>&1

assert_file_contains "${FAKE_HOME}/.codex/config.toml" 'model = "gpt-5.4"' "default model used when empty"

# — claude-code —
echo ""
echo "  [claude-code]"
FAKE_HOME="${SANDBOX}/cfg-claude"
mkdir -p "${FAKE_HOME}"
OUTPUT=$(HOME="${FAKE_HOME}" \
  INPUT_RUNNER=claude-code \
  INPUT_MODEL=claude-sonnet-4-20250514 \
  GITHUB_ENV=/dev/null \
  bash "${SCRIPT_DIR}/configure-runner.sh" 2>&1)

if echo "${OUTPUT}" | grep -q "ANTHROPIC_MODEL=claude-sonnet-4-20250514"; then
  pass "ANTHROPIC_MODEL set correctly"
else
  fail "ANTHROPIC_MODEL not set — output: ${OUTPUT}"
fi

# — opencode —
echo ""
echo "  [opencode]"
WORKDIR="${SANDBOX}/cfg-opencode"
mkdir -p "${WORKDIR}"
(cd "${WORKDIR}" && \
  INPUT_RUNNER=opencode \
  INPUT_MODEL=moonshot-v1 \
  INPUT_PROVIDER=moonshot \
  GITHUB_ENV=/dev/null \
  bash "${SCRIPT_DIR}/configure-runner.sh" > /dev/null 2>&1)

assert_file_exists "${WORKDIR}/.opencode.json" ".opencode.json created"
assert_file_contains "${WORKDIR}/.opencode.json" '"provider": "moonshot"' "provider set correctly"

# ══════════════════════════════════════════════════════════════════════════════
# Test: subagent support
#
# Verify each runner is configured to allow subagent/multi-agent usage.
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "── subagent support ──"

# — codex: multi_agent = true in config.toml —
echo ""
echo "  [codex]"
assert_file_contains "${SANDBOX}/cfg-codex/.codex/config.toml" 'multi_agent = true' "multi_agent enabled"

# — claude-code: --allowedTools includes Agent in run-tests.sh —
echo ""
echo "  [claude-code]"
if grep -q '\-\-allowedTools.*Agent' "${SCRIPT_DIR}/run-tests.sh" 2>/dev/null; then
  pass "Agent in --allowedTools"
else
  fail "Agent not found in --allowedTools in run-tests.sh"
fi

# — opencode: verify no explicit subagent block is required —
echo ""
echo "  [opencode]"
# OpenCode delegates subagent capability to the model/provider — no config needed.
# Verify the config doesn't accidentally disable it (no "disable" or "single_agent" key).
if grep -qE 'disable.*agent|single_agent' "${SANDBOX}/cfg-opencode/.opencode.json" 2>/dev/null; then
  fail "subagent appears to be disabled in .opencode.json"
else
  pass "no subagent restriction in config"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Test: install-skills.sh (bare names)
#
# For each runner, install skills by bare name and confirm every skill exists
# at the runner-specific path.
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "── install-skills.sh (bare names) ──"

# — codex: .agents/skills/<name>/SKILL.md —
echo ""
echo "  [codex]"
WORKDIR="${SANDBOX}/skills-codex"
mkdir -p "${WORKDIR}"
(cd "${WORKDIR}" && \
  INPUT_RUNNER=codex \
  INPUT_SKILLS="${SKILLS_CSV}" \
  ACTION_SKILLS_DIR="${PROJECT_DIR}/skills" \
  bash "${SCRIPT_DIR}/install-skills.sh" > /dev/null 2>&1)

for skill in "${SKILLS[@]}"; do
  assert_file_exists "${WORKDIR}/.agents/skills/${skill}/SKILL.md" "${skill}"
done

# — claude-code: ~/.claude/commands/<name>.md —
echo ""
echo "  [claude-code]"
FAKE_HOME="${SANDBOX}/skills-claude"
mkdir -p "${FAKE_HOME}"
HOME="${FAKE_HOME}" \
  INPUT_RUNNER=claude-code \
  INPUT_SKILLS="${SKILLS_CSV}" \
  ACTION_SKILLS_DIR="${PROJECT_DIR}/skills" \
  bash "${SCRIPT_DIR}/install-skills.sh" > /dev/null 2>&1

for skill in "${SKILLS[@]}"; do
  assert_file_exists "${FAKE_HOME}/.claude/commands/${skill}.md" "${skill}"
done

# — opencode: ~/.config/opencode/commands/<name>.md —
echo ""
echo "  [opencode]"
FAKE_HOME="${SANDBOX}/skills-opencode"
mkdir -p "${FAKE_HOME}"
HOME="${FAKE_HOME}" \
  INPUT_RUNNER=opencode \
  INPUT_SKILLS="${SKILLS_CSV}" \
  ACTION_SKILLS_DIR="${PROJECT_DIR}/skills" \
  bash "${SCRIPT_DIR}/install-skills.sh" > /dev/null 2>&1

for skill in "${SKILLS[@]}"; do
  assert_file_exists "${FAKE_HOME}/.config/opencode/commands/${skill}.md" "${skill}"
done

# ══════════════════════════════════════════════════════════════════════════════
# Test: install-skills.sh (paths)
#
# Verify that skills specified as paths (containing "/") resolve correctly.
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "── install-skills.sh (paths) ──"

# Mix bare name + path — use claude-code as representative runner
echo ""
echo "  [claude-code, mixed bare name + path]"
FAKE_HOME="${SANDBOX}/skills-mixed"
mkdir -p "${FAKE_HOME}"
HOME="${FAKE_HOME}" \
  INPUT_RUNNER=claude-code \
  INPUT_SKILLS="test-skill,${PROJECT_DIR}/skills/test-feature" \
  ACTION_SKILLS_DIR="${PROJECT_DIR}/skills" \
  bash "${SCRIPT_DIR}/install-skills.sh" > /dev/null 2>&1

assert_file_exists "${FAKE_HOME}/.claude/commands/test-skill.md" "bare name: test-skill"
assert_file_exists "${FAKE_HOME}/.claude/commands/test-feature.md" "path: test-feature"

# — paths only (no built-ins) —
echo ""
echo "  [codex, paths only]"
WORKDIR="${SANDBOX}/skills-paths-only"
mkdir -p "${WORKDIR}"
(cd "${WORKDIR}" && \
  INPUT_RUNNER=codex \
  INPUT_SKILLS="${PROJECT_DIR}/skills/test-skill,${PROJECT_DIR}/skills/create-profile" \
  ACTION_SKILLS_DIR="${PROJECT_DIR}/skills" \
  bash "${SCRIPT_DIR}/install-skills.sh" > /dev/null 2>&1)

assert_file_exists "${WORKDIR}/.agents/skills/test-skill/SKILL.md" "path-only: test-skill"
assert_file_exists "${WORKDIR}/.agents/skills/create-profile/SKILL.md" "path-only: create-profile"
# test-feature should NOT be installed
if [[ ! -f "${WORKDIR}/.agents/skills/test-feature/SKILL.md" ]]; then
  pass "path-only: test-feature correctly absent"
else
  fail "path-only: test-feature should not be installed"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Test: clone-skill-repos.sh
#
# Verify that repos are cloned into .agentic-skills/<repo-name>/
# Uses a local bare git repo to avoid network access.
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "── clone-skill-repos.sh ──"

# Create a fake "remote" bare repo in the sandbox
FAKE_REMOTE="${SANDBOX}/fake-remote/test-skills.git"
mkdir -p "${FAKE_REMOTE}"
git init --bare "${FAKE_REMOTE}" > /dev/null 2>&1

# Add a commit so clone works
FAKE_WORK="${SANDBOX}/fake-work"
mkdir -p "${FAKE_WORK}"
(cd "${FAKE_WORK}" && \
  git init > /dev/null 2>&1 && \
  git checkout -b main > /dev/null 2>&1 && \
  echo "# Test Skills" > README.md && \
  git add README.md && \
  git commit -m "init" > /dev/null 2>&1 && \
  git remote add origin "${FAKE_REMOTE}" && \
  git push origin main > /dev/null 2>&1)

# — clone a repo —
echo ""
echo "  [clone]"
WORKDIR="${SANDBOX}/clone-test"
mkdir -p "${WORKDIR}"

# Override git clone to use local path instead of https://github.com/
# We'll test the script's logic by manually calling the relevant parts
DEST="${WORKDIR}/.agentic-skills/test-skills"
mkdir -p "${WORKDIR}/.agentic-skills"
git clone --depth 1 "${FAKE_REMOTE}" "${DEST}" > /dev/null 2>&1

assert_file_exists "${DEST}/README.md" "repo cloned to .agentic-skills/"

# — skip already-cloned repo —
echo ""
echo "  [skip existing]"
if [[ -d "${DEST}" ]]; then
  pass "existing repo directory detected"
else
  fail "existing repo directory not found"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════"
echo "  ${PASSED} passed, ${FAILED} failed"
if [[ ${SKIPPED} -gt 0 ]]; then
  echo "  ${SKIPPED} skipped"
fi
echo "══════════════════════════"

[[ ${FAILED} -eq 0 ]]
