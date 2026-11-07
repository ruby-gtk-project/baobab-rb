# Translation parity — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `ff9ec7c` |
| Domain | `baobab` |
| Upstream messages | 79 (confirmed by `catalogue.rb <upstream worktree> --role upstream`: 79 messages, 93 occurrences, 12 reused, 4 plural, 9 with context) |
| Ported (byte-identical msgid reachable, hand census) | 77 of 79 |
| Gaps | 2 (concrete bug, below) + translated help pages (separate from the UI catalogue, see component-parity) |
| Languages shipped by the port | **108 of 108**, byte-identical `po/` + `LINGUAS` to upstream |

Supersedes the `translation-parity.md` written against `66f3ac3` (0 of 108
languages shipped, 0 of 79 messages reaching any catalogue). That report is
now **wrong about the current branch** — `po/` was ported in `6788534`,
five commits before this audit's `HEAD`. Carrying its headline number
forward without re-running the census would itself be the stale/false-green
failure this skill's companion `accountability-ensurance` pass exists to
catch.

## Headline: the catalogue ships and actually translates at runtime

```
$ find . -iname '*.po' | wc -l           # 108
$ diff <(git show origin/main:po/LINGUAS) po/LINGUAS   # empty
$ LANG=de_DE.UTF-8 ruby -I lib -e 'require "translations"; \
    puts Translations.gettext("Disk Usage Analyzer"); \
    puts Translations.gettext("Home Folder")'
Festplattenbelegungsanalyse
Persönlicher Ordner
```

This is a live resolution against the shipped `po/de.po`, not a file-count
check — the prior report correctly identified the marking plumbing as real
but the catalogue as entirely absent; the catalogue is no longer absent, and
it works.

## Machine census, re-run with the skill's own tool against a real upstream worktree

The scanner's marker list does not know `Translations.gettext`/`.pgettext`
(the port's own names, a legitimate correspondence per the skill's rule),
so an automated `--compare` under-counts the port side (`catalogue.rb .
--role port` finds only 16 messages — all from `data/*.in`/`.gschema.xml`,
none from `lib/*.rb`'s calls). Per the skill's escalation order, I censused
by hand against the upstream-side tool's real output (`catalogue.rb
<upstream worktree> --role upstream`, 79 messages, run against an actual
`git worktree add` of `origin/main`, not inferred).

**All 79 upstream msgids were checked by grep against `lib/*.rb` and the
port's `data/*.in`/`.gschema.xml`, not sampled.** 74 matched on the first
pass; the 5 non-matches were individually resolved:

- 3 are **false misses**, not gaps: `"Devices & Locations"` (upstream's
  source has the XML entity `&amp;`, the Ruby literal correctly uses a bare
  `&` — same string, different escaping, verified by reading
  `lib/window.rb:156,904`), and two long metainfo/CLI-help strings that are
  wrapped across multiple lines in both upstream's `.vala`/`.xml.in` and the
  port's `data/org.gnome.baobab.metainfo.xml.in` / `lib/application.rb` —
  grep missed them for being multi-line, direct reading confirms byte
  identity.
- **2 are a real, newly-found bug, not a wording gap**: see below.

## Gap: `_Rings Chart` / `_Treemap Chart` — wrong msgid, breaks translation for exactly these two strings

Upstream's `data/ui/baobab-main-window.ui:259,273` marks the two chart-stack
tab titles `_Rings Chart` and `_Treemap Chart` (leading underscore =
mnemonic). The port's `lib/window.rb:73` table drops the underscore:
`CHARTS = { 'rings' => 'Rings Chart', 'treemap' => 'Treemap Chart' }`, then
calls `Translations.gettext('Rings Chart')` — a key that exists in no `.po`
file, because every one of the 108 catalogues keys this message as
`_Rings Chart`. Confirmed live:

```
$ LANG=de_DE.UTF-8 ruby -I lib -e 'require "translations"; \
    puts Translations.gettext("Rings Chart").inspect; \
    puts Translations.gettext("_Rings Chart").inspect'
"Rings Chart"      # always English, in every locale — wrong key
"K_reisdiagramm"   # correct key, translates and keeps the mnemonic
```

So in every one of the 108 languages the port ships, including German
above, these two tab titles render in English only — a real, if narrow,
translation-parity gap, and (per component-parity) a mnemonic-accelerator
loss even in English. Every other sampled mnemonic string in the port
(`_Help`, `_Add Location`, `_About Disk Usage Analyzer`, `_Open
Externally`, `_Copy Path to Clipboard`) kept its leading underscore
correctly — this is isolated to the `CHARTS` hash's two values, a one-line
fix (add the underscores back), not a systemic marking problem.

## Help catalogue: English content ships; translated help does not

`help/C/` (9 Mallard pages, English) is ported and resolves via
`win.help` → `Gtk.show_uri(uri: 'help:baobab')`. Upstream additionally ships
28 translated help catalogues (`help/<lang>/<lang>.po`, `help/LINGUAS`); none
are ported — `help` has only `C/` and `media/` subdirectories. This is a
real gap, smaller than the prior report's "whole help system… not ported"
(which predated the port of `help/C/` itself), and it is a content gap, not
a wiring one: there is nothing to render a non-English user even if they
switch locale.

## Rules check

- Key sets equal: **77 of 79**, by hand census against the upstream
  scanner's real 79-message output, not a round number asserted.
- Byte-identical: true for 77; the 2 exceptions are named with file:line and
  confirmed live, not described abstractly.
- Languages ship: **true**, 108 of 108, `diff`-confirmed against upstream's
  `LINGUAS`, and live-translation-confirmed for one language, not just
  file-count-confirmed.
- The scanner's own under-count (16 vs. 79) is named as a scanner limitation,
  with the escalation order followed (hand census against a real upstream
  worktree run, not a guess).
- Nothing here is carried forward from the stale prior report without an
  independent re-check this round.
