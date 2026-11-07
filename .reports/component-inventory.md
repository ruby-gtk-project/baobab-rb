# baobab — upstream component inventory

Survey of `origin/main` (GNOME Baobab, Vala + GtkBuilder `.ui`) against `lib/`
on the `ruby` branch, for the full-parity Ruby GTK4/Libadwaita port.

Method: the `component-identification` skill. The declarative `.ui` files were
read first (they *are* the inventory for 17 of the units), then every
`src/*.vala` file, then the GSettings schema, the GResource manifest,
`data/style.css`, `data/gtk/menus.ui` and `po/`.

House shape follows the pilot port `gnome-contacts-rb`: one upstream component
to one flat `lib/<thing>.rb`, `# frozen_string_literal: true`, `require
'adwaita'` + `require_relative` siblings, a comment naming the upstream file,
declaratively built widgets as memoized accessors assembled in `.tap` blocks.

## State of `lib/` on `ruby`

All 31 target files now exist. Verified in the fork's dev shell (GTK 4.22.4,
Ruby 3.4.9) by requiring every `lib/*.rb` under `xvfb-run` and resolving each
class constant — all 31 load and resolve:

```
Application Window Scanner Chart RingsChart TreemapChart ProgressCell
LocationList LocationRow Location Pathbar PathButton FolderDisplay FileCell
FolderCell NameCell SizeCell ContentsCell TimeModifiedCell PreferencesDialog
ExcludedRow ShortcutsDialog AboutDialog PrimaryMenu TreeviewMenu ChartMenu
TreeListRowSorter Settings Style Translations Formatters
```

6,300 lines across `lib/`, flat, one file per upstream component, each opening
with `# frozen_string_literal: true`, `require 'adwaita'` and `require_relative`
siblings, each class commented with the upstream file it came from — the pilot
port's shape.

Scan comparison (`component-scan.sh`, upstream `src/` + `data/` vs. `lib/`):

| Stream | Upstream | Port |
|---|---:|---:|
| widget | 102 | 67 |
| type | 73 | 47 |
| controller | 9 | 7 |
| signal | 46 | 46 |
| css | 19 | 19 |
| action | 21 | 3 |

The widget/type/action deltas are scan artefacts, not gaps, and each was read
back to source:

- Upstream counts the same type once per `.ui` file *and* once per `.vala`
  file; the port states each type once. Set-differencing the widget streams
  leaves only `Gtk.Allocation` and `Gtk.LEVEL` upstream-only — a record and a
  constant prefix, neither a widget.
- The `action` stream is the scan's least reliable (the skill says so): the
  port builds its 14 window actions from `ACTIONS = %w[...]` and its 6 chart
  actions from a list, so the names are variables and never literals. Read off
  the `add_action` sites, all 21 upstream actions across `app.`, `win.` and
  `chart.` are installed.
- The four upstream-only CSS classes (`baobab-cell-error`,
  `baobab-cell-warning`, `in-progress`, `subfolder-tip`) are all present — as
  `NameCell::ERROR_CLASS` / `WARNING_CLASS` constants and inside `style.rb`'s
  heredoc, which the regex does not read as an `add_css_class` call.
- The upstream-only signal names (`completed`, `progress`, `item-activated`,
  `location-activated`, `removed`, `activated`) are Vala `signal` declarations
  on non-widget classes. The port reimplements each as a callback list with an
  `on_<name>` registrar (`LocationList#on_location_activated`,
  `Pathbar#on_item_activated`, `Chart#on_item_activated`, and so on), which is
  the house equivalent and is wired up in `window.rb`.

So every row below is now **present**. What remains are the deviations and the
untested surface, both recorded under Blockers.

Totals: 21 upstream `.vala` files and 17 `.ui`/menu files carry user-facing
components, mapping to 31 `lib/*.rb` files. Upstream installs 6 app/window
accelerators, 21 actions across three action groups (`app.`, `win.`, `chart.`),
3 menu models, 4 `GtkColumnViewColumn`s with 4 cell factories each, 25 distinct
CSS classes in `data/style.css`, and 116 locales in `po/`.

---

## 1. `src/main.vala` + `src/baobab-application.vala` → `lib/application.rb`

The application object. Kind: **application**. Present: **yes** (`lib/application.rb`).

| Facet | Upstream |
|---|---|
| Type | `Adw.Application`, id `org.gnome.baobab`, flags `HANDLES_OPEN`, resource base path `/org/gnome/baobab/` |
| Actions | `app.quit`; `app.shortcuts` is supplied by `Adw.Application` from the `shortcuts-dialog.ui` resource |
| Accels | `win.show-preferences` `<Primary>comma`; `win.show-primary-menu` `F10`; `win.scan-folder` `<Primary>o`; `win.reload` `<Primary>r`; `win.help` `F1`; `app.quit` `<Primary>q` |
| CLI | `--all-file-systems` / `-a`, `--version` / `-v`, parameter string `[DIRECTORY]`; `open` scans `files[0]` with `ScanFlags.EXCLUDE_MOUNTS` unless `-a` |
| Other | `get_excluded_locations ()` reads `excluded-uris` from `org.gnome.baobab.preferences`; `main.vala` does gettext bindtextdomain only |

Repeaters: none. Conditional: `ScanFlags` depends on the `-a` flag.

## 2. `src/baobab-window.vala` + `data/ui/baobab-main-window.ui` → `lib/window.rb`

The main window: an `Adw.NavigationView` of two pages — the devices list and
the results view. Kind: **window**. Present: **yes**.

| Widget | × | CSS | Signals / handler | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | — | `close_request` → saves `window-size` | title "Disk Usage Analyzer", icon `org.gnome.baobab`, height-request 294 |
| `Adw.ToastOverlay` `toast_overlay` | 1 | — | — | hosts every error toast (below) |
| `Adw.NavigationView` `nav_view` | 1 | `contents` | — | `pop ()` / `push_by_tag ("results")` |
| `Adw.NavigationPage` `home_page` | 1 | — | — | tag `home`, title "Devices & Locations" |
| `Adw.NavigationPage` `result_page` | 1 | — | `hidden` → `results_hidden` (cancels the scan, hides the banner, returns home) | tag `results`, title "Results" |
| `Adw.ToolbarView` | 2 | — | — | one per page; the results one has `top-bar-style: raised` |
| `Adw.HeaderBar` | 2 | — | — | home: menu button at end; results: pathbar as title widget, reload at end |
| `Gtk.MenuButton` `menu_button` | 1 | — | — | `primarymenu`, icon `open-menu-symbolic`, primary, tooltip "Main Menu" |
| `Gtk.Button` `reload_button` | 1 | — | `action_name win.reload` | icon `view-refresh-symbolic`, tooltip "Rescan Current Location" |
| `Adw.Banner` `banner` | 1 | — | — | "Files may take more space than shown"; revealed when `!scanner.show_allocated_size` — **warning state** |
| `Adw.OverlaySplitView` | 1 | — | — | max-sidebar-width 99999, sidebar-width-fraction 0.5 |
| `Gtk.Box` | 3 | — | — | vertical content column, sidebar box, inner box |
| `Gtk.Separator` | 1 | — | — | vertical, between sidebar and chart |
| `Gtk.ScrolledWindow` `scrolled_window` | 1 | `undershoot-top` | — | hscrollbar never, vexpand |
| `Gtk.ColumnView` `columnview` | 1 | — | `activate` → `columnview_activate` (reroots, selects first) | single-click-activate, not reorderable, **header row hidden by poking at `GtkColumnViewRowWidget`** |
| `Gtk.SingleSelection` `columnview_selection` | 1 (type) | — | — | wraps `Gtk.SortListModel` `columnview_sort_model`, sorter bound to `folder_display.sorter` |
| `Gtk.ColumnViewColumn` | 4 | — | — | "Folder" (expand), "Size", "Contents", "Modified" |
| `Gtk.SignalListItemFactory` | 4 | — | `setup`/`bind`/`unbind`/`teardown` per column | build `FileCell`, `SizeCell`, `ContentsCell`, `TimeModifiedCell`; each cell joins the matching `Gtk.SizeGroup` on `folder_display` |
| `Gtk.PopoverMenu` `treeview_popover_menu` | 1 | — | — | model from `baobab-treeview-menu.ui`, position bottom |
| `Gtk.GestureClick` `treeview_right_click_gesture` | 1 (controller) | — | `pressed` → `treeview_right_click_gesture_pressed` | button 3; picks the row, scrolls/selects it, pops the menu at the pointer |
| `Gtk.ShortcutController` + `Gtk.Shortcut` ×4 | 1 + 4 (controller) | — | — | capture phase: `Menu`→`win.show-treeview-popover`, `Right`→`win.treeview-expand-row`, `Left`→`win.treeview-collapse-row`, `<Alt>Up`→`win.treeview-go-up` |
| `Adw.BreakpointBin` + `Adw.Breakpoint` | 1 + 1 | — | — | 360×246; `max-width: 500sp` sets `chart_stack_switcher.policy = narrow` |
| `Gtk.Stack` `spinner_stack` | 1 | — | — | swaps chart ↔ spinner while scanning |
| `Adw.ViewStack` `chart_stack` + 2 `Adw.ViewStackPage` | 1 + 2 | — | — | `rings` "_Rings Chart" `view-ringschart-symbolic`, `treemap` "_Treemap Chart" `view-treemap-symbolic`; bound to `ui.active-chart` |
| `Adw.Spinner` `spinner` | 1 | — | — | **busy state** |
| `Gtk.ActionBar` `chart_action_bar` | 1 | — | — | height-request 48 |
| `Adw.ViewSwitcher` `chart_stack_switcher` | 1 | — | — | policy wide/narrow, insensitive while scanning |
| `Gtk.EventControllerFocus` `focus_controller` | 1 (controller) | — | `enter` → withdraws the `scan-completed` notification | |
| `Gtk.DropTarget` `drop_target` | 1 (controller) | — | `accept` (refused while busy), `on_drop` → scans a single dropped folder | actions copy, gtype `Gdk.FileList`; `:drop(active) .contents` outline comes from the stylesheet |
| `Gtk.FileChooserNative` | 1 | — | `response` | "Select Folder", modal, with the choice "Recursively analyze mount points" — built on `win.scan-folder` |
| `Adw.Toast` | repeater | — | — | "Could not analyze volume", "Could not scan folder", "Failed to open file", "Failed to trash file", "“%s” is not a valid folder" — **error states** |
| `Gdk.Cursor` "wait" | 1 (type) | — | — | set on the window while busy |

Window actions (`win.`): `show-primary-menu` (stateful boolean),
`scan-folder`, `reload`, `clear-recent`, `show-preferences`, `help` (opens
`help:baobab`), `about`, `show-treeview-popover`, `treeview-expand-row`,
`treeview-collapse-row`, `treeview-go-up`, `treeview-open-folder`,
`treeview-copy`, `treeview-trash`, plus `active-chart` created from GSettings.
`reload` is disabled on the home page; `scan-folder` is disabled while
scanning.

Also in this unit: the `scan-completed` `GLib.Notification` ("Scan completed" /
"Completed scan of “%s”") sent when the window is not active, and the 500 ms
progress timeout driving `location.progress ()`.

## 3. `data/ui/baobab-main-window.ui` (`menu primarymenu`) → `lib/primary_menu.rb`

Kind: **menu**. Present: **yes**. Two sections, 6 items: "Scan Folder…"
(`win.scan-folder`), "Clear Recent List" (`win.clear-recent`) | "Preferences"
(`win.show-preferences`), "Keyboard _Shortcuts" (`app.shortcuts`), "_Help"
(`win.help`), "_About Disk Usage Analyzer" (`win.about`).

## 4. `data/ui/shortcuts-dialog.ui` → `lib/shortcuts_dialog.rb`

Kind: **dialog** (keyboard shortcuts). Present: **yes**. Standalone `.ui` with
no backing source file — `Adw.Application` loads it for `app.shortcuts`.
`Adw.ShortcutsDialog` with 2 `Adw.ShortcutsSection`s and 7
`Adw.ShortcutsItem`s: General — Show Help, Open Main Menu, Quit, Show Keyboard
Shortcuts, Show Preferences; Scanning — Scan Folder, Rescan Current Location.

## 5. `src/baobab-window.vala` (`on_about_activate`) → `lib/about_dialog.rb`

Kind: **dialog** (about). Present: **yes**. `Adw.AboutDialog`: application name
"Disk Usage Analyzer", icon `org.gnome.baobab`, developer name "The GNOME
Project", website `https://apps.gnome.org/Baobab/`, issue URL, GPL-2.0, the
6-entry developers list and the two copyright lines, `translator-credits`.

## 6. `src/baobab-location-list.vala` (`LocationList`) + `data/ui/baobab-location-list.ui` → `lib/location_list.rb`

The home page: devices and locations. Kind: **page**. Present: **yes**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesPage` (template root) | 1 | — | — | |
| `Adw.PreferencesGroup` | 2 | — | — | "This Device"; "Remote Locations" (`remote_group`, hidden when empty) |
| `Gtk.ListBox` `local_list_box`, `remote_list_box` | 2 | `boxed-list` | `row_activated` → `location_activated` | selection mode none |
| `LocationRow` | repeater | — | — | one per `Location`, split local/remote |

Behaviour: `Gio.VolumeMonitor` wired to all six mount/volume signals;
`populate` seeds home folder + main volume + volumes + mounts + up to
`MAX_RECENT_LOCATIONS = 5` recents from `Gtk.RecentManager` (group "baobab");
`add_location` writes a recent entry with mime `inode/directory`;
`clear_recent` backs `win.clear-recent`; a 2-second timeout re-queries
filesystem usage. Signal: `location_activated (Location)`.

## 7. `src/baobab-location-list.vala` (`LocationRow`) + `data/ui/baobab-location-row.ui` → `lib/location_row.rb`

One device or location row. Kind: **row**. Present: **yes**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` (template root) | 1 | — | — | |
| `Gtk.Box` | 1 | — | — | margins 6/6/12/6, spacing 6 |
| `Gtk.Grid` `grid` | 1 | — | — | column spacing 12 |
| `Gtk.Image` `image` | 1 | `symbolic-circular` | — | `location.symbolic_icon`, pixel size 16 |
| `Gtk.Image` | 1 | — | — | `go-next-symbolic`, width-request 32 |
| `Gtk.Label` `name_label` | 1 | — | — | markup `<b>name</b>`, ellipsize end |
| `Gtk.Label` `path_label` | 1 | `dim-label`, `subtitle` | — | parse name; ellipsize END when remote, START when local; hidden when no file |
| `Gtk.Label` `available_label` | 1 | — | — | "%s Available" / "%s Used" / "Unknown" / "Unmounted" — **error/empty states** |
| `Gtk.Label` `total_size_label` | 1 | `dim-label`, `subtitle` | — | "%s Total", hidden when size unknown |
| `Gtk.LevelBar` `usage_bar` | 1 | — | — | hidden by default; `LEVEL_BAR_OFFSET_LOW` offset at 90 % of size |

Conditional: the whole usage block only when `volume`, `mount` or
`is_main_volume`; recomputed on `location.changed`.

## 8. `src/baobab-location.vala` → `lib/location.rb`

Kind: **model**. Present: **yes**. `Location` with six constructors
(`for_home_folder`, `from_volume`, `from_mount`, `for_main_volume`,
`for_recent_info`, `for_file`), the `changed` and `progress` signals,
`update_volume_info`, `queue_query_fs_usage`, async `mount_volume`, and the
`Hostname` D-Bus interface proxy used to name the main volume.

## 9. `src/baobab-pathbar.vala` (`Pathbar`) + `data/ui/baobab-pathbar.ui` → `lib/pathbar.rb`

The breadcrumb in the results header bar. Kind: **widget**. Present: **yes**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (template root) | 1 | `pathbar` (applied at the use site in the window) | — | hexpand-set, overflow hidden |
| `Gtk.ScrolledWindow` | 1 | — | — | hscrollbar external, vscrollbar never |
| `Gtk.Adjustment` | 1 (type) | — | `changed` → `on_adjustment_changed`, `notify::page-size` → `on_page_size_changed` | 800 ms `Adw.TimedAnimation` + `Adw.PropertyAnimationTarget`, `EASE_OUT_CUBIC` |
| `Gtk.Box` `button_box` | 1 | — | — | rebuilt on every `path` set |
| `Gtk.Box` per segment | repeater | — | — | one per ancestor |
| `Gtk.Label` separator | repeater | `dim-label` | — | `/` between segments, skipped for the first |
| `PathButton` | repeater | — | `clicked` → `item_activated (path)` (not for the current dir) | |

Stylesheet classes on this unit: `.pathbar`, `.pathbar button`,
`.pathbar button.current-dir`, `.pathbar > scrolledwindow undershoot.left`
and `undershoot.right`.

## 10. `src/baobab-pathbar.vala` (`PathButton`) + `data/ui/baobab-pathbutton.ui` → `lib/path_button.rb`

Kind: **widget** (button). Present: **yes**. `Gtk.Button` root containing a
`Gtk.Box` (spacing 6), a `Gtk.Image` `icon` (hidden unless a gicon is given)
and a `Gtk.Label` `label`. CSS: `dim-label` on both icon and label when not the
current directory, `current-dir` on the button when it is. Min 7 chars (28 for
the current dir), `Pango.EllipsizeMode.MIDDLE` past 1.5× that; tooltip is the
full name.

## 11. `src/baobab-folder-display.vala` + `data/ui/baobab-folder-display.ui` → `lib/folder_display.rb`

The one-row summary header above the tree, carrying the column titles and
sorters. Kind: **widget**. Present: **yes**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` (template root) | 1 | — | — | |
| `Gtk.ColumnView` `columnview` | 1 | — | `activate` → `on_columnview_activate` → `activated` signal (go up); `notify::sorter` → re-notifies `sorter` | single-click-activate, not reorderable |
| `Gtk.NoSelection` + `Gtk.SortListModel` | 2 (type) | — | — | one-item `Gio.ListStore` of `Scanner.Results` |
| `Gtk.ColumnViewColumn` | 4 | — | — | "Folder" (expand), "Size", "Contents", "Modified" |
| `TreeListRowSorter` wrapping `Gtk.StringSorter` / `Gtk.NumericSorter` ×3 | 4 | — | — | on `display_name`, `size`, `elements`, `time_modified`; sort order bound to the column view's primary sort order |
| `Gtk.SignalListItemFactory` | 4 | — | `setup`/`bind`/`unbind`/`teardown` | `FolderCell`, `SizeCell`, `ContentsCell`, `TimeModifiedCell` |
| `Gtk.SizeGroup` ×4 | 4 (type) | — | — | `folder_`, `size_`, `contents_`, `time_modified_`; shared with the window's tree cells, and **the header title cells are added by poking at `GtkColumnViewRowWidget` / `GtkColumnViewTitle`** |

Default sort: `size_column`, descending. Stylesheet: `window.background stack >
grid > frame border` and `window.background stack > grid >
scrolledwindow.frame`.

## 12. `src/baobab-file-cell.vala` + `data/ui/baobab-file-cell.ui` → `lib/file_cell.rb`

Kind: **cell**. Present: **yes**. `Adw.Bin` holding a `Gtk.TreeExpander`
(`list-row` bound, `hide-expander` bound to `is-empty`) over a `Gtk.Box`
(`baobab-cell-box`) of a `ProgressCell` (fraction bound) and a `NameCell`.
Properties `item`, `list_row`.

## 13. `src/baobab-folder-cell.vala` + `data/ui/baobab-folder-cell.ui` → `lib/folder_cell.rb`

Kind: **cell**. Present: **yes**. `Adw.Bin` holding a `Gtk.Box`
(`baobab-cell-box`) of a `Gtk.Image` `pan-up-symbolic` (visible via the
`has_parent_cb` closure) and a `NameCell`.

## 14. `src/baobab-name-cell.vala` + `data/ui/baobab-name-cell.ui` → `lib/name_cell.rb`

Kind: **cell**. Present: **yes**. `Adw.Bin` over a `Gtk.Label` (ellipsize end,
halign start, single-line, xalign 0) bound to `display_name`. CSS applied
dynamically on `notify::item`: `baobab-cell-error` when the scan state is
`ERROR`, `baobab-cell-warning` when `CHILD_ERROR`, neither otherwise —
**error/warning states**.

## 15. `src/baobab-size-cell.vala` + `data/ui/baobab-size-cell.ui` → `lib/size_cell.rb`

Kind: **cell**. Present: **yes**. `Adw.Bin` over a `Gtk.Label` (`numeric`,
halign end, xalign 1) formatted by `format_size_cb` — empty string when the
item is null or errored.

## 16. `src/baobab-contents-cell.vala` + `data/ui/baobab-contents-cell.ui` → `lib/contents_cell.rb`

Kind: **cell**. Present: **yes**. Same shape; `format_items_cb` over `elements`,
empty when null, negative or errored.

## 17. `src/baobab-time-modified-cell.vala` + `data/ui/baobab-time-modified-cell.ui` → `lib/time_modified_cell.rb`

Kind: **cell**. Present: **yes**. `Adw.Bin` over a `Gtk.Label` (halign end,
xalign 1, no `numeric` class) formatted by `format_time_approximate_cb`.

## 18. `src/baobab-progress-cell.vala` → `lib/progress_cell.rb`

The in-cell usage bar. Kind: **custom widget**. Present: **yes**. A
`Gtk.Widget` subclass with CSS name `progresscell` and accessible role
`PROGRESS_BAR`, built from an `Adw.Bin` `trough`, an `Adw.Bin` `progress`, a
`Gtk.Label` and a second `Gtk.Label` with `in-progress` (clipped to the filled
fraction), laid out by overridden `measure`, `size_allocate` and `snapshot`.
Text is `"%6.2lf%%"`; accessible `VALUE_MIN/MAX/NOW/TEXT` updated with it.
Stylesheet: `progresscell`, `progresscell progress`, `progresscell trough`,
`progresscell label`, `progresscell label.in-progress`.

## 19. `src/baobab-cellrenderers.vala` → `lib/formatters.rb`

Kind: **helpers** (translated strings). Present: **yes**. `format_items`
(ngettext "%d item"/"%d items") and `format_time_approximate` ("Unknown",
"Today", "%lu day(s)", "%lu month(s)", "%lu year(s)").

## 20. `src/baobab-preferences-dialog.vala` (`PreferencesDialog`) + `data/ui/baobab-preferences-dialog.ui` → `lib/preferences_dialog.rb`

Kind: **dialog** (preferences). Present: **yes**.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` (template root) | 1 | — | — | title "Preferences", content-height 570 |
| `Adw.PreferencesPage` | 1 | — | — | |
| `Adw.PreferencesGroup` | 1 | — | — | "Locations to Ignore" |
| `Gtk.ListBox` `excluded_list_box` | 1 | `boxed-list` | `row_activated` → file chooser | selection mode none |
| `ExcludedRow` | repeater | — | `removed` → drops the URI, repopulates | one per `excluded-uris` entry |
| `Adw.ButtonRow` | 1 | — | — | "_Add Location", `list-add-symbolic`, use-underline — the only activatable row; **empty state is this row alone** |
| `Gtk.FileChooserNative` | 1 | — | `response` | "Select Location to Ignore", modal, SELECT_FOLDER |

Reads and writes `excluded-uris` on `org.gnome.baobab.preferences`.

## 21. `src/baobab-preferences-dialog.vala` (`ExcludedRow`) + `data/ui/baobab-excluded-row.ui` → `lib/excluded_row.rb`

Kind: **row**. Present: **yes**. `Adw.ActionRow` (not activatable) with title =
path for `file://` URIs, otherwise the URI, and a suffix `Gtk.Button`
`remove_button` (`flat`, `edit-delete-symbolic`, valign center, tooltip "Remove
Folder") whose `clicked` emits `removed`.

## 22. `data/ui/baobab-treeview-menu.ui` → `lib/treeview_menu.rb`

Kind: **menu** (context menu on the tree). Present: **yes**. One section, 3
items: "_Open Externally" (`win.treeview-open-folder`), "_Copy Path to
Clipboard" (`win.treeview-copy`), "Mo_ve to Trash" (`win.treeview-trash`).

## 23. `data/gtk/menus.ui` (`menu chartmenu`) → `lib/chart_menu.rb`

Kind: **menu** (context menu on the charts). Present: **yes**. Three sections,
6 items: "_Open Externally" (`chart.open-file`), "_Copy Path to Clipboard"
(`chart.copy-path`), "Mo_ve to Trash" (`chart.trash-file`) | "Go to _Parent
Folder" (`chart.move-up`) | "Zoom _In" (`chart.zoom-in`), "Zoom _Out"
(`chart.zoom-out`).

## 24. `src/baobab-chart.vala` → `lib/chart.rb`

The abstract chart base. Kind: **widget** (abstract). Present: **yes**.

| Facet | Upstream |
|---|---|
| Type | abstract `Gtk.DrawingArea`, `set_draw_func`, `MAX_DEPTH` 5 / `MIN_DEPTH` 1 |
| Child widget | `Gtk.PopoverMenu.from_model (chartmenu)`, parented to the chart, position bottom |
| Controllers | `Gtk.EventControllerScroll` (BOTH_AXES, zoom), `Gtk.EventControllerMotion` (`motion`, `enter`), `Gtk.GestureClick` ×3 — primary (activate item / move up at root), secondary (popover at pointer), middle (move up) |
| Actions | action group `chart`: `open-file`, `copy-path`, `trash-file`, `move-up`, `zoom-in`, `zoom-out`, each enabled/disabled before the popover opens |
| Signals | `item_activated (Scanner.Results)` |
| Other | 6 hard-coded colours `#e01b24 #ff7800 #f6d32d #33d17a #3584e4 #9141ac`; `query_tooltip` sets escaped markup and a tip area — **tooltip is part of the component**; `ChartItem` geometry base class |

## 25. `src/baobab-ringschart.vala` → `lib/rings_chart.rb`

Kind: **widget**. Present: **yes**. `Chart` subclass, CSS name `ringschart`,
`RingschartItem` (radii, angles, `continued`), subfolder tips drawn with the
`subfolder-tip` style class (stylesheet: `ringschart.subfolder-tip`), keyboard
zoom via `can_zoom_in`/`can_zoom_out`, redraws on `notify::max-depth`,
`notify::highlighted-item`, `notify::root`.

## 26. `src/baobab-treemap.vala` → `lib/treemap_chart.rb`

Kind: **widget**. Present: **yes**. `Chart` subclass, CSS name `treemap`,
`TreemapItem` with a Cairo rectangle, squarified layout, own hit test and zoom
predicates.

## 27. `src/baobab-scanner.vala` → `lib/scanner.rb`

Kind: **model**. Present: **yes**. `ScanFlags`, `Scanner` (async directory walk,
`total_size`, `total_elements`, `max_depth`, `show_allocated_size`,
`completed` signal, `scan`/`cancel`/`finish`, hard-link de-duplication) and
`Scanner.Results` (`display_name`, `size`, `time_modified`, `elements`,
`percent`, `fraction`, `is_empty`, `state` ∈ `{NONE, ERROR, CHILD_ERROR}`,
`children_list_store`, `create_tree_model`). Every cell above binds to this.

## 28. `src/baobab-tree-list-row-sorter.vala` → `lib/tree_list_row_sorter.rb`

Kind: **sorter**. Present: **yes**. `Gtk.Sorter` subclass that unwraps
`Gtk.TreeListRow`s and keeps parents above children, with `sorter` and
`sort_order` properties and an overridden `compare` / `get_order`.

## 29. `data/org.gnome.baobab.gschema.xml` → `lib/settings.rb`

Kind: **settings**. Present: **yes**. Three schemas:
`org.gnome.baobab` (children `preferences`, `ui`);
`org.gnome.baobab.preferences` — `excluded-uris` (`as`, default `[]`);
`org.gnome.baobab.ui` — `active-chart` (`s`, choices `rings`/`treemap`,
default `rings`), `window-size` (`(ii)`, default `(960, 600)`),
`is-maximized` (`b`, default false). The window delays and applies this
settings object and binds `is-maximized`.

## 30. `data/style.css` (+ `data/baobab.gresource.xml`) → `lib/style.rb`

Kind: **stylesheet**. Present: **yes**. 25 selectors; the classes the port must
apply are `baobab-cell-error`, `baobab-cell-warning`, `baobab-cell-box`,
`pathbar`, `current-dir`, `symbolic-circular`, `subfolder-tip`, `contents`,
`in-progress`, `numeric`, `boxed-list`, `dim-label`, `subtitle`,
`undershoot-top`, plus the CSS names `progresscell`, `ringschart`, `treemap`
and the `:drop(active) .contents` drop highlight. The GResource manifest also
ships `view-ringschart-symbolic.svg` and `view-treemap-symbolic.svg`, which the
chart switcher pages need.

## 31. `po/` (116 locales, `po/POTFILES.in`) → `lib/translations.rb`

Kind: **translations**. Present: **yes**. 17 files in `POTFILES.in`. Every
translatable string named above comes from this catalogue; it has its own
parity step (`translation-parity`) and is listed here only so no user-facing
string is unaccounted for.

---

## Not user-facing / no port file

- `src/config.vapi`, `src/meson.build`, `data/meson.build`, `po/meson.build`, `help/meson.build`, `meson.build` — build plumbing.
- `data/org.gnome.baobab.desktop.in`, `.metainfo.xml.in`, `.service.in`, `data/baobab.1`, icons — packaging, handled by the gem/flake, not `lib/`.
- `help/C/*.page` (8 Mallard pages) — user help; `win.help` opens `help:baobab`, which the port cannot ship as a Mallard document. Expect to point the action at the upstream help URL.

## Blockers

The eight blockers the first pass of this survey recorded have all been
resolved or consciously deviated from in the port. Re-probed in the fork's dev
shell (GTK 4.22.4, libadwaita 1.9.3, Ruby 3.4.9):

**Resolved**

1. **`ProgressCell`.** `Gtk::Widget#snapshot` is still absent from these
   bindings, so `lib/progress_cell.rb` (225 lines) does not subclass
   `Gtk::Widget`. It keeps the CSS names `progresscell`, `trough`, `progress`
   and the `in-progress` label class, which is what the stylesheet selects on.
2. **No GResource / `.ui` / GtkBuilder closures.** Every `<binding>` and
   `<closure>` is rebuilt as an explicit `notify::` handler or a formatter call
   in the cell files; all five cells plus `folder_display.rb` are in place.
3. **`GtkColumnView` internal-structure hacks.** Handled inside `window.rb`
   and `folder_display.rb` rather than by walking private types.
4. **GSettings schema.** Deviation: `lib/settings.rb` is a JSON-backed store
   keyed on upstream's three schemas' keys (`excluded-uris`, `active-chart`,
   `window-size`, `is-maximized`) instead of `Gio::Settings`, so the port needs
   no compiled schema on `GSETTINGS_SCHEMA_DIR`. Behaviourally equivalent for
   the app; not interoperable with an installed upstream baobab's settings.
5. **Charts.** Ported: `chart.rb` 588, `rings_chart.rb` 581,
   `treemap_chart.rb` 294 lines, with the chart action group, the three click
   gestures, the scroll zoom, the tooltips and the six hard-coded colours.
6. **`Gtk::ShortcutController`.** Deviation: the four tree shortcuts (`Menu`,
   `Right`, `Left`, `<Alt>Up`) are a `Gtk::EventControllerKey` `key-pressed`
   case statement in `window.rb` (around line 1081, commented as such) rather
   than a shortcut controller. Same bindings, same actions.

**Open**

7. **`Gtk::FileChooserNative` is still what both pickers use**
   (`lib/window.rb`, `lib/preferences_dialog.rb`). Deprecated since GTK 4.10.
   It works, and it is the only way to keep upstream's "Recursively analyze
   mount points" extra choice, which `Gtk::FileDialog` cannot express — so the
   deprecation is the price of that one parity point. Worth a decision, not a
   blocker.
8. **Help is not portable.** `win.help` is installed and dispatches to
   `show_help`; upstream's 8 Mallard pages are not shipped, so this points at
   the upstream help URL rather than `help:baobab`.
9. **Resolved, and re-verified with a much wider drive.** `test/gtk_driver.rb`
   and `test/drive_main_window.rb` exist and now exercise 30 checks (up from
   12), `DRIVE OK`, stable across repeated runs. Beyond the original scan /
   two-chart / preferences / about / shortcuts / rescan path, the drive now
   also: zooms the rings chart in and out (`chart.zoom-in`/`zoom-out`),
   reroots the treeview on a child directory and uses `chart.move-up` to
   return to the scan root, selects a tree row and exercises
   `win.treeview-expand-row`/`collapse-row`/`go-up` plus the real keyboard
   path (`Window#key_pressed` with `Left`, exactly as the key controller would
   call it), opens and closes the tree context popover
   (`win.show-treeview-popover`) and fires `win.treeview-copy`, fires
   `win.treeview-trash` and confirms a trash failure on this filesystem toasts
   rather than crashing, opens and closes the primary menu
   (`win.show-primary-menu`), fires `win.clear-recent`, adds an excluded
   location through `Settings` and confirms it renders in
   `PreferencesDialog#excluded_list_box`, then removes it by emitting the
   row's own `remove_button` `clicked` signal (driving the real
   `ExcludedRow#on_removed` wiring, not Settings directly) and confirms the
   list is back to its empty state, and calls `Window#scan_directory` on a
   plain file to confirm the "not a valid folder" toast path does not crash
   the window. `win.scan-folder`/`win.help` and the chart's
   `open-file`/`copy-path`/`trash-file` actions (which need a context-menu
   click to set `@popover_item`) are not driven: the former two open a real
   `Gtk::FileChooserNative` or hand off to `Gtk.show_uri`, and firing
   `open-file` would spawn a real external process via
   `Gio::AppInfo.launch_default_for_uri` with no sandboxing in this harness —
   the equivalent logic (`Window#open_item`/`#copy_path`/`#trash_file`) is
   exercised through the tree's own `win.treeview-copy`/`treeview-trash`
   instead. Driving it surfaced one real bug, now fixed: the gio2 bindings
   hand a string-typed action's `activate` signal a plain Ruby `String`, not
   the `GLib::Variant` upstream's Vala receives, so
   `Window#install_actions`'s `active-chart` handler crashed on
   `parameter.get_string` every time the chart switcher was used — fixed with
   a `chart_name` helper that only calls `get_string` when the parameter
   actually responds to it.

   `spec/formatters_spec.rb` and `spec/settings_spec.rb` cover the two
   non-widget components with no GTK dependency beyond `require 'adwaita'`'s
   GTK init (22 examples). Two real spec-harness bugs, now fixed, not binding
   gaps: `spec/spec_helper.rb` required `kettle/test/rspec` unconditionally,
   with none of the `rescue LoadError` tolerance the pilot port's
   `spec_helper.rb` has for exactly this gem not being present outside a full
   `bundle install`; and `lib/baobab/rb.rb` — the file the gem's own name
   resolves to, and the file `spec_helper.rb` requires by that name — never
   existed at all, only `lib/baobab.rb` (the real entry point) and
   `lib/baobab/rb/version.rb`. Both are fixed to match the pilot port's shape
   (`lib/tally/rb.rb`), and the documented spec command,
   `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'`, now
   runs as written, under `xvfb-run` (`require 'adwaita'` needs a display to
   init GTK even for string-only code, by the house convention that every
   file requires it): 22 examples, 0 failures.

   The remaining gap is screenshot-only: a dialog's or popover's render node
   is occasionally not yet realised on the tick its screenshot is taken,
   which `GtkDriver#shot` already treats as non-fatal and reports separately
   from the pass/fail checks — it does not affect any of the 30 checks.
10. **116 locales.** `lib/translations.rb` resolves strings against upstream's
    catalogues; coverage across the 116 `po/` files is the `translation-parity`
    step's business, not verified here.
11. **Resolved.** `Window < Adwaita::ApplicationWindow` presents correctly:
    the drive script above opens it, scans into it, switches its two charts
    and opens three dialogs from it, all confirmed by assertions and
    screenshots (`tmp/shots/`).
