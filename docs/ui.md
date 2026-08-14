# UI

Current UI contract for Notinhas. Read this before changing capture HUDs,
annotation editors, pinned notes, toolbar controls, preferences surfaces, or
post-capture routing. Feature mechanics remain in the flow documents linked
from [`docs/README.md`](README.md); durable rationale belongs in
[`docs/adr/`](adr/).

## Product intent

Notinhas is a visual-handoff tool: capture a screenshot, add numbered pins,
rectangles, or notes, then copy the precise annotated result. Optimize for
speed, visual reference, and clipboard-ready output. Do not add unrelated
product chrome or broaden the inherited capture machinery merely to make it
look different.

## Sources of truth

- Shared tokens and controls: [`Notinhas/Shared/Styles/DesignTokens.swift`](../Notinhas/Shared/Styles/DesignTokens.swift)
- Capture flow: [`docs/CAPTURE.md`](CAPTURE.md)
- Annotation flow: [`docs/ANNOTATE.md`](ANNOTATE.md)
- Post-capture routing: [`docs/POST_CAPTURE.md`](POST_CAPTURE.md)
- Theme and appearance: [`Notinhas/Services/Appearance/ThemeManager.swift`](../Notinhas/Services/Appearance/ThemeManager.swift)
- Related decisions: [`docs/adr/066-absorb-counter-from-upstream.md`](adr/066-absorb-counter-from-upstream.md), [`docs/adr/070-retain-snapzy-surfaces.md`](adr/070-retain-snapzy-surfaces.md)

The implementation and this file must describe the same current behavior.
Reconcile stale flow docs when changing the relevant UI; do not create a
second canonical design-system document.

## Principles and invariants

- Preserve the handoff loop: capture → annotate → export/copy.
- Prefer native macOS controls and semantic system appearance over decorative
  chrome. Reuse shared tokens before adding local values.
- The standard spacing grid is 4, 8, 16, 24, and 32 points. Shared radii are
  4, 6, 8, and 12; default and selected strokes are 1 and 2 points.
- Toolbar controls are real `Button`s with a 28×28 visual frame, clear hover
  and selected states, and explicit accessibility selection/value.
- Sidebar and swatch states use semantic fills and borders: default, hover,
  selected, and disabled must remain distinguishable in Light and Dark.
- Numbered pins/notes are the product identity. Preserve their ordering,
  editing, rendering, and export semantics when changing editor chrome.
- Notinhas notes use the fixed palette in `NotinhasPaletteColor`; each palette
  color owns its explicit numeral ink color. Do not derive note numeral color
  from luminance or replace the palette with system colors.
- Use one owner for each scrollable surface. Avoid nested decorative panels
  that compete with the capture or annotation canvas.

## States and accessibility

For affected surfaces verify idle, hover, pressed, focused, selected,
disabled, loading, empty, error, and permission states as applicable. Labels,
values, selected state, keyboard navigation, and VoiceOver behavior are part of
the UI contract, not follow-up polish. Respect Light/Dark/System appearance,
Reduce Motion, and Reduce Transparency; solid fallbacks must retain hierarchy
and contrast.

## Review checklist

- [ ] The change still optimizes capture, annotation, and export speed.
- [ ] Shared `DesignTokens` and existing feature components were reused.
- [ ] Relevant states work with keyboard, VoiceOver, Light/Dark, Reduce Motion,
      and Reduce Transparency.
- [ ] Feature flow docs and localization were reconciled if behavior changed.
- [ ] Update this file for reusable rules or invariants.
- [ ] Add or update an ADR for a meaningful alternative, risk, ownership
      decision, or external reference; do not use an ADR for a one-off tweak.

## Lifecycle

Create or update this file when a visual rule is reusable across surfaces,
constrains future work, or explains a product-level trade-off. Do not record
every pixel adjustment. Retire rules when the implementation and references are
removed, keeping historical rationale in an ADR when useful.
