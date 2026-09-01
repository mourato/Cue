# ADR 076: Annotate Workspace and Floating Materials

Status: Accepted
Date: 2026-08-23

## Context

Cue's annotation editor prioritizes a fast visual handoff: numbered
notes and shapes must remain prominent while canvas styling and export actions
stay close to the image. Screendrop demonstrates a useful visual treatment: a
neutral dotted workspace, labeled primary actions, and glass-like floating
controls. Its current implementation targets macOS 26.4 and uses Liquid Glass,
while Cue targets macOS 26.0+ and keeps a Reduce Transparency solid fallback for Liquid Glass chrome.

## Decision

1. Add a neutral dotted grid only to the annotation workspace. It is editor
   chrome and must never be rendered into saved or clipboard output.
2. Group canvas appearance controls under collapsible `Background` and `Style`
   sections. `Style` is collapsed by default because its controls are less
   frequent. Keep every annotation tool visible in the toolbar.
3. Make the clipboard handoff action a labeled, prominent `Copy` button in the
   bottom action island. Keep other secondary actions in their existing order
   and configuration model.
4. Evolve the existing `captureFloatingToolbarMaterial()` surface: use native
   Liquid Glass when available and retain the current material/solid fallback
   for older systems and Reduce Transparency.

## Consequences

- The editor has stronger canvas/workspace separation without changing export
  semantics.
- Common background choices remain visible while advanced styling occupies less
  initial space.
- Liquid Glass remains a localized treatment for transient control islands,
  rather than becoming a product-wide visual dependency.
- The toolbar remains discoverable and complete; no tool moves into an overflow
  menu.

## Rejected or deferred

- Moving the sidebar from left to right is deferred because it changes the
  editor's information architecture rather than just its visual hierarchy.
- Raising Cue's minimum macOS version solely for Liquid Glass is deferred.
- `GlassEffectContainer` morphing is deferred until the editor has a real
  surface-morph interaction that needs it.

## References and license

- [Screendrop](https://github.com/fayazara/Screendrop), commit `f4883be`,
  CC0 1.0. Inspiration and independent reimplementation only; no code or
  assets are copied.
- [Apple: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views).

## Affected surfaces

- `Cue/Features/Annotate/AnnotateMainView.swift`
- `Cue/Features/Annotate/Components/AnnotateSidebarView.swift`
- `Cue/Features/Annotate/Components/AnnotateBottomBarView.swift`
- `Cue/Services/Capture/FloatingToolbar/CaptureFloatingToolbarChrome.swift`
