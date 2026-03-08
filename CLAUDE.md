# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

agentic-tests is a skill-based plugin for AI coding assistants (Claude Code, Codex, OpenCode) that provides agent-driven testing capabilities. It is not a traditional code project — it consists of skill definition files (SKILL.md) that define agent interaction protocols for testing.

## Skills

Three skills in `skills/`, each defined by a `SKILL.md` with YAML frontmatter + instructions:

- **create-profile** — Creates and manages reusable agent profiles. Guides users through selecting a feature/skill, defining a use case with expected outcome, and choosing or generating an agent persona.
- **test-skill** — Tests any skill's conversational flow by role-playing the interaction: main agent follows the skill's SKILL.md, while a subagent plays a simulated user with a generated persona. Produces structural analysis, UX feedback, and actionable suggestions.
- **test-feature** — Tests any software project's features from a downstream user's perspective. Auto-detects project type, dispatches subagents as simulated users who read docs, set up the project, and exercise features end-to-end.

## Architecture

**test-skill** uses a two-agent architecture:
- Main agent = executor following the target skill's instructions
- Subagent = simulated user with a persona, resumed at each decision point
- Phases: Analyze skill → Generate persona → Execute with role-play → Collect feedback & report

**test-feature** uses a fan-out architecture:
- Main agent = coordinator that discovers features and dispatches testers
- Subagents = independent simulated users, one per feature (can run in parallel)
- Phases: Discover project & features → Test each feature → Aggregate report

## Agent Profiles

Reusable test configurations stored in `docs/agent-profiles/` as Markdown files.

- **`<feature>-<name>.md`** — saved profiles with feature, use case, expected outcome, and optional agent persona
- Use `/create-profile` to create profiles interactively; test-skill and test-feature load saved profiles in their Step 0
- Features and skills are discovered on the fly from project docs (README.md, CLAUDE.md, AGENTS.md) and project structure — no persistent list files needed

## Report Format

Both skills output reports to `docs/test-reports/`:
- `test-skill`: `docs/test-reports/<skill-name>-<YYYYMMDD-HHMMSS>.md`
- `test-feature`: `docs/test-reports/test-feature-<YYYYMMDD-HHMMSS>.md`

## Installation

- **Claude Code:** `/plugin marketplace add GiggleLiu/agentic-tests`
- **Codex:** Clone → symlink to `~/.agents/skills/agentic-tests`
- **OpenCode:** Clone → symlink to `~/.config/opencode/skills/agentic-tests`

## GitHub Action (CI)

Downstream projects can run agentic tests in CI via the GitHub Action:

```yaml
- uses: GiggleLiu/agentic-tests@v1
  with:
    provider: anthropic
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

The action installs the chosen runner (OpenCode, Codex, or Claude Code — configurable via `runner` input), detects features affected by the PR diff (AI-inferred), runs `/test-feature` for each, and posts results as a PR comment with full reports as downloadable artifacts.

See `examples/agentic-test.yml` for a ready-to-copy workflow.

## Key Files

- `.claude-plugin/plugin.json` / `marketplace.json` — Plugin metadata for Claude Code marketplace
- `action.yml` — GitHub Action metadata (composite action)
- `scripts/` — CI helper scripts (install, detect, test, comment)
- `examples/agentic-test.yml` — Example workflow for downstream repos
- `docs/agent-profiles/` — Reusable agent profiles
- `docs/plans/` — Design documents
- `docs/test-reports/` — Test report output directory
