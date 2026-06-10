# Durable Knowledge System

Think of it as a linter for the docs and rules your AI coding agent reads (Claude Code, or anything that reads your repo's docs). It keeps that committed knowledge in sync with the actual code, and, unlike a normal linter, it red-teams its own checks and proves each one actually fires, so the gate can't quietly go blind.

> There are two different "AI memory" problems, and most tools only solve one.
>
> Recall is the famous one: the agent forgot your codebase, so it greps around blindly and burns tokens. Tools like [claude-mem](https://github.com/thedotmack/claude-mem) and code knowledge-graphs like [Graphify](https://github.com/safishamsi/graphify) handle that well.
>
> Drift is the other one, and it's what this repo is about. Your committed rules, decisions, and docs slowly stop matching the code. A script gets renamed, a default changes, a rule never gets re-read at the moment it would have helped. Nothing errors. The agent just gets confidently wrong, and you end up catching the same mistakes by hand, over and over.
>
> The two are complementary. Use a recall tool for navigation and this for correctness, and you have both covered. Credit to those projects; this is just the piece they don't.

## The problem

Give a coding agent a CLAUDE.md or AGENTS.md, some memory files, a wiki. Over a few weeks it drifts:

- a rule says "use build.sh" but the script was renamed
- a doc claims a default the code no longer has
- a lesson gets written down but never re-read when it would have helped
- a new file is added but never indexed, so later sessions can't find it
- the every-session context keeps growing until the rules that matter are buried

None of this throws an error. The agent just gets quietly wrong, and you become the test, catching the same kinds of mistakes again and again.

## How it works

Four parts, none of them complicated.

**1. Distilled, committed knowledge.** Small Markdown files: a short checklist of the rules you'd otherwise forget, the decisions you've locked in (with the reasoning, so nobody re-litigates them), and an index. A rule earns a spot in the always-read set based on how often it matters and how bad it is to miss. Everything you'd know to look up stays in on-demand docs instead.

**2. A mechanical gate** (`tools/verify.sh`). Plain grep-and-glob checks, no LLM involved: every file is referenced where a session would look for it, a doc's claimed defaults still match the code (the code wins), no broken links, every "read this first" doc is actually listed in the gate, and the always-read set stays small. Drift is a warning a human resolves; a real breakage fails hard.

**3. A pre-commit hook.** The gate runs on every commit, so drift shows up the moment it's introduced instead of weeks later. That's the difference between a ritual you can skip and something that just runs.

**4. Behavior-proofs** (`tools/verify-selftest.sh`). For each check, it plants a real violation and confirms the check catches it. A check that exists is not the same as a check that works. This is basically mutation testing pointed at your own gate, which I haven't seen done for agent-memory discipline. It's already caught the embarrassing cases: a glob that only covered 10 of 46 files, and a "passed" line for a check that never actually ran.

There's also a failure-mode catalog ([FAILURE-MODES.md](FAILURE-MODES.md)). The system uses it to red-team itself for design flaws, not just drift, and each new flaw turns into a new check. The rule there: red-team a new rule or gate when you write it, not at some cleanup pass later. Putting it off is exactly why you keep being the one who catches the problem.

## A few principles behind it

- **Disk is truth.** Read state from the filesystem, don't trust a stored summary of it. A map can go stale; the code can't lie about itself.
- **Some checks scale for free, some don't.** "Every file in this dir must be in that index" is a glob, so new files are covered automatically. A specific claim like "this doc says the default is X" needs its own check, plus a note about when to update it.
- **Write it small to begin with.** Don't write big and compact later. When something gets too long, distill it to a line and link out to the detail. Don't delete the detail.
- **Verify before you claim.** Run the check and read the result before you say "done" or "it's consistent." The most common entry in the catalog is someone reporting success they never actually checked.
- **Load eagerly only what you'd miss.** If you'd know to look something up, leave it on-demand. If you'd walk straight past the mistake without a reminder, keep it in the always-read set. A cheap recall layer makes the on-demand half basically free, which is another reason this pairs well with one.

## Using it

```sh
cp -r tools <your-repo>/
cd <your-repo>
git config core.hooksPath tools/githooks   # wire up the hook (see the note below if you already use hooks)
# open tools/verify.sh and replace the TODO-marked, project-specific
# globs and facts with yours. the generic checks work as-is.
bash tools/verify.sh            # run the gate
bash tools/verify-selftest.sh   # prove the checks actually fire
```

This repo ships the scripts and these docs, nothing else. You build your own knowledge structure (a `docs/` folder and index, your CLAUDE.md or AGENTS.md, a "read before" doc) and point the TODO globs at it. The generic checks (read-before sweep, broken links, hook-wired, doctrine-vs-enforcement) work without changes.

A couple of things to expect on a fresh copy. The gate will warn that your tools aren't referenced in any doc yet, which is correct (mention them somewhere, or drop that check). And `verify-selftest.sh` reports the budget check as skipped until you have a CLAUDE.md or AGENTS.md for it to test against.

If you already use a hooks manager (husky, lefthook, or a populated `.git/hooks`), don't switch `core.hooksPath`, since that disables your existing hooks. Instead call `bash tools/verify.sh` from your current pre-commit.

One heads-up: these are shell scripts that read your repo, and `verify-selftest.sh` briefly sets and restores your local `git config core.hooksPath` (it restores even if you interrupt it). They're short on purpose, so read them before you run them.

The checks try hard not to cry wolf. A gate that fires on normal, fine states just trains you to ignore it, which is its own kind of broken (see F12 in the catalog). Tune the patterns so every warning points at a real fix.

## What it isn't

- Not a replacement for your code linter. It is lint-like, but pointed at the docs and rules your agent reads, the layer eslint/ruff/shellcheck never check.
- Not a memory or recall store. Pair it with one (claude-mem, a knowledge-graph, an MCP memory server).
- Not an LLM reviewing your code. The gate is plain grep and glob, so it's fast, deterministic, and cheap enough to run on every commit.
- Not a framework. It's about three short shell scripts and a way of writing your docs. Read them, adapt them.

## Credits

Built to sit alongside the recall tools it complements: [Graphify](https://github.com/safishamsi/graphify) (a local code knowledge-graph) and [claude-mem](https://github.com/thedotmack/claude-mem) (session capture and re-injection). They solve recall; this is the correctness side they don't cover.

Built with AI assistance (Claude Code).

## License

MIT, see [LICENSE](LICENSE).
