#!/usr/bin/env bash
# verify-selftest.sh — BEHAVIOR-PROOF for verify.sh. For every check, plant a KNOWN violation and assert
# the matching warning FIRES. A check that stays silent here is a FALSE-NEGATIVE — the gate claims coverage
# it doesn't have. Re-run after editing verify.sh to prove no check silently broke.  (See FAILURE-MODES F14/F19.)
#
# F19 lesson baked in: plant the case the check is WEAKEST on (the off-convention name / non-globbed dir),
# not just the happy path — a selftest that only plants the easy case "proves" a check that misses the corpus.
#
# SAFE BY DESIGN: planted violations are untracked __selftest* files (rm'd on exit); checks that need an
# EXISTING file to LOSE a token use a backup + trap-restore. A before/after `git status` proves nothing leaked.
cd "$(dirname "$0")/.." || exit 2
PASS=0; FAIL=0; SKIP=0; CREATED=(); BACKUPS=(); HOOKSAVE=""; HOOK_TOUCHED=0; DOCS_MADE=0
TREE_BEFORE=$(git status --porcelain 2>/dev/null)
cleanup(){ for f in "${CREATED[@]}"; do rm -rf "$f"; done
           for b in "${BACKUPS[@]}"; do [ -f "$b" ] && mv -f "$b" "${b%.selftestbak}"; done
           [ "$DOCS_MADE" = 1 ] && rmdir docs 2>/dev/null   # only if WE created docs/, and only if now-empty
           # restore git config too (BLOCKER fix): an interrupt mid-§7 must not leave hooksPath broken
           if [ "$HOOK_TOUCHED" = 1 ]; then
             if [ -n "$HOOKSAVE" ]; then git config core.hooksPath "$HOOKSAVE"; else git config --unset core.hooksPath 2>/dev/null; fi
           fi; }
trap cleanup EXIT INT TERM
runv(){ bash tools/verify.sh 2>&1 || true; }
expect(){ if runv | grep -qF -- "$2"; then printf '  \033[32m✓ FIRES\033[0m  %s\n' "$1"; PASS=$((PASS+1));
          else printf '  \033[31m✗ SILENT (FALSE-NEGATIVE)\033[0m  %s\n      expected: %s\n' "$1" "$2"; FAIL=$((FAIL+1)); fi; }
mk(){ CREATED+=("$1"); }

# ── §2 index-or-die ── (plant a doc NOT in the index)
[ -d docs ] || DOCS_MADE=1
f="docs/__selftest.md"; mk "$f"; mkdir -p docs; printf '# x\n' > "$f"
expect "§2 doc not in index"            "doc not in docs/README.md index: __selftest.md"
rm -f "$f"
f="tools/__selftest.sh"; mk "$f"; printf '#!/bin/sh\n' > "$f"
expect "§2 tool not referenced"         "tool not referenced in any doc: __selftest.sh"
rm -f "$f"

# ── §3 read-before sweep ── (a doc that self-declares but isn't in the gate)
f="docs/__selftest_craft.md"; mk "$f"; printf '# craft\n\nRead before authoring.\n' > "$f"
expect "§3 read-before doc not in gate" "read-before doc NOT in the gate"
rm -f "$f"

# ── §5 broken cross-reference ── (a path-qualified ref to a nonexistent file)
f="docs/__selftest_ref.md"; mk "$f"; printf 'see docs/nope-selftest-xyz.md\n' > "$f"
expect "§5 broken path-qualified ref"   "referenced file not found: docs/nope-selftest-xyz.md"
rm -f "$f"

# ── §6 CORE budget ── (push an always-read file over budget)
if [ -f AGENTS.md ] || [ -f CLAUDE.md ]; then
  tgt=$([ -f AGENTS.md ] && echo AGENTS.md || echo CLAUDE.md)
  cp "$tgt" "$tgt.selftestbak"; BACKUPS+=("$tgt.selftestbak")
  head -c 14000 /dev/zero | tr '\0' 'x' >> "$tgt"
  expect "§6 over-budget always-read file" "over budget"
  mv -f "$tgt.selftestbak" "$tgt"; BACKUPS=("${BACKUPS[@]/$tgt.selftestbak}")
else
  printf '  \033[33m⊘ SKIPPED\033[0m  §6 over-budget (no AGENTS.md/CLAUDE.md to plant against — create one + re-run to prove it)\n'; SKIP=$((SKIP+1))
fi

# ── §7 commit-hook wired ── (behavior-test via a SAVED+restored local git config; HOOK_TOUCHED→cleanup() restores on interrupt)
HOOKSAVE=$(git config core.hooksPath 2>/dev/null); HOOK_TOUCHED=1
git config core.hooksPath /tmp/__no_such_hookdir 2>/dev/null
expect "§7 commit-hook not wired"        "commit-hook NOT wired"
if [ -n "$HOOKSAVE" ]; then git config core.hooksPath "$HOOKSAVE"; else git config --unset core.hooksPath 2>/dev/null; fi
HOOK_TOUCHED=0

# ── §8 doctrine↔enforcement ── (the hard check: remove a section's header from verify.sh, assert F10 reds)
cp tools/verify.sh tools/verify.sh.selftestbak; BACKUPS+=("tools/verify.sh.selftestbak")
grep -v '^echo "── 5\. Broken cross-references' tools/verify.sh.selftestbak > tools/verify.sh
expect "§8 doctrine↔enforcement (a gate section went missing)" "claimed gate section missing"
mv -f tools/verify.sh.selftestbak tools/verify.sh; BACKUPS=("${BACKUPS[@]/tools\/verify.sh.selftestbak}")

# (Add a plant for each project-specific check you add to verify.sh §2/§4.)

echo "────────────────────────────────────────────────────────────"
TREE_AFTER=$(git status --porcelain 2>/dev/null)
[ "$TREE_BEFORE" != "$TREE_AFTER" ] && { printf '\033[31m  ✗ SELFTEST CHANGED THE TREE (a temp file leaked or a backup was not restored)\033[0m\n'; FAIL=$((FAIL+1)); }
if [ "$FAIL" -gt 0 ]; then printf '\033[31mSELFTEST: %d behavior FAILURE(s), %d proven, %d skipped.\033[0m\n' "$FAIL" "$PASS" "$SKIP"; exit 1; fi
if [ "$SKIP" -gt 0 ]; then printf '\033[32mSELFTEST: OK\033[0m  — %d checks proven, %d skipped (⊘ above — create the missing files + re-run to prove them).\n' "$PASS" "$SKIP"; exit 0; fi
printf '\033[32mSELFTEST: OK\033[0m  — %d planted checks proven (each fired on a known violation).\n' "$PASS"; exit 0
