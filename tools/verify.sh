#!/usr/bin/env bash
# verify.sh — the mechanical anti-drift gate (TEMPLATE — adapt the marked sections to your repo).
#
# WHY: read-before-act / index-or-die / doc-accuracy disciplines enforced only by a RITUAL drift until
# the next time someone runs the ritual. This makes the GLOBBABLE (Class-A) invariants mechanical so a
# new file/rule/default that isn't wired in is caught at COMMIT time (via tools/githooks/pre-commit) or
# on demand — not "eventually". Pair it with tools/verify-selftest.sh, which PROVES each check fires.
#
# CLASSES: Class-A = "every X in dir Y must be referenced in index Z" → globbable → scales for free.
#          Class-B = bespoke contracts (the triangulation greps) → each needs its own check + a trigger.
# DRIFT = WARNING (a human decides). A missing gate section = HARD (exit 1). --strict makes warnings exit 1 too.
#
# ADAPT: search for "TODO:" — those are the project-specific globs/facts/budgets. The generic checks
# (read-before sweep, broken-links, hook-wired, doctrine↔enforcement) work as-is.
cd "$(dirname "$0")/.." || exit 2
[ -f tools/verify.sh ] || { echo "run from a repo that has tools/verify.sh"; exit 2; }   # don't operate on a stray parent dir
fail=0; warn=0
red(){ printf "\033[31m  ✗ %s\033[0m\n" "$1"; fail=$((fail+1)); }
yel(){ printf "\033[33m  ! %s\033[0m\n" "$1"; warn=$((warn+1)); }
grn(){ printf "\033[32m  ✓ %s\033[0m\n" "$1"; }
have(){ grep -qF "$1" "$2" 2>/dev/null; }   # substring contains-check; anchor to boundaries if names collide (F22)
STRICT=0; [ "$1" = "--strict" ] && STRICT=1

echo "── 1. Typecheck / build (opt-in: VERIFY_BUILD=1) ──"
if [ "${VERIFY_BUILD:-0}" = "1" ]; then
  # TODO: replace this with your real build/typecheck command and grn on success / red on failure.
  echo "  (no build command wired yet — add yours here)"
else echo "  (skipped — set VERIFY_BUILD=1)"; fi

echo "── 2. Index-or-die drift (Class-A globs — every artifact referenced where a session looks) ──"
d0=$warn
# TODO: for each knowledge dir, assert every file is referenced in its index. Examples:
# docs → an INDEX/README (read via process-substitution so the warn counter survives + filenames-with-spaces are safe):
while IFS= read -r f; do [ -e "$f" ] || continue; b=$(basename "$f")
  case "$b" in README.md|INDEX.md) continue;; esac
  have "$b" docs/README.md || yel "doc not in docs/README.md index: $b"
done < <(find docs -name '*.md' 2>/dev/null)
# tools → referenced in at least one doc (so they're discoverable):
for f in tools/*.sh tools/*.py tools/*.mjs; do [ -e "$f" ] || continue
  b=$(basename "$f"); grep -rqF "$b" README.md docs 2>/dev/null || yel "tool not referenced in any doc: $b"
done
# detail docs → reachable (≥1 inbound link) so a compaction's paged-out detail can be found again:
while IFS= read -r f; do [ -e "$f" ] || continue; b=$(basename "$f")
  case "$b" in README.md|INDEX.md) continue;; esac
  grep -rlF "$b" README.md docs 2>/dev/null | grep -vqF "$f" || yel "doc ORPHANED (no inbound link — a compaction must LINK its paged-out detail): $b"
done < <(find docs -name '*.md' 2>/dev/null)
[ "$warn" -eq "$d0" ] && grn "indices in sync"

echo "── 3. Read-before-authoring coverage (the DERIVATION sweep — F3/F4) ──"
d1=$warn
# Every doc whose own header says "read before …" MUST be listed in your read-before gate doc.
# TODO: point GATE at your gate file (the doc that lists what to read before acting).
GATE="docs/read-before.md"
while IFS= read -r f; do [ -e "$f" ] || continue
  b=$(basename "$f"); have "$b" "$GATE" || yel "read-before doc NOT in the gate ($GATE): $b"
done < <(grep -rliE 'read (this )?before (authoring|building|writing|touching|editing)' docs --include='*.md' 2>/dev/null)
[ "$warn" -eq "$d1" ] && grn "every read-before doc is in the gate"

echo "── 4. Triangulation (Class-B — docs ↔ code; code wins) ──"
d2=$warn
# TODO: one check per default your docs CLAIM. Pattern: assert the doc's claimed value matches the code.
# Example (delete/replace): a doc says the build command is build.sh, and that's what's wired:
# { have "build.sh" docs/README.md && [ -f build.sh ]; } || yel "build-command drift: docs vs repo"
[ "$warn" -eq "$d2" ] && grn "claimed defaults agree with code/tools  (add your checks here)"

echo "── 5. Broken cross-references (PATH-qualified refs only) ──"
d3=$warn
# Validate refs that include a directory (a real path); bare 'foo.md' is usually shorthand, not a link.
for ref in $(grep -rhoE '[A-Za-z0-9_./-]+/[A-Za-z0-9_-]+\.md' docs README.md 2>/dev/null | sort -u); do
  case "$ref" in //*|*'<'*) continue;; esac   # external URLs (https://…/x.md) + template placeholders
  b=$(basename "$ref")
  # NB validates by basename-exists (loose, to tolerate doc-relative refs); tighten to exact path only if no relative refs.
  find . -name "$b" -not -path './.git/*' 2>/dev/null | grep -q . || yel "referenced file not found: $ref"
done
[ "$warn" -eq "$d3" ] && grn "no broken in-repo cross-references"

echo "── 6. CORE read-budget (always-read files must stay tight; per-file + AGGREGATE — F7) ──"
d4=$warn
budget(){ b=$(wc -c < "$1" 2>/dev/null || echo 0); [ "$b" -gt "$2" ] && yel "over budget: $(basename "$1") ${b}B > ${2}B → distill to one line + LINK the detail (never delete-without-link); page on-demand detail OUT."; }
# TODO: budget every file your agent reads EVERY session. A self-improvement LOG must NOT live here —
# keep the distilled RULE (one line) in the always-read set, page the teardown to an on-demand doc.
for f in AGENTS.md CLAUDE.md; do [ -f "$f" ] && budget "$f" 13000; done
# AGGREGATE ceiling: per-file budgets don't stop splitting one bloated file into two under-budget files.
core_total=$(cat AGENTS.md CLAUDE.md 2>/dev/null | wc -c)
[ "$core_total" -gt 40000 ] && yel "CORE TOTAL over aggregate budget (${core_total}B) — splitting/adding always-read files doesn't cut RAM; distill out."
[ "$warn" -eq "$d4" ] && grn "always-read files within budget"

echo "── 7. Commit-hook wired (the gate must RUN at commit, not just on demand — F8) ──"
hp=$(git config core.hooksPath 2>/dev/null)
if [ "$hp" = "tools/githooks" ]; then grn "commit-hook wired (core.hooksPath=tools/githooks)"
else yel "commit-hook NOT wired (core.hooksPath='$hp') → commits skip this gate; run: git config core.hooksPath tools/githooks (or call verify.sh from your existing hook)"; fi

echo "── 8. Doctrine↔enforcement (F10 — every check the docs CLAIM the gate runs must EXIST here) ──"
d5=$warn; f5=$fail
SELF="tools/$(basename "$0")"
# The gate's own section contract: a section silently deleted while a doc still advertises it = divergence.
# Anchored to the "── N. <name>" HEADER lines so the for-loop's own list can't self-satisfy the grep (the bug a
# naive `grep -qF "$sec"` has). UPDATE this list when you add/rename a section. verify-selftest.sh proves it fires.
for sec in "Index-or-die drift" "Read-before-authoring coverage" "Triangulation" "Broken cross-references" "CORE read-budget" "Commit-hook wired"; do
  grep -qE "^echo \"── [0-9]+\. ${sec}" "$SELF" 2>/dev/null || red "F10: claimed gate section missing from verify.sh: '$sec'"
done
[ "$warn" -eq "$d5" ] && [ "$fail" -eq "$f5" ] && grn "doctrine↔enforcement: every claimed section present"

echo "────────────────────────────────────────────────────────────"
if [ "$fail" -gt 0 ]; then printf "\033[31mVERIFY: %d HARD failure(s), %d drift warning(s).\033[0m\n" "$fail" "$warn"; exit 1; fi
if [ "$STRICT" = "1" ] && [ "$warn" -gt 0 ]; then printf "\033[33mVERIFY (--strict): %d drift warning(s) → fail.\033[0m\n" "$warn"; exit 1; fi
printf "\033[32mVERIFY: OK\033[0m  (%d drift warning(s))\n" "$warn"; exit 0
