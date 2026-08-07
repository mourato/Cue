---
name: localization
description: Localization guidance for Notinhas — user-facing annotate/Notinhas copy, tooltips, toasts, and accessible strings.
---

# Localization

Use when adding or changing user-visible strings, tooltips, permission toasts, or empty-state copy for Notinhas or shared Annotate UI.

## Rules

- User-facing text lives in Notinhas localization (`Notinhas/Resources/Localization/*.xcstrings`) and `L10n` / Notinhas-specific helpers.
- Keep tone short and direct — designer handoff, not marketing prose.
- Use stable keys; do not concatenate sentences in code for grammar-sensitive languages.
- Accessible labels should describe the action (“Add note”, “Copy to clipboard”, “Upload image”), not only the visual glyph.
- Technical tokens (HEX in upstream features, file formats) may stay locale-stable; surrounding chrome can localize.
- Avoid hard-coded English in new permission/error toasts when a strings table exists.

## Checklist

- Are new strings reachable for `Localizable.strings` / xcstrings extraction?
- Do Notinhas note editor labels localize consistently with Annotate chrome?

## Related

- AX labels → `swiftui-accessibility-audit`
- Docs ownership → `documentation`
