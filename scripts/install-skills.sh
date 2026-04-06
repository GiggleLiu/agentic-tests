#!/usr/bin/env bash
set -euo pipefail

# install-skills.sh — Install skills into the runner's command directory.
#
# Skills are specified as a comma-separated list. Each entry is either:
#   - A bare name (e.g., "test-skill") — resolved against ACTION_SKILLS_DIR
#   - A path containing "/" (e.g., "./my-skills/custom") — resolved as-is
#
# Each resolved directory must contain a SKILL.md file.
#
# Env vars:
#   INPUT_RUNNER       — "opencode", "codex", or "claude-code"
#   INPUT_SKILLS       — Comma-separated list of skills to install
#   ACTION_SKILLS_DIR  — Base directory for resolving bare skill names

RUNNER="${INPUT_RUNNER:-opencode}"
INPUT_SKILLS="${INPUT_SKILLS:-}"
ACTION_SKILLS_DIR="${ACTION_SKILLS_DIR:-$(cd "$(dirname "$0")/.." && pwd)/skills}"

# ── Helpers ──────────────────────────────────────────────────────────────────
gh_group()    { echo "::group::$1"; }
gh_endgroup() { echo "::endgroup::"; }
gh_error()    { echo "::error::$1"; }

if [[ -z "${INPUT_SKILLS}" ]]; then
  gh_error "INPUT_SKILLS is empty — no skills to install"
  exit 1
fi

gh_group "Installing skills for ${RUNNER}"

INSTALLED=0

IFS=',' read -ra ENTRIES <<< "${INPUT_SKILLS}"
for entry in "${ENTRIES[@]}"; do
  entry="$(echo "${entry}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "${entry}" ]] && continue

  # Resolve: bare name or path
  if [[ "${entry}" == */* ]]; then
    skill_dir="${entry}"
  else
    skill_dir="${ACTION_SKILLS_DIR}/${entry}"
  fi

  if [[ ! -f "${skill_dir}/SKILL.md" ]]; then
    gh_error "Skill not found: ${entry} (looked for ${skill_dir}/SKILL.md)"
    exit 1
  fi

  skill_name="$(basename "${skill_dir}")"

  case "${RUNNER}" in
    codex)
      dest=".agents/skills/${skill_name}"
      mkdir -p "${dest}"
      cp "${skill_dir}/SKILL.md" "${dest}/SKILL.md"
      ;;
    claude-code)
      dest="${HOME}/.claude/commands"
      mkdir -p "${dest}"
      cp "${skill_dir}/SKILL.md" "${dest}/${skill_name}.md"
      ;;
    *)
      dest="${HOME}/.config/opencode/commands"
      mkdir -p "${dest}"
      cp "${skill_dir}/SKILL.md" "${dest}/${skill_name}.md"
      ;;
  esac

  INSTALLED=$((INSTALLED + 1))
  echo "  ${skill_name}"
done

echo "Installed ${INSTALLED} skill(s)"
gh_endgroup
