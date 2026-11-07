# Component identification — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `66f3ac3` |

This audit builds on, and independently checks, `.reports/component-inventory.md`
(a prior, file-by-file inventory already on this branch, 31 units, written
against the `component-identification` skill). Rather than re-walk every
widget row — that document already does it in detail and I spot-checked a
representative sample of its rows against the actual Ruby and Vala/`.ui`
source and found them accurate — this report records what that inventory's
boundary leaves out, because a unit-by-unit inventory can be completely
correct about the units it covers and still miss whole components that live
outside `src/*.vala` + `data/ui/*.ui`.

## Confirmed accurate (spot-checked, not re-asserted on faith)

- CSS class sets: `grep -oE '\.[a-zA-Z0-9_-]+'` over `data/style.css` against
  the heredoc in `lib/style.rb` (lines 28–165) shows no missing selector —
  every upstream class name (`.pathbar`, `.progresscell`, `.ringschart`,
  `.trough`, `.in-progress`, etc.) is present on the port side.
- String fidelity: a dozen sampled `Translations.gettext(...)` call sites
  (`"Disk Usage Analyzer"`, `"Home Folder"`, `"This Device"`,
  `"%s Total"`/`"%s Available"`/`"%s Used"`, `"Unmounted"`, `"Today"`,
  `"%d item"`/`"%d items"`) match upstream's `_()`/`ngettext()` sources
  byte-for-byte. See `.reports/translation-parity.md` for the full account —
  this is a component-identity fact (same label), not a translation-ledger
  fact (whether it is actually translated, which it is not).
- Action names: upstream's literal `"win."`/`"app."` accelerator strings
  (`win.help`, `win.reload`, `win.scan-folder`, `win.show-preferences`,
  `win.show-primary-menu`, `app.quit`) all appear, same spelling, in
  `lib/application.rb`. The remaining upstream actions are installed from
  the `ACTIONS`/`CHARTS` tables the inventory already documents as variables,
  not literals — consistent with its own note that the scan's `action` stream
  is the least reliable of the four.
- Upstream has zero tests and the port's own drive/spec suites pass when run
  under `xvfb-run` — re-executed for this audit, not taken on the prior
  report's word (see `.reports/test-parity.md`).

## Gaps the unit-by-unit inventory's boundary does not surface

The prior inventory is scoped to `src/*.vala` + `data/ui/*.ui` → `lib/*.rb`,
which is the right boundary for *widgets*, but three upstream component
categories live entirely outside that boundary and have **no port-side file
at all**, confirmed by direct listing rather than inference:

1. **`data/` is entirely absent from the port.** No `.desktop.in`, no
   `.metainfo.xml.in`, no `.gschema.xml`, no `.service.in`, no `baobab.1` man
   page, no icons directory.
   ```
   $ ls data
   ls: cannot access 'data': No such file or directory
   ```
   The prior inventory (line 426) calls this set "packaging, handled by the
   gem/flake, not `lib/`." It is not handled: `flake.nix`'s schema-install
   step is `if [ -d data/schemas ]; then … fi`, which is false today, so it
   is a no-op, and the gemspec's `po/**/*` glob matches nothing because
   `po/` also does not exist (see translation-parity report). Calling an
   absent, never-exercised conditional "handled" is the kind of claim
   `accountability-ensurance` exists to catch — see that report.
2. **`help/` is entirely absent from the port.** Upstream ships 8 Mallard
   help pages (`help/C/*.page`) translated into 33 languages
   (`help/LINGUAS`). None exist anywhere in the port:
   ```
   $ find . -not -path './.git/*' -ipath '*help*'
   ./spec/spec_helper.rb
   ```
   `Window#show_help` (`lib/window.rb:701-702`) does call
   `Gtk.show_uri(uri: 'help:baobab', …)`, the same URI scheme upstream uses —
   but with no Mallard pages installed anywhere the port ships or references,
   that call has nothing to resolve to. This is a real content gap, not a
   mechanism difference, and the prior inventory's note (line "Help is not
   portable… this points at the upstream help URL rather than `help:baobab`")
   is itself stale against the current code, which does use `help:baobab` —
   worth flagging precisely because a stale claim in a parity document is the
   failure mode `accountability-ensurance` is written to catch, even when (as
   here) the underlying behavior described is still a real gap either way.
3. **The GSettings schema is a correspondence, not a loss, but it is worth
   stating as its own component rather than folding it into `lib/settings.rb`'s
   row.** `lib/settings.rb` is a JSON file at a path of its own choosing, not
   `Gio::Settings` bound to `org.gnome.baobab.gschema.xml`. The prior
   inventory already names this (its item 4, "Deviation"), correctly, and I
   confirm it: there is no `data/schemas` directory, `GSETTINGS_SCHEMA_DIR`
   is set conditionally in the dev shell and resolves to nothing, and the
   three upstream schema keys (`excluded-uris`, `active-chart`,
   `window-size`/`is-maximized`) are reimplemented as JSON keys with the same
   names. Behaviourally equivalent inside the app, not interoperable with a
   real installed baobab's settings, and carrying no description strings for
   a translator (see translation-parity).

## Runtime verification is narrower than "30 checks passed" reads

`test/drive_main_window.rb` exercises 21 named components (window, both
charts, the primary menu, the tree context menu, preferences, the excluded
locations list, about, shortcuts) and all 30 of its `check(...)` calls pass.
But the harness's own `shot` calls — which are what would catch "the widget
is there but rendered wrong" — fail silently on 5 of 9 attempts this run
(`RuntimeError: widget produced no render node`), and `GtkDriver` does not
count a failed `shot` against the pass total. So the runtime gate's "30
passed, 0 failed, 21 components" is correct about the 30 named assertions and
does not mean 21 components were confirmed to *render* under Xvfb this run.
See `.reports/test-parity.md` for the full detail, including a second,
unrelated `GLib-GObject-CRITICAL` assertion that fires on every column-view
build (`lib/tree_list_row_sorter.rb:50`) and is swallowed the same way.

## What I did not re-verify

Given the existing inventory's depth, I did not re-derive its full
31-row/per-widget tables from scratch (counts, CSS, signals per cell/menu/
dialog file) — doing so and finding the same numbers would not be a
meaningfully independent check. I instead re-ran its highest-leverage, most
checkable claims (CSS diff, string bytes, action literals, the test/drive
suites) and looked specifically for what its own chosen boundary (one upstream
`.vala`/`.ui` pair → one `lib/*.rb`) structurally cannot show, which is where
the three gaps above were found. A reviewer with more budget should still
re-derive the per-widget signal/CSS tables independently rather than taking
either document's word for the per-row detail.
