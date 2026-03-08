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

Run agentic tests automatically on pull requests via the GitHub Action:

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
      - uses: GiggleLiu/agentic-tests@v1
        with:
          provider: anthropic
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

The action detects which features are affected by the PR diff, tests each with a simulated user, and posts results as a PR comment. Full reports are uploaded as workflow artifacts.

See `examples/agentic-test.yml` for more options (model selection, explicit feature lists, custom profile directories).

## Reports

Test reports are saved to `docs/test-reports/` with timestamped filenames.

## License

MIT. Feel free to adapt these skills for your own using, BUT please acknowledge this repo properly, thank you!
