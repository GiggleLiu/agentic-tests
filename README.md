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

## Installation

### Claude Code

```
/plugin marketplace add GiggleLiu/agentic-tests
/plugin install agentic-tests@agentic-tests
```

### Codex

```bash
git clone https://github.com/GiggleLiu/agentic-tests.git ~/.codex/agentic-tests
mkdir -p ~/.agents/skills
ln -s ~/.codex/agentic-tests/skills/agentic-tests ~/.agents/skills/agentic-tests
```

### OpenCode

```bash
git clone https://github.com/GiggleLiu/agentic-tests.git ~/.config/opencode/agentic-tests
mkdir -p ~/.config/opencode/skills
ln -s ~/.config/opencode/agentic-tests/skills/agentic-tests ~/.config/opencode/skills/agentic-tests
```

## CI Integration

Run agentic tests automatically on pull requests via the GitHub Action. The action uses [OpenCode](https://github.com/opencode-ai/opencode) (open-source, headless) with your LLM API key.

### Quick Start

Copy `examples/agentic-test.yml` to `.github/workflows/` in your repo, then add your API key as a repository secret (`Settings > Secrets > Actions`).

```yaml
# .github/workflows/agentic-test.yml
name: Agentic Tests
on:
  pull_request:

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
      - uses: GiggleLiu/agentic-tests@main
        with:
          provider: anthropic
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### How It Works

1. **Installs OpenCode** and registers agentic-tests skills as OpenCode commands
2. **Detects affected targets** — uses AI to infer which features or skills changed in the PR (from the diff + project docs like README.md, CLAUDE.md)
3. **Runs tests** — dispatches `/test-feature` or `/test-skill` for each target, with matching agent profiles if available
4. **Reports results** — posts a summary table as a PR comment; uploads full reports as workflow artifacts

### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `runner` | `opencode` | Agent runner: `opencode` or `codex` |
| `provider` | (required) | LLM provider: `anthropic`, `openai`, `moonshot`, etc. |
| `mode` | `feature` | `feature` (test project features), `skill` (test skill flows), or `both` |
| `model` | runner default | Model to use (e.g., `claude-sonnet-4-6`, `gpt-5.4`) |
| `features` | `auto` | `auto` = AI-detect from diff, or comma-separated explicit list |
| `profiles-dir` | `docs/agent-profiles` | Directory containing saved agent profiles |
| `base-branch` | `origin/main` | Base branch for diff comparison |
| `extra-prompt` | | Extra instructions appended to each test (e.g., `test as a beginner`) |

### Modes

- **`feature`** — tests project features via `/test-feature`. Simulated users read docs, install, and exercise code. Best for libraries, CLIs, web services.
- **`skill`** — tests skill flows via `/test-skill`. Role-plays through each SKILL.md with a simulated user persona. Best for skill/plugin repos.
- **`both`** — runs both. Detection returns items prefixed `feature:name` or `skill:name`.

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

Use Codex as the runner:
```yaml
with:
  runner: codex
  provider: openai
  model: gpt-5.4
env:
  CODEX_API_KEY: ${{ secrets.OPENAI_API_KEY }}
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Explicit feature list (skip AI detection):
```yaml
with:
  provider: anthropic
  features: 'authentication,REST API,CLI commands'
```

## Reports

Test reports are saved to `docs/test-reports/` with timestamped filenames.

## License

MIT. Feel free to adapt these skills for your own using, BUT please acknowledge this repo properly, thank you!
