---
name: test-writing
description: Use when testing a paper's writing quality from a reader's perspective — simulates first-time readers with calibrated audience profiles who scan, then deep-read section by section, reporting on clarity, confusion points, structure, and flow
---

## Test Writing

Simulates first-time readers who encounter an academic paper for the first time. Each simulated reader scans the abstract and titles, then reads section by section in document order, flagging every point of confusion as it occurs. The reader never re-reads to resolve confusion — if the writing didn't prevent it, that's a writing problem.

Works with any academic paper in LaTeX format.

**Input:** `/test-writing <file-path>` tests the paper at the given path. `/test-writing` without arguments looks for `.tex` files in the current directory.

---

### Step 0 — Audience Profile

The caller provides an audience profile that calibrates the reader's confusion threshold. If no profile is provided, infer one from the paper's `\documentclass`, title, and abstract.

**Profile fields:**
- **Field**: The reader's research area (e.g., "quantum computing / AMO physics")
- **Level**: Experience level (e.g., "active researcher", "PhD student", "general physicist")
- **Assumes**: What background the reader has (e.g., "familiarity with toric code, Rydberg blockade, EIT")
- **Confusion threshold**: HIGH / MEDIUM / LOW

**How the threshold calibrates the read:**

| Aspect | HIGH (specialist) | MEDIUM (broad) | LOW (general) |
|--------|-------------------|----------------|---------------|
| **Confusion flags** | Only truly novel/ambiguous notation | Unexplained subfield jargon | Any term a general reader wouldn't know |
| **Acronym expansion** | Only paper-specific acronyms | All subfield acronyms | Every acronym |
| **Concepts-before-use** | Only protocol-specific concepts | Subfield concepts too | All technical concepts |
| **Redundancy tolerance** | Tight — assume reader follows quickly | Some recapping OK at section boundaries | More recapping acceptable |

---

### Step 1 — Discover Paper Structure

Read ONLY:
- The `\documentclass` line (for journal class and target)
- The `\title{...}`
- The `\begin{abstract}...\end{abstract}` block
- Every `\section{}` and `\subsection{}` title (NOT body text)
- The first `\begin{figure*}` or `\begin{figure}` caption (the overview figure)

Do NOT read the body text of any section yet.

---

### Step 2 — Test the Paper (Subagent Read)

Dispatch a **subagent** as a first-time reader. Give the subagent:

- **Role:** From the audience profile (field, level, assumed background)
- **Confusion threshold:** From the audience profile
- **File path:** The LaTeX file
- **Instructions:**

```
You are a first-time reader of an academic paper.

**Audience profile:**
- Field: [field]
- Level: [level]
- Assumes: [assumed background]
- Confusion threshold: [HIGH / MEDIUM / LOW]

**File:** [absolute path to .tex file]

## Core Principle: Read Like a Human

Read the way a real first-time reader does:

1. **Scan first** — abstract, section titles, main figure caption. Form a
   first impression BEFORE reading any section body.
2. **Read section by section** — one at a time, in document order.
3. **Complain when confused** — if something doesn't make sense on first
   read, flag it immediately. Don't silently figure it out by reading ahead.
   Real readers don't have that luxury. Confusion on first read = a writing
   problem.
4. **Never re-read to resolve confusion** — if you had to re-read, look
   ahead, or consult an earlier section to understand something, that's a
   confusion flag. The writing should have prevented that. Flag it and
   move on.

## The Confusion Protocol

At every reading stage, if you feel confused, lost, or need to re-read
something, STOP and record it as a confusion flag:

  [CONFUSED] Line 87: "sequential excitation protocol" — first mention,
     no prior explanation. I have no idea what this means yet.

  [CONFUSED] Sec III preamble: After reading titles, I expected gate
     design here, but the first paragraph is about decoherence channels.

  [CONFUSED] Line 263: Notation switches from $V_{dd}$ to $V_{ct}$.
     Are these the same thing? I had to re-read the previous section.

Key rule: If you had to re-read, look ahead, or consult an earlier section
to understand something, that's a confusion flag. The writing should have
prevented that.

Calibrate your sensitivity using your confusion threshold:
- HIGH: only flag truly novel/ambiguous notation or protocol-specific terms
- MEDIUM: also flag unexplained subfield jargon
- LOW: flag any term a general reader wouldn't know

## Tasks

### Task A: Quick Scan

Read ONLY: abstract, section/subsection titles, first figure caption.
Do NOT read section bodies yet.

Report:
(a) What is this paper about? (1-2 sentences, your best guess)
(b) What is the main contribution? (from abstract)
(c) Does the section structure make sense for this type of paper?
(d) Does the main figure help you understand the paper's story?
(e) Is the abstract self-contained? Could a reader in the field understand
    the contribution from abstract + figure alone? What's missing?
(f) Any confusion flags from the scan alone?

### Task B: Section-by-Section Deep Read

Now read each section's body text one at a time, in document order.
After reading each section, IMMEDIATELY record (before reading the next):

- **What it accomplished** (1 sentence)
- **Delivered on title?** (Yes/No + brief note)
- **Confusion flags**: Anything that didn't make sense on first read.
  Format: [CONFUSED-N] Line XX: "quoted text" — why it confused you.

**CRITICAL**: Do NOT re-read earlier sections to resolve confusion.
If you're confused, that's the paper's problem. Flag it and move on.

### Task C: Structure Assessment

After reading all sections once, assess:
(a) Convention: IMRaD / proposal+validation / theory+experiment / other?
(b) Mission of each section (1 sentence each) — in a table
(c) Does the ordering serve the paper's story?
(d) Are there gaps, redundancies, or misplaced content?

### Task D: Paragraph Flow Diagnosis

Only for sections that had confusion flags or structural issues:
1. What is the expected paragraph flow for this section type?
   (Introduction: context -> gap -> contribution -> outline;
    Methods: setup -> procedure -> validation; etc.)
2. Does each paragraph advance the section's mission?
3. Flag paragraphs that are misplaced, missing, or don't serve the mission.

## Output Format

Return ALL of the following:

### First Impression (Task A)
[What the paper is about, main contribution, structure sense,
 figure helpfulness, abstract self-containedness, scan confusion flags]

### Per-Section Notes (Task B)
[One block per section: accomplishment + delivered? + confusion flags]

### Structure Analysis (Task C)
[Convention, mission table, structure issues]

### Paragraph Flow Diagnosis (Task D)
[Only for flagged sections: mission, expected flow, assessment]
```

---

### Step 3 — Report

Gather the subagent's results. Present report in this format:

```markdown
# Writing Test Report: [paper title]

**Date:** [timestamp]
**Paper type:** [journal class / convention]
**Audience profile:** [field, level, threshold]
**Sections tested:** [list]
**Confusion flags:** [total count]

## First Impression
[From subagent Task A — what the reader understood from scan alone]

## Summary

| Section | Delivered on Title | Confusion Flags | Flow Issues |
|---------|-------------------|-----------------|-------------|
| [name]  | [yes/partial/no]  | [count]         | [yes/no]    |

## Per-Section Details

### [section name]
- **What it accomplished:** [1 sentence]
- **Delivered on title?** [yes/no + note]
- **Confusion flags:**
  - [CONFUSED-N] Line XX: "text" — reason
- **Paragraph flow:** [assessment, if flagged]

## Structure Analysis
[Convention, ordering assessment, gaps/redundancies]

## All Confusion Flags (ordered by severity)
[Consolidated list, most impactful first]

## Suggestions
[Actionable improvements ordered by impact]
```

The caller (e.g., paper-revision skill) uses this report to propose fixes.

---

### Cross-Platform Subagent Guide

Subagent support varies across AI coding assistants. Use the right mechanism for your platform:

#### Claude Code

Use the **`Agent`** tool:
- Use `subagent_type: "general-purpose"` for simulated readers
- Single subagent per paper (reads sequentially by design)

```
Agent(prompt: "You are [role]. Read [paper]...", subagent_type: "general-purpose")
```

#### OpenCode

Use the **`Task`** tool:
- Subagents are stateless — each invocation is a fresh session
- Each subagent gets its own full prompt with all context needed

```
Task(prompt: "You are [role]. Read [paper]. ...")
```

---

### Integration

| Direction | Skill | Relationship |
|-----------|-------|-------------|
| Caller | `paper-revision` | Invokes test-writing for Phase 0, uses report to propose fixes |
| Caller | `academic-paper-reviewer` | Can invoke test-writing for readability assessment |
| Standalone | — | User runs directly to get a reader's perspective on their paper |

---

### Version Info

| Item | Content |
|------|---------|
| Version | 1.0 |
| Created | 2026-04-05 |
| Role | Simulate first-time readers testing paper writing quality |
