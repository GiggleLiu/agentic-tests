# Design: Agent Profiles

**Date:** 2026-03-08

## Overview

Add reusable "agent profiles" to both test-skill and test-feature. A profile is a saved test configuration capturing what to test (feature, use case, expected outcome) and who tests it (agent persona). Profiles live in `docs/agent-profiles/` as Markdown files, enabling users to re-run tests with consistent configurations.

## Decisions

- **Scope:** Both test-skill and test-feature
- **Profile = test config:** Primarily stores feature, use case, expected outcome. Agent persona details are secondary/optional.
- **Storage:** `docs/agent-profiles/<feature>-<name>.md` (pure Markdown)
- **Feature list:** Persistent `docs/agent-profiles/FEATURES.md` avoids re-discovery every run
- **Approach:** Pre-step insertion (Step 0) before existing skill logic

## File Structure

```
docs/
├── agent-profiles/
│   ├── FEATURES.md              ← persistent feature list
│   ├── authentication-alice.md  ← saved profile
│   └── cli-setup-bob.md         ← saved profile
├── plans/
└── test-reports/
```

## FEATURES.md Format

```markdown
# Features

- Authentication — OAuth login, token management
- CLI Setup — Installation and initial configuration
- Plugin System — Loading and configuring plugins
```

Auto-discovered from project docs on first run. Loaded from file on subsequent runs. User can choose to update/re-discover.

## Profile Format

`docs/agent-profiles/<feature>-<name>.md`:

```markdown
# <feature>-<name>

## Target
Authentication

## Use Case
Frontend developer integrating OAuth login into a React app, following docs to set up token refresh.

## Expected Outcome
Successfully authenticate, receive tokens, and refresh an expired token without re-login.

## Agent

### Background
Frontend developer with 3 years of React experience.

### Experience Level
Intermediate

### Decision Tendencies
Prefers quick results, skips optional steps.

### Quirks
Skeptical of auto-generated code.
```

**Core fields** (always present): Target (feature or skill name), Use Case, Expected Outcome.

**Optional fields** (under `## Agent`): Background, Experience Level, Decision Tendencies, Quirks, Domain Expertise, Communication Style, or any custom heading. If omitted, the skill auto-generates persona details based on the use case.

## Step 0 Flow — Select Feature, Scenario & Agent Profile

### 0a. Select Feature

Load `docs/agent-profiles/FEATURES.md`. If it doesn't exist, discover features from project docs and create the file.

Present via `AskUserQuestion`:

> "Which feature would you like to test?"
> - **(a)** Authentication — OAuth login, token management
> - **(b)** CLI Setup — Installation and initial configuration
> - **(c)** Plugin System — Loading and configuring plugins
> - **(d)** Update feature list — re-discover from docs and edit

### 0b. Select Use Case

Analyze the chosen feature's docs/code. Propose 2-4 scenarios with suggested expected outcomes.

Present via `AskUserQuestion`:

> "Pick a use case for testing [feature]:"
> - **(a)** Happy path login — User logs in via OAuth, receives valid tokens. *Expected: redirect to dashboard with access + refresh tokens stored*
> - **(b)** Token refresh — Access token expires, app refreshes silently. *Expected: new access token without re-login prompt*
> - **(c)** Invalid credentials — User enters wrong password. *Expected: clear error message, no token issued*
> - **(d)** Describe my own use case

User can confirm or modify the expected outcome before proceeding.

### 0c. Select Agent Profile

Scan `docs/agent-profiles/<feature>-*.md` for existing profiles matching the selected feature. Generate 3 diverse personas based on the feature and use case.

Present via `AskUserQuestion`:

> "Choose an agent profile for this test:"
> - **(a)** Load saved: `authentication-alice` — Frontend dev, intermediate, 3yr React experience
> - **(b)** Wei — Backend engineer, expert | Methodical, reads all docs before starting. Pushes back on ambiguous instructions.
> - **(c)** Jordan — CS student, beginner | Enthusiastic but easily confused. Skips setup steps. Asks lots of questions.
> - **(d)** Priya — DevOps engineer, intermediate | Wants quick results, tests edge cases instinctively. Skeptical of magic.
> - **(e)** Create custom profile
> - **(f)** Random — auto-generate and go

- Option (a) only shown when matching saved profiles exist
- Options (b-d) are freshly generated each time, diverse in background/experience/tendencies
- On selection of (b-d), ask whether to save the profile for reuse
- Option (f) auto-generates everything and proceeds immediately

## Integration with Existing Skills

### test-skill

Step 0 (Select Feature, Scenario & Profile) is inserted before the current Step 0 (Choose Target & Analyze). The profile's feature field determines the target skill. The use case and expected outcome inform the test scope. The agent persona replaces Step 1 (Generate Persona) — missing optional fields are auto-filled.

### test-feature

Step 0 (Select Feature, Scenario & Profile) is inserted before the current Step 0 (Discover Project & Features). The profile's feature field narrows which features to test. The use case and expected outcome shape the subagent instructions. The agent persona details shape the "role" given to each subagent — missing fields are auto-generated.

### Backward Compatibility

Both skills retain their existing behavior when the user chooses "Random" or if no profiles directory exists. The new step is additive.
