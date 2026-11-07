# Test parity — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `66f3ac3` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |
| Test command | `nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'` |

## Census

Upstream `main` has no test suite: `git ls-tree -r origin/main` lists no
`test/`, `tests/`, `*_test.vala` or `*test*.c`; `meson.build` and
`src/meson.build` declare no `test()` target; `test-census.sh` against the
upstream worktree returns **0 rows**. Verified directly, not inferred from
absence of a directory name.

Parity is **0/0, met trivially**. The port therefore inherits no safety net
from upstream — every check below was written for the port and pins nothing
upstream itself considered worth pinning down.

## Running the port's own suite — verified, not assumed

Both of the port's harnesses were actually executed in this audit, headless,
under `nix develop --command xvfb-run -a ruby …`, not read as code and taken
on faith:

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'
22 examples, 0 failures

$ nix develop --command xvfb-run -a ruby test/drive_main_window.rb
30 of 30 checks passed
DRIVE OK
```

**One real gap in the documentation, not the suite.** The dev shell's own
printed banner gives the spec command as plain `ruby -e '...'`, with no
`xvfb-run`. Run exactly as banner-printed, it fails before a single example
runs:

```
Gtk::InitError: failed to initialize GTK
```

because `spec/formatters_spec.rb` requires `lib/formatters.rb`, which
requires `adwaita`, which needs a display to initialize GTK even for a module
with no widgets in it — the same constraint `test/drive_*.rb` states for
itself in its own header comment, just not carried over to the banner that
prints the spec command. Anyone who copy-pastes the banner's own suggested
command gets a false failure. This is a one-line fix to `flake.nix`'s
`shellHook`, and it is reported here because the task's instruction to treat
an unexecuted claim as a gap cuts both ways: the previously-written
`.reports/component-inventory.md` states "the documented spec command … now
runs as written" (line ~519) — true only once `xvfb-run` is prepended by
hand, which is not what "as written" says. Fixed by running it under
`xvfb-run`, as shown above; the banner text itself is still wrong on disk as
of this audit.

**The drive's 30/30 is real but narrower than it reads.** The checks
themselves all pass, and the harness also attempts to capture a PNG after
nine of its steps. Six of those nine screenshot attempts fail with
`RuntimeError: widget produced no render node (not realised yet?)` —
`08-chart-rooted-on-child`, `09-treeview-popover`, `10-after-trash-attempt`,
`11-primary-menu`, `05-about` all failed this run. `GtkDriver` does not count
a failed `shot` against the 30, so `30 of 30 checks passed` and `DRIVE OK` are
both literally true while five of nine screenshots silently did not render —
a render-timing problem in the offscreen Xvfb path, not a logic bug the
`check` calls would catch, but it means the visual state of the primary menu,
the tree popover, the rooted chart, the after-trash toast and the about
dialog is **not actually confirmed to render** by this run, only that the
underlying widget state is correct. Treat "DRIVE OK" as a claim about the 30
named assertions, not about the screenshots; re-run to see if it is this
run's flake or a standing timing gap before relying on the shots for a visual
review.

A second, unrelated runtime symptom surfaced on every run: constructing
`TreeListRowSorter`'s `Gtk::StringSorter`/`Gtk::NumericSorter` (via
`lib/tree_list_row_sorter.rb:50` → `lib/folder_display.rb`) throws a
`GLib-GObject-CRITICAL: g_object_ref: assertion 'G_IS_OBJECT (object)'
failed` on every column-view build — once per scan in this run — with a full
Ruby backtrace printed to stderr. GLib criticals are non-fatal by default, so
the drive and specs both still pass, but a check that only reads exit status
and the `checks passed` line would not notice an app that is logging a GObject
assertion failure on every folder scan. Recorded here as a found defect; not
a test-parity gap in itself (upstream has no test that would catch it either),
but it is exactly the kind of thing a "0 failed" runtime gate hides when the
only thing counted is explicit `check(...)` calls.

## Extra

- `spec/formatters_spec.rb` — 13 examples on `Formatters.format_size`,
  `.format_items`, `.format_timestamp`, `.escape_markup`.
- `spec/settings_spec.rb` — 9 examples on `Settings`'s JSON-backed defaults,
  validation, persistence and corrupt-file recovery.
- `test/drive_main_window.rb` — 30 `check(...)` assertions driving the real
  application through a scan, both charts, zoom, rerooting, the tree
  keyboard path, the context menu, a failed trash, the primary menu, the
  excluded-locations round trip in preferences, a bad-folder scan, and the
  about/shortcuts dialogs.

None of these 52 checks maps to an upstream test, because upstream has none.
They are the port's own safety net, and they are real — both suites were
re-run for this audit, not taken on the previous report's word — but they are
not test-parity work and are not counted toward it, per the skill's own rule
that parity is a floor owed to upstream, never a ceiling on what the port may
additionally test.

## Rules check

- Counts equal: 0 upstream, 0 ported. ✓
- No row left without a state: there are no rows (0/0 degenerate case),
  stated per the skill's own guidance for this case rather than built as an
  empty table.
- "0/0" is not silently read as "nothing to check" — the finding that the
  port inherits no upstream safety net is stated explicitly above, as the
  skill requires.
