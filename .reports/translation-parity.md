# Translation parity — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `4e581e4` |
| Domain | `baobab` |
| Upstream messages | 79 (confirmed by `catalogue.rb <upstream worktree> --role upstream`: 79 messages, 93 occurrences, 12 reused, 4 plural, 9 with context) |
| Ported (byte-identical msgid reachable, hand census) | **79 of 79** as of this round (was 77 of 79 at `ff9ec7c`) |
| Gaps | 0 open — both gaps this report found at `ff9ec7c` are closed, see re-check below |
| Languages shipped by the port, UI catalogue | **108 of 108**, byte-identical `po/` + `LINGUAS` to upstream |
| Languages shipped by the port, help catalogue | **28 of 28**, byte-identical `help/<lang>/<lang>.po` + `help/LINGUAS` to upstream (closed this round, was 0 of 28 at `ff9ec7c`) |

Supersedes the `translation-parity.md` written against `66f3ac3` and then
`ff9ec7c`. Carrying either forward without re-running the census would be
the stale/false-green failure this skill's companion
`accountability-ensurance` pass exists to catch.

## Re-check this round: both prior gaps closed, re-verified live

1. **`_Rings Chart`/`_Treemap Chart` msgid bug — closed at `95c8bdc`.**
   `lib/window.rb:73` now reads `'_Rings Chart'`/`'_Treemap Chart'`. Live
   re-check: `LANG=de_DE.UTF-8 ruby -I lib -e 'require "translations";
   puts Translations.gettext("_Rings Chart")'` → `"K_reisdiagramm"` — the
   correct `.po` key, resolved and translated. This brings the hand census
   to 79 of 79, not 77 of 79.
2. **Translated help catalogues — closed at `4e581e4`.** `help/<lang>/
   <lang>.po` now exists for all 28 codes in upstream's `help/LINGUAS`.
   Checked this round with a `diff` loop over all 28 files against
   `origin/main`, not sampled: zero byte differences, `help/LINGUAS` also
   identical. (This is the catalogue, matching upstream's own source tree
   exactly — upstream likewise ships only `.po` files in `help/<lang>/` and
   renders them to installed `.page`s via a Meson/itstool build step this
   port does not reproduce for English `help/C/` either; same boundary,
   applied consistently, not a selectively lower bar for the fix.)

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

## Gap (as found at `ff9ec7c`, CLOSED at `95c8bdc`): `_Rings Chart` / `_Treemap Chart` — wrong msgid, breaks translation for exactly these two strings

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

## Help catalogue (as found at `ff9ec7c`, CLOSED at `4e581e4`): English content ships; translated help does not

`help/C/` (9 Mallard pages, English) is ported and resolves via
`win.help` → `Gtk.show_uri(uri: 'help:baobab')`. Upstream additionally ships
28 translated help catalogues (`help/<lang>/<lang>.po`, `help/LINGUAS`). As
of `4e581e4` these are ported too: `help/<lang>/<lang>.po` exists for all
28 codes, `diff`-identical to `origin/main`, with `help/LINGUAS` matching.
Same boundary as `help/C/` (ships the catalogue, same as upstream's own
source tree — the rendered `.page`s are a Meson/itstool build product in
both upstream and the gap this closes, not something either tree carries
pre-rendered).

## Rules check

- Key sets equal: **79 of 79** this round (was 77 of 79 at `ff9ec7c`, now
  re-censused live after `95c8bdc`), by hand census against the upstream
  scanner's real 79-message output, not a round number asserted.
- Byte-identical: true for all 79 as of this round.
- Languages ship, UI catalogue: **true**, 108 of 108, `diff`-confirmed
  against upstream's `LINGUAS`, and live-translation-confirmed for one
  language, not just file-count-confirmed.
- Languages ship, help catalogue: **true**, 28 of 28 as of this round (was
  0 of 28 at `ff9ec7c`), `diff`-confirmed file-by-file against
  `origin/main`, not just a `find`/count match.
- The scanner's own under-count (16 vs. 79) is named as a scanner limitation,
  with the escalation order followed (hand census against a real upstream
  worktree run, not a guess).
- Nothing here is carried forward from the stale prior report without an
  independent re-check this round, including the two gaps' closure, which
  was verified live (German translation call, 28-file diff loop), not
  accepted from the fixing commits' own messages.
