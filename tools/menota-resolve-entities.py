#!/usr/bin/env python3
"""
menota-resolve-entities.py

Preprocess a MENOTA-encoded TEI file for upload to TEI Publisher.

Why this exists
---------------
MENOTA files reference an external DTD entity file:

    <!ENTITY % Menota_entities SYSTEM 'https://www.menota.org/menota-entities.txt'>
    %Menota_entities;

eXist-db (and most XML parsers in safe-by-default mode) will not fetch
external entities at parse time, so the file fails to load with errors
like "undefined entity &aenl;". This script resolves those entities
inline so the resulting file parses cleanly anywhere.

Usage
-----
    # Resolve entities, write to a new file:
    python3 menota-resolve-entities.py input.xml -o output.xml

    # Resolve in place (overwrites the input):
    python3 menota-resolve-entities.py input.xml --in-place

    # Use a local copy of the entity file instead of fetching:
    python3 menota-resolve-entities.py input.xml -o output.xml \\
        --entities /path/to/menota-entities.txt

The script fetches https://www.menota.org/menota-entities.txt the first
time it runs and caches the parsed table in memory. Pass --entities to
use an offline copy.

What it preserves
-----------------
- All TEI/MENOTA markup, attributes, and whitespace.
- All Unicode characters in element/attribute content - the entity
  expansion only replaces &name; references, not character data.
- The DOCTYPE block is removed (it points to an external entity file
  that's no longer needed). The xml-model and oxygen processing
  instructions, the xml declaration, and the TEI root with all its
  namespaces are preserved.

What it does NOT do
-------------------
- It does not validate against the MENOTA RELAX NG schema. Validate
  separately with `jing menotaP5.rng input.xml` or in oXygen before
  uploading.
- It does not normalise whitespace, reformat the document, or change
  any other content.

License: LGPL v3, same as menota-publisher-lib.
"""
import argparse
import re
import sys
import urllib.request
from pathlib import Path

ENTITIES_URL = "https://www.menota.org/menota-entities.txt"
# Vendored copy alongside this script. Subset covering ~80 most common
# entities used in MENOTA-archive files. Run with --entities to point
# at the full upstream list when needed.
VENDORED_ENTITIES = Path(__file__).parent / "menota-entities.txt"

# Pattern matching a single ENTITY declaration line:
#   <!ENTITY name "&#xHHHH;">
# Tolerates extra whitespace and lowercase/uppercase hex.
ENTITY_DECL_RE = re.compile(
    r'<!ENTITY\s+(\S+)\s+"&#x([0-9A-Fa-f]+);"\s*>'
)

# Pattern for entity references in the document body. Excludes the five
# XML built-in entities (amp, lt, gt, apos, quot) which must be preserved.
BUILTIN = {"amp", "lt", "gt", "apos", "quot"}
ENTITY_REF_RE = re.compile(r'&([A-Za-z][A-Za-z0-9_-]*);')

# Match the DOCTYPE block to strip it (no longer needed once entities
# are inlined, and keeping it would re-trigger the external fetch).
DOCTYPE_RE = re.compile(r'<!DOCTYPE[^>[]*(\[[^\]]*\])?[^>]*>', re.DOTALL)


def load_entity_table(path_or_url: str) -> dict[str, str]:
    """Parse menota-entities.txt and return {name: unicode_char}."""
    if path_or_url.startswith(("http://", "https://")):
        with urllib.request.urlopen(path_or_url) as resp:
            text = resp.read().decode("utf-8", errors="replace")
    else:
        text = Path(path_or_url).read_text(encoding="utf-8")

    table: dict[str, str] = {}
    for m in ENTITY_DECL_RE.finditer(text):
        name = m.group(1)
        codepoint = int(m.group(2), 16)
        table[name] = chr(codepoint)
    return table


def resolve_entities(xml_text: str, table: dict[str, str]) -> tuple[str, dict[str, int]]:
    """Replace &name; references with their Unicode characters.

    Returns (new_text, stats) where stats is a count of unresolved entities
    by name. Built-in XML entities are left alone.
    """
    unresolved: dict[str, int] = {}

    def replace(m: re.Match) -> str:
        name = m.group(1)
        if name in BUILTIN:
            return m.group(0)
        if name in table:
            return table[name]
        unresolved[name] = unresolved.get(name, 0) + 1
        return m.group(0)  # leave untouched so the user sees the parse error

    new_text = ENTITY_REF_RE.sub(replace, xml_text)
    return new_text, unresolved


def strip_doctype(xml_text: str) -> str:
    """Remove the DOCTYPE block, since the external entity ref is no
    longer needed once entities are inlined."""
    return DOCTYPE_RE.sub("", xml_text, count=1)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("input", help="MENOTA XML file to process")
    p.add_argument("-o", "--output", help="Output file (default: stdout)")
    p.add_argument("--in-place", action="store_true",
                   help="Overwrite the input file")
    p.add_argument("--entities",
                   default=None,
                   help="Path or URL to menota-entities.txt. "
                        "Defaults to the vendored copy next to this script. "
                        f"Upstream: {ENTITIES_URL}")
    p.add_argument("--keep-doctype", action="store_true",
                   help="Don't strip the DOCTYPE block (default: strip it)")
    args = p.parse_args()

    if args.in_place and args.output:
        p.error("--in-place and --output are mutually exclusive")

    entities_source = args.entities
    if entities_source is None:
        if VENDORED_ENTITIES.exists():
            entities_source = str(VENDORED_ENTITIES)
        else:
            entities_source = ENTITIES_URL

    print(f"[info] loading entity table from {entities_source}", file=sys.stderr)
    try:
        table = load_entity_table(entities_source)
    except Exception as e:
        print(f"[error] failed to load entity table: {e}", file=sys.stderr)
        return 2
    print(f"[info] {len(table)} entities loaded", file=sys.stderr)

    xml_text = Path(args.input).read_text(encoding="utf-8")

    if not args.keep_doctype:
        xml_text = strip_doctype(xml_text)

    new_text, unresolved = resolve_entities(xml_text, table)

    if unresolved:
        print(f"[warn] {sum(unresolved.values())} unresolved entity references "
              f"({len(unresolved)} distinct names):", file=sys.stderr)
        for name, count in sorted(unresolved.items(),
                                   key=lambda kv: -kv[1])[:20]:
            print(f"  &{name};  ({count}x)", file=sys.stderr)
        if len(unresolved) > 20:
            print(f"  ... and {len(unresolved) - 20} more", file=sys.stderr)

    out_path = args.input if args.in_place else args.output
    if out_path:
        Path(out_path).write_text(new_text, encoding="utf-8")
        print(f"[info] wrote {out_path}", file=sys.stderr)
    else:
        sys.stdout.write(new_text)

    return 1 if unresolved else 0


if __name__ == "__main__":
    sys.exit(main())
