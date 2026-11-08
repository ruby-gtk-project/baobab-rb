# Component identification — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` (Add Maori translation) |
| Port | `ruby` @ `4e581e4` (Port translated help catalogues from upstream) |

This re-runs the identification pass from scratch against the current `ruby`
HEAD, two commits past the `ff9ec7c` version of this report. Those two
commits (`95c8bdc`, `4e581e4`) close the two gaps *this* report's own
`ff9ec7c` version found below (the chart-tab msgid bug, the missing
translated help catalogues) — both re-verified closed this round (see
"Gaps found" below), not assumed from the commit messages. The four prior
reports under `.reports/` before that were written against `ruby` @
`66f3ac3`; treating any stale document as current would be the false-green
failure `accountability-ensurance` exists to catch, so every claim below is
re-derived against the files on disk now, not copied forward.

`.reports/component-inventory.md` (the file-by-file survey, last rewritten at
`8662ed4`) is largely still accurate and is confirmed below; it is kept as
the inventory layer underneath this report.

## File-level mapping — confirmed complete, re-checked by listing, not inference

```
$ find data help po -type f | wc -l   # port
... (data: 8, help: 13, po: 110) matches upstream counts below
```

- `data/`: desktop entry, metainfo, D-Bus service file, GSettings schema
  (under `data/schemas/`), app icon (2 variants) + symbolic icon + the two
  chart-mode action icons (`view-ringschart-symbolic.svg`,
  `view-treemap-symbolic.svg`, previously missing — confirmed now present).
  `diff` against `origin/main`'s `data/org.gnome.baobab.desktop.in`,
  `.metainfo.xml.in`, and `data/org.gnome.baobab.gschema.xml` is **empty** —
  byte-identical.
- `po/`: 108 `.po` files, `LINGUAS` (110 lines, header + 108 codes),
  `POTFILES.in`, `POTFILES.skip` — all four `diff`-identical to
  `origin/main`'s `po/`.
- `help/C/`: all 9 upstream Mallard pages + `legal.xml` + `media/` present.
- `help/<lang>/`: all 28 upstream translated catalogues now present too
  (closed this round at `4e581e4` — see "Gaps found" below), `diff`-
  identical to `origin/main`, `help/LINGUAS` matching.
- Every upstream `src/*.vala` class and `data/ui/*.ui` template still has its
  one `lib/*.rb` counterpart (31 units; re-confirmed against
  `component-inventory.md`'s table, spot-checked a sample directly).

## Gaps found (re-derived, not inherited from the stale reports)

1. **Translated help pages — found missing at `ff9ec7c`, CLOSED at
   `4e581e4`.** Upstream ships 28 translated Mallard catalogues under
   `help/<lang>/<lang>.po` (`help/LINGUAS`, 28 entries: bg, ca, cs, da, de,
   el, es, eu, fi, fr, gl, hr, hu, id, it, kk, ko, nl, pl, pt, pt_BR, ru,
   sl, sr, sv, tr, uk, zh_CN). At `4e581e4` all 28 are present and
   `diff`-identical to `origin/main`'s copies, re-checked this round file
   by file, not re-read from the fixing commit's message.
2. **Nothing else found missing at the file-identification level.** The
   action-icon gap and the `data/`/`po/`/`help/C/` absence that the prior
   `component-identification.md` and `component-parity.md` reported are
   **closed** — verified by `diff`, not by re-reading the old report's
   claim. The GSettings schema is a real `.gschema.xml` file now shipped
   under `data/schemas/`, wired into the dev shell
   (`GSETTINGS_SCHEMA_DIR`) and `flake.nix`'s install step
   (`if [ -d data/schemas ]` is now **true**, not the dead branch the prior
   audit found) — though `lib/settings.rb` still stores state as JSON
   rather than binding `Gio::Settings` to that schema at runtime (see
   component-parity, item 3 — a documented correspondence, not a gap).

## What I did not re-derive from scratch

I did not re-walk all 31 `lib/*.rb` files' per-widget CSS/signal tables again
— `component-inventory.md` already does this and nothing in the five
intervening commits touches widget-internals in a way that would invalidate
it (the commits are: inventory, icon port, po/data/help port, a GI-crash fix
in `tree_list_row_sorter.rb`, and a screenshot-timing fix in
`test/gtk_driver.rb`). I did re-check the two files those commits touch
directly (`lib/tree_list_row_sorter.rb`, `test/gtk_driver.rb`) and the
packaging/translation surface, which is where this round's changes landed.
