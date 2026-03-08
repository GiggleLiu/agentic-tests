# Design: GitHub Action for Agentic Tests

**Date:** 2026-03-08

## Overview

A GitHub Action (`GiggleLiu/agentic-tests@v1`) that downstream projects use to run agentic tests in CI. Uses OpenCode (open-source, headless) to simulate users testing project features affected by a PR, then posts results as a PR comment with full reports as downloadable artifacts.

## Decisions

- **Approach:** GitHub Action (action.yml) — familiar UX, versioned, marketplace-ready
- **Agent:** OpenCode — open-source, headless via `opencode -p "..." -q`, auto-approves permissions in non-interactive mode
- **Trigger:** User-specified — the action doesn't dictate triggers; downstream repos configure their own `on:` block
- **Feature detection:** AI-inferred — pass PR diff + project docs to OpenCode, get back affected feature list as JSON
- **Reports:** PR comment (summary table) + GitHub Actions artifact (full markdown reports)
- **Scope:** Only features changed in the PR, not the entire project
- **Profile matching:** Auto-discover from `docs/agent-profiles/`; fall back to feature-name-only invocation
- **Feature list:** No dedicated project docs (README.md, CLAUDE.md, AGENTS.md) — features are inferred from README.md, CLAUDE.md, AGENTS.md, or project structure. One less file to maintain.

## Architecture

```
PR opened / label added / manual trigger
              |
              v
+---------------------------------------------+
|  GitHub Action (GiggleLiu/agentic-tests@v1) |
|---------------------------------------------|
|  1. Install OpenCode + agentic-tests cmds   |
|  2. Get PR diff (git diff origin/main...HEAD)|
|  3. Detect features (lightweight OpenCode)   |
|     - Input: diff + project docs (README.md, CLAUDE.md, AGENTS.md) + README.md  |
|     - Output: ["feature1", "feature2"] JSON  |
|  4. For each affected feature:               |
|     - Find profile in docs/agent-profiles/   |
|     - Run: opencode -p                       |
|       "/test-feature <profile-or-feature>"   |
|  5. Collect reports from docs/test-reports/  |
|  6. Upload reports as artifact               |
|  7. Post PR comment with summary             |
+---------------------------------------------+
```

## Files to Add

```
agentic-tests/
├── action.yml                    # GitHub Action metadata
├── scripts/
│   ├── install-opencode.sh       # Install OpenCode CLI
│   ├── detect-features.sh        # Diff → feature list (via OpenCode)
│   ├── run-test.sh               # Run one feature test (via OpenCode)
│   └── post-comment.sh           # Format & post PR comment
```

## action.yml

### Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `provider` | yes | — | LLM provider: `anthropic`, `openai`, `moonshot`, etc. |
| `model` | no | provider default | Model to use for test runs |
| `features` | no | `"auto"` | `"auto"` = AI-detect from diff, or explicit comma-separated list |
| `profiles-dir` | no | `docs/agent-profiles` | Where to find saved profiles |

### Outputs

| Output | Description |
|--------|-------------|
| `features-tested` | Comma-separated feature names that were tested |
| `pass` | `true` if no critical issues found |

### Environment Variables (set by downstream repo)

| Variable | Required | Description |
|----------|----------|-------------|
| `ANTHROPIC_API_KEY` | if provider=anthropic | Anthropic API key |
| `OPENAI_API_KEY` | if provider=openai | OpenAI API key |
| `MOONSHOT_API_KEY` | if provider=moonshot | Moonshot API key |
| `GITHUB_TOKEN` | yes | For posting PR comments (provided by Actions) |

## Downstream Usage

Minimal setup — add one workflow file:

```yaml
# .github/workflows/agentic-test.yml
name: Agentic Tests
on:
  pull_request:
  # or: workflow_dispatch, label triggers, etc.

jobs:
  agentic-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # need full history for diff
      - uses: GiggleLiu/agentic-tests@v1
        with:
          provider: anthropic
          model: claude-sonnet-4-6  # optional
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Optionally add profiles to `docs/agent-profiles/` for richer testing with specific personas and use cases.

## Feature Detection Flow

```
git diff origin/main...HEAD (file names + hunks)
        |
        v
+-------------------------------------------+
|  OpenCode (lightweight, cheap call)       |
|                                           |
|  Input:                                   |
|  - PR diff                                |
|  - Project docs (README, CLAUDE.md, etc.) |
|                                           |
|  Prompt:                                  |
|  "Given this diff and project docs,       |
|   which user-facing features are affected? |
|   Return JSON array of feature names."    |
|                                           |
|  Output: ["authentication", "REST API"]   |
+-------------------------------------------+
        |
        v
For each feature:
  - Glob docs/agent-profiles/<feature>-*.md
  - If profile found -> opencode -p "/test-feature <profile-path>"
  - If no profile    -> opencode -p "/test-feature <feature-name>"
```

Edge cases:
- No project docs at all: OpenCode infers features from project structure and file names
- No features affected: exit early, post "no features affected" comment
- features input is explicit list: skip detection, test those features directly

## PR Comment Format

```markdown
## Agentic Test Results

**Features tested:** 3 | **Passed:** 2 | **Issues:** 1

| Feature | Setup | Works | Docs | Verdict |
|---------|-------|-------|------|---------|
| Authentication | pass | pass | warning: missing example | Pass |
| REST API | pass | fail: 404 on /users | pass | Fail |
| CLI commands | pass | pass | pass | Pass |

### Issues Found
1. **REST API** — `GET /users` returns 404; docs say it should list users
2. **Authentication** — no example for OAuth flow in README

### Suggestions
1. Add REST API integration test for `/users` endpoint
2. Add OAuth example to authentication docs

Full reports: [download from artifacts](link)
```

## Script Details

### install-opencode.sh

- Download latest OpenCode release binary for Linux amd64
- Place in PATH
- Copy agentic-tests skill files to `~/.config/opencode/commands/`
- Verify with `opencode --version`

### detect-features.sh

- Input: base branch (default `origin/main`)
- Runs `git diff $base...HEAD` to get changed files and hunks
- Reads project docs (README.md, CLAUDE.md, AGENTS.md) if present
- Calls OpenCode with a structured prompt requesting JSON output
- Parses JSON array, outputs one feature per line
- If `features` input is not `"auto"`, echoes the explicit list instead

### run-test.sh

- Input: feature name, profiles directory
- Searches `$profiles_dir/<feature>-*.md` for a matching profile
- Runs `opencode -p "/test-feature <profile-or-feature>" -q`
- Captures output and exit code
- Reports are written by the test-feature skill to `docs/test-reports/`

### post-comment.sh

- Input: PR number, test reports directory
- Reads all reports from `docs/test-reports/`
- Parses each report's summary table, issues, and suggestions
- Assembles the PR comment markdown
- Posts via `gh pr comment $PR_NUMBER --body "$COMMENT"`
- Handles comment length limits (GitHub max ~65536 chars) — truncate with link to artifacts if needed

## Cost Control

- Feature detection call is cheap: small prompt, structured JSON output
- Expensive calls are per-feature test runs — only affected features are tested
- Model choice is configurable — use a cheaper model for detection, full model for tests
- If no features are detected, exit early with no test runs

## OpenCode Configuration

The action creates a `.opencode.json` in the workspace:

```json
{
  "provider": "<from input>",
  "agents": {
    "coder": {
      "model": "<from input or default>"
    }
  }
}
```

API keys are passed via environment variables (already supported by OpenCode).

## Limitations

- OpenCode's custom commands system differs from Claude Code's skills — SKILL.md files need adaptation to `.md` command files in `~/.config/opencode/commands/`
- OpenCode cannot specify model per-run via CLI flag (uses `.opencode.json` config) — the action writes config before each run
- No `allowed_tools` support in OpenCode yet (issue #322) — all tools are auto-approved in non-interactive mode
- PR comment size limit (~65K chars) may require truncation for large test suites
