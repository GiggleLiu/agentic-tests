# agentic-tests

Agent-driven testing toolkit for AI coding assistants. Test skills via role-play and test project features via simulated users.

## Skills

### test-skill

Tests any skill's conversational flow by role-playing the interaction. A main agent follows the target skill's instructions while a subagent plays a simulated user with a generated persona. Produces structural analysis, UX feedback, and actionable suggestions.

```
/test-skill
```

### test-feature

Tests any software project's features from a downstream user's perspective. Auto-detects project type (library, CLI, web service, plugin, etc.), dispatches subagents as simulated users who read docs, set up the project, and exercise features end-to-end.

```
/test-feature
/test-feature authentication
/test-feature "CLI commands" "config system"
```

### create-profile

Creates and manages reusable agent profiles. Guides you through selecting a feature or skill, defining a use case with expected outcome, and choosing or generating an agent persona. Saved profiles are reused by `test-skill` and `test-feature`.

```
/create-profile
```

## Installation

### Claude Code

Via plugin marketplace:
```
/plugin marketplace add GiggleLiu/agentic-tests
/plugin install agentic-tests@agentic-tests
```

Or manually (symlinks all skills into `~/.claude/commands/`):
```bash
git clone https://github.com/GiggleLiu/agentic-tests.git ~/.claude/agentic-tests
mkdir -p ~/.claude/commands
for skill in ~/.claude/agentic-tests/skills/*/; do
  name=$(basename "$skill")
  ln -sf "$skill/SKILL.md" ~/.claude/commands/"agentic-tests:$name.md"
done
```

### Codex

```bash
git clone https://github.com/GiggleLiu/agentic-tests.git ~/.codex/agentic-tests
mkdir -p ~/.agents/skills
for skill in ~/.codex/agentic-tests/skills/*/; do
  ln -s "$skill" ~/.agents/skills/"$(basename "$skill")"
done
```

### OpenCode

```bash
git clone https://github.com/GiggleLiu/agentic-tests.git ~/.config/opencode/agentic-tests
mkdir -p ~/.config/opencode/commands
for skill in ~/.config/opencode/agentic-tests/skills/*/; do
  name=$(basename "$skill")
  ln -s "$skill/SKILL.md" ~/.config/opencode/commands/"$name".md
done
```

## CI Integration

Run agentic tests on demand by commenting `/agentic-tests` on any issue or PR. Supports three runners: [OpenCode](https://github.com/opencode-ai/opencode), [Codex](https://github.com/openai/codex), and [Claude Code](https://claude.ai/code).

### Quick Start

Copy `examples/agentic-test.yml` to `.github/workflows/` in your repo, then add your API key as a repository secret (`Settings > Secrets > Actions`).

Trigger by commenting on any issue or PR:
- `/agentic-tests` — test all configured features
- `/agentic-tests feat1,feat2` — test specific features

Only repo owners, members, and collaborators can trigger runs.

### How It Works

1. **Triggers on comment** — filters for `/agentic-tests` prefix, reacts with eyes emoji
2. **Checks out the right code** — if commented on a PR, resolves the PR head repo and SHA before checkout; otherwise uses the default branch
3. **Installs the agent runner** (OpenCode, Codex, or Claude Code) and registers agentic-tests skills
4. **Runs tests** — dispatches `/test-feature` or `/test-skill` for each listed feature, with matching agent profiles if available
5. **Reports results** — posts a summary as a comment on the triggering issue/PR; uploads full reports as workflow artifacts

### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `runner` | `opencode` | Agent runner: `opencode`, `codex`, or `claude-code` |
| `provider` | (required) | LLM provider: `anthropic`, `openai`, `moonshot`, etc. |
| `mode` | `feature` | `feature` (test project features), `skill` (test skill flows), or `both` |
| `model` | runner default | Model to use (e.g., `claude-sonnet-4-6`, `gpt-5.4`) |
| `features` | (required) | Comma-separated list of features/skills to test |
| `profiles-dir` | `docs/agent-profiles` | Directory containing saved agent profiles |
| `issue-number` | | Issue or PR number to post results to |
| `extra-prompt` | | Extra instructions appended to each test (e.g., `test as a beginner`) |

### Modes

- **`feature`** — tests project features via `/test-feature`. Simulated users read docs, install, and exercise code. Best for libraries, CLIs, web services.
- **`skill`** — tests skill flows via `/test-skill`. Role-plays through each SKILL.md with a simulated user persona. Best for skill/plugin repos.
- **`both`** — runs both. Detection returns items prefixed `feature:name` or `skill:name`.

### Agent Profiles

Saved profiles live in `docs/agent-profiles/`. The current profile schema includes:

- `## Target Type` — `feature` or `skill`
- `## Target` — the concrete feature or skill name
- `## Use Case`
- `## Expected Outcome`
- `## Agent`

### Examples

Test a library's features:
```yaml
with:
  provider: anthropic
  mode: feature
```

Test a skill repo's conversational flows:
```yaml
with:
  provider: anthropic
  mode: skill
```

Test with custom instructions:
```yaml
with:
  provider: openai
  model: gpt-4o
  extra-prompt: 'focus on error handling and edge cases'
```

Use Claude Code as the runner:
```yaml
with:
  runner: claude-code
  provider: anthropic
  model: claude-opus-4-6
env:
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Use Codex as the runner:
```yaml
with:
  runner: codex
  provider: openai
  model: gpt-5.4
  features: 'authentication,REST API'
env:
  OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Reports

Test reports are saved to `docs/test-reports/` with timestamped filenames.

## License

MIT. Feel free to adapt these skills for your own using, BUT please acknowledge this repo properly, thank you!
