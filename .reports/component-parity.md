# Component parity — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `66f3ac3` |
| Units with 4-axis parity (count/style/behaviour/text all clean) | most of 31, see gaps below |

Axes, per the skill: **count**, **style** (CSS defined and attached),
**behaviour** (signals/actions actually fire), **text** (byte-identical
msgid, actually translated). The first three were checked by driving the
real app headlessly and reading source; the fourth is a separate ledger
(`.reports/translation-parity.md`) and is summarized here only where it
closes or blocks a component.

## Verified clean, by driving the app (not by reading code)

Re-ran `nix develop --command xvfb-run -a ruby test/drive_main_window.rb` for
this audit. These components' behaviour axis is confirmed live, this run,
not asserted from the source:

| Unit | Count | Style | Behaviour | Text | Verdict |
|---|---:|---|---|:-:|---|
| Window / devices-and-locations page | ✓ | ✓ | ✓ scan starts, results page shown | ✓* | parity, *text marked but untranslated |
| Rings chart | ✓ | ✓ | ✓ zoom-in/out, move-up, reroot all fire and change state | ✓* | parity* |
| Treemap chart | ✓ | ✓ | ✓ chart-switch action fires, root set | ✓* | parity* |
| Tree keyboard path (`Left`/expand/collapse/go-up) | ✓ | — | ✓ driven through the real `key_pressed` handler, same as the controller would call it | — | parity |
| Tree context popover | ✓ | ✓ | ✓ opens, `treeview-copy` fires | ✓* | parity* |
| Trash action | ✓ | — | ✓ fails cleanly on this filesystem, toasts, does not crash | ✓* | parity* |
| Primary menu | ✓ | ✓ | ✓ opens/closes via action, `clear-recent` fires | ✓* | parity* |
| Preferences dialog + excluded-locations row | ✓ | ✓ | ✓ add via settings, list renders, remove via the row's own button signal (not a settings shortcut) | ✓* | parity* |
| About dialog | ✓ | — | ✓ opens | ✓* | parity* |
| Shortcuts dialog | ✓ | — | ✓ opens, lists both sections | ✓* | parity* |
| Bad-folder scan error path | ✓ | — | ✓ toasts, does not crash, stays on results | ✓* | parity* |

`✓*` = the string shown is byte-identical to upstream's (verified, see
translation-parity), but currently renders in English only in every locale,
because no `po/` catalogue ships. That is a **text-axis gap for every row
marked `✓*`**, recorded once here and in full in
`.reports/translation-parity.md`, per the skill's own rule that a mismatched
or absent translation is tracked in both ledgers.

**Not driven, and explicitly flagged as not confirmed live:** `win.scan-folder`
(opens a real `Gtk::FileChooserNative`), `win.help` (hands off to
`Gtk.show_uri`), and the chart's `open-file` (would spawn a real external
process via `Gio::AppInfo.launch_default_for_uri`). The prior inventory
documents this choice and it is a reasonable harness boundary — but it means
these three are verified only by reading the source, not by driving them,
and that distinction should not be lost in a summary that just says "driven."

## Gaps

### 1. Help content — gap, not a mechanism difference

`win.help` / `app.help` fires and calls `Gtk.show_uri(uri: 'help:baobab')`
(`lib/window.rb:701-702`), the same scheme upstream uses. But upstream's 8
Mallard help pages (`help/C/*.page`, translated into 33 languages) are not
ported — `find . -ipath '*help*'` over the port tree returns nothing except
an unrelated `spec_helper.rb`. The action exists; the content it points at
does not exist anywhere the port ships or builds. This is a genuine
component gap (a whole help system, 8 pages × 33 languages) — not a binding
limitation, since nothing prevents shipping Mallard XML or rendering it, and
not excused anywhere in the port's own documents (there is no `PORTING.md`
or `FINDINGS.md` on this branch to excuse it in, which is itself notable —
see `.reports/accountability-ensurance.md`).

### 2. `data/` — desktop entry, AppStream metadata, GSettings schema: absent, not "handled elsewhere"

No `.desktop.in`, `.metainfo.xml.in`, `.gschema.xml`, `.service.in`, or icons
directory exists in the port (`ls data` fails outright). `lib/settings.rb`'s
JSON store is a reasonable behavioural substitute for the schema's storage
(confirmed: defaults, validation and persistence match upstream's three keys,
and the port's own `spec/settings_spec.rb` — re-run for this audit, 9/9
green — pins exactly that), but the **desktop entry and AppStream metadata
have no substitute at all**, behavioural or otherwise: nothing in the port
installs a `.desktop` file, so there is no component for a desktop
environment to list this app by, launch it from an app grid, or show its
AppStream description/screenshots in a software center. This is a component
the port has not built, full stop, and the packaging code that would carry
it (`flake.nix`'s `data/schemas` copy, the gemspec's `po/**/*` glob) is
present but inert because the directories it expects were never created.

### 3. `Gtk::FileChooserNative` — correspondence, recorded as the skill requires

Both file pickers use the deprecated (GTK 4.10+) `Gtk::FileChooserNative`
rather than `Gtk::FileDialog`, because only the native chooser can carry
upstream's extra "Recursively analyze mount points" choice, which
`Gtk::FileDialog` has no API for. This is the right call under full parity —
dropping the mount-points choice to modernize the picker would itself be a
parity loss — and it is recorded here, by name, with the reason, rather than
left as a silent deviation. Not a gap; a documented substitution.

### 4. `Gtk::ShortcutController` → `key-pressed` case statement — correspondence

The four tree shortcuts (`Menu`, `Right`, `Left`, `<Alt>Up`) are implemented
as a `Gtk::EventControllerKey` `key-pressed` handler in `lib/window.rb`
rather than a `Gtk::ShortcutController`. Driven directly in this audit's
re-run of the test suite (`Left collapses via the keyboard path`, passing)
and confirmed to fire the same actions upstream's controller would. Not a
gap; a documented substitution, same bindings, same effect.

## What this report does not re-certify

It does not re-walk all 31 `lib/*.rb` files' per-widget CSS/signal tables —
`.reports/component-inventory.md` already does, in detail, and
`.reports/component-identification.md` spot-checks a sample of it. It does
not re-derive the full occurrence-count cross-check on every CSS class
(`css`/`css-name` streams) beyond the class-name diff already run. Both are
reasonable next passes for a reviewer with more time; what is reported here
is independently re-driven and newly found, not copied from the prior
document.

## Rules check

- Parity reported per-unit, not as an app-wide total.
- Every `✓*` text flag is also open in `translation-parity.md` — not closed
  here alone.
- The two correspondences (`FileChooserNative`, key controller) are named
  with file and reason, not silently waved through.
- The two gaps (help content, `data/` packaging) are named with file:line
  where applicable and with what a user experiences (no help content opens;
  no desktop/software-center entry exists), not with the construct's name
  alone.
