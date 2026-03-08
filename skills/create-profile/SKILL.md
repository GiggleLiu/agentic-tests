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
   ```
   If only features or only skills were found, show just that section. If the user is testing a skill, record the specific skill name (for example `test-skill`) rather than a broader feature label. If the user is testing project functionality, record the feature name.

3. Record the chosen target type (`feature` or `skill`), the chosen target name, and a normalized target slug (lowercase, spaces replaced with hyphens) for later filename suggestions.

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
4. Record the chosen use case and expected outcome. Do not ask follow-up edit questions; continue directly to persona selection.

### Step 3 — Choose Agent Persona

1. Generate 3 diverse persona suggestions based on the feature/skill and use case. Vary experience level (beginner, intermediate, expert) and background.
2. Present via `AskUserQuestion`:
   ```
   Agent profile options:
   a) [Name] — [Experience level], [one-line background summary]
   b) [Name] — [Experience level], [one-line background summary]
   c) [Name] — [Experience level], [one-line background summary]

   Which agent profile?
   ```
3. If the user picks a generated persona (a-c), populate the full profile fields.

### Step 4 — Save Profile

1. Generate normalized slugs for the target, persona name, and use case. Slugs must contain only lowercase letters, numbers, and hyphens. Always build the save path as:
   - `docs/agent-profiles/<target-slug>-<use-case-slug>-<persona-slug>.md`

2. Present the complete profile to the user together with a short save preview. Then save it immediately using the generated path unless there is a filename collision:
   ```
   Profile summary:
   - Target Type: [feature/skill]
   - Target: [feature/skill name]
   - Use Case: [use case]
   - Expected Outcome: [expected outcome]
   - Agent: [name] — [background], [experience level]
   - Tendencies: [decision tendencies]
   - Quirks: [quirks]

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

5. After saving, offer next steps via `AskUserQuestion`:
   ```
   Profile ready. What next?
   a) Create another profile
   b) Run /test-feature with this profile
   c) Run /test-skill with this profile
   d) Done
   ```
