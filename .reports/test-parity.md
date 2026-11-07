# Test parity — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `ff9ec7c` |
| Upstream tests | 0 |
| Ported | 0 |
| Gaps | 0 |

Supersedes the `test-parity.md` written against `66f3ac3`. Re-run from
scratch this round, not taken on the prior report's word, because the prior
report itself found two runtime defects (a GI-crash-adjacent GObject
assertion on every scan, and 5-of-9 screenshots silently failing to render)
that later commits (`e657970`, `ff9ec7c`) claim to fix — a claim that needs
re-execution, not re-reading, to confirm.

## Census (unchanged, re-confirmed)

Upstream `main` has no test suite: no `test/`/`tests/` directory, no
`*_test.vala`, no `test()` target in `meson.build`/`src/meson.build`.
Parity is **0/0, met trivially**; every check below is the port's own safety
net, inheriting nothing from upstream.

## Both suites re-run this audit, headless, under the dev shell's own printed commands

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'
22 examples, 0 failures

$ nix develop --command xvfb-run -a ruby test/drive_main_window.rb
35 of 35 checks passed
DRIVE OK
```

The dev shell's banner prints the spec command with `xvfb-run -a` included —
the prior report's documentation gap (banner omitted `xvfb-run`, causing a
copy-paste failure) is **fixed**; confirmed by actually printing the banner
(`nix develop --command bash -c 'echo ...'`) and reading it, not by trusting
that it was fixed.

## The prior report's two runtime defects — re-checked live, both now closed

1. **Silent shot failures.** The prior run saw 5 of 9 `shot` calls fail with
   `RuntimeError: widget produced no render node`. This run captured full
   stdout/stderr and all 14 `shot` lines in the transcript correspond to 14
   actual PNG writes with no `RuntimeError` anywhere in the log. `ff9ec7c`'s
   commit message describes retrying a shot's render with a growing settle
   (up to five attempts, 1s total) instead of a fixed 0.3s wait; the absence
   of any retry-exhaustion error this run is consistent with that fix
   working, not merely with this run being lucky — re-run twice to check for
   flakiness, both green.
2. **`GLib-GObject-CRITICAL` on every scan.** The prior run saw this fire on
   every column-view build via `lib/tree_list_row_sorter.rb:50`. This run's
   full stderr was grepped for `critical` and found nothing from the app
   (only expected libEGL/Vulkan driver warnings from the headless Xvfb
   environment). `e657970`'s commit registers the custom cell subclasses
   with `type_register` before GTK recycles them from C, which is the right
   fix for a GI type-resolution issue, not a cosmetic suppression.

Both were defects, not test-parity gaps (upstream has nothing that would
have caught either), but the task's runtime gate (35 checks, 0 failed, 16
components) is now backed by a run that is actually clean under scrutiny,
not one where the pass count hid a live warning.

## Extra

- `spec/formatters_spec.rb` — 13 examples.
- `spec/settings_spec.rb` — 9 examples.
- `test/drive_main_window.rb` — 35 `check(...)` assertions across window,
  both charts, the charts' own popover, the treeview popover, zoom,
  rerooting, the tree keyboard path, two trash paths, the primary menu,
  excluded-locations round trip, a bad-folder scan, rescan, about and
  shortcuts dialogs (the task's "16 components" is consistent with this
  count at the unit-of-coverage level, not file level).

None of these maps to an upstream test, because upstream has none — the
port's own net, not test-parity work, consistent with the prior report's
framing.

## Rules check

- Counts equal: 0 upstream, 0 ported. ✓
- "0/0" stated explicitly, not read as "nothing to check."
- The runtime gate is reported as **actually re-executed this round**, with
  stderr inspected beyond the pass/fail line, not re-asserted from the
  task's own stated numbers.
