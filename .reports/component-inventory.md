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

```
lib/baobab.rb              requires baobab/application
lib/baobab/application.rb  the scaffold stub: one Adw.ApplicationWindow,
                           one Adw.ToolbarView, one Adw.HeaderBar, one
                           Adw.StatusPage reading "The Ruby port has not
                           been written yet."
lib/baobab/rb/version.rb   gem version
```

**No user-facing component of baobab exists yet.** Every row below is a gap.
The stub's four widgets correspond to nothing upstream and are placeholders to
be replaced, not parity.

Totals: 21 upstream `.vala` files and 17 `.ui`/menu files carry user-facing
components, mapping to 31 `lib/*.rb` files. Upstream installs 6 app/window
accelerators, 21 actions across three action groups (`app.`, `win.`, `chart.`),
3 menu models, 4 `GtkColumnViewColumn`s with 4 cell factories each, 25 distinct
CSS classes in `data/style.css`, and 116 locales in `po/`.

---

## 1. `src/main.vala` + `src/baobab-application.vala` → `lib/application.rb`

The application object. Kind: **application**. Present: **no** (the stub at
`lib/baobab/application.rb` is unrelated placeholder content).

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
the results view. Kind: **window**. Present: **no**.

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

Kind: **menu**. Present: **no**. Two sections, 6 items: "Scan Folder…"
(`win.scan-folder`), "Clear Recent List" (`win.clear-recent`) | "Preferences"
(`win.show-preferences`), "Keyboard _Shortcuts" (`app.shortcuts`), "_Help"
(`win.help`), "_About Disk Usage Analyzer" (`win.about`).

## 4. `data/ui/shortcuts-dialog.ui` → `lib/shortcuts_dialog.rb`

Kind: **dialog** (keyboard shortcuts). Present: **no**. Standalone `.ui` with
no backing source file — `Adw.Application` loads it for `app.shortcuts`.
`Adw.ShortcutsDialog` with 2 `Adw.ShortcutsSection`s and 7
`Adw.ShortcutsItem`s: General — Show Help, Open Main Menu, Quit, Show Keyboard
Shortcuts, Show Preferences; Scanning — Scan Folder, Rescan Current Location.

## 5. `src/baobab-window.vala` (`on_about_activate`) → `lib/about_dialog.rb`

Kind: **dialog** (about). Present: **no**. `Adw.AboutDialog`: application name
"Disk Usage Analyzer", icon `org.gnome.baobab`, developer name "The GNOME
Project", website `https://apps.gnome.org/Baobab/`, issue URL, GPL-2.0, the
6-entry developers list and the two copyright lines, `translator-credits`.

## 6. `src/baobab-location-list.vala` (`LocationList`) + `data/ui/baobab-location-list.ui` → `lib/location_list.rb`

The home page: devices and locations. Kind: **page**. Present: **no**.

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

One device or location row. Kind: **row**. Present: **no**.

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

Kind: **model**. Present: **no**. `Location` with six constructors
(`for_home_folder`, `from_volume`, `from_mount`, `for_main_volume`,
`for_recent_info`, `for_file`), the `changed` and `progress` signals,
`update_volume_info`, `queue_query_fs_usage`, async `mount_volume`, and the
`Hostname` D-Bus interface proxy used to name the main volume.

## 9. `src/baobab-pathbar.vala` (`Pathbar`) + `data/ui/baobab-pathbar.ui` → `lib/pathbar.rb`

The breadcrumb in the results header bar. Kind: **widget**. Present: **no**.

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

Kind: **widget** (button). Present: **no**. `Gtk.Button` root containing a
`Gtk.Box` (spacing 6), a `Gtk.Image` `icon` (hidden unless a gicon is given)
and a `Gtk.Label` `label`. CSS: `dim-label` on both icon and label when not the
current directory, `current-dir` on the button when it is. Min 7 chars (28 for
the current dir), `Pango.EllipsizeMode.MIDDLE` past 1.5× that; tooltip is the
full name.

## 11. `src/baobab-folder-display.vala` + `data/ui/baobab-folder-display.ui` → `lib/folder_display.rb`

The one-row summary header above the tree, carrying the column titles and
sorters. Kind: **widget**. Present: **no**.

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

Kind: **cell**. Present: **no**. `Adw.Bin` holding a `Gtk.TreeExpander`
(`list-row` bound, `hide-expander` bound to `is-empty`) over a `Gtk.Box`
(`baobab-cell-box`) of a `ProgressCell` (fraction bound) and a `NameCell`.
Properties `item`, `list_row`.

## 13. `src/baobab-folder-cell.vala` + `data/ui/baobab-folder-cell.ui` → `lib/folder_cell.rb`

Kind: **cell**. Present: **no**. `Adw.Bin` holding a `Gtk.Box`
(`baobab-cell-box`) of a `Gtk.Image` `pan-up-symbolic` (visible via the
`has_parent_cb` closure) and a `NameCell`.

## 14. `src/baobab-name-cell.vala` + `data/ui/baobab-name-cell.ui` → `lib/name_cell.rb`

Kind: **cell**. Present: **no**. `Adw.Bin` over a `Gtk.Label` (ellipsize end,
halign start, single-line, xalign 0) bound to `display_name`. CSS applied
dynamically on `notify::item`: `baobab-cell-error` when the scan state is
`ERROR`, `baobab-cell-warning` when `CHILD_ERROR`, neither otherwise —
**error/warning states**.

## 15. `src/baobab-size-cell.vala` + `data/ui/baobab-size-cell.ui` → `lib/size_cell.rb`

Kind: **cell**. Present: **no**. `Adw.Bin` over a `Gtk.Label` (`numeric`,
halign end, xalign 1) formatted by `format_size_cb` — empty string when the
item is null or errored.

## 16. `src/baobab-contents-cell.vala` + `data/ui/baobab-contents-cell.ui` → `lib/contents_cell.rb`

Kind: **cell**. Present: **no**. Same shape; `format_items_cb` over `elements`,
empty when null, negative or errored.

## 17. `src/baobab-time-modified-cell.vala` + `data/ui/baobab-time-modified-cell.ui` → `lib/time_modified_cell.rb`

Kind: **cell**. Present: **no**. `Adw.Bin` over a `Gtk.Label` (halign end,
xalign 1, no `numeric` class) formatted by `format_time_approximate_cb`.

## 18. `src/baobab-progress-cell.vala` → `lib/progress_cell.rb`

The in-cell usage bar. Kind: **custom widget**. Present: **no**. A
`Gtk.Widget` subclass with CSS name `progresscell` and accessible role
`PROGRESS_BAR`, built from an `Adw.Bin` `trough`, an `Adw.Bin` `progress`, a
`Gtk.Label` and a second `Gtk.Label` with `in-progress` (clipped to the filled
fraction), laid out by overridden `measure`, `size_allocate` and `snapshot`.
Text is `"%6.2lf%%"`; accessible `VALUE_MIN/MAX/NOW/TEXT` updated with it.
Stylesheet: `progresscell`, `progresscell progress`, `progresscell trough`,
`progresscell label`, `progresscell label.in-progress`.

## 19. `src/baobab-cellrenderers.vala` → `lib/formatters.rb`

Kind: **helpers** (translated strings). Present: **no**. `format_items`
(ngettext "%d item"/"%d items") and `format_time_approximate` ("Unknown",
"Today", "%lu day(s)", "%lu month(s)", "%lu year(s)").

## 20. `src/baobab-preferences-dialog.vala` (`PreferencesDialog`) + `data/ui/baobab-preferences-dialog.ui` → `lib/preferences_dialog.rb`

Kind: **dialog** (preferences). Present: **no**.

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

Kind: **row**. Present: **no**. `Adw.ActionRow` (not activatable) with title =
path for `file://` URIs, otherwise the URI, and a suffix `Gtk.Button`
`remove_button` (`flat`, `edit-delete-symbolic`, valign center, tooltip "Remove
Folder") whose `clicked` emits `removed`.

## 22. `data/ui/baobab-treeview-menu.ui` → `lib/treeview_menu.rb`

Kind: **menu** (context menu on the tree). Present: **no**. One section, 3
items: "_Open Externally" (`win.treeview-open-folder`), "_Copy Path to
Clipboard" (`win.treeview-copy`), "Mo_ve to Trash" (`win.treeview-trash`).

## 23. `data/gtk/menus.ui` (`menu chartmenu`) → `lib/chart_menu.rb`

Kind: **menu** (context menu on the charts). Present: **no**. Three sections,
6 items: "_Open Externally" (`chart.open-file`), "_Copy Path to Clipboard"
(`chart.copy-path`), "Mo_ve to Trash" (`chart.trash-file`) | "Go to _Parent
Folder" (`chart.move-up`) | "Zoom _In" (`chart.zoom-in`), "Zoom _Out"
(`chart.zoom-out`).

## 24. `src/baobab-chart.vala` → `lib/chart.rb`

The abstract chart base. Kind: **widget** (abstract). Present: **no**.

| Facet | Upstream |
|---|---|
| Type | abstract `Gtk.DrawingArea`, `set_draw_func`, `MAX_DEPTH` 5 / `MIN_DEPTH` 1 |
| Child widget | `Gtk.PopoverMenu.from_model (chartmenu)`, parented to the chart, position bottom |
| Controllers | `Gtk.EventControllerScroll` (BOTH_AXES, zoom), `Gtk.EventControllerMotion` (`motion`, `enter`), `Gtk.GestureClick` ×3 — primary (activate item / move up at root), secondary (popover at pointer), middle (move up) |
| Actions | action group `chart`: `open-file`, `copy-path`, `trash-file`, `move-up`, `zoom-in`, `zoom-out`, each enabled/disabled before the popover opens |
| Signals | `item_activated (Scanner.Results)` |
| Other | 6 hard-coded colours `#e01b24 #ff7800 #f6d32d #33d17a #3584e4 #9141ac`; `query_tooltip` sets escaped markup and a tip area — **tooltip is part of the component**; `ChartItem` geometry base class |

## 25. `src/baobab-ringschart.vala` → `lib/rings_chart.rb`

Kind: **widget**. Present: **no**. `Chart` subclass, CSS name `ringschart`,
`RingschartItem` (radii, angles, `continued`), subfolder tips drawn with the
`subfolder-tip` style class (stylesheet: `ringschart.subfolder-tip`), keyboard
zoom via `can_zoom_in`/`can_zoom_out`, redraws on `notify::max-depth`,
`notify::highlighted-item`, `notify::root`.

## 26. `src/baobab-treemap.vala` → `lib/treemap_chart.rb`

Kind: **widget**. Present: **no**. `Chart` subclass, CSS name `treemap`,
`TreemapItem` with a Cairo rectangle, squarified layout, own hit test and zoom
predicates.

## 27. `src/baobab-scanner.vala` → `lib/scanner.rb`

Kind: **model**. Present: **no**. `ScanFlags`, `Scanner` (async directory walk,
`total_size`, `total_elements`, `max_depth`, `show_allocated_size`,
`completed` signal, `scan`/`cancel`/`finish`, hard-link de-duplication) and
`Scanner.Results` (`display_name`, `size`, `time_modified`, `elements`,
`percent`, `fraction`, `is_empty`, `state` ∈ `{NONE, ERROR, CHILD_ERROR}`,
`children_list_store`, `create_tree_model`). Every cell above binds to this.

## 28. `src/baobab-tree-list-row-sorter.vala` → `lib/tree_list_row_sorter.rb`

Kind: **sorter**. Present: **no**. `Gtk.Sorter` subclass that unwraps
`Gtk.TreeListRow`s and keeps parents above children, with `sorter` and
`sort_order` properties and an overridden `compare` / `get_order`.

## 29. `data/org.gnome.baobab.gschema.xml` → `lib/settings.rb`

Kind: **settings**. Present: **no**. Three schemas:
`org.gnome.baobab` (children `preferences`, `ui`);
`org.gnome.baobab.preferences` — `excluded-uris` (`as`, default `[]`);
`org.gnome.baobab.ui` — `active-chart` (`s`, choices `rings`/`treemap`,
default `rings`), `window-size` (`(ii)`, default `(960, 600)`),
`is-maximized` (`b`, default false). The window delays and applies this
settings object and binds `is-maximized`.

## 30. `data/style.css` (+ `data/baobab.gresource.xml`) → `lib/style.rb`

Kind: **stylesheet**. Present: **no**. 25 selectors; the classes the port must
apply are `baobab-cell-error`, `baobab-cell-warning`, `baobab-cell-box`,
`pathbar`, `current-dir`, `symbolic-circular`, `subfolder-tip`, `contents`,
`in-progress`, `numeric`, `boxed-list`, `dim-label`, `subtitle`,
`undershoot-top`, plus the CSS names `progresscell`, `ringschart`, `treemap`
and the `:drop(active) .contents` drop highlight. The GResource manifest also
ships `view-ringschart-symbolic.svg` and `view-treemap-symbolic.svg`, which the
chart switcher pages need.

## 31. `po/` (116 locales, `po/POTFILES.in`) → `lib/translations.rb`

Kind: **translations**. Present: **no**. 17 files in `POTFILES.in`. Every
translatable string named above comes from this catalogue; it has its own
parity step (`translation-parity`) and is listed here only so no user-facing
string is unaccounted for.

---

## Not user-facing / no port file

- `src/config.vapi`, `src/meson.build`, `data/meson.build`, `po/meson.build`, `help/meson.build`, `meson.build` — build plumbing.
- `data/org.gnome.baobab.desktop.in`, `.metainfo.xml.in`, `.service.in`, `data/baobab.1`, icons — packaging, handled by the gem/flake, not `lib/`.
- `help/C/*.page` (8 Mallard pages) — user help; `win.help` opens `help:baobab`, which the port cannot ship as a Mallard document. Expect to point the action at the upstream help URL.

## Blockers

Probed in the fork's dev shell (`nix develop`, GTK 4.22.4, libadwaita 1.9.3,
Ruby 3.4.9). Everything the port needs exists as a constant — `Adwaita::`
`ButtonRow`, `ShortcutsDialog`, `ShortcutsSection`, `ShortcutsItem`, `Spinner`,
`Banner`, `ToastOverlay`, `NavigationView`, `OverlaySplitView`,
`BreakpointBin`, `ViewSwitcher`, `PreferencesDialog`, `AboutDialog`,
`TimedAnimation`, `PropertyAnimationTarget`; `Gtk::` `ColumnView`,
`ColumnViewCell`, `ColumnViewColumn`, `TreeExpander`, `TreeListModel`,
`TreeListRow`, `SignalListItemFactory`, `StringSorter`, `NumericSorter`,
`CustomSorter`, `PropertyExpression`, `PopoverMenu`, `DropTarget`,
`ShortcutController`, `LevelBar`, `FileChooserNative`, `FileDialog`,
`DrawingArea#set_draw_func`; `Gio::` `Settings`, `SimpleActionGroup`, `Menu`,
`ListStore`, `VolumeMonitor`; `Gtk::RecentManager`. What remains:

1. **`ProgressCell` cannot be ported as written.** `Gtk::Widget` in these
   bindings exposes `measure` and `size_allocate` but **not `snapshot`**
   (`Gtk::Widget.method_defined?(:snapshot) == false`), and upstream's cell
   relies on overriding `snapshot` to clip the `in-progress` label to the
   filled fraction. It needs a different construction — a `Gtk::DrawingArea`
   with a draw func, or a `Gtk::Overlay` over a trough/progress pair — and a
   decision on how faithfully to keep the CSS names `progresscell`,
   `trough`, `progress`.
2. **No GResource, no `.ui`, no GtkBuilder bindings/closures.** Nine upstream
   `.ui` files carry their behaviour as `<binding>`/`<closure>` expressions
   (every cell's label, `has_parent_cb`, `format_size_cb`, the sorters' sort
   order). The port rebuilds these as explicit `notify::` handlers or
   `Gtk::PropertyExpression`s; the cells are where that is most work.
3. **Two `GtkColumnView` internal-structure hacks.** Hiding the tree's header
   row and adding the header title cells to the size groups both walk children
   looking for the private types `GtkColumnViewRowWidget` and
   `GtkColumnViewTitle`. `GLib::Type.from_name` is reachable from Ruby, so
   this is portable in principle, but it is unverified and the alignment
   between the summary row and the tree depends on it.
4. **GSettings needs a compiled schema.** `Gio::Settings.new` aborts when the
   schema is not installed. The port has to ship and compile its own
   `gschema.xml` (under its own id) and put it on `GSETTINGS_SCHEMA_DIR` in
   the dev shell, or wrap settings behind an in-memory fallback.
5. **`Gtk::FileChooserNative` is deprecated in GTK 4.10+.** Both file pickers
   (scan a folder, exclude a location) should use `Gtk::FileDialog`, which
   changes the "Recursively analyze mount points" extra choice — `FileDialog`
   has no `add_choice`, so that option needs rehousing (a check button in the
   primary menu or a preference).
6. **The charts are ~1,200 lines of Cairo geometry.** `chart.vala` +
   `ringschart.vala` + `treemap.vala` carry the hit testing, the subfolder
   tips, the zoom and the tooltips. They are portable via `set_draw_func` but
   are the single largest unit in the port and should be planned as their own
   phase.
7. **Help is not portable.** `win.help` opens `help:baobab` from 8 Mallard
   pages the port does not ship; needs a decision (external URL vs. omitting).
8. **116 locales.** Parity on translations is a separate step; the inventory
   records which strings are translatable so nothing is missed.
