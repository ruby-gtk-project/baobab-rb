# Accountability ensurance — baobab

Scanned `lib/`, `exe/`, every `.reports/*.md` on this branch, and the repo
root for `PORTING.md`/`FINDINGS.md` (neither exists). Also ran the skill's
own scanner:

```
$ bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
.reports/component-inventory.md:225:skipped:honest but toothless - name the behaviour and owe it
```

## That one hit is a false positive, read in context

Line 225 of `.reports/component-inventory.md`:

> `Gtk.Label` separator | repeater | `dim-label` | — | `/` between segments,
> skipped for the first |

"Skipped" there describes real UI behaviour (`pathbar.rb` does not draw a
leading `/` before the first path segment) — it is not an admission of
unported work. Confirmed by reading `lib/pathbar.rb`'s separator-building
loop, which does skip the leading separator, matching upstream. Not rewritten.

## No `PORTING.md`, no `FINDINGS.md` — and that absence is itself worth flagging

Neither document exists on this branch. On one hand this means there is no
"Dropped deliberately" section, no citation of a port-written note as
authority for a gap, and no place for a gap to be laundered into settled
architecture — the specific failure this skill exists to catch did not
happen here in the form it took in `console-rb`.

On the other hand, it means the two real gaps this audit found
(`.reports/translation-parity.md`'s 0-of-108-languages finding and
`.reports/component-parity.md`'s missing Help content / `data/` packaging)
are recorded **nowhere** in the port's own prose before this audit — not
excused, but also not owed anywhere a future agent would read before
touching this code. An omission with no record is not an accountability
violation under this skill's definition (nothing was written claiming it was
handled), but it is the condition under which the next agent is most likely
to *assume* parity and build on top of it. Recommend a `PORTING.md` /
`FINDINGS.md` pair get written as part of closing these gaps, specifically so
the next agent inherits a debt rather than a silent gap — but note that
writing one now, in the admission format this skill requires, is future work
for whoever closes the gap, not something to retrofit into this audit's
reports.

## Grep for the specific constructions, beyond the script's pattern set

```
$ grep -rniE 'TODO|FIXME|not implemented|for now|in a future|out of scope|
  not applicable|n/a\b|does not carry over|by design|not needed|
  dropped deliberately|intentionally omitted' lib/ exe/ README.md AGENTS.md IRP.md
README.md:266:  (a Mastodon follow badge URL containing the literal string
                "n/a"-shaped nothing — false match on a shield.io query param)
```

No real hit. No `TODO`, no `FIXME`, no "not implemented", no "for now", no
"out of scope", no "by design" anywhere in `lib/`, `exe/`, or the port's
root-level prose.

## `.reports/component-inventory.md` — read for soft language, not just the regex

This document is long, detailed, and largely holds up under the independent
re-checks in this audit's other four reports. Two phrasings in it deserve a
closer look against this skill's standard, even though neither matched the
scanner:

1. **"packaging, handled by the gem/flake, not `lib/`."** (line 426,
   describing `data/org.gnome.baobab.desktop.in`, `.metainfo.xml.in`,
   `.service.in`, `baobab.1`, icons.) Checked directly in
   `.reports/component-identification.md`: it is not handled. The flake's
   schema-copy step is `if [ -d data/schemas ]; then … fi`, which is false
   today because `data/` does not exist, so the step is a silent no-op, and
   the gemspec's `po/**/*` glob matches nothing for the same reason. "Handled
   by the flake" is the exact shape of claim this skill exists to catch —
   a plausible-sounding deferral that, read closely, defers to a mechanism
   that never fires. This is now named directly, with the conditional and
   the file:line, in `component-identification.md` and
   `component-parity.md`, rather than left as a citation a future agent
   could repeat.
2. **"Deviation: … Behaviourally equivalent for the app; not interoperable
   with an installed upstream baobab's settings."** (line 446, on the JSON
   settings store.) This one is fine under the skill's own rule — it names
   the substitution, states the real cost ("not interoperable"), and does
   not claim the gap is closed. It is a documented correspondence, not an
   excuse, and is recorded as such (not rewritten) in
   `component-parity.md`.

## What this report is not

It is not a certificate that the port is finished — `.reports/
component-parity.md` and `.reports/translation-parity.md` both record real,
material, unexcused gaps (no help content, no desktop/metainfo/schema files,
zero languages shipped). This report's finding is narrower and specific to
its own skill: those gaps are not currently being *laundered* as decisions
anywhere in this port's own prose. They are simply gaps, stated as gaps, in
the other four reports — which is the outcome this skill is checking for,
not a substitute for those reports existing and being read.

## Rules check

- Rewrite in place, never delete: the one scanner hit was read in context and
  left as-is (false positive), not deleted.
- No new excuse introduced while writing this: the `data/`/flake finding is
  named as "the flake's step is a no-op," not softened to "not yet wired up."
- First person is not applicable here in the sense the skill's worked
  examples use it (there is no existing excuse-sentence in this port to
  rewrite into an admission) — the admission format is for rewriting an
  existing excuse, and none exists to rewrite. Where this audit itself
  found gaps, they are stated as gaps with file:line in the other four
  reports, which is the standard this skill asks a *finding* to meet, not
  the admission format, which is for a *port's own* prose about its own
  skip.
