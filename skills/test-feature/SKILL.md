---
name: test-feature
description: Use when testing a project's features from a user's perspective — simulates downstream users who read docs, set up the project, and exercise features end-to-end, reporting on discoverability, functionality, and documentation quality
---

## Test Feature

Simulates downstream users who want to use a software project's features. Each simulated user reads the project's documentation, follows setup instructions, writes code or runs commands exercising the feature, and reports whether the experience matches what the docs promise.

Works with any software project type: libraries, CLI tools, web services, plugins, frameworks, etc.

**Input:** User specifies feature name(s) (e.g., `/test-feature authentication`). If none specified, discover features from project docs and test all.

---

### Step 0 — Discover Project & Features

1. Read `README.md`, doc files, and project structure to understand:
   - **Project type** — library, CLI tool, web service, plugin, framework, or hybrid
   - **Language/ecosystem** — determines how to install, build, and run
   - **User-facing features** — capabilities exposed to downstream users (e.g., "REST API", "CLI commands", "library API", "plugin system", "configuration options")
2. Determine scope:
   - User specified feature(s): test only those
   - User specified nothing: list discovered features, then test all
3. For each feature, collect the relevant doc sections — installation instructions, usage examples, API references, configuration guides.

Print a brief summary of the project and features to test. Proceed immediately.

### Step 1 — Test Each Feature

For each feature, dispatch a **subagent** (via Agent tool). Give the subagent:

- **Role:** A lightweight user description relevant to the feature and project type. Infer from the project's target audience and the feature's purpose. Examples:
  - Library: "a developer integrating this library into their web service"
  - CLI tool: "a data engineer who wants to automate data pipeline tasks"
  - Web service: "a frontend developer consuming this API"
  - Plugin: "a user extending their editor with this plugin"
- **Docs:** The README and relevant doc excerpts for this feature.
- **Instructions:**

```
You are [role description]. You want to use the "[feature]" capability of this project.

Here is the README:
[content]

Here are the relevant docs:
[excerpts]

Your task — act as a real user:
1. Read the docs to figure out how to use "[feature]".
2. Follow the installation/setup instructions.
3. Write and run code (or commands) that exercises the feature meaningfully.
4. Report back with:
   - **Discoverability:** Could you figure out how to use this from docs alone? What was missing?
   - **Setup:** Did installation/setup work as described?
   - **Functionality:** Did the feature work? What succeeded, what failed?
   - **Friction points:** What was confusing, misleading, or undocumented?
   - **Doc suggestions:** What would you add or change in the docs?
```

**Parallelism:** Independent features can be tested in parallel via multiple subagents.

### Step 2 — Report

Gather results from all subagents. Save report to `docs/test-reports/test-feature-<YYYYMMDD-HHMMSS>.md`:

```markdown
# Feature Test Report: [project name]

**Date:** [timestamp]
**Project type:** [library/CLI/web service/plugin/etc.]
**Features tested:** [list]

## Summary

| Feature | Discoverable | Setup | Works | Doc Quality |
|---------|-------------|-------|-------|-------------|
| [name]  | [yes/partial/no] | [yes/no] | [yes/partial/no] | [good/missing X/outdated] |

## Per-Feature Details

### [feature name]
- **Role:** [who the simulated user was]
- **What they tried:** [brief description]
- **Discoverability:** [could they find how to use it from docs alone?]
- **Setup:** [did installation work as described?]
- **Functionality:** [what worked, what didn't]
- **Friction points:** [what was confusing or missing]
- **Doc suggestions:** [what would help a real user]

## Issues Found
[problems discovered, ordered by severity]

## Suggestions
[actionable improvements ordered by impact]
```

Present the report path. Offer to fix documentation gaps or re-test specific features.
