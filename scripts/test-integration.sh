#!/usr/bin/env bash
set -euo pipefail

# test-integration.sh — Smoke-test installed agent runners.
#
# For each runner that is installed and has its API key set, sends a trivial
# prompt that requires a subagent, then checks the runner exits cleanly.
#
# Env vars (optional — tests are skipped when missing):
#   ANTHROPIC_API_KEY — needed for claude-code
#   OPENAI_API_KEY   — needed for codex
#   MOONSHOT_API_KEY / OPENAI_API_KEY — needed for opencode (provider-dependent)
#
# Usage:
#   ./scripts/test-integration.sh                  # auto-detect installed runners
#   ./scripts/test-integration.sh claude-code       # test a specific runner

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PASSED=0
FAILED=0
SKIPPED=0
TIMEOUT_SECS=120

# ── Helpers ──────────────────────────────────────────────────────────────────
pass()  { PASSED=$((PASSED + 1));   echo "  ✓ $1"; }
fail()  { FAILED=$((FAILED + 1));   echo "  ✗ $1"; }
skip()  { SKIPPED=$((SKIPPED + 1)); echo "  - $1 (skipped)"; }

# ── Determine which runners to test ─────────────────────────────────────────
if [[ $# -gt 0 ]]; then
  RUNNERS=("$@")
else
  RUNNERS=(claude-code codex opencode)
fi

echo "Runners to test: ${RUNNERS[*]}"
echo ""

# ── Setup sandbox for skills ─────────────────────────────────────────────────
SANDBOX=$(mktemp -d)
trap 'rm -rf "${SANDBOX}"' EXIT

# ══════════════════════════════════════════════════════════════════════════════
# Test: runner is installed
# ══════════════════════════════════════════════════════════════════════════════

echo "── runner installed ──"
echo ""

for runner in "${RUNNERS[@]}"; do
  case "${runner}" in
    claude-code) BIN=claude ;;
    codex)       BIN=codex ;;
    opencode)    BIN=opencode ;;
    *)           echo "Unknown runner: ${runner}"; exit 1 ;;
  esac

  if command -v "${BIN}" &>/dev/null; then
    pass "${runner} found ($(command -v "${BIN}"))"
  else
    skip "${runner} not installed"
  fi
done

# ══════════════════════════════════════════════════════════════════════════════
# Test: runner can execute a simple prompt (no subagent)
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "── simple prompt ──"
echo ""

SIMPLE_PROMPT="Respond with exactly: HELLO_AGENTIC_TEST"

for runner in "${RUNNERS[@]}"; do
  case "${runner}" in
    claude-code) BIN=claude;   KEY_VAR=ANTHROPIC_API_KEY ;;
    codex)       BIN=codex;    KEY_VAR=OPENAI_API_KEY ;;
    opencode)    BIN=opencode; KEY_VAR=OPENAI_API_KEY ;;
  esac

  if ! command -v "${BIN}" &>/dev/null; then
    skip "${runner}: not installed"
    continue
  fi
  if [[ -z "${!KEY_VAR:-}" ]]; then
    skip "${runner}: ${KEY_VAR} not set"
    continue
  fi

  LOG="${SANDBOX}/${runner}-simple.log"

  set +e
  case "${runner}" in
    claude-code)
      timeout "${TIMEOUT_SECS}" claude -p "${SIMPLE_PROMPT}" --no-session-persistence > "${LOG}" 2>&1
      ;;
    codex)
      timeout "${TIMEOUT_SECS}" codex exec --full-auto "${SIMPLE_PROMPT}" > "${LOG}" 2>&1
      ;;
    opencode)
      timeout "${TIMEOUT_SECS}" opencode -p "${SIMPLE_PROMPT}" -q > "${LOG}" 2>&1
      ;;
  esac
  RC=$?
  set -e

  if [[ ${RC} -eq 0 ]]; then
    pass "${runner}: exited cleanly"
  elif [[ ${RC} -eq 124 ]]; then
    fail "${runner}: timed out after ${TIMEOUT_SECS}s"
  else
    fail "${runner}: exited with code ${RC}"
  fi
done

# ══════════════════════════════════════════════════════════════════════════════
# Test: runner can spawn a subagent
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "── subagent prompt ──"
echo ""

SUBAGENT_PROMPT="Use the Agent tool to launch a subagent that responds with exactly: SUBAGENT_OK. Then respond with: MAIN_OK"

for runner in "${RUNNERS[@]}"; do
  case "${runner}" in
    claude-code) BIN=claude;   KEY_VAR=ANTHROPIC_API_KEY ;;
    codex)       BIN=codex;    KEY_VAR=OPENAI_API_KEY ;;
    opencode)    BIN=opencode; KEY_VAR=OPENAI_API_KEY ;;
  esac

  if ! command -v "${BIN}" &>/dev/null; then
    skip "${runner}: not installed"
    continue
  fi
  if [[ -z "${!KEY_VAR:-}" ]]; then
    skip "${runner}: ${KEY_VAR} not set"
    continue
  fi

  LOG="${SANDBOX}/${runner}-subagent.log"

  set +e
  case "${runner}" in
    claude-code)
      timeout "${TIMEOUT_SECS}" claude -p "${SUBAGENT_PROMPT}" \
        --allowedTools "Agent" --no-session-persistence > "${LOG}" 2>&1
      ;;
    codex)
      # Ensure multi_agent is enabled
      mkdir -p "${SANDBOX}/codex-home/.codex"
      cat > "${SANDBOX}/codex-home/.codex/config.toml" <<'TOML'
approval_policy = "never"
[features]
multi_agent = true
TOML
      HOME="${SANDBOX}/codex-home" \
        timeout "${TIMEOUT_SECS}" codex exec --full-auto "${SUBAGENT_PROMPT}" > "${LOG}" 2>&1
      ;;
    opencode)
      timeout "${TIMEOUT_SECS}" opencode -p "${SUBAGENT_PROMPT}" -q > "${LOG}" 2>&1
      ;;
  esac
  RC=$?
  set -e

  if [[ ${RC} -eq 0 ]]; then
    pass "${runner}: subagent exited cleanly"
  elif [[ ${RC} -eq 124 ]]; then
    fail "${runner}: subagent timed out after ${TIMEOUT_SECS}s"
  else
    fail "${runner}: subagent exited with code ${RC}"
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════"
echo "  ${PASSED} passed, ${FAILED} failed, ${SKIPPED} skipped"
echo "══════════════════════════"

[[ ${FAILED} -eq 0 ]]
