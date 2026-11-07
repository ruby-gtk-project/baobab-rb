# Translation parity — baobab

| | |
|---|---|
| Upstream | `main` @ `8c68f9b` |
| Port | `ruby` @ `66f3ac3` |
| Domain | `baobab` |
| Upstream messages | 79 |
| Ported (keys reaching a shipped catalogue) | **0** |
| Gaps | 79 |
| Extra (untranslated) | 0 |
| Upstream occurrences | 93 across 79 messages (12 reused) |
| Port occurrences (marked call sites, any kind) | ~40, see "Marking" below |
| Upstream languages | 108 `.po` files, 7,491 translated, 1,033 untranslated, 500 fuzzy |
| Languages shipped by the port | **0 of 108** |
| Build command | none — there is no `po/` directory to build |

## Headline finding: the catalogue is not shipped at all

`lib/translations.rb` is a real, working piece of infrastructure — it reads
`.po` files directly (no gettext dependency available to the Ruby bindings),
keys them by `msgid` with `\u0004`-joined `msgctxt`, and resolves
`LC_ALL`/`LC_MESSAGES`/`LANG` to the right file. Its own doc comment says:

> "The catalogue directory defaults to a `po` directory beside this
> checkout, so dropping upstream's `po/` in place localises the port with no
> further wiring."

That `po/` directory was never dropped in place. Verified directly:

```
$ find . -not -path './.git/*' -iname '*.po' -o -iname LINGUAS -o -iname 'POTFILES*'
(nothing)
$ ls po
ls: cannot access 'po': No such file or directory
```

There is no `po/`, no `LINGUAS`, no `POTFILES.in`, anywhere in the port. So
`Translations.catalogue_directory` resolves to a path that does not exist,
`load_catalogue` finds no file for any locale, and every call falls back to
the English `msgid` — which is exactly what gettext does with no catalogue,
and exactly the regression the `translation-parity` skill names by name:

> "Shipping without them is a regression the port introduced, not a feature
> it has not reached."

This is not a partial gap or a rewording problem. It is **0 of 108 languages,
0 of 7,491 translated strings**, carried over from an upstream project that
ships all of them today, in the same repository, on the branch one `git show`
away.

The port's own `baobab-rb.gemspec` (line 81) already globs
`File.join(gemspec_root, "po/**/*")` for packaging, and `flake.nix` already
has a conditional branch (`optionalDirs`, includes `"po"`) that copies a
`po/` directory into the Nix derivation *if one exists*. Both are dead code
today — they were written for a directory nobody ever added.

## Marking is mostly real, which makes the catalogue's absence worse, not better

The port does **not** use the standard gettext marker names (`_`, `N_`,
`ngettext`, …) that `translation-parity`'s scanner looks for — it defines its
own `Translations.gettext` / `.pgettext` / `.nplural`. That is a legitimate
correspondence under the skill's own rule ("a message may be *produced*
differently in Ruby… n_() instead of ngettext()… that is fine and still
`ported`, because the key that reaches the catalogue is the same"), and it is
exactly why the automated scan this skill specifies
(`catalogue.rb . --role port`) reports **0 messages, 2 unresolved** — a false
reading, caused by a marker name the shared scanner script does not know, not
by an absence of strings. Per the skill's own escalation order ("fix the
scanner… if it cannot be fixed generally, census by hand and say so"), I
censused by hand rather than editing the shared script for one fork.

Hand census: `grep -rn 'Translations\.\(gettext\|pgettext\)' lib/*.rb` finds
roughly 40 call sites across `lib/about_dialog.rb`, `lib/application.rb`,
`lib/chart_menu.rb`, `lib/excluded_row.rb`, `lib/folder_display.rb`,
`lib/location.rb`, `lib/location_list.rb`, `lib/location_row.rb`,
`lib/formatters.rb`, `lib/primary_menu.rb`, `lib/shortcuts_dialog.rb`,
`lib/window.rb`. Spot-checked a dozen against upstream's `_()`/`ngettext()`
call sites and every one is **byte-identical**: `"Disk Usage Analyzer"`,
`"Home Folder"`, `"Computer"`, `"This Device"`, `"Remote Locations"`,
`"%s Total"`, `"%s Available"`, `"%s Used"`, `"Unmounted"`, `"Unknown"`,
`"Today"`, `"%d item"/"%d items"`, `"The GNOME Project"`,
`"translator-credits"` all match upstream's `src/*.vala` and
`data/ui/*.ui` sources exactly, no rewording found in the sample.

So the English is faithful where it is marked, and the marking plumbing
works (it falls back to the msgid with no catalogue present, by design) — but
every one of those correct keys currently resolves to itself, because there
is nothing behind it. A translator opening this repository today has no file
to translate. The careful byte-matching work is real but currently invisible
to every one of baobab's 108 language communities.

**I could not run the automated message-count cross-check this skill
specifies** (`catalogue.rb --compare`) meaningfully, because the port side
comes back empty from the shared scanner regardless of what is marked — see
above. Treat the ~40-call-site figure as a hand count, not a machine-verified
one; a full by-hand census against all 79 upstream messages (closing the
remaining ones not yet checked for call-site coverage, e.g. the preferences
dialog strings, the four `FileChooserNative` filter labels, the CLI
`--help`/`--version` strings) is unrun and is itself an open item.

## What else is missing and feeds this gap

`data/org.gnome.baobab.desktop.in`, `.metainfo.xml.in` and
`.gschema.xml` do not exist anywhere in the port (confirmed: `ls data` fails,
`find . -iname '*.desktop*' -o -iname '*.metainfo*' -o -iname '*.gschema*'`
returns nothing). Those three files alone carry several of upstream's 79
messages (the app name, summary, screenshot captions, and the three GSettings
schema key descriptions). This is simultaneously a component-parity finding
— there is no desktop entry, no AppStream metadata, and `lib/settings.rb` is
a JSON store rather than a compiled `Gio::Settings` schema — and a
translation-parity one: those messages have no file in the port to be marked
in at all, so they cannot reach `ported` until the component exists.
`.reports/component-inventory.md` calls this "packaging, handled by the
gem/flake, not `lib/`" (line 426); it is not handled by either — `flake.nix`'s
own schema-copy step is wrapped in `if [ -d data/schemas ]`, which is false
today, so it is a no-op, not a mechanism that papers over the missing files.

## Rules check

- Key sets equal: **false**. 0 of 79 upstream keys reach any shipped
  catalogue (none is shipped).
- Byte-identical: true for every sampled key; unverified for the remainder
  (named above) — reported as unrun, not as passed.
- Languages ship: **false**, 0 of 108.
- `summary.parity` from the generated scan reads `false` (0 messages) for a
  reason that is partly a scanner limitation and partly real — both are
  stated above rather than collapsed into one number.
- Nothing here is reported as a check that passed without being run: the
  hand census is marked as a hand census, and the full 79-message
  cross-check is marked unrun.
