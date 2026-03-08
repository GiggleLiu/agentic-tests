---
name: test-feature
description: Use when testing a project's features from a user's perspective — simulates downstream users who read docs, set up the project, and exercise features end-to-end, reporting on discoverability, functionality, and documentation quality
---

## Test Feature

Simulates downstream users who want to use a software project's features. Each simulated user reads the project's documentation, follows setup instructions, writes code or runs commands exercising the feature, and reports whether the experience matches what the docs promise.

Works with any software project type: libraries, CLI tools, web services, plugins, frameworks, etc.

**Input:** User specifies feature name(s) (e.g., `/test-feature authentication`). If none specified, discover features from project docs and test all.

---

### Step 0 — Select Agent Profile

#### 0a. Select Feature

1. Check whether `docs/agent-profiles/FEATURES.md` exists in the project.
   - **If it exists:** Load the feature list from it.
   - **If it does not exist:** Discover features from the project's README, doc files, and project structure. Create `docs/agent-profiles/FEATURES.md` with the discovered features using this format:
     ```markdown
     # Features

     - [Feature Name] — [one-line description]
     ```
   - **Note:** This file is separate from `SKILLS.md` used by test-skill. Both can coexist in the same directory.
2. Present the feature list to the user via `AskUserQuestion`:
   ```
   I found these features:
   a) [Feature 1] — [description]
   b) [Feature 2] — [description]
   ...
   u) Update the feature list

   Which feature would you like to test?
   ```
3. If the user picks "Update the feature list", let them add/remove/edit features, save the updated `docs/agent-profiles/FEATURES.md`, and re-present the list.
4. Record the chosen feature name for the following sub-steps.

#### 0b. Select Use Case

1. Analyze the chosen feature's documentation (README sections, doc files, examples, API references) to understand what a user can do with this feature.
2. Propose 2–4 realistic usage scenarios, each with a suggested expected outcome. Present via `AskUserQuestion`:
   ```
   Here are some use cases for "[feature]":
   a) [Scenario 1] — Expected: [what success looks like]
   b) [Scenario 2] — Expected: [what success looks like]
   c) [Scenario 3] — Expected: [what success looks like]
   d) Describe your own use case

   Which use case would you like to test?
   ```
3. If the user picks "Describe your own use case", ask them to describe the scenario and expected outcome.
4. Confirm the expected outcome with the user:
   ```
   Use case: [selected use case]
   Expected outcome: [expected outcome]

   Does this look right? (yes / edit)
   ```
5. Record the chosen use case and expected outcome.

#### 0c. Select Agent Profile

1. Scan `docs/agent-profiles/` for files matching `<feature>-*.md` (where `<feature>` is the chosen feature name, lowercased, with spaces replaced by hyphens).
2. Generate 3 diverse persona suggestions based on the feature and use case. Vary experience level (beginner, intermediate, expert) and background.
3. Present via `AskUserQuestion`:
   ```
   Agent profile options:
   [If saved profiles exist:]
   a) Load saved: [profile-name-1]
   [... additional saved profiles ...]

   Generated personas:
   b) [Name] — [Experience level], [one-line background summary]
   c) [Name] — [Experience level], [one-line background summary]
   d) [Name] — [Experience level], [one-line background summary]
   e) Create a custom profile (I'll describe the persona)
   f) Random (generate a surprising persona)

   Which agent profile?
   ```
   If no saved profiles exist, omit the "Load saved" section and start generated personas at (a).
4. If the user picks a saved profile, load it from the file.
5. If the user picks a generated persona, populate the full profile fields and ask whether to save it:
   ```
   Save this profile to docs/agent-profiles/[feature]-[name].md? (yes / no)
   ```
   If yes, write the file using this format:
   ```markdown
   # [feature]-[name]

   ## Feature
   [Feature name]

   ## Use Case
   [What the user is trying to do]

   ## Expected Outcome
   [What success looks like]

   ## Agent

   ### Background
   [Who this person is]

   ### Experience Level
   [Beginner/Intermediate/Expert]

   ### Decision Tendencies
   [How they behave]

   ### Quirks
   [Realistic traits]
   ```
6. If the user picks "Create a custom profile", ask them to describe the persona, then populate the profile fields and offer to save.
7. If the user picks "Random", generate a surprising but plausible persona, populate the profile fields, and offer to save.
8. Record the full profile (name, background, experience level, decision tendencies, quirks) for use in subsequent steps.

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
