---
name: create-profile
description: Use when creating or managing agent profiles for testing — guides users through selecting a feature/skill, defining a use case with expected outcome, and choosing or generating an agent persona, saving reusable profiles to docs/agent-profiles/
---

## Create Profile

Creates reusable agent profiles for test-skill and test-feature. A profile captures what to test (feature, use case, expected outcome) and who tests it (agent persona). Profiles are saved as Markdown files in `docs/agent-profiles/` and can be loaded by test-skill and test-feature.

**Input:** `/create-profile` with no arguments starts the interactive flow. `/create-profile <feature-name>` skips to Step 2 with the feature pre-selected.

---

### Step 1 — Select Feature or Skill

Determine whether the user wants to test a project feature or a skill:

1. Discover features and skills from the project:
   - **Features:** Read `README.md`, `CLAUDE.md`, `AGENTS.md`, doc files, and project structure for user-facing features.
   - **Skills:** Search for `SKILL.md` files under `skills/` and common locations (`~/.claude/skills/`, plugin directories).

2. Present the combined list via `AskUserQuestion`:
   ```
   What would you like to create a profile for?

   Features:
   a) [Feature 1] — [description]
   b) [Feature 2] — [description]

   Skills:
   c) [Skill 1] — [description]
   d) [Skill 2] — [description]

   u) Re-discover — scan project again
   ```
   If only features or only skills were found, show just that section.

3. If the user picks "Re-discover", re-scan the project and re-present.
4. Record the chosen feature/skill name.

### Step 2 — Define Use Case

1. Analyze the chosen feature's docs or skill's `SKILL.md` to understand what scenarios are possible.
   - **For features:** Read README sections, doc files, examples, API references.
   - **For skills:** Read the skill's phases, decision points, and flow.
2. Propose 2-4 realistic usage scenarios, each with a suggested expected outcome. Present via `AskUserQuestion`:
   ```
   Here are some use cases for "[feature/skill]":
   a) [Scenario 1] — Expected: [what success looks like]
   b) [Scenario 2] — Expected: [what success looks like]
   c) [Scenario 3] — Expected: [what success looks like]
   d) Describe your own use case

   Which use case?
   ```
3. If the user picks "Describe your own use case", ask them to describe the scenario and expected outcome.
4. Confirm the expected outcome with the user:
   ```
   Use case: [selected use case]
   Expected outcome: [expected outcome]

   Does this look right? (yes / edit)
   ```
5. Record the chosen use case and expected outcome.

### Step 3 — Choose Agent Persona

1. Scan `docs/agent-profiles/` for files matching `<feature>-*.md` (where `<feature>` is the chosen name, lowercased, with spaces replaced by hyphens).
2. Generate 3 diverse persona suggestions based on the feature/skill and use case. Vary experience level (beginner, intermediate, expert) and background.
3. Present via `AskUserQuestion`:
   ```
   Agent profile options:
   [If saved profiles exist:]
   a) Load saved: [profile-name] — [background summary]
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
4. If the user picks a saved profile, load it and ask if they want to update the use case/expected outcome (since those may differ from what's saved).
5. If the user picks a generated persona (b-d), populate the full profile fields.
6. If the user picks "Create a custom profile", ask for background and experience level. Optionally ask for decision tendencies and quirks.
7. If the user picks "Random", generate a surprising but plausible persona.

### Step 4 — Save Profile

1. Present the complete profile to the user:
   ```
   Profile summary:
   - Target: [feature/skill name]
   - Use Case: [use case]
   - Expected Outcome: [expected outcome]
   - Agent: [name] — [background], [experience level]
   - Tendencies: [decision tendencies]
   - Quirks: [quirks]
   ```

2. Ask via `AskUserQuestion`:
   ```
   Save this profile?
   a) Save to docs/agent-profiles/[feature]-[name].md
   b) Edit something first
   c) Don't save — just display it
   ```

3. If saving, write the file using this format:

   ```markdown
   # [feature]-[name]

   ## Target
   [Feature or skill name]

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
   [How they behave at choice points]

   ### Quirks
   [Realistic traits that add personality]
   ```

4. After saving (or displaying), offer next steps via `AskUserQuestion`:
   ```
   Profile ready. What next?
   a) Create another profile
   b) Run /test-feature with this profile
   c) Run /test-skill with this profile
   d) Done
   ```
