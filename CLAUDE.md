# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

agentic-tests is a skill-based plugin for AI coding assistants (Claude Code, Codex, OpenCode) that provides agent-driven testing capabilities. It is not a traditional code project — it consists of skill definition files (SKILL.md) that define agent interaction protocols for testing.

## Skills

Two skills in `skills/`, each defined by a `SKILL.md` with YAML frontmatter + instructions:

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

## Report Format

Both skills output reports to `docs/test-reports/`:
- `test-skill`: `docs/test-reports/<skill-name>-<YYYYMMDD-HHMMSS>.md`
- `test-feature`: `docs/test-reports/test-feature-<YYYYMMDD-HHMMSS>.md`

## Installation

- **Claude Code:** `/plugin marketplace add GiggleLiu/agentic-tests`
- **Codex:** Clone → symlink to `~/.agents/skills/agentic-tests`
- **OpenCode:** Clone → symlink to `~/.config/opencode/skills/agentic-tests`

## Key Files

- `.claude-plugin/plugin.json` / `marketplace.json` — Plugin metadata for Claude Code marketplace
- `docs/plans/` — Design documents
- `docs/test-reports/` — Test report output directory
