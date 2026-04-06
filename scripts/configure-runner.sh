#!/usr/bin/env bash
set -euo pipefail

# configure-runner.sh — Write runner-specific configuration.
#
# Env vars:
#   INPUT_RUNNER   — "opencode", "codex", or "claude-code"
#   INPUT_MODEL    — Model override (optional)
#   INPUT_PROVIDER — LLM provider name (required for codex/opencode)

RUNNER="${INPUT_RUNNER:-opencode}"
MODEL="${INPUT_MODEL:-}"
PROVIDER="${INPUT_PROVIDER:-}"

# ── Helper: GitHub Actions log annotations ───────────────────────────────────
gh_group()    { echo "::group::$1"; }
gh_endgroup() { echo "::endgroup::"; }

gh_group "Configuring ${RUNNER}"

case "${RUNNER}" in
  codex)
    mkdir -p ~/.codex
    {
      echo "model = \"${MODEL:-gpt-5.4}\""
      echo "model_provider = \"${PROVIDER}\""
      echo "approval_policy = \"never\""
      echo ""
      echo "[features]"
      echo "multi_agent = true"
    } > ~/.codex/config.toml
    # Authenticate codex with API key
    if [ -n "${OPENAI_API_KEY:-}" ]; then
      printf '%s' "$OPENAI_API_KEY" | codex login --with-api-key
    fi
    echo "Wrote ~/.codex/config.toml"
    ;;
  claude-code)
    export ANTHROPIC_MODEL="${MODEL:-claude-opus-4-6}"
    echo "ANTHROPIC_MODEL=${MODEL:-claude-opus-4-6}" >> "${GITHUB_ENV:-/dev/null}"
    echo "Set ANTHROPIC_MODEL=${MODEL:-claude-opus-4-6}"
    ;;
  *)
    python3 -c "
import json
config = {'provider': '${PROVIDER}'}
model = '${MODEL}'
if model:
    config['agents'] = {'coder': {'model': model}}
with open('.opencode.json', 'w') as f:
    json.dump(config, f, indent=2)
"
    echo "Wrote .opencode.json"
    ;;
esac

gh_endgroup
