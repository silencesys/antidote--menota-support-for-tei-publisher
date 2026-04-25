# Release notes

## v0.10.2 — 2026-04-25

First public release of **ANTIDOTE · Menota support for TEI Publisher**.

### What's included

- **`menota.odd`** — Processing-model rules for the full Menota namespace
  (`me:facs`, `me:dipl`, `me:norm`, `me:pal`, `me:punct`, `me:suppressed`)
  and overrides for `<choice>`, `<w>`, `<pc>`, `<ex>`, `<am>`, `<supplied>`,
  `<unclear>`, `<gap>`, `<add>`, `<del>`, `<seg>`, `<c>`, `<pb>`, `<lb>`,
  `<cb>`. The active level is selected at runtime via the `level` parameter
  (default: `dipl`). Styles are compiled into TEI Publisher's generated
  stylesheet via `<outputRendition>` blocks — no external CSS dependency.

- **`menota-document.html`** — Single-column viewer with a level switcher
  in the app-header. Pins `odd="menota"` on `<pb-document>` so no
  `?odd=` URL parameter is required.

- **`menota-document-grid.html`** — Multi-column side-by-side viewer.
  Opens with one column; readers can add more (one per available level).
  Also pins `odd="menota"` on `<pb-document>`.

- **`<menota-level-switcher>`** — Standalone Web Component
  (`resources/js/menota-level-switcher.js`) that can be embedded in any
  TEI Publisher template. Communicates via `pb-events`, mirrors state to
  the URL, and optionally auto-detects which levels are present in the
  loaded document.

- **`tools/menota-resolve-entities.py`** — Python 3 helper that resolves
  the external `%Menota_entities` entity reference eXist cannot fetch at
  parse time. Supports a local entity file for offline use.

- **Post-install script** — Detects all TEI Publisher apps on the eXist-db
  instance and copies the ODD, templates, JS component, and XQuery modules
  into each one. Also compiles `menota.odd` into XQuery transform modules
  automatically (equivalent to clicking *Recompile* in the ODD editor).

### Requirements

- eXist-db 5.x or 6.x
- TEI Publisher 9.0+ (developed against 9.1.1)
- `tei-publisher-lib` 4.0.0+
- Python 3.9+ (entity-resolver tool only)

### Known limitations

- The post-install script runs once at install time. TEI Publisher apps
  created **after** the package is installed will not receive the assets
  automatically. Reinstall the package, or run the manual XQuery snippet
  documented in `docs.md § Troubleshooting`.

- `menota.odd` extends TEI Publisher's built-in `teipublisher.odd`.
  Projects that use a heavily customised base ODD should import
  `menota.odd` into their own ODD instead of using it directly.
