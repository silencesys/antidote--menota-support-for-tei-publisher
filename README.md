# ANTIDOTE ・ MENOTA support for TEI Publisher

A TEI Publisher 9 extension that adds rendering support for manuscripts
encoded according to the [MENOTA](https://menota.org) guidelines.

Developed by [Martin Roček](https://martin.rocek.dev) for the
[Antidote](https://antidote.hi.is) project at the University of Iceland.

> **Not affiliated with MENOTA.** This package is an independent library
> built to make MENOTA-encoded sources easier to publish through TEI
> Publisher. It is not produced, endorsed by, or maintained by the
> MENOTA project itself.

## What it does

MENOTA-encoded texts use the `me:*` namespace (`me:facs`, `me:dipl`,
`me:norm`, `me:pal`) inside `<w>` to represent up to four parallel
transcription levels of the same word. TEI Publisher's stock ODD has no
rules for these elements, so multi-level documents render as a
concatenation of every level.

This package ships:

- `menota.odd` &mdash; processing-model rules for `me:facs`, `me:dipl`,
  `me:norm`, `me:pal`, plus overrides for `<choice>`, `<w>`, `<pc>`,
  `<ex>`, `<am>`, `<pb>`, `<lb>`, `<cb>`, `<seg type="lig">`, `<c>`.
- `menota-document.html` &mdash; a single-column viewer with a level
  switcher in the header.
- `menota-document-grid.html` &mdash; a multi-column viewer for
  side-by-side comparison of two or more levels.
- `<menota-level-switcher>` &mdash; a custom element you can drop into
  your own templates.
- `tools/menota-resolve-entities.py` &mdash; a pre-processing helper
  that inlines the external entity references MENOTA files rely on,
  so eXist can parse them at upload.

## Requirements

- eXist-db 5.x or 6.x
- TEI Publisher 9.0 or higher (developed against 9.1.1)
- `tei-publisher-lib` 4.0.0 or higher
- Python 3.9+ for the entity-resolver tool

## Installation

Open the eXist-db **Package Manager**, click **Add Package** and upload
`antidote-menota-publisher-<version>.xar`.

The post-install script auto-detects every TEI Publisher app on the
instance and copies in:

- `odd/menota.odd`
- `templates/pages/menota-document.html`
- `templates/pages/menota-document-grid.html`
- `templates/snippets/level-switcher.html`
- `resources/js/menota-level-switcher.js`
- `modules/get-levels.xql`
- `modules/lib/api/compile-menota-odd.xql`

It then compiles `menota.odd` into XQuery transform modules in the
host app's `transform/` collection (the same step you'd otherwise
trigger via *Recompile* in the ODD editor).

## Pre-processing MENOTA files

MENOTA documents reference an external entity table:

```xml
<!ENTITY % Menota_entities SYSTEM 'https://www.menota.org/menota-entities.txt'>
```

eXist won't fetch this at parse time. Run the bundled resolver before
uploading:

```sh
python3 tools/menota-resolve-entities.py input.xml -o input-resolved.xml
```

For files using less common entities, supply the full upstream list:

```sh
curl -o full-entities.txt https://www.menota.org/menota-entities.txt
python3 tools/menota-resolve-entities.py input.xml -o input-resolved.xml \
    --entities full-entities.txt
```

## Usage

### Bundled templates

After installation, open a MENOTA document via:

```
/exist/apps/<your-tei-app>/<doc-path>?template=menota-document.html
```

or, for side-by-side comparison:

```
/exist/apps/<your-tei-app>/<doc-path>?template=menota-document-grid.html
```

The single-column template carries a level switcher in the header. The
grid template starts with one column and lets the reader add more (one
per available level).

### Embedding the switcher in your own template

Include the script and the element wherever you need them:

```html
<script type="module" src="resources/js/menota-level-switcher.js"></script>

<menota-level-switcher channel="transcription" value="dipl"></menota-level-switcher>
```

Pair it with a `<pb-view>` that subscribes to the same channel and
declares an initial level:

```html
<pb-view src="document1" subscribe="transcription" emit="transcription">
    <pb-param name="level" value="dipl"/>
</pb-view>
```

Attributes (all optional):

| Attribute            | Default          | Notes                                   |
|----------------------|------------------|-----------------------------------------|
| `channel`            | `transcription`  | pb-events channel to drive              |
| `value`              | `dipl`           | initial level                           |
| `label`              | `MENOTA level:`  | pass `label=""` to hide                 |
| `update-url`         | `true`           | mirrors the choice into `?level=`       |
| `populate-available` | `true`           | filters to levels actually in the doc   |

### Levels

| Parameter | Element     | Description |
|-----------|-------------|-------------|
| `facs`    | `<me:facs>` | Letter-by-letter, palaeographic detail, abbreviations unexpanded |
| `dipl`    | `<me:dipl>` | Expanded abbreviations, reduced palaeographic detail (default) |
| `norm`    | `<me:norm>` | Standardised orthography |
| `pal`     | `<me:pal>`  | Highly detailed palaeographic level (rare) |

If a `<w>` has no child for the requested level, that word renders
nothing at that level. Override in your project ODD if you need
different behaviour.

## Building the .xar

```sh
./build.sh
```

The script reads the version from `expath-pkg.xml` and produces
`antidote-menota-publisher-<version>.xar`.

## Licence

MIT &mdash; see [LICENSE](LICENSE).
