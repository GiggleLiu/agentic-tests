# Agent Profiles Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add reusable agent profiles to both test-skill and test-feature, enabling users to save and reuse test configurations (feature, use case, expected outcome, persona).

**Architecture:** A new "Step 0 — Select Agent Profile" is prepended to both skills. A persistent `FEATURES.md` caches discovered features. Profiles are pure Markdown files in `docs/agent-profiles/`.

**Tech Stack:** Markdown skill definitions (no runtime code)

---

### Task 1: Create agent-profiles directory

**Files:**
- Create: `docs/agent-profiles/.gitkeep`

**Step 1: Create the directory with .gitkeep**

```bash
mkdir -p docs/agent-profiles && touch docs/agent-profiles/.gitkeep
```

**Step 2: Commit**

```bash
git add docs/agent-profiles/.gitkeep
git commit -m "chore: add docs/agent-profiles directory"
```

---

### Task 2: Update test-feature SKILL.md — insert Step 0 (agent profiles)

**Files:**
- Modify: `skills/test-feature/SKILL.md:14-27` (current Step 0 becomes Step 1)

**Step 1: Insert the new Step 0 and renumber existing steps**

Replace the entire body of `skills/test-feature/SKILL.md` (lines 6–99) with the updated version. The changes are:

1. Update the intro paragraph (line 12) to mention agent profiles
2. Insert new `### Step 0 — Select Agent Profile` section before current Step 0
3. Renumber current Step 0 → Step 1, Step 1 → Step 2, Step 2 → Step 3
4. In Step 2 (formerly Step 1), update the subagent instructions to use the profile's use case, expected outcome, and persona fields
5. In Step 3 (formerly Step 2), add profile name to the report header

The new Step 0 section to insert (between `---` on line 14 and current Step 0 on line 16):

```markdown
### Step 0 — Select Agent Profile

#### 0a. Select Feature

Check if `docs/agent-profiles/FEATURES.md` exists.

- **If it exists:** Read the feature list from the file.
- **If it doesn't exist:** Read `README.md`, doc files, and project structure to discover user-facing features. Create `docs/agent-profiles/FEATURES.md` with the discovered features in this format:

```markdown
# Features

- [Feature Name] — [one-line description]
- [Feature Name] — [one-line description]
```

Present the features via `AskUserQuestion`:

> "Which feature would you like to test?"
> - **(a)** [Feature 1] — [description]
> - **(b)** [Feature 2] — [description]
> - ...
> - **(N)** Update feature list — re-discover from project docs and edit

#### 0b. Select Use Case

Analyze the chosen feature's docs and code. Propose 2-4 test scenarios with suggested expected outcomes.

Present via `AskUserQuestion`:

> "Pick a use case for testing [feature]:"
> - **(a)** [Scenario name] — [description]. *Expected: [suggested outcome]*
> - **(b)** [Scenario name] — [description]. *Expected: [suggested outcome]*
> - **(c)** [Scenario name] — [description]. *Expected: [suggested outcome]*
> - **(d)** Describe my own use case

After the user picks a scenario, confirm or let them modify the expected outcome before proceeding.

#### 0c. Select Agent Profile

Scan `docs/agent-profiles/` for files matching `<feature>-*.md` (where `<feature>` matches the selected feature, lowercased with spaces replaced by hyphens). Also generate 3 diverse persona suggestions based on the feature and use case.

Present via `AskUserQuestion`:

> "Choose an agent profile for this test:"
> - **(a)** Load saved: `<feature>-<name>` — [background summary] *(only shown if matching profiles exist)*
> - **(b)** [Name] — [role], [level] | [tendencies summary]
> - **(c)** [Name] — [role], [level] | [tendencies summary]
> - **(d)** [Name] — [role], [level] | [tendencies summary]
> - **(e)** Create custom profile
> - **(f)** Random — auto-generate and go

The 3 generated personas (b-d) should be diverse in background, experience level, and decision tendencies.

**If the user selects a generated persona (b-d):** Ask whether to save it as a profile for reuse. If yes, save to `docs/agent-profiles/<feature>-<name>.md`.

**If the user selects "Create custom profile" (e):** Ask for name, background, and experience level. Optionally ask for decision tendencies and quirks. Save to `docs/agent-profiles/<feature>-<name>.md`.

**If the user selects "Random" (f):** Auto-generate a complete persona and proceed immediately without saving.

**Profile file format** (`docs/agent-profiles/<feature>-<name>.md`):

```markdown
# <feature>-<name>

## Target
[Feature or skill name]

## Use Case
[Description of what the user is trying to do]

## Expected Outcome
[What success looks like]

## Agent

### Background
[Who this person is]

### Experience Level
[Beginner/Intermediate/Expert]

### Decision Tendencies
[How they behave at choice points]

### Quirks
[Realistic traits that add friction or personality]
```

The selected profile's Target, Use Case, and Expected Outcome carry forward into subsequent steps. The Agent section provides the persona for subagents. Missing optional Agent fields are auto-generated based on the use case.
```

The updated Step 1 (formerly Step 0) keeps its existing content but is renumbered.

The updated Step 2 (formerly Step 1) modifies the subagent instructions template to include use case and expected outcome from the profile:

```
You are [role from profile Agent section]. You want to use the "[feature from profile]" capability of this project.

Your use case: [use case from profile]
Your expected outcome: [expected outcome from profile]

Here is the README:
[content]

Here are the relevant docs:
[excerpts]

Your task — act as a real user:
1. Read the docs to figure out how to use "[feature]".
2. Follow the installation/setup instructions.
3. Write and run code (or commands) that exercises the feature meaningfully.
4. Evaluate whether the expected outcome was achieved.
5. Report back with:
   - **Discoverability:** Could you figure out how to use this from docs alone? What was missing?
   - **Setup:** Did installation/setup work as described?
   - **Functionality:** Did the feature work? What succeeded, what failed?
   - **Expected vs Actual:** Did the outcome match what you expected?
   - **Friction points:** What was confusing, misleading, or undocumented?
   - **Doc suggestions:** What would you add or change in the docs?
```

The updated Step 3 (formerly Step 2) adds profile and use case info to the report header:

```markdown
**Profile:** [profile name or "ephemeral"]
**Use Case:** [use case description]
**Expected Outcome:** [expected outcome]
```

And adds an "Expected vs Actual Outcome" section to the report body.

**Step 2: Verify the SKILL.md reads correctly**

Read `skills/test-feature/SKILL.md` end-to-end. Verify step numbering is sequential (0, 1, 2, 3), all `AskUserQuestion` calls are well-formed, and the profile format example is correct.

**Step 3: Commit**

```bash
git add skills/test-feature/SKILL.md
git commit -m "feat: add agent profile selection to test-feature skill"
```

---

### Task 3: Update test-skill SKILL.md — insert Step 0 (agent profiles)

**Files:**
- Modify: `skills/test-skill/SKILL.md:14-57` (current Step 0 becomes Step 1), `skills/test-skill/SKILL.md:58-81` (current Step 1 becomes Step 2)

**Step 1: Insert the new Step 0 and renumber existing steps**

Insert the same Step 0 section (0a, 0b, 0c) as in Task 2 between the `---` separator (line 12) and the current Step 0 (line 14).

Renumber: Step 0 → Step 1, Step 1 → Step 2, Step 2 → Step 3, Step 3 → Step 4.

**Adapt Step 0 for test-skill context:**

- In 0a (Select Feature), "feature" means "skill to test" — the FEATURES.md lists available skills, not project features. Discovery searches for `SKILL.md` files under `skills/` and common skill locations.
- In 0b (Select Use Case), scenarios are inferred from the skill's decision points and phases rather than feature docs.
- In 0c, the profile is used to populate the persona for the simulated user subagent.

**Update Step 2 (formerly Step 1 — Generate Persona):**

- If a profile was selected with Agent details: skip persona generation, use the profile's Agent section directly. Auto-fill missing optional fields.
- If "Random" or "Skip" was selected: run the existing persona generation logic unchanged.
- Keep the existing `AskUserQuestion` for persona adjustment (looks good / more challenging / more cooperative / adversarial / custom) — but pre-populate with the profile's persona if one was loaded.

**Update Step 3 (formerly Step 2 — Execute):** The subagent prompt uses the profile's use case and expected outcome to give the simulated user a specific goal.

**Update Step 4 (formerly Step 3 — Report):** Add profile name, use case, and expected outcome to the report header. Add "Expected vs Actual Outcome" section.

**Step 2: Verify the SKILL.md reads correctly**

Read `skills/test-skill/SKILL.md` end-to-end. Verify step numbering is sequential (0, 1, 2, 3, 4), all `AskUserQuestion` calls are well-formed, profile references are consistent.

**Step 3: Commit**

```bash
git add skills/test-skill/SKILL.md
git commit -m "feat: add agent profile selection to test-skill skill"
```

---

### Task 4: Update CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Add agent profiles documentation**

Add a new section after "## Architecture" describing the agent profiles feature:

```markdown
## Agent Profiles

Reusable test configurations stored in `docs/agent-profiles/` as Markdown files.

- **FEATURES.md** — persistent feature list, auto-discovered on first run
- **`<feature>-<name>.md`** — saved profiles with feature, use case, expected outcome, and optional agent persona
- Both skills present a Step 0 that lets users select a feature, use case, and agent profile before testing begins
```

Update the "## Key Files" section to include:

```markdown
- `docs/agent-profiles/` — Reusable agent profiles and feature list
```

**Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add agent profiles to CLAUDE.md"
```

---

### Task 5: Update design doc structure

**Files:**
- Modify: `docs/plans/2026-03-06-agentic-tests-design.md`

**Step 1: Update the Structure section**

Add `agent-profiles/` to the directory tree:

```
docs/
├── agent-profiles/
│   ├── FEATURES.md
│   └── *.md (saved profiles)
├── plans/
└── test-reports/
```

**Step 2: Commit**

```bash
git add docs/plans/2026-03-06-agentic-tests-design.md
git commit -m "docs: update project structure with agent-profiles"
```
