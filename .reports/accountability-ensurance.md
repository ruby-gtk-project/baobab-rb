# Accountability ensurance — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `ff9ec7c` |

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

## What this round found that was not being laundered, but also was not being looked for

The `_Rings Chart` / `_Treemap Chart` msgid-mismatch (full detail in
`component-parity.md` and `translation-parity.md`) is not an excuse anywhere
in the port's prose — there is no comment near `lib/window.rb:73` claiming
these are intentionally untranslated or deliberately mnemonic-free. It is a
plain bug, silently present, found only by hand-censusing every one of
upstream's 79 msgids against the port rather than trusting the automated
scanner's partial count or the prior report's sampled-dozen spot check
(which happened not to include these two strings). This is the shape of
gap `accountability-ensurance` is least equipped to catch by grepping for
excuse-words, because no excuse was written — it is recorded here as a
reminder that this skill's negative result ("no excuse found") is not the
same claim as "no gap exists," and the other four skills' row-by-row
re-derivation is what actually found it.

## Rules check

- Rewrite in place, never delete: no excuse-sentence existed in the port's
  own code to rewrite; the scanner's hits are prose-about-vocabulary, read
  in context, not deleted.
- No new excuse introduced while writing this report: the remaining open
  items (translated help, the chart-tab bug, no `PORTING.md`) are stated as
  open, not softened.
- This report does not certify the port clean — it certifies that no gap
  found by the other four reports this round is currently being excused in
  `lib/`, `exe/`, or the port's own prose. Two real, concrete gaps remain
  open (see `component-parity.md`/`translation-parity.md`), and they are
  gaps, stated as gaps, not decisions.
