# Accountability ensurance — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `4e581e4` |

Supersedes the `accountability-ensurance.md` written against `66f3ac3`.
That report's own headline finding — real, unexcused, but *unrecorded in the
port's own prose* — described two gaps (0/108 languages, missing help/
data/) that have both since been substantially closed by commits
`6788534`/`8662ed4`/`785d7e3`/`e657970`/`ff9ec7c`. Re-checked from scratch,
not re-read, for the reason this skill exists: a stale finding, repeated
without re-verification, is itself the false-green failure to catch.

## The biggest single risk this round: the four sibling reports' own prior content

Before this round's rewrite, `.reports/component-identification.md`,
`component-parity.md`, `test-parity.md`, and `translation-parity.md` all
described the port as it stood at `66f3ac3` — missing `po/`/`data/`/`help/`,
0 languages shipped, two unrebuilt runtime defects — while `HEAD` had moved
five commits past that and fixed exactly those things. Had this audit
treated those documents as current (e.g. "the prior report already says
translation is 0/108, nothing to re-check"), it would have reported a real
regression-of-the-audit: a true state (108/108 shipped, verified live) sitting
behind a false, stale "0/108" claim, serving exactly the role this skill
flags as most serious — "a false green claim that rests on something never
executed," except inverted into a false *red* that was never re-executed
either. Every claim in this round's four sibling reports was re-derived this
session (worktree diff, live `LANG=de_DE.UTF-8` translation calls, a fresh
drive run with full stderr inspection, a hand census against a freshly-run
upstream-side scanner) rather than carried forward.

## This round's own scanner run

```
$ bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
.reports/translation-parity.md:... "by design"   (prose about mnemonics, not an excuse)
.reports/accountability-ensurance.md:... multiple hits (this file quoting its own trigger words to explain them)
```

All hits are inside `.reports/*.md`'s own meta-discussion of the skill's
vocabulary (quoting "dropped deliberately", "by design", etc. to explain why
something is or is not one), not an excuse written about the port's own
code. Read in context, confirmed false positives — same disposition as the
prior round found for its one hit, re-verified rather than assumed.

```
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|
  not applicable|n/a\b|does not carry over|by design|not needed|
  dropped deliberately|intentionally omitted' lib/ exe/
(no output)
```

No hit anywhere in `lib/` or `exe/`. Still no `PORTING.md`, no `FINDINGS.md`
on this branch — the gap in the port's own documentation practice the prior
round flagged is unchanged: the two real findings this round *does* make
(below) are recorded only in `.reports/`, nowhere in the port's own prose,
which is the condition under which a future agent is most likely to assume
parity and build on top of a gap. Recommend, again, that closing the chart-
tab-mnemonic bug and the help-translation gap be accompanied by a
`PORTING.md` note, not just a commit message.

## What the prior round found that was not being laundered, but also was not being looked for

The `_Rings Chart` / `_Treemap Chart` msgid-mismatch (full detail in
`component-parity.md` and `translation-parity.md`) was not an excuse
anywhere in the port's prose — there was no comment near `lib/window.rb:73`
claiming these were intentionally untranslated or deliberately
mnemonic-free. It was a plain bug, silently present, found only by
hand-censusing every one of upstream's 79 msgids against the port rather
than trusting the automated scanner's partial count or an earlier sampled
spot check. This is the shape of gap `accountability-ensurance` is least
equipped to catch by grepping for excuse-words, because no excuse was
written — recorded here as a reminder that this skill's negative result
("no excuse found") is not the same claim as "no gap exists."

## This round: re-check of the two gaps the prior round found, both now closed and re-verified, not re-excused

`95c8bdc` fixed the `CHARTS` msgid bug and `4e581e4` ported the 28
translated help catalogues. Neither commit's message, nor either sibling
report, is taken on its word here: this round independently re-ran the
live German-translation call (`Translations.gettext("_Rings Chart")` →
`"K_reisdiagramm"`) and a 28-file `diff` loop against `origin/main`'s
`help/<lang>/<lang>.po`, both clean. A commit message that *says* a gap is
fixed, accepted without re-execution, would itself be exactly the
false-green pattern this skill exists to catch — inverted from last
round's finding (a true fix mistaken for still-open), but the same failure
mode in reverse, so it gets the same re-derivation this round rather than
either optimistic or stale treatment.

Scanner and grep re-run fresh against current `HEAD` (not re-read from the
prior round's output):

```
$ bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
.reports/translation-parity.md:... "by design"   (prose about mnemonics, not an excuse)
.reports/accountability-ensurance.md:... multiple hits (this file quoting its own trigger words)
```

```
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|
  not applicable|n/a\b|does not carry over|by design|not needed|
  dropped deliberately|intentionally omitted' lib/ exe/
(no output)
```

Same result as last round: both hits are inside `.reports/*.md`'s own
meta-discussion, not an excuse about the port's code; `lib/` and `exe/` are
clean. `PORTING.md` is still absent — the recommendation from the prior
round (record the two fixes there, not only in commit messages and
`.reports/`) was not acted on. That is not itself a new gap (nothing in the
task requires `PORTING.md` to exist), but it is worth repeating: the only
place either fix is explained in prose, for a future agent who has not read
this `.reports/` directory, is the two commit messages.

## Rules check

- Rewrite in place, never delete: no excuse-sentence existed in the port's
  own code to rewrite; the scanner's hits are prose-about-vocabulary, read
  in context, not deleted.
- No new excuse introduced while writing this report: both gaps are stated
  as closed-and-reverified, not as assumed-fixed-because-a-commit-says-so.
- This report certifies that no gap found by the other four reports this
  round is currently being excused in `lib/`, `exe/`, or the port's own
  prose, **and** that neither of the two gaps closed since the last audit
  round was accepted on the strength of a commit message alone — both were
  re-executed live this round. Zero gaps remain open as of `4e581e4`.
