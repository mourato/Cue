# ADR 072: Fixed Notinhas note palette and numeral ink

## Status

Accepted (2026-08-14)

## Context

Notinhas notes are visual handoff markers. The shared numbered-badge renderer
had started choosing black or white numeral ink from background luminance. That
was technically adaptive, but black numerals on the red, orange, and blue note
colors made the markers less pleasant to read in the product's primary flow.

## Decision

Use the fixed seven-color Notinhas palette owned by `NotinhasPaletteColor`:

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
adaptive ink, so a future custom-color feature would need an explicit ink rule.

## Affected surfaces

- `NotinhasPaletteColor`
- Notinhas note editor and quick color controls
- numbered note canvas/export rendering
