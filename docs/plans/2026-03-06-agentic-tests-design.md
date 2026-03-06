# Design: agentic-tests Plugin

**Date:** 2026-03-06
**Repository:** https://github.com/GiggleLiu/agentic-tests

## Overview

A skill-based plugin for AI coding assistants that provides agent-driven testing capabilities. Two skills:

1. **test-skill** — Tests any skill's conversational flow via role-play (main agent + simulated user subagent)
2. **test-feature** — Tests any software project's features from a downstream user's perspective (auto-detects project type, dispatches parallel subagents)

## Decisions

- **Scope of test-feature:** Generic across any software project type (library, CLI, web service, plugin, framework). Not broadened to non-software artifacts.
- **Convention:** Follows sci-brain plugin structure (SKILL.md with YAML frontmatter, plugin.json, marketplace.json, CLAUDE.md)
- **test-skill:** Copied from sci-brainstorm as-is — already general-purpose
- **test-feature:** Generalized from ~/.claude/skills/test-feature — removed ecosystem-specific assumptions, added project type auto-detection

## Structure

```
agentic-tests/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/
│   ├── test-skill/SKILL.md
│   └── test-feature/SKILL.md
├── docs/
│   ├── plans/
│   └── test-reports/
├── CLAUDE.md
├── README.md
├── LICENSE
└── .gitignore
```
