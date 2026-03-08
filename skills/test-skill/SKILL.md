---
name: test-skill
description: Use when testing a skill — role-plays through a skill's conversational flow with a simulated user persona, then produces a test report with structural analysis, UX feedback, and actionable suggestions
---

## Test Skill

A general-purpose skill testing framework. It executes any skill's SKILL.md by role-playing the interaction: the main agent follows the skill's instructions, while a subagent plays a realistic simulated user. This tests whether the skill produces a coherent experience end-to-end.

**Architecture:** Main agent = AI executing the target skill. Subagent = simulated user with a persona, resumed at each decision point.

---

### Step 0 — Select Agent Profile

#### 0a. Select Skill

1. Check whether `docs/agent-profiles/SKILLS.md` exists in the project.
   - **If it exists:** Load the skill list from it.
   - **If it does not exist:** Discover available skills by searching for `SKILL.md` files under `skills/` in the current project and common skill locations (`~/.claude/skills/`, plugin directories). Create `docs/agent-profiles/SKILLS.md` with the discovered skills using this format:
     ```markdown
     # Skills

     - [Skill Name] — [one-line description from SKILL.md frontmatter]
     ```
   - **Note:** This file is separate from `FEATURES.md` used by test-feature. Both can coexist in the same directory.
2. Present the skill list to the user via `AskUserQuestion`:
   ```
   I found these skills:
   a) [Skill 1] — [description]
   b) [Skill 2] — [description]
   ...
   u) Update the skill list

   Which skill would you like to test?
   ```
3. If the user picks "Update the skill list", let them add/remove/edit skills, save the updated `docs/agent-profiles/SKILLS.md`, and re-present the list.
4. Record the chosen skill name and path for the following sub-steps.

#### 0b. Select Use Case

1. Read the chosen skill's `SKILL.md` and analyze its phases, decision points, and flow to understand what interaction scenarios are possible.
2. Propose 2–4 realistic usage scenarios, each with a suggested expected outcome. Infer scenarios from the skill's decision points and phases. Present via `AskUserQuestion`:
   ```
   Here are some use cases for "[skill name]":
   a) [Scenario 1 — e.g., "Happy path — user accepts all suggestions"] — Expected: [what success looks like]
   b) [Scenario 2 — e.g., "Challenging — user pushes back at first decision point"] — Expected: [what success looks like]
   c) [Scenario 3 — e.g., "Off-topic — user asks about unrelated topic mid-flow"] — Expected: [what success looks like]
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

1. Scan `docs/agent-profiles/` for files matching `<skill>-*.md` (where `<skill>` is the chosen skill name, lowercased, with spaces replaced by hyphens).
2. Generate 3 diverse persona suggestions based on the skill and use case. Vary experience level (beginner, intermediate, expert) and background.
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
   Save this profile to docs/agent-profiles/[skill]-[name].md? (yes / no)
   ```
   If yes, write the file using this format:
   ```markdown
   # [skill]-[name]

   ## Feature
   [Skill name]

   ## Use Case
   [What the user scenario is]

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

### Step 1 — Choose Target & Analyze

Accept a skill path from the user, or — if a skill was already selected in Step 0 — use that selection. If neither, list available skills and let the user pick via `AskUserQuestion`.

**Find available skills:** Search for `SKILL.md` files under `skills/` in the current project. Also check common skill locations (`~/.claude/skills/`, plugin directories). Present each skill with its `name` and `description` from frontmatter.

Once the user selects a skill (or the Step 0 selection is confirmed), read its full `SKILL.md` and extract:

- **Phases/steps** and their entry conditions (e.g., "skip if chaining from survey")
- **Decision points** — every place the skill calls `AskUserQuestion`, with the options it presents
- **Preconditions** — files, registries, context, or external services the skill expects (e.g., survey registries, user profiles, MCP servers)
- **Expected outputs** — files created, formats, locations
- **Dependencies** — other skills referenced, MCP servers, APIs

**Flag structural issues** found during analysis:
- Decision points with no fallback/escape option (e.g., user must pick from presented choices with no "none of these")
- Abrupt phase transitions where the skill jumps from one mode to another without bridging
- Phases that reference files or context without checking if they exist first
- Asymmetric option handling (e.g., option (a) has a follow-up but (b) and (c) don't)

Present this structural analysis to the user, including any flagged issues. Example format:

```
## Skill Analysis: [name]

**Phases:** [list with brief descriptions]
**Decision points:** [count] AskUserQuestion calls identified
**Preconditions:**
  - [file/context] — [required/optional]
**Expected outputs:**
  - [file path] — [description]
**Dependencies:**
  - [skill/service] — [how it's used]
**Structural flags:**
  - [issue] at [location]
```

Ask the user via `AskUserQuestion`:

> "Here's what I found. Ready to proceed, or want to adjust the test scope?"
> - **(a)** Proceed — test the full skill flow
> - **(b)** Focus on specific phases — choose which phases to test
> - **(c)** Adjust preconditions — set up specific mock context before testing

### Step 2 — Generate Persona

**If a profile was loaded in Step 0 with Agent details:** Pre-populate the persona from the profile fields (Background, Experience Level, Decision Tendencies, Quirks). Infer Motivation from the profile's Use Case. Present the pre-populated persona to the user for adjustment (see below).

**If "Random" was selected in Step 0:** Run the full persona generation below as if no profile exists.

**If a profile was loaded but has no Agent details:** Auto-generate a persona based on the use case and skill analysis, then present for adjustment.

**If Step 0 was skipped (no profile):** Analyze the skill to infer what kind of user it serves. Consider:

- What domain knowledge does the skill assume?
- What motivations would bring someone to this skill?
- What range of experience levels does it handle?

Generate a persona with:

- **Name and background** — relevant to the skill's domain
- **Motivation** — why they'd use this skill (specific and concrete)
- **Experience level** — beginner, intermediate, or expert in the relevant domain
- **Decision tendencies** — how they'll behave at choice points (e.g., "explores broadly before committing", "wants quick results", "pushes back on suggestions", "asks lots of clarifying questions")
- **Quirks** — one or two realistic traits that make them not a perfectly compliant test subject (e.g., "sometimes goes off on tangents", "skeptical of AI-generated suggestions", "changes their mind after seeing options")

Present the persona to the user via `AskUserQuestion`:

> "[Persona description]"
> - **(a)** Looks good — start the test
> - **(b)** Make them more challenging — increase pushback and skepticism
> - **(c)** Make them more cooperative — reduce friction, focus on happy path
> - **(d)** Adversarial — generate a persona designed to break assumptions (one-word answers, misunderstandings, off-topic tangents, ignores instructions)
> - **(e)** Let me describe a custom persona

### Step 3 — Execute the Skill with Role Play

**Set up preconditions.** Based on Step 1 analysis, create any mock files or context the skill expects. For example:
- If the skill checks for a user profile, create a mock `docs/discussion/user-profile.md` matching the persona
- If the skill expects survey registries, create minimal mock registries
- If the skill needs MCP servers, note which are available and which will be absent

**Important:** Create mock files in a test-scoped location when possible (e.g., prefix with `test-` or use a temporary directory) to avoid polluting the user's actual data. When mock files must go in expected locations, track them for cleanup.

**Launch the user subagent** via `Task` tool (subagent_type: `general-purpose`):

```
You are role-playing as a simulated user testing a skill. Here is your persona:

Name: [name]
Background: [background]
Motivation: [motivation]
Experience: [experience level]
Decision tendencies: [tendencies]
Quirks: [quirks]

You are testing a tool that [one-line skill description].

Use case: [use case from profile, or "general exploration" if none]
Expected outcome: [expected outcome from profile, or "discover what happens" if none]

Your goal is to interact with this skill as a real user pursuing the above use case. Your interactions should naturally drive toward (or away from, if your persona would) the expected outcome.

When I present you with questions or options, respond in character:
- Be realistic — sometimes enthusiastic, sometimes uncertain, sometimes push back or ask for clarification
- Stay consistent with your persona's background and tendencies
- Give enough detail in your responses that the skill can work with them (don't just say "option A")
- If options don't fit what your persona would want, say so and explain what you'd prefer
- Don't break character or discuss the test itself

At the end, I'll ask for your feedback on the experience from your persona's perspective.

The first question is: [first decision point from the skill]
```

**Execute the target skill's phases**, following its SKILL.md instructions exactly. At each point where the skill calls `AskUserQuestion`:

1. **Resume the subagent** with the question and options, plus brief conversation context
2. Record the subagent's response
3. Continue executing the skill as if the subagent's response came from a real user

**Track the interaction** as a trace — record each:
- Phase/step being executed
- Question presented (with options)
- Subagent's response
- Main agent's next action
- Any files created or modified

**Safety caps:**
- Maximum **20 decision points** — if reached, gracefully wrap up the skill
- Maximum **10 subagent resumes** per phase — if a phase loops, note it and move on
- If the skill attempts to launch its own subagents (e.g., survey's parallel strategies), execute them normally — only the user-facing `AskUserQuestion` calls go to the simulated user

### Step 4 — Collect Feedback & Report

**Resume the subagent one final time** — stay in character. Interview the persona as the skill's agent would naturally wrap up:

```
We're wrapping up. A few questions before you go:

1. What was most useful from today?
2. Was there anything confusing, or that didn't fit what you needed?
3. Were there parts that felt too rushed, or parts where we spent too long?
4. Was there anything you wanted to do or ask about but couldn't?
5. What did you walk away with, and what would you change next time?
6. Any other thoughts on how to make this better?
```

The persona answers as themselves — no stepping out of character, no meta-analysis. What they report is grounded in what actually happened during the interaction. The test executor interprets these answers in the Structural Observations section of the report.

**Generate the test report** at `docs/test-reports/<skill-name>-<YYYYMMDD-HHMMSS>.md`:

```markdown
# Test Report: [skill name]

**Date:** [timestamp]
**Persona:** [name] — [one-line description]
**Profile:** [profile name or "ephemeral"]
**Use Case:** [use case description or "none specified"]
**Expected Outcome:** [expected outcome or "none specified"]
**Phases tested:** [list]
**Decision points exercised:** [N of M total]

## Flow Completeness

- **Phases reached:** [which phases were entered]
- **Phases skipped:** [which were skipped and why]
- **Decision points exercised:** [list each with the option chosen]
- **Untested branches:** [options that were NOT selected — these represent untested paths]

## Interaction Trace

[Condensed trace of the full interaction — phase, question, response, action. Not a raw transcript — summarize each exchange in 2-3 lines.]

## Output Validation

- **Expected files:** [list from Step 1 analysis]
- **Actually created:** [list with status — created/missing/wrong format]
- **Format check:** [any format issues in created files]

## Broken References

[Files, skills, paths, or services mentioned in the SKILL.md that don't exist or aren't accessible]

## Persona Interview

[In-character responses from the simulated user to the wrap-up questions. These reflect what happened during the interaction, not meta-analysis.]

## Expected vs Actual Outcome

[Compare the expected outcome (from the profile or Step 0) against what actually happened during the test. Was the expected outcome achieved, partially achieved, or not achieved? Describe any surprising differences. If no expected outcome was specified, note "No expected outcome was specified" and summarize what the interaction produced.]

## Structural Observations (from test executor)

[Main agent's own observations about the skill's design:]
- Ambiguous instructions encountered
- Edge cases not handled
- Phases that felt too long or too short
- Logic that was hard to follow

## Suggestions

[Actionable improvements, ordered by impact:]
1. [High impact suggestion]
2. [Medium impact suggestion]
...
```

**Clean up** any mock files created during testing. List what was cleaned up in the report.

**Add an intent-vs-experience comparison** to the Structural Observations section: for each phase tested, note what the skill's instructions intended to happen alongside what the simulated user actually experienced. Highlight gaps where the experience diverged from intent.

Present the report path to the user and offer:

> "Test complete. Report saved to `docs/test-reports/[file]`. What next?"
> - **(a)** Review the report together — walk through findings
> - **(b)** Run another test — same skill, different persona (skips Step 1 analysis — reuses the existing analysis)
> - **(c)** Test a different skill
> - **(d)** Done

**Re-run shortcut:** When the user selects **(b)**, skip Step 1 entirely — the skill analysis doesn't change. Go straight to Step 2 (persona generation) with the same target skill. If a profile was used, return to Step 0c to select a new profile; otherwise go to Step 2.
