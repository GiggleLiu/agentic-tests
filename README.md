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

Let AI agents test your project on every PR — just like human reviewers, but they actually run the code.

Comment `/agentic-tests` on any issue or PR, and an AI agent will:

1. Read your docs and figure out how to set up the project
2. Exercise the features you specify, as a real user would
3. Post a pass/fail summary right back on the issue or PR

Works with three agent runners: [Claude Code](https://claude.ai/code), [Codex](https://github.com/openai/codex), and [OpenCode](https://github.com/opencode-ai/opencode).

### Setup (2 minutes)

**Step 1.** Copy the example workflow into your repo:

```bash
mkdir -p .github/workflows
curl -o .github/workflows/agentic-test.yml \
  https://raw.githubusercontent.com/GiggleLiu/agentic-tests/main/examples/agentic-test.yml
```

**Step 2.** Add your API key as a repository secret:

> Settings → Secrets and variables → Actions → New repository secret

| Runner | Secret name | Value |
|--------|-------------|-------|
| Claude Code | `ANTHROPIC_API_KEY` | `sk-ant-...` |
| Codex | `OPENAI_API_KEY` | `sk-...` |
| OpenCode | depends on provider | e.g., `OPENAI_API_KEY` |

**Step 3.** Edit the workflow to list your features:

```yaml
env:
  DEFAULT_FEATURES: 'auth,api,cli'   # ← your features here
```

That's it. Now comment `/agentic-tests` on any issue or PR to run.

### Usage

```
/agentic-tests              # test all default features
/agentic-tests auth,api     # test specific features
```

Only repo owners, members, and collaborators can trigger runs.

### What happens behind the scenes

```
Comment "/agentic-tests"
    │
    ▼
┌─ GitHub Action ────────────────────────────┐
│  1. Install agent runner (Claude/Codex/OC) │
│  2. Configure model & API keys             │
│  3. Register agentic-tests skills          │
│  4. For each feature:                      │
│     → spawn a simulated user agent         │
│     → read docs, install, exercise feature │
│     → write test report                    │
│  5. Post summary comment on issue/PR       │
│  6. Upload full reports as artifacts       │
└────────────────────────────────────────────┘
```

### Choosing a runner

```yaml
# Claude Code (default: claude-opus-4-6)
with:
  runner: claude-code
  provider: anthropic
env:
  ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

# Codex (default: gpt-5.4)
with:
  runner: codex
  provider: openai
env:
  OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}

# OpenCode (default runner)
with:
  runner: opencode
  provider: moonshot
```

### All inputs

| Input | Default | Description |
|-------|---------|-------------|
| `runner` | `opencode` | `opencode`, `codex`, or `claude-code` |
| `provider` | *(required)* | `anthropic`, `openai`, `moonshot`, etc. |
| `features` | *(required)* | Comma-separated features to test |
| `mode` | `feature` | `feature`, `skill`, or `both` |
| `model` | runner default | Override model (e.g., `claude-sonnet-4-6`) |
| `skills` | built-in skills | Skills to install (see [Custom skills](#custom-skills)) |
| `profiles-dir` | `docs/agent-profiles` | Directory with saved agent profiles |
| `skill-repos` | | GitHub repos with skills to clone (e.g., `owner/repo`) |
| `extra-prompt` | | Extra instructions (e.g., `test as a beginner`) |
| `issue-number` | | Issue/PR number to post results to |

### Custom skills

By default, the action installs the three built-in skills (`test-skill`, `test-feature`, `create-profile`). You can add your own skills or replace the defaults using the `skills` input.

Each entry is either a **bare name** (built-in skill) or a **path** (directory containing `SKILL.md`):

```yaml
# Built-in + a custom skill from your repo
with:
  skills: 'test-skill,test-feature,./my-skills/lint-checker'

# Only your custom skills — no built-ins
with:
  skills: './skills/security-audit,./skills/perf-test'
```

To use skills from another GitHub repo, use `skill-repos` — the AI agent clones the repo, reads the README, and installs the skills itself:

```yaml
- uses: GiggleLiu/agentic-tests@v1
  with:
    skill-repos: 'owner/skill-repo,owner/another-repo'
```

This works with any repo structure — the agent figures out how to install the skills by reading the repo's documentation. No need to know the internal layout.

For more control, you can also check out repos manually and reference paths directly:

```yaml
- uses: actions/checkout@v4
  with:
    repository: owner/skill-repo
    path: .skill-repo

- uses: GiggleLiu/agentic-tests@v1
  with:
    skills: 'test-skill,.skill-repo/skills/brainstorming'
```

A skill directory just needs a `SKILL.md` file:

```
my-skills/
  lint-checker/
    SKILL.md       ← skill definition (YAML frontmatter + instructions)
```

### Setup runner only

If you just need a configured agent runner without running tests (e.g., for your own workflows):

```yaml
- uses: GiggleLiu/agentic-tests/setup-runner@v1
  with:
    runner: claude-code
    provider: anthropic
    skills: 'test-skill,test-feature'
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}

# Now use the runner for your own purposes
- run: claude -p "your prompt here"
```

### Testing modes

- **`feature`** — simulated users read your docs, install, and exercise code. Best for libraries, CLIs, and web services.
- **`skill`** — role-plays through each SKILL.md with a simulated user persona. Best for skill/plugin repos.
- **`both`** — runs both. Prefix items with `feature:` or `skill:` to control which mode each gets.

### Agent profiles

Want more control over how the AI tests your features? Create agent profiles in `docs/agent-profiles/`:

```markdown
## Target Type
feature

## Target
authentication

## Use Case
Sign up, log in, reset password as a new user

## Expected Outcome
All auth flows complete without errors

## Agent
A junior developer unfamiliar with the codebase
```

The CI automatically picks up matching profiles and uses them to guide the test persona.

## Reports

Test reports are saved to `docs/test-reports/` with timestamped filenames.

## License

MIT. Feel free to adapt these skills for your own using, BUT please acknowledge this repo properly, thank you!
