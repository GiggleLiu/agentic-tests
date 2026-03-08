---
name: test-feature
description: Use when testing a project's features from a user's perspective — simulates downstream users who read docs, set up the project, and exercise features end-to-end, reporting on discoverability, functionality, and documentation quality
---

## Test Feature

Simulates downstream users who want to use a software project's features. Each simulated user reads the project's documentation, follows setup instructions, writes code or runs commands exercising the feature, and reports whether the experience matches what the docs promise.

Works with any software project type: libraries, CLI tools, web services, plugins, frameworks, etc.

**Input:** `/test-feature` starts the interactive profile selection. `/test-feature <profile-path>` loads a saved profile directly and skips Step 0 (e.g., `/test-feature docs/agent-profiles/auth-alex.md`). `/test-feature <feature-name>` (non-path argument) tests the named feature with auto-generated persona. If none specified, discover features from project docs and test all.

---

### Step 0 — Load Agent Profile

**If the argument is a file path (contains `/` or ends in `.md`):** Read the profile file directly. Extract Target (feature name), Use Case, Expected Outcome, and Agent fields. Skip the selection UI below and proceed to Step 1.

**If the argument is a feature name (not a path):** Use it as the feature to test, skip Step 0, and proceed to Step 1 with auto-generated persona.

**Otherwise:** Scan `docs/agent-profiles/` for saved profile files (`*.md`). Present via `AskUserQuestion`:

```
Choose a test profile:
[If saved profiles exist:]
a) [profile-name] — [feature]: [use case summary]
[... additional profiles ...]

b) Create a new profile (runs /create-profile)
c) Random — auto-generate a persona and start immediately
```

If no saved profiles exist, omit option (a) and show only "Create new" and "Random."

- **Load saved:** Read the profile file. Extract Target (feature name), Use Case, Expected Outcome, and Agent fields. These carry forward into subsequent steps.
- **Create new:** Suggest the user run `/create-profile` first, then return to `/test-feature` with the saved profile.
- **Random:** Auto-generate a feature selection (from project docs), use case, expected outcome, and persona. Proceed immediately without saving.

### Step 1 — Discover Project & Features

1. Read `README.md`, doc files, and project structure to understand:
   - **Project type** — library, CLI tool, web service, plugin, framework, or hybrid
   - **Language/ecosystem** — determines how to install, build, and run
   - **User-facing features** — capabilities exposed to downstream users (e.g., "REST API", "CLI commands", "library API", "plugin system", "configuration options")
2. Determine scope:
   - If a feature was already selected in Step 0: test only that feature
   - User specified feature(s) but skipped Step 0: test only those
   - User specified nothing: list discovered features, then test all
3. For each feature, collect the relevant doc sections — installation instructions, usage examples, API references, configuration guides.

Print a brief summary of the project and features to test. Proceed immediately.

### Step 2 — Test Each Feature

For each feature, dispatch a **subagent** (via Agent tool). Give the subagent:

- **Role:** From the profile's Agent section (background, experience level, decision tendencies, quirks). If no profile was selected, infer a lightweight user description relevant to the feature and project type.
- **Use case:** From the profile's Use Case field. If no profile, infer from the feature's purpose.
- **Expected outcome:** From the profile's Expected Outcome field. If no profile, omit.
- **Docs:** The README and relevant doc excerpts for this feature.
- **Instructions:**

```
You are [role description from profile: background, experience level].
Decision tendencies: [decision tendencies from profile]
Quirks: [quirks from profile]

You want to use the "[feature]" capability of this project.

Use case: [use case from profile]
Expected outcome: [expected outcome from profile]

Here is the README:
[content]

Here are the relevant docs:
[excerpts]

Your task — act as a real user with the above persona:
1. Read the docs to figure out how to use "[feature]".
2. Follow the installation/setup instructions.
3. Write and run code (or commands) that exercises the feature meaningfully, guided by your use case.
4. Report back with:
   - **Discoverability:** Could you figure out how to use this from docs alone? What was missing?
   - **Setup:** Did installation/setup work as described?
   - **Functionality:** Did the feature work? What succeeded, what failed?
   - **Expected vs Actual:** Did the outcome match what you expected? Describe any differences.
   - **Friction points:** What was confusing, misleading, or undocumented?
   - **Doc suggestions:** What would you add or change in the docs?
```

**Parallelism:** Independent features can be tested in parallel via multiple subagents.

### Step 3 — Report

Gather results from all subagents. Save report to `docs/test-reports/test-feature-<YYYYMMDD-HHMMSS>.md`:

```markdown
# Feature Test Report: [project name]

**Date:** [timestamp]
**Project type:** [library/CLI/web service/plugin/etc.]
**Features tested:** [list]
**Profile:** [profile name or "ephemeral"]
**Use Case:** [use case description]
**Expected Outcome:** [expected outcome]

## Summary

| Feature | Discoverable | Setup | Works | Expected Outcome Met | Doc Quality |
|---------|-------------|-------|-------|---------------------|-------------|
| [name]  | [yes/partial/no] | [yes/no] | [yes/partial/no] | [yes/partial/no] | [good/missing X/outdated] |

## Per-Feature Details

### [feature name]
- **Role:** [who the simulated user was]
- **Use Case:** [what they were trying to accomplish]
- **What they tried:** [brief description]
- **Discoverability:** [could they find how to use it from docs alone?]
- **Setup:** [did installation work as described?]
- **Functionality:** [what worked, what didn't]
- **Expected vs Actual Outcome:** [did the result match the expected outcome? describe differences]
- **Friction points:** [what was confusing or missing]
- **Doc suggestions:** [what would help a real user]

## Expected vs Actual Outcome
[For each feature, summarize whether the expected outcome was achieved, partially achieved, or not achieved. Highlight any surprising differences.]

## Issues Found
[problems discovered, ordered by severity]

## Suggestions
[actionable improvements ordered by impact]
```

Present the report path. Offer to fix documentation gaps or re-test specific features.
