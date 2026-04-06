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

- **`<target>-<use-case>-<persona>.md`** — saved profiles with `Target Type`, target, use case, expected outcome, and optional agent persona
- Use `/create-profile` to create profiles interactively; test-skill and test-feature load saved profiles in their Step 0
- Features and skills are discovered on the fly from project docs (README.md, CLAUDE.md, AGENTS.md) and project structure — no persistent list files needed
- `test-feature` should only load profiles whose `Target Type` is `feature`; `test-skill` should only load profiles whose `Target Type` is `skill`

## Report Format

Both skills output reports to `docs/test-reports/`:
- `test-skill`: `docs/test-reports/<skill-name>-<YYYYMMDD-HHMMSS>.md`
- `test-feature`: `docs/test-reports/test-feature-<YYYYMMDD-HHMMSS>.md`

## Installation

- **Claude Code:** `/plugin marketplace add GiggleLiu/agentic-tests`, or manually: clone to `~/.claude/agentic-tests` and symlink each `skills/*/SKILL.md` into `~/.claude/commands/agentic-tests:<skill>.md`
- **Codex:** Clone → symlink each directory under `skills/*/` into `~/.agents/skills/`
- **OpenCode:** Clone → symlink each `skills/*/SKILL.md` into `~/.config/opencode/commands/<skill>.md`

## GitHub Action (CI)

Downstream projects can run agentic tests in CI via the GitHub Action. Users trigger tests by commenting `/agentic-tests` on any issue or PR:

```yaml
- uses: GiggleLiu/agentic-tests@v1
  with:
    provider: anthropic
    features: auth,api,cli
    issue-number: ${{ github.event.issue.number }}
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

Trigger commands:
- `/agentic-tests` — test all configured features
- `/agentic-tests feat1,feat2` — test specific features (overrides default)

Required API key env vars per runner:
- **codex** — `OPENAI_API_KEY`
- **claude-code** — `ANTHROPIC_API_KEY`
- **opencode** — depends on provider (e.g., `MOONSHOT_API_KEY`, `OPENAI_API_KEY`)

The action installs the chosen runner, runs `/test-feature` (or `/test-skill`) for each listed feature, posts results as a comment on the triggering issue/PR, and uploads full reports as workflow artifacts.

See `examples/agentic-test.yml` for a ready-to-copy workflow.

## Development

Run `make` to see available commands:

- `make test` — Run all offline tests (no API keys needed)
- `make test-integration` — Smoke-test installed runners with API keys
- `make lint` — Lint shell scripts with shellcheck
- `make check` — Lint + tests (use before committing)

### Scripts

Each step in `action.yml` delegates to a standalone script:

| Script | Purpose |
|--------|---------|
| `scripts/install-codex.sh` | Install Codex CLI binary |
| `scripts/install-claude-code.sh` | Install Claude Code CLI |
| `scripts/install-opencode.sh` | Install OpenCode CLI binary |
| `scripts/configure-runner.sh` | Write runner-specific config (env: `INPUT_RUNNER`, `INPUT_MODEL`, `INPUT_PROVIDER`) |
| `scripts/install-skills.sh` | Copy SKILL.md files to runner-specific paths (env: `INPUT_RUNNER`, `SKILLS_DIR`) |
| `scripts/clone-skill-repos.sh` | Clone external skill repos to `.agentic-skills/` for agent-driven installation |
| `scripts/run-tests.sh` | Execute agentic tests for each feature |
| `scripts/post-result.sh` | Post test results as a GitHub issue/PR comment |
| `scripts/test-scripts.sh` | Offline tests for configure-runner and install-skills |
| `scripts/test-integration.sh` | Integration smoke-tests for installed runners |

## Key Files

- `.claude-plugin/plugin.json` / `marketplace.json` — Plugin metadata for Claude Code marketplace
- `action.yml` — Main GitHub Action (composite action, delegates to scripts)
- `setup-runner/action.yml` — Standalone sub-action for runner setup only (install, configure, skills)
- `Makefile` — Development workflow commands
- `scripts/` — CI helper scripts (install runners, configure, run tests, post results)
- `examples/agentic-test.yml` — Example workflow for downstream repos
- `docs/agent-profiles/` — Reusable agent profiles
- `docs/plans/` — Design documents
- `docs/test-reports/` — Test report output directory
