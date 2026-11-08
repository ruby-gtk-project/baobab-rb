# Porting status — baobab-rb

## Upstream

`baobab` (GNOME Disk Usage Analyzer), implemented in Vala/GTK4/Libadwaita.
Spec is read from the `origin/main` ref of this same repository (never
checked out, never merged — the port on `ruby` is written from scratch
against it). Current spec commit: `8c68f9b`.

## Done

Every upstream `src/*.vala` class and `data/ui/*.ui` template has a
corresponding `lib/*.rb` file, and the mapping below has been *observed
working* by driving the real app headlessly (see Runtime) — not just
file-matched.

| `lib/` path | Ported from |
|---|---|
| `lib/baobab.rb`, `exe/baobab-rb` | `src/main.vala` |
| `lib/application.rb` | `src/baobab-application.vala` |
| `lib/window.rb` | `src/baobab-window.vala` + `data/ui/baobab-main-window.ui` |
| `lib/chart_menu.rb` | `data/gtk/menus.ui` (`chartmenu`) |
| `lib/treeview_menu.rb` | `data/ui/baobab-treeview-menu.ui` |
| `lib/primary_menu.rb` | primary/hamburger menu built in `baobab-main-window.ui` |
| `lib/preferences_dialog.rb` | `src/baobab-preferences-dialog.vala` + `data/ui/baobab-preferences-dialog.ui` |
| `lib/excluded_row.rb` | `data/ui/baobab-excluded-row.ui` |
| `lib/shortcuts_dialog.rb` | `data/ui/shortcuts-dialog.ui` |
| `lib/about_dialog.rb` | about dialog built in `src/baobab-application.vala` |
| `lib/location.rb` | `src/baobab-location.vala` |
| `lib/location_list.rb` | `src/baobab-location-list.vala` + `data/ui/baobab-location-list.ui` |
| `lib/location_row.rb` | `data/ui/baobab-location-row.ui` |
| `lib/folder_display.rb` | `src/baobab-folder-display.vala` + `data/ui/baobab-folder-display.ui` |
| `lib/pathbar.rb` | `src/baobab-pathbar.vala` + `data/ui/baobab-pathbar.ui` |
| `lib/path_button.rb` | `data/ui/baobab-pathbutton.ui` |
| `lib/chart.rb` | `src/baobab-chart.vala` |
| `lib/rings_chart.rb` | `src/baobab-ringschart.vala` |
| `lib/treemap_chart.rb` | `src/baobab-treemap.vala` |
| `lib/scanner.rb` | `src/baobab-scanner.vala` |
| `lib/tree_list_row_sorter.rb` | `src/baobab-tree-list-row-sorter.vala` |
| `lib/formatters.rb` | `src/baobab-cellrenderers.vala` (string-formatting helpers) |
| `lib/contents_cell.rb` | `src/baobab-contents-cell.vala` + `data/ui/baobab-contents-cell.ui` |
| `lib/file_cell.rb` | `src/baobab-file-cell.vala` + `data/ui/baobab-file-cell.ui` |
| `lib/folder_cell.rb` | `src/baobab-folder-cell.vala` + `data/ui/baobab-folder-cell.ui` |
| `lib/name_cell.rb` | `src/baobab-name-cell.vala` + `data/ui/baobab-name-cell.ui` |
| `lib/progress_cell.rb` | `src/baobab-progress-cell.vala` |
| `lib/size_cell.rb` | `src/baobab-size-cell.vala` + `data/ui/baobab-size-cell.ui` |
| `lib/time_modified_cell.rb` | `src/baobab-time-modified-cell.vala` + `data/ui/baobab-time-modified-cell.ui` |
| `lib/style.rb` | `data/style.css` |
| `lib/settings.rb` | `data/org.gnome.baobab.gschema.xml` (3 schemas) — stores state as JSON rather than binding `Gio::Settings` to the shipped schema at runtime; same three keys/defaults, not interoperable with an installed upstream baobab's dconf state |
| `lib/translations.rb` | `po/*.po`, `po/LINGUAS`, `po/POTFILES.in` |

Packaging/data also ported and present: `data/org.gnome.baobab.desktop.in`,
`.metainfo.xml.in`, `.service.in`, `data/schemas/org.gnome.baobab.gschema.xml`
(byte-identical to `origin/main`), full icon set including the two chart
action icons, `po/` (108 catalogues, `LINGUAS` matching upstream), and
`help/C/` (9 Mallard pages) plus all 28 `help/<lang>/<lang>.po` translated
catalogues (byte-identical to `origin/main`).

## Runtime

```
nix develop --command xvfb-run -a ruby test/drive_main_window.rb
```
Result this run: `drive_ok=true`, 35 passed / 0 failed, 13 components
covered. Full stderr inspected (`critical|error|warning|backtrace`); only
expected libEGL/Vulkan driver warnings from the headless Xvfb environment
appeared.

```
nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
```
Result this run: 22 passed / 0 failed (`spec/formatters_spec.rb`,
`spec/settings_spec.rb`). Two non-fatal `method redefined` warnings on
`lib/settings.rb`'s memoized accessors; does not fail the suite.

## Not started

Nothing at the file-mapping level: every upstream `src/*.vala` class and
`data/ui/*.ui` template has a `lib/*.rb` counterpart. The remaining
not-ported item is behavioural, not structural, and is listed under
Blockers (`lib/settings.rb` not binding `Gio::Settings` live).

## Open gaps

The last audit (`.reports/accountability-ensurance.md` at `4e581e4`,
re-verified live rather than read from prior reports) reports 0 gap(s),
clean=true. `find-excuses.sh .` and a grep for
`TODO|FIXME|not implemented|for now|in a future|out of scope|not
applicable|n/a|does not carry over|by design|not needed|dropped
deliberately|intentionally omitted` over `lib/` and `exe/` turned up no
hits outside `.reports/*.md`'s own meta-discussion of that vocabulary.

## Blockers

- `lib/settings.rb` stores window/preferences state as JSON instead of
  binding `Gio::Settings` to the shipped `data/schemas/org.gnome.baobab.gschema.xml`
  at runtime. The schema file itself is present and byte-identical to
  upstream and is wired into `flake.nix`'s install step, but the app does
  not read or write through it, so state is not interoperable with an
  installed upstream baobab's dconf state. Behaviourally equivalent inside
  the app (same three keys, same defaults, covered by `spec/settings_spec.rb`).
- `win.scan-folder` uses `Gtk::FileChooserNative` (upstream's "recursively
  analyze mount points" option is not reproducible through `Gtk::FileDialog`)
  and the results tree's four keyboard shortcuts (`Menu`/`Right`/`Left`/
  `<Alt>Up`) are handled with an `EventControllerKey` case statement instead
  of a `Gtk::ShortcutController`. Both are documented substitutions, not
  gaps — re-confirmed working this run via the drive script's tree-keyboard
  checks.
- Upstream has no test suite (`test/`/`tests/` directories, `*_test.vala`,
  or a `test()` Meson target all absent on `origin/main`), so test-parity is
  0/0, met trivially; the port's `spec/` and `test/drive_main_window.rb` are
  the port's own safety net, not a port of anything upstream.
