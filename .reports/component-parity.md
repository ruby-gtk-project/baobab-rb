# Component parity — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `4e581e4` |

As with `component-identification.md`, this supersedes the
`component-parity.md` written against `66f3ac3` and then `ff9ec7c`.
Re-driven and re-read against current `HEAD`, not copied forward.

## Re-check: both gaps this report named at `ff9ec7c` are now closed

The prior pass (below, kept rather than deleted, per this skill's rewrite-
in-place rule) found two open gaps: the `_Rings Chart`/`_Treemap Chart`
msgid mismatch (gap 0) and missing translated help catalogues (gap 1). Two
commits since (`95c8bdc`, `4e581e4`) claim to close them. Re-verified this
round, not taken on the commit messages' word:

- **Gap 0, closed.** `lib/window.rb:73` now reads `CHARTS = { 'rings' =>
  '_Rings Chart', 'treemap' => '_Treemap Chart' }`. Live check this run:
  `LANG=de_DE.UTF-8 ruby -I lib -e 'require "translations"; puts
  Translations.gettext("_Rings Chart")'` → `"K_reisdiagramm"`, the correct
  msgid, mnemonic preserved. `git diff ff9ec7c HEAD -- lib/ exe/` shows
  exactly this one line changed outside `help/` — no other code moved.
- **Gap 1, closed.** `help/<lang>/<lang>.po` now exists for all 28 codes in
  upstream's `help/LINGUAS`, and every one is byte-identical to
  `origin/main`'s copy — checked this run with a `diff` loop over all 28,
  not sampled, zero differences. `help/LINGUAS` itself also matches.
  Upstream has no build-time itstool-render step reproduced in this port for
  either `help/C/` or `help/<lang>/`, so "ships the catalogue, not a
  compiled-page renderer" is the correct scope match to upstream's own
  source tree (upstream's repo also ships only the `.po` files; the
  rendered `.page`s are a Meson/itstool build product, not source).

Both fixes re-verified against a fresh `DRIVE OK` run (35/35, see below) and
a fresh `rspec` run (22/22) at this `HEAD`, confirming neither fix
regressed anything already green.

## Verified clean, by driving the real app headlessly this run

```
$ nix develop --command xvfb-run -a ruby test/drive_main_window.rb
35 of 35 checks passed
DRIVE OK
```

All 14 `shot` calls in this run produced a render (none of the prior run's
5-of-9 silent "widget produced no render node" failures recurred — consistent
with `test/gtk_driver.rb`'s retry-with-growing-settle fix in `ff9ec7c`). No
`GLib-GObject-CRITICAL` fired this run (consistent with `e657970`'s
`type_register` fix to `lib/tree_list_row_sorter.rb`'s cell classes) — stderr
was captured and grepped for `critical|error|warning|backtrace`; only
expected libEGL/Vulkan driver warnings from the headless Xvfb environment
appeared.

| Unit | Count | Style | Behaviour | Text | Verdict |
|---|---:|---|---|:-:|---|
| Window / devices-and-locations page | ✓ | ✓ | ✓ scan starts, results shown | ✓ | parity |
| Rings chart | ✓ | ✓ | ✓ zoom in/out, move-up, reroot, right-click popover | ✓ (gap 0 closed, see re-check) | parity |
| Treemap chart | ✓ | ✓ | ✓ chart-switch, root set | ✓ (gap 0 closed, see re-check) | parity |
| Chart's own context popover (open/copy-path/trash) | ✓ | ✓ | ✓ opens, all three actions enabled on a real item | ✓ | parity |
| Tree keyboard path (Left/expand/collapse/go-up) | ✓ | — | ✓ driven through the real handler | — | parity |
| Tree context popover + copy-path | ✓ | ✓ | ✓ opens, fires | ✓ | parity |
| Trash action (chart + treeview) | ✓ | — | ✓ fails cleanly on this filesystem, toasts, no crash | ✓ | parity |
| Primary menu, incl. clear-recent | ✓ | ✓ | ✓ opens/closes, clear-recent fires | ✓ | parity |
| Preferences dialog + excluded-locations round trip | ✓ | ✓ | ✓ add, list, remove via row button | ✓ | parity |
| About dialog | ✓ | — | ✓ opens, names the app | ✓ | parity |
| Shortcuts dialog | ✓ | — | ✓ opens, both sections, all 8 rows match upstream's accelerators/titles 1:1 (checked by diff, see below) | ✓ | parity |
| Bad-folder scan error path | ✓ | — | ✓ toasts, stays on results | ✓ | parity |
| Rescan | ✓ | — | ✓ lands back on results, total unchanged | ✓ | parity |

Text axis is now a genuine `✓`, not the prior report's `✓*`-with-asterisk: a
live check this run (`LANG=de_DE.UTF-8`, loading `lib/translations.rb`
directly) resolved `"Disk Usage Analyzer"` → `"Festplattenbelegungsanalyse"`
and `"Home Folder"` → `"Persönlicher Ordner"`, matching `po/de.po` exactly.
The catalogue is not just present on disk, it actually loads and translates
at runtime.

**Not driven, confirmed only by reading source (same boundary as before,
reasonable):** `win.scan-folder` (`Gtk::FileChooserNative`), `win.help`
(`Gtk.show_uri`), chart's `open-file` (`Gio::AppInfo.launch_default_for_uri`).

**Menu/shortcut content diffed directly against upstream, not sampled:**
`chart_menu.rb`'s 6 labels match `data/gtk/menus.ui`'s 6 `<attribute
name="label">` entries verbatim (`_Open Externally`, `_Copy Path to
Clipboard`, `Mo_ve to Trash`, `Go to _Parent Folder`, `Zoom _In`, `Zoom
_Out`); `shortcuts_dialog.rb`'s 8 rows match `data/ui/shortcuts-dialog.ui`'s
8 titled shortcuts verbatim, same accelerators.

## Gaps (as found at `ff9ec7c`, both now closed — see re-check above)

### 0. Chart tab titles — msgid mismatch breaks both English mnemonic and translation — CLOSED at `95c8bdc`

`lib/window.rb:73` defines `CHARTS = { 'rings' => 'Rings Chart', 'treemap' =>
'Treemap Chart' }`, and `add_chart_page` (line 457) calls
`Translations.gettext(title)` on those two literals, then sets
`page.use_underline = true` (line 464) expecting an underscore-marked
mnemonic character in the string it was just given. Upstream's source
strings, from `data/ui/baobab-main-window.ui:259,273`, are `_Rings Chart` and
`_Treemap Chart` — the port dropped the leading underscore when it copied
the text into the `CHARTS` hash. Two independent, user-visible effects,
confirmed live:

1. **The English keyboard mnemonic is gone.** With `use_underline` on and no
   `_` in the string, there is no mnemonic character to underline or bind,
   where upstream binds Alt+R / Alt+T (or whichever letter) to switch chart
   type from the stack switcher.
2. **The string can never be translated, in any locale**, because
   `po/*.po`'s msgid is `_Rings Chart` / `_Treemap Chart`, not `Rings Chart`
   / `Treemap Chart`, and gettext lookups are exact-key. Confirmed by direct
   call:
   ```
   $ LANG=de_DE.UTF-8 ruby -I lib -e 'require "translations"; \
       puts Translations.gettext("Rings Chart").inspect; \
       puts Translations.gettext("_Rings Chart").inspect'
   "Rings Chart"          # wrong key — always falls back to English
   "K_reisdiagramm"       # correct key — translates, mnemonic preserved
   ```
   Every other sampled mnemonic string (`_Help`, `_Add Location`, `_About
   Disk Usage Analyzer`, `_Open Externally`, `_Copy Path to Clipboard`) kept
   its underscore correctly — this is isolated to the two `CHARTS` values,
   not a systemic pattern. One-line fix: change the hash's two values to
   `'_Rings Chart'` / `'_Treemap Chart'`.

### 1. Translated help content — real, narrower than before — CLOSED at `4e581e4`

`help/C/` (English Mallard pages) is ported and `win.help` resolves to it.
Upstream's 28 translated help catalogues (`help/<lang>/<lang>.po`) are not
ported — confirmed by listing (`help` has only `C/` and `media/` as
subdirectories). A non-English user who clicks Help gets English content
where upstream would give them their language. This is the one component
gap this audit found; it is real but far smaller than the prior report's
"whole help system… not ported" finding, which predated `6788534`.

### 2. GSettings schema — correspondence, now backed by a real shipped schema

`lib/settings.rb` still stores window/preferences state as JSON rather than
binding `Gio::Settings` to the now-present
`data/schemas/org.gnome.baobab.gschema.xml` at runtime. The schema file
itself is present, byte-identical to upstream, and correctly wired
(`flake.nix`'s `if [ -d data/schemas ]` branch is live, not dead code, and
`GSETTINGS_SCHEMA_DIR` is exported). But the Ruby app does not actually read
or write through that schema — it is shipped for packaging/discoverability
correctness, not consumed. Behaviourally equivalent to upstream inside the
app (same three keys, same defaults, re-confirmed via `spec/settings_spec.rb`,
22/22 green this run including this file), not interoperable with an
installed upstream baobab's dconf state. Documented correspondence, not an
excuse — same conclusion the prior report reached, still true.

### 3. `Gtk::FileChooserNative` / `key-pressed` controller — correspondences, unchanged

Same two documented substitutions as the prior report (native chooser for
the "recursively analyze mount points" option `Gtk::FileDialog` cannot
carry; an `EventControllerKey` case statement instead of
`Gtk::ShortcutController` for the four tree shortcuts). Re-confirmed this
run via the drive script's "Left collapses via the keyboard path" check.

## What this report does not re-certify

Same boundary as the prior version: it does not re-derive
`component-inventory.md`'s full per-widget CSS/signal tables from scratch.

## Rules check

- Parity reported per-unit.
- Both gaps named at `ff9ec7c` are now closed, each re-verified live this
  round (not re-asserted from the fixing commits' own messages).
- The remaining two correspondences (settings-as-JSON, native
  chooser/EventControllerKey) are named with file and reason, same as
  before.
- No component gap remains open as of `4e581e4`. The `no PORTING.md` /
  "no excuse to cover a gap" finding belongs to `accountability-ensurance.md`,
  not repeated here.
- Nothing here is asserted from the prior stale report without an
  independent re-check this round (drive re-run, diff, live locale test).
