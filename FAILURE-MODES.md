# Failure-mode catalog

The system audits **itself** for design flaws, not just for drift. This is an FMEA-style catalog of the ways a knowledge/memory discipline (and the gate that enforces it) quietly fails. **Red-team a new rule/gate/check/tool — or even a *proposal* — at the moment you create it**, by walking this list against it. Every confirmed flaw becomes a fix *plus* a new mechanical check (so the class becomes drift-caught) and, where it's project-agnostic, a new row here.

Two provenance notes used below: *"the operator caught it"* = a human found it, not the system (the thing we're trying to stop); cross-project rows came from running the same discipline in a second, unrelated repo — which is much of the value (a flaw found in one project hardens all of them).

| # | Failure mode | Probe question | Caught by |
|---|---|---|---|
| F1 | **Linked-but-not-triggered** | what *triggers* this doc's read at the moment of need — a read-before-act pointer, or just an index entry nobody opens? | red-team (partial: the gate's coverage sweep) |
| F2 | **Distill-without-link** (orphaned detail) | does every compacted one-liner LINK to where its detail went? is every on-demand doc reachable? | **mechanical** (orphan + broken-link) |
| F3 | **Hand-assembled list that should be derived** | is this gate/index built from a sweep/glob, or typed from memory (so it silently goes stale)? | **mechanical** (derivation sweep) |
| F4 | **Self-declaring-only detection** | what *should* this check catch but doesn't, because the target doesn't opt in (e.g. a doc missing the magic header phrase)? | red-team |
| F5 | **Hardcoded list (doesn't auto-scale)** | is this a glob (auto-covers new items) or a fixed list (needs an "update-me-when" trigger)? what new item slips through? | red-team (+ the trigger) |
| F6 | **Doc-vs-code drift** | what defaults does this doc claim? do the code/tools actually do that? (code wins) | **mechanical** (triangulation, for covered facts) |
| F7 | **CORE bloat** | is this file always-read? is it bounded by a budget? does it mix an eager checklist with on-demand detail that should page out? | **mechanical** (per-file + aggregate budget) |
| F8 | **Ritual-only enforcement** | what enforces this — a hook (every commit) or a ritual (skippable)? | red-team |
| F9 | **Stale forward-looking claim** | does any "PLANNED / TODO / soon" here already exist? | **mechanical** (grep) |
| F10 | **Doctrine↔enforcement divergence** | does every discipline that *claims* a mechanical check actually HAVE one in the gate (and vice-versa)? | **mechanical** (meta-check: assert each claimed section exists) |
| F11 | **New mechanism shipped without red-teaming ITSELF** | before shipping a rule/gate/check/tool/**proposal**, did you run this catalog *against it* the **same turn** (not deferred to a later ritual — deferring is *why the operator keeps being the test*)? does it self-maintain? what feeds it? | red-team |
| F12 | **Gate noise / false-positive fatigue** | does every warning map to a real fix? what *legitimate* state does it flag (a planned pointer, an intentional exception)? a gate that cries wolf gets ignored = effectively off. | red-team → mechanizable (derive the exception from the artifact's own signal — a `[ ]`/`planned`/`pending` marker — never a hardcoded suppress-list, which is just F5) |
| F13 | **Vague rule/lesson (no concrete fix or link)** | does each lesson read `symptom → a concrete fix` (or link the detail)? a bare imperative isn't actionable. | red-team — deliberately NOT mechanized (a prose-parser cry-wolfs = F12); prevented structurally by a lesson *template* |
| F14 | **Existence-verified, not behavior-verified** | does a check assert the *effect* (the number moved, the output changed, the heal was denied), or only that the entity/flag/row is *present*? "it's there" ≠ "it works." | red-team → mechanizable per-feature (assert the state-delta) |
| F15 | **Tuning/economy drift no pass/fail gate measures** | did this touch a numeric balance/pacing constant? is it checked by a *measurement* probe (a curve/number), or only by "the build passes"? | red-team — deliberately not a binary gate (a threshold on "fun"/"feel" cry-wolfs); use a measurement probe + human check |
| F16 | **Silent graceful-degrade masks a real break (or fakes one)** | does each fallback (asset→placeholder, save→fresh, net-down→cached) emit a distinguishable signal for *which* path fired, so healthy ≠ degraded ≠ broken is visible? | red-team → partially mechanizable (a degrade sets an observable flag) |
| F17 | **Unverified success claim** | before reporting "done / works / consistent," did you RUN the check and READ the result — or are you asserting from "it should"? (F14 turned on your own report — the recurring one the operator catches.) | discipline: *verify, don't assert* — not fully mechanizable; standing rule + operator backstop |
| F18 | **Concurrent shared-doc edit** | when editing a doc shared across projects, did you commit YOUR change immediately + atomically (not leave it for another session to sweep into the wrong commit)? prefer append-only. | red-team → mitigations: commit-immediately, append-only, a unique-id + fixed-shape that makes a collision detectable |
| F19 | **Behavior-test samples only the easy case** | does the selftest plant the case the check is WEAKEST on (the off-convention name, the non-globbed dir), or just the happy path? | red-team → mechanizable: plant the adversarial sample. *(A reachability check globbed `*Foo*` and "proved" itself on a `*Foo*`-named file — while covering only ~20% of the real corpus, which is mostly named otherwise.)* |
| F20 | **Tool asserts an UNRUN check** | does every "✓ X verified" the tool prints correspond to a check that ACTUALLY RAN this invocation, or is the message ahead of the code? (F17 baked into a tool.) | **mechanical** (the F10 meta-check). *(A gate printed "resolution agrees with code" but never checked it.)* |
| F21 | **Validate-the-worktree-not-the-committed-snapshot** | does a commit/CI gate validate EXACTLY what's being committed (the staged index), or the looser working tree? a partial `git add` commits broken state behind a green gate. | red-team → mitigations: validate the index (stash-keep) for a blocking gate; for an advisory hook, print the caveat |
| F22 | **Substring match false-satisfies a contains-check** | does an index / "is X referenced?" check match a WHOLE token/path, or any substring (so a longer mention satisfies a shorter artifact's requirement)? | red-team — anchor to word/path boundaries; latent until a name collision triggers it |

## How to use this

1. **At creation** of any new rule/gate/tool/proposal, walk the list and ask each probe.
2. A confirmed flaw → a fix **and** a new mechanical check **and** (if it's project-agnostic) a new row here, tagged with which project/date/trigger found it.
3. Checks marked **mechanical** live in `tools/verify.sh`; each is behavior-proven in `tools/verify-selftest.sh`.
4. Some rows are **deliberately not mechanized** (F13/F15) because the mechanical version would cry wolf (F12) — recorded so no future session bolts on the noisy check.
