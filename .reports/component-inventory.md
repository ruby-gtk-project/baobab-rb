# Component inventory — baobab-rb vs upstream (org.gnome.baobab, origin/main)

> **Stale note, added by the `Parity reports` audit at `ff9ec7c`:** this
> document was last written at `8662ed4`, before `785d7e3` ported the two
> action-icon SVGs this document's "Gaps found" §1 and the table row below
> still call missing. Both icons are now present at
> `data/icons/hicolor/scalable/actions/view-ringschart-symbolic.svg` and
> `view-treemap-symbolic.svg`. Left in place rather than deleted, per the
> accountability-ensurance rule of rewriting in context rather than erasing
> a prior finding — see `.reports/component-identification.md` and
> `.reports/accountability-ensurance.md` for the current-state re-check.

Survey only; no app code written in this step. Produced with the
`component-identification` method: upstream's `src/*.vala` + `data/ui/*.ui`
files are the component units (Baobab has no GResource-templated GJS/Rust
split — each `.vala` class owns one `.ui` template, or none, one to one),
compared file-by-file against the `ruby` branch's `lib/`.

## Summary

Upstream has 21 meaningful `src/` files (20 classes + `main.vala`) and 15
`data/ui/*.ui` templates, plus `data/gtk/menus.ui` (one shared menu model
with one `<menu>` root), `data/style.css`, `data/org.gnome.baobab.gschema.xml`
(three schemas), `data/org.gnome.baobab.desktop.in`,
`data/org.gnome.baobab.metainfo.xml.in`, `data/org.gnome.baobab.service.in`,
and the hicolor/symbolic icon set. The `ruby` branch's `lib/` already has one
file for every upstream class and every `.ui` template — **no upstream
component file is unmapped**. `po/`, `data/` and `help/C/` were ported in a
prior commit (`6788534`). This inventory lists the mapping and flags
components whose *upstream file* existing does not yet guarantee the *port
file* reproduces every widget, signal and action inside it (that finer-grained
check is `component-parity`'s job, not this survey's, so entries below are
marked "exists" at the file level only).

| Upstream file(s) | → `lib/*.rb` | Kind | Exists? |
|---|---|---|---|
| `src/main.vala` | `lib/baobab.rb` (+ `exe/baobab-rb`) | entry point | yes |
| `src/baobab-application.vala` | `lib/application.rb` | application (actions, accelerators, About entry point, CLI options) | yes |
| `src/baobab-window.vala` + `data/ui/baobab-main-window.ui` | `lib/window.rb` | main window (`Adw.ApplicationWindow`): toolbar view, stack (empty state / scanning / results), path bar host, primary menu host | yes |
| `data/gtk/menus.ui` (`chartmenu`) | `lib/chart_menu.rb` | context menu — rings/treemap chart (open externally, copy path, trash, move up, zoom in/out) | yes |
| `data/ui/baobab-treeview-menu.ui` | `lib/treeview_menu.rb` | context menu — results tree view | yes |
| (hamburger menu built in `baobab-window.vala`) | `lib/primary_menu.rb` | menu model — primary/hamburger menu | yes |
| `src/baobab-preferences-dialog.vala` + `data/ui/baobab-preferences-dialog.ui` | `lib/preferences_dialog.rb` | preferences dialog (`Adw.PreferencesDialog`), with the excluded-locations list | yes |
| `data/ui/baobab-excluded-row.ui` | `lib/excluded_row.rb` | row — one excluded location inside the preferences dialog | yes |
| `data/ui/shortcuts-dialog.ui` | `lib/shortcuts_dialog.rb` | keyboard shortcuts window | yes |
| (About dialog built in `baobab-application.vala`) | `lib/about_dialog.rb` | about dialog (`Adw.AboutDialog`) | yes |
| `src/baobab-location.vala` | `lib/location.rb` | model — one scannable location (home, filesystem, remote, other) | yes |
| `src/baobab-location-list.vala` + `data/ui/baobab-location-list.ui` | `lib/location_list.rb` | start page — list of scannable locations | yes |
| `data/ui/baobab-location-row.ui` | `lib/location_row.rb` | row — one location on the start page | yes |
| `src/baobab-folder-display.vala` + `data/ui/baobab-folder-display.ui` | `lib/folder_display.rb` | results page — chart + tree view + toggle | yes |
| `src/baobab-pathbar.vala` + `data/ui/baobab-pathbar.ui` | `lib/pathbar.rb` | path bar container above the results | yes |
| `data/ui/baobab-pathbutton.ui` | `lib/path_button.rb` | one segment button inside the path bar | yes |
| `src/baobab-chart.vala` | `lib/chart.rb` | shared chart base (hit-testing, context menu wiring, zoom/navigation actions) for rings + treemap | yes |
| `src/baobab-ringschart.vala` | `lib/rings_chart.rb` | rings chart view | yes |
| `src/baobab-treemap.vala` | `lib/treemap_chart.rb` | treemap chart view | yes |
| `src/baobab-scanner.vala` | `lib/scanner.rb` | scan engine (GIO-based directory walker, exclusions, progress) | yes |
| `src/baobab-tree-list-row-sorter.vala` | `lib/tree_list_row_sorter.rb` | `Gtk.Sorter` for the results tree | yes |
| `src/baobab-cellrenderers.vala` | `lib/formatters.rb` | shared string-formatting helpers (`format_items`, `format_time_approximate`) used by the cell factories | yes |
| `src/baobab-contents-cell.vala` + `data/ui/baobab-contents-cell.ui` | `lib/contents_cell.rb` | tree cell — item count column | yes |
| `src/baobab-file-cell.vala` + `data/ui/baobab-file-cell.ui` | `lib/file_cell.rb` | tree cell — file row | yes |
| `src/baobab-folder-cell.vala` + `data/ui/baobab-folder-cell.ui` | `lib/folder_cell.rb` | tree cell — folder row (expander) | yes |
| `src/baobab-name-cell.vala` + `data/ui/baobab-name-cell.ui` | `lib/name_cell.rb` | tree cell — name column (shared file/folder icon + label) | yes |
| `src/baobab-progress-cell.vala` | `lib/progress_cell.rb` | tree cell — proportional usage bar | yes |
| `src/baobab-size-cell.vala` + `data/ui/baobab-size-cell.ui` | `lib/size_cell.rb` | tree cell — size column | yes |
| `src/baobab-time-modified-cell.vala` + `data/ui/baobab-time-modified-cell.ui` | `lib/time_modified_cell.rb` | tree cell — last-modified column | yes |
| `data/style.css` | `lib/style.rb` | application stylesheet installer | yes |
| `data/org.gnome.baobab.gschema.xml` (3 schemas) | `lib/settings.rb` | GSettings keys (window state, preferences, UI state) | yes |
| `po/*.po`, `po/LINGUAS`, `po/POTFILES.in` | `lib/translations.rb` | message-catalogue resolver | yes (ported in commit `6788534`) |

### Non-component data already ported (not `lib/*.rb` targets)

| Upstream | Port location | Exists? |
|---|---|---|
| `data/icons/hicolor/scalable/apps/org.gnome.baobab.svg` + `.Devel.svg` | `data/icons/hicolor/scalable/apps/` | yes |
| `data/icons/hicolor/symbolic/apps/org.gnome.baobab-symbolic.svg` | `data/icons/hicolor/symbolic/apps/` | yes |
| `data/icons/scalable/actions/view-ringschart-symbolic.svg`, `view-treemap-symbolic.svg` | not found under port `data/icons/` — **only the app/symbolic icons were ported, the two chart-mode action icons were not** | **no — gap** |
| `data/org.gnome.baobab.desktop.in` | `data/org.gnome.baobab.desktop.in` | yes |
| `data/org.gnome.baobab.metainfo.xml.in` | `data/org.gnome.baobab.metainfo.xml.in` | yes |
| `data/org.gnome.baobab.service.in` | `data/org.gnome.baobab.service.in` | yes |
| `data/org.gnome.baobab.gschema.xml` | `data/schemas/org.gnome.baobab.gschema.xml` | yes |
| `help/C/*.page` (9 pages) + `help/C/media/org.gnome.baobab.svg` | `help/C/` | yes (ported in commit `6788534`) |
| `help/<locale>/*.po` (24 translated help catalogues) | — | not checked in this survey; flag for `translation-parity` |
| `po/*.po` (139 UI catalogues) | `po/` | yes (ported in commit `6788534`); exact locale-count match not verified here — flag for `translation-parity` |

## Gaps found

1. **Action-icon SVGs not ported.** `data/icons/scalable/actions/view-ringschart-symbolic.svg`
   and `view-treemap-symbolic.svg` (the rings/treemap view-switcher icons used
   by the folder-display toggle, `lib/folder_display.rb`) are not present
   anywhere under the port's `data/icons/`. Without them the chart-type
   toggle button in `folder_display.rb` has no icon to show (or falls back to
   a generic one), which is a visible parity gap.
2. **This survey is file-level only.** Every upstream file has a same-named
   port file, but that is necessary, not sufficient, for parity — the widgets,
   CSS classes, signals and actions *inside* each pair still need the
   `component-parity` skill's row-by-row comparison before any file here can
   be called done. In particular `lib/window.rb` (1130 lines) and
   `lib/scanner.rb` (559 lines) are large enough that partial coverage inside
   a file would not show up at this granularity.
3. **Help and UI translation catalogue completeness** was not verified
   (counted files only, not locale coverage or message completeness) — left
   for the `translation-parity` skill.

## Conclusion

At the file-mapping level, baobab-rb's `ruby` branch is essentially complete:
all 20 upstream widget/model classes, all 15 `.ui` templates, the shared menu
model, the GSettings schemas, the stylesheet, the desktop/metainfo/service
files, the icon set (bar the two action icons above), `po/` and `help/C/` all
have a corresponding port artifact. The next step is not "write missing
files" but (a) fetch the two missing action icons, and (b) run
`component-parity` on each pair above, starting with the largest/most complex
units (`window.rb`, `scanner.rb`, `chart.rb`/`rings_chart.rb`/`treemap_chart.rb`).
