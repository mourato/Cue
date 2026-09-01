# ADR 072: Fixed Cue note palette and numeral ink

## Status

Accepted (2026-08-14)

## Context

Cue notes are visual handoff markers. The shared numbered-badge renderer
had started choosing black or white numeral ink from background luminance. That
was technically adaptive, but black numerals on the red, orange, and blue note
colors made the markers less pleasant to read in the product's primary flow.

## Decision

Use the fixed seven-color Cue palette owned by `CuePaletteColor`:

- red `#D93530` — white numeral
- orange `#ED8413` — white numeral
- blue `#0076DE` — white numeral
- green `#5EDBA7` — black numeral
- purple `#9747FF` — white numeral
- magenta `#E8178A` — white numeral
- black `#212121` — white numeral

The note renderer receives the numeral ink explicitly from the palette. The
shared badge helper no longer computes luminance; its default remains white so
legacy Counter rendering is deterministic. Existing persisted note colors are
not rewritten or migrated; colors outside the fixed palette fall back to white
ink.

## Consequences

The notes experience is visually stable and matches the approved palette,
including the new Magenta choice. Custom or historical colors do not receive
adaptive ink, so colors outside the fixed Notes slots fall back to white
numeral ink.

Annotate tool color pickers and the Notes editor share
`AnnotateBuiltInColorPalette` as the built-in dictionary. Named overlaps keep
the Notes hex values above; annotate-only extras (for example yellow and white)
are merged without duplicating RGB. User customs continue to live in
`AnnotateColorPaletteStore`.

## Affected surfaces

- `CuePaletteColor`
- `AnnotateBuiltInColorPalette`
- Cue note editor and annotate color pickers
- numbered note canvas/export rendering
