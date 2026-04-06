#!/usr/bin/env bash
set -euo pipefail

# clone-skill-repos.sh — Clone external skill repositories.
#
# Clones each repo into .agentic-skills/<repo-name>/ so the AI agent
# can read their docs and install skills at runtime.
#
# Env vars:
#   INPUT_SKILL_REPOS — Comma-separated list of GitHub repos (e.g., "owner/repo,owner/repo2")

INPUT_SKILL_REPOS="${INPUT_SKILL_REPOS:-}"
DEST_DIR=".agentic-skills"

if [[ -z "${INPUT_SKILL_REPOS}" ]]; then
  echo "No skill repos to clone."
  exit 0
fi

mkdir -p "${DEST_DIR}"

IFS=',' read -ra REPOS <<< "${INPUT_SKILL_REPOS}"
for repo in "${REPOS[@]}"; do
  repo="$(echo "${repo}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "${repo}" ]] && continue

  repo_name="$(basename "${repo}")"
  dest="${DEST_DIR}/${repo_name}"

  if [[ -d "${dest}" ]]; then
    echo "Already cloned: ${repo} → ${dest}"
    continue
  fi

  echo "Cloning ${repo} → ${dest}"
  git clone --depth 1 "https://github.com/${repo}.git" "${dest}"
done

echo "Skill repos cloned to ${DEST_DIR}/"
ls -1 "${DEST_DIR}/"
