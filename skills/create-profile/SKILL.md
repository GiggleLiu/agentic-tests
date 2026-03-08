---
name: create-profile
description: Use when creating or managing agent profiles for testing — guides users through selecting a feature/skill, defining a use case with expected outcome, and choosing or generating an agent persona, saving reusable profiles to docs/agent-profiles/
---

## Create Profile

Creates reusable agent profiles for test-skill and test-feature. A profile captures what to test (target, use case, expected outcome) and who tests it (agent persona). Profiles are saved as Markdown files in `docs/agent-profiles/` and can be loaded by test-skill and test-feature.

**Input:** `/create-profile` with no arguments starts the interactive flow. `/create-profile <target-name>` skips to Step 2 with the feature or skill pre-selected.

---

### Step 1 — Select Feature or Skill

Determine whether the user wants to test a project feature or a skill:

1. Discover features and skills from the project:
   - Read `README.md`, `CLAUDE.md`, `AGENTS.md`, other doc files, and project structure when present. If any expected file is missing, continue with the remaining sources instead of failing.
   - **Features:** Extract user-facing project capabilities such as commands, workflows, APIs, integrations, or configuration systems.
   - **Skills:** Search for `SKILL.md` files under `skills/`, `.agents/skills/`, and `~/.agents/skills/`. Also check command files under `~/.claude/commands/` and `~/.config/opencode/commands/`.

2. Present the combined list via `AskUserQuestion`, explicitly separating features from skills:
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
   If only features or only skills were found, show just that section. If the user is testing a skill, record the specific skill name (for example `test-skill`) rather than a broader feature label. If the user is testing project functionality, record the feature name.

3. If the user picks "Re-discover", re-scan the project and re-present.
4. Record the chosen target type (`feature` or `skill`), the chosen target name, and a normalized target slug (lowercase, spaces replaced with hyphens) for later filename suggestions.

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
4. Confirm the use case and expected outcome with an explicit edit loop:
   ```
   Use case: [selected use case]
   Expected outcome: [expected outcome]

   Does this look right?
   a) Accept
   b) Edit use case
   c) Edit expected outcome
   d) Edit both
   ```
   - If the user picks **Edit use case**, ask for a rewritten use case, then regenerate or confirm the expected outcome again.
   - If the user picks **Edit expected outcome**, ask for the rewritten expected outcome directly.
   - If the user picks **Edit both**, ask for both fields explicitly and re-confirm them.
5. Record the chosen use case and expected outcome. Do not ask about filenames yet; leave save decisions for Step 4 after the persona is finalized.

### Step 3 — Choose Agent Persona

1. Scan `docs/agent-profiles/` for files matching `<target-slug>-*.md`. Prefer profiles whose `## Target Type` exactly matches the chosen target type. If the field is missing, treat the file as a legacy profile and only offer it when its `## Target` clearly matches the chosen target.
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
4. If the user picks a saved profile, load it and ask:
   ```
   Reuse this saved profile's persona?
   a) Yes — keep my current use case and expected outcome
   b) Yes — also replace my current use case and expected outcome with the saved values
   c) No — go back to the persona choices
   ```
5. If the user picks a generated persona (b-d), populate the full profile fields.
6. If the user picks "Create a custom profile", ask for name, background, experience level, decision tendencies, and quirks. If the user only gives part of this information, ask only for the missing fields.
7. If the user picks "Random", generate a surprising but plausible persona.

### Step 4 — Save Profile

1. Generate normalized slugs for the target, persona name, and use case. Slugs must contain only lowercase letters, numbers, and hyphens. Always build the save path as:
   - `docs/agent-profiles/<target-slug>-<use-case-slug>-<persona-slug>.md`

2. Present the complete profile to the user together with the save choices and a short save preview:
   ```
   Profile summary:
   - Target Type: [feature/skill]
   - Target: [feature/skill name]
   - Use Case: [use case]
   - Expected Outcome: [expected outcome]
   - Agent: [name] — [background], [experience level]
   - Tendencies: [decision tendencies]
   - Quirks: [quirks]

   Next action:
   a) Save as [target-usecase-persona path]
   b) Don't save — just display it

   Saved file preview:
   # [chosen filename stem]

   ## Target Type
   [feature/skill]

   ## Target
   [feature/skill name]

   ## Use Case
   [use case]

   ## Expected Outcome
   [expected outcome]
   ```
3. If the chosen path already exists, ask:
   ```
   That profile already exists.
   a) Overwrite it
   b) Cancel save
   ```
4. If saving, write the file using this format:
   - Before writing, verify one more time that the resolved destination is inside `docs/agent-profiles/`.
   - Never overwrite files outside `docs/agent-profiles/`, even if the normalized filename appears valid.

   ```markdown
   # [filename stem]

   ## Target Type
   [feature|skill]

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

5. After saving (or displaying), offer next steps via `AskUserQuestion`:
   ```
   Profile ready. What next?
   a) Create another profile
   b) Run /test-feature with this profile
   c) Run /test-skill with this profile
   d) Done
   ```
