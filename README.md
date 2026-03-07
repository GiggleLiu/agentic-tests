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

## Reports

Test reports are saved to `docs/test-reports/` with timestamped filenames.

## License

MIT. Feel free to adapt these skills for your own using, BUT please acknowledge this repo properly, thank you!
