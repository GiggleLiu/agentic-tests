---
name: doc-blindtest
description: Use when auditing whether documentation is sufficient to USE a project, not just understand it. Gives a subagent only the rendered/compiled docs (no source, no repo links), has it explain the architecture and write a minimal integration program from the docs alone, then compiles that program against the real project as a downstream user. The compile result is a binary pass/fail gate; the orchestrator verifies the subagent's inferred API facts against source before trusting them.
---

# Doc Blind-Test

A source-blind documentation audit with a compile gate. It answers a sharper
question than an explain-only doc review: **can a newcomer actually build working
code from the published docs alone?** An explain-only audit can pass while a
real doer is still blocked (missing signatures, no way to construct a core
object, unstated dependency). Compiling doc-faithful code surfaces those gaps
concretely.

This is a stricter instantiation of `test-feature`'s Step 2 subagent, with two
additions: (1) enforced source-blindness — the doer is handed ONLY rendered docs,
never the repo; (2) an explicit compile-against-the-real-project gate whose
verdict is binary, not a subagent's qualitative opinion.

## Two kinds of signal (read this first)

The doer produces two valuable things, and the second is easy to throw away:

1. Where it is **blocked or writes non-compiling code** → a hard documentation
   gap.
2. Where it **confidently misreads** — a wrong inferred fact, or an
   over-escalated worry → a place the docs *invite* misunderstanding.

A weak doer's false positive is **not noise to discard**. A weak reader
misreading X is strong evidence that a real newcomer reading X would misread it
too. The wrong inference pinpoints, for free and with precise location, what the
docs fail to make unmissable. So the response to a doc-induced false positive is
**not "reject"** — it is to lay a **signpost** that makes the misread impossible:
a clarifying sentence, an explicit type annotation, a worked example, a
cross-link, or a comment in the source/rustdoc. Rejecting the candidate without
leaving a signpost wastes the signal and guarantees the same false report — and
the same confused human — next time.

(Examples from real runs: the doer guesses a return type the docs never state;
or it flags two identically-named re-exported types as a clash the docs never
clarify. Neither is a bug; both are exact spots that need one sentence.)

## Roles

- **Orchestrator (this agent)**: has full repo access. Prepares the isolated doc
  artifact, dispatches the blind doer, runs the compile gate, and — critically —
  verifies the doer's claims against real source. The orchestrator owns the
  verdict.
- **Blind doer (subagent)**: has access to ONLY the rendered docs. Explains the
  project and writes a from-docs integration program. Its inferences are
  candidates, never ground truth.

## Step 0 — Load Agent Profile (optional)

Same pattern as `test-feature`. Optionally load a profile from
`docs/agent-profiles/` whose `## Target Type` is `feature`. The persona's
experience level shapes how forgiving the doer is (a "first Rust project"
persona surfaces more gaps than an expert). With no profile, use an ephemeral
"new user, competent in the language, new to this library" persona.

## Step 1 — Identify And Isolate The Doc Surface

Pick the artifact a real new user would actually read, and **physically isolate
it** so the doer cannot reach anything else:

- Prefer rendered/compiled output: the docs site (mdBook/Quarto/Docusaurus
  build), `cargo doc` / `pdoc` / Sphinx HTML, or docs.rs-equivalent. README +
  getting-started/quickstart is the canonical onboarding artifact.
- Copy the chosen files into a fresh, isolated directory (e.g. a scratch dir).
  Do NOT include source code, `Cargo.toml`/`pyproject.toml` internals beyond
  what docs show, git history, issue links, or other repo files.
- Record exactly which doc files were included. The report must state the doc
  surface; gaps only count against docs that were in scope.

## Step 2 — Dispatch The Blind Doer

Use a cheap / non-frontier model. A weaker doer is a feature here: it is less
able to paper over gaps with prior knowledge, so it reveals what the docs
actually fail to say.

Give the subagent ONLY the isolated artifact directory and these instructions:

- **Hard constraint**: read only files in the artifact dir. Do not open the
  project source, do not browse the repo, do not use web search, do not recall
  this library from memory or guess by analogy to other libraries. If something
  needed is not in these docs, that is a FINDING, never something to work around.
- **Task A — Explain**: mental model / architecture, the intended usage path
  step by step, unknowns, and documentation gaps (each citing the doc location).
- **Task B — Build test**: write ONE minimal end-to-end program performing the
  simplest workflow the docs advertise, using ONLY APIs the docs literally show
  (exact import paths, type names, constructors, signatures). Also write the
  dependency manifest block exactly as the docs would lead a user to write it.
  At every point where the docs do not supply something needed to write correct
  code, insert an inline `// GAP: <what is missing>` marker at that exact spot
  instead of guessing. Save the program and manifest into the artifact dir.
- Forbid the doer from compiling or hunting for the project. Writing-from-docs
  is the test; compilation is the orchestrator's job.

Safety rules (inherit from `test-feature`): no sudo, no `rm -rf`, no
curl-pipe-to-shell installs, no writes outside the workspace, no secret access.

## Step 3 — Compile Gate (the binary verdict)

The orchestrator now resolves the doer's program against the **real** project,
as an external downstream consumer would:

1. Create a throwaway downstream project OUTSIDE the workspace. Add the project
   as a dependency the way the docs instruct (resolve any placeholder path/URL
   to the real local checkout or published package).
2. Drop in the doer's program. Build with the language-appropriate command
   (`cargo build`, `pip install . && python prog.py -c`, `tsc`, `go build`, …).
3. Record the build result and full compiler output verbatim. Pass/fail on the
   compile step is the headline verdict.
4. If the docs ship multiple runnable snippets, compile each independently —
   a doc page often contains one rotten snippet beside correct ones.

A clean compile is necessary but not sufficient: a program can compile while
relying on a fact the doer guessed. So also:

5. **Verify the doer's inferred API facts against real source.** Treat every
   "I think X returns Option / takes usize / lives in crate Y" as a candidate.
   Confirm or correct each against the actual signatures. Downgrade or reject
   the doer's severity calls; doers tend to over-escalate cosmetic gaps to
   CRITICAL and under-notice real compile breaks. The orchestrator's
   source-checked verdict, not the doer's, goes in the report.

6. **Turn doc-induced false positives into signposts.** For every inference you
   refuted or severity you downgraded, ask whether the docs led the doer there.
   If the docs are silent, ambiguous, or arranged so a careful reader reaches the
   wrong conclusion, that is an actionable finding even though no bug exists — the
   wrong guess pinpoints exactly what to clarify. Plan a signpost (a clarifying
   sentence, type annotation, worked example, cross-link, or source/rustdoc
   comment). Only a candidate a clear doc would not have provoked is a pure
   reject.

## Step 4 — Report

Save to `docs/test-reports/doc-blindtest-<YYYYMMDD-HHMMSS>.md`:

- **Verdict**: pass/fail of the compile gate; one-line summary.
- **Doc surface**: exact files handed to the doer.
- **Doer architecture summary**: what the docs successfully conveyed.
- **Generated program + manifest**: the from-docs code, with its `// GAP` markers.
- **Compile result**: command(s) + verbatim output, per snippet.
- **Confirmed findings** (orchestrator-verified, with source/permalink + the
  doc location): real compile breaks first, then doc-clarity gaps. Note where
  the doer's inferred answer was WRONG.
- **Misleading-doc findings** (from refuted / over-escalated candidates): for
  each — what the doer wrongly inferred, the doc location that led there, and the
  proposed **signpost** that makes the misread impossible (a one-line
  clarification, type annotation, example, cross-link, or source/rustdoc
  comment). Often the highest-value output: a precisely-located map of where the
  docs mislead, even where nothing is broken.
- **Pure rejects**: candidates a clear doc would not have provoked (doer error),
  recorded with the reason so the next run does not re-raise them.
- **Suggestions**: concrete doc edits; prefer backing snippets with
  compile-checked example files so they cannot rot.

Offer a review-and-fix or re-test follow-up, as `test-feature` does.

## Common Mistakes

| Mistake | Correction |
|---|---|
| Trusting the doer's verdict | The compile gate + source verification is the truth; the doer only generates candidates. |
| Letting the doer see source/repo/web | Isolate the doc artifact in its own dir and forbid everything else; otherwise it is not blind. |
| Using a frontier model "to be safe" | A cheaper doer hides fewer gaps; reserve the strong model for the orchestrator's verification. |
| Accepting a clean compile as full proof | Also verify guessed facts in source; code can compile on a lucky guess. |
| Reporting doer severities verbatim | Re-grade against confirmed user impact; doers over-escalate and miss real breaks. |
| Just rejecting a false positive | A doc-induced false positive is a clarity finding: leave a signpost (note / annotation / cross-link / comment) so the next reader can't misread. Only pure doer errors are silent rejects. |
| Compiling all snippets as one program | Compile each runnable snippet independently to localize the rotten one. |
| Counting gaps against out-of-scope docs | Gaps only count against the doc surface actually handed to the doer; record that surface. |
