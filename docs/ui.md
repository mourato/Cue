# UI

Current UI contract for Cue. Read this before changing capture HUDs,
annotation editors, pinned notes, toolbar controls, preferences surfaces, or
post-capture routing. Feature mechanics remain in the flow documents linked
from [`docs/README.md`](README.md); durable rationale belongs in
[`docs/adr/`](adr/).

## Product intent

Cue is a visual-handoff tool: capture a screenshot, add numbered pins,
rectangles, or notes, then copy the precise annotated result. Optimize for
speed, visual reference, and clipboard-ready output. Do not add unrelated
product chrome or broaden the inherited capture machinery merely to make it
look different.

- Selection edges use the current backdrop's cached boundary index during the
  initial drag and All-In-One refinement. Hold `Option` to bypass snapping for
  the current gesture. Snap guide lines are configurable in Capture settings
  and are enabled by default.
- During screenshot and recording area selection, `Space` switches from manual
  region selection to application-window selection; it never moves an active
  selection rectangle.

## Sources of truth

- Shared tokens and controls: [`Cue/Shared/Styles/DesignTokens.swift`](../Cue/Shared/Styles/DesignTokens.swift)
- Capture flow: [`docs/CAPTURE.md`](CAPTURE.md)
- Annotation flow: [`docs/ANNOTATE.md`](ANNOTATE.md)
- Post-capture routing: [`docs/POST_CAPTURE.md`](POST_CAPTURE.md)
- Theme and appearance: [`Cue/Services/Appearance/ThemeManager.swift`](../Cue/Services/Appearance/ThemeManager.swift)
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
- The All-In-One mode strip is visually neutral: `selectedMode` remains the
  functional and accessibility state for `Return` and the dimensions bar, but
  it does not tint one mode button differently from the others.
- Recording toolbar microphone and camera device popovers, plus system audio,
  share the same icon label, frame, hover treatment, inactive opacity, and
  accessibility state value; opening a device popover must not change the
  control's geometry.
- The pre-recording toolbar is composed of three compact floating islands:
  cancel/options/dimensions/mode, direct recording toggles, and labeled GIF or
  Video start actions. Area dimensions are editable screen points; changing a
  dimension preserves the selection center and clamps the result to the display
  containing the selection. Screenshot capture is not a pre-recording toolbar
  action.
- The live recording camera preview is draggable within the selected area and
  exposes session-only size and shape controls through the camera popover or
  the preview's contextual menu. The persisted `Show preview while recording`
  option is enabled by default and controls whether that preview remains on
  screen after recording starts; size and shape remain session-only.
- Sidebar and swatch states use semantic fills and borders: default, hover,
  selected, and disabled must remain distinguishable in Light and Dark.
- Numbered pins/notes are the product identity. Preserve their ordering,
  editing, rendering, and export semantics when changing editor chrome.
- For rectangular notes, the numbered badge sits centered on one of the four
  vertices (not a side midpoint). New drags store the drag-start corner;
  resize/move keep that corner; image rotation remaps it; legacy sessions
  without a stored corner use `topLeft`. Badge center is exactly on the vertex.
- Selected rectangles, including note rectangles, expose corner and midpoint
  side handles; a side drag changes one dimension while keeping the opposite
  edge fixed and respecting the minimum size.
- The **Uploads** preferences tab owns both hosting-provider configuration and
  image upload encoding controls. Upload optimization creates a temporary
  derivative for the provider; it never changes the local capture or the
  annotation source.
- ImageKit video upload uses the configured plan limit with a 5% safety margin.
  Quick Access presents one compact popover at or above that target with MP4 /
  H.264 output, dimensions, quality, frame rate, and audio controls. The source
  remains the card's file; temporary derivatives and multipart bodies are
  removed after upload or failure.
- The provider picker controls the shared upload action label and configured
  state across Preferences, Annotate, and Quick Access. Quick Access also
  disables media types unsupported by the selected provider; Annotate always
   uploads its final composed image. Credential fields show masked Keychain
   state; a missing selected-provider credential is explained locally. No new
   layout, material, or animation rule is introduced. In-flight uploads expose
   Cancel; cancelling is silent (no error toast) and leaves the local file
   untouched.
- Rectangle and Circle tools share `AnnotationShapeFillStyle`
  (outline / solid / tinted / hatched) with a single stroke color. Notes areas
  use the same enum but omit solid in the picker.
- Drawn annotation stroke width uses discrete `AnnotationStrokeWidth` presets
  (`2 / 4 / 6 / 8 / 12`, Screendrop-aligned) via a segmented dot picker in the
  annotate quick-properties stroke popover, sidebar, inline area controls, and
  recording annotation toolbar. Continuous stroke sliders are not used for drawn
  elements.
- Rectangular Cue note editors keep compact Stroke, Style, and Color
  triggers together in the header; point notes expose Color only. The note
  Style picker keeps the shared shape previews while omitting `solid`.
- In `AnnotateQuickPropertiesBar`, Color, Stroke/Size, and shape Style open as
  popovers that stay open until dismissed by clicking outside or pressing Esc.
  Stroke and Style triggers show a live preview of the current value. The bar
  sizes to its content on a single centered row (no wrap) over the canvas.
- Cue notes share the built-in annotate color dictionary in
  `AnnotateBuiltInColorPalette`, which keeps `CuePaletteColor` hex values
  for named overlaps and still owns numeral ink via palette matching. Do not
  derive note numeral color from luminance or replace Notes hex slots with
  system colors. User-added customs remain in `AnnotateColorPaletteStore`.
- Use one owner for each scrollable surface. Avoid nested decorative panels
  that compete with the capture or annotation canvas.
- Video Editor keeps the camera bubble as an independent overlay outside the
  screen zoom layer. `VideoEditorCameraOverlayLayout` owns the shared geometry
  used by preview and export: new recordings use their captured normalized
  frame, size, and shape, and changing one camera field preserves the others.
  Older recordings retain corner-anchored aspect-fit defaults and optional
  inverse zoom scaling.
- Video Editor's selected-zoom sidebar exposes one Camera Behavior control:
  Follow pointer, Follow activity, or Fixed position. The center picker is
  available only for Fixed position; output aspect ratio and dimensions belong
  to export settings, not the background sidebar.
- Video Editor cursor controls live in a dedicated Cursor section. A recording
  with a baked cursor never enables a reconstructed cursor overlay; Smart
  Pointer recordings own reconstructed cursor visibility, size, and smoothing
  preset. Click effects and shortcut captions remain independent metadata
  overlays and do not add a second cursor. A reconstructed cursor is hidden
  while its recorded position is outside the capture area.
- In `AnnotateMainView`, contextual properties and bottom actions float over the
  central canvas host. The side dock remains in normal layout flow and reduces
  that host's bounds; full-width separator or background bands must not appear
  beneath the floating islands.
- The annotation workspace uses a neutral dotted grid behind the canvas for
  visual separation; the grid is editor chrome only and never enters export or
  clipboard output.
- Background controls are grouped under a collapsible `Background` section,
  while style, layout, mockup, and combine controls remain available under a
  collapsed-by-default `Style` section. The annotation toolbar keeps its
  complete visible tool inventory.
- Floating control islands reuse `captureFloatingToolbarMaterial()`: use
  Liquid Glass by default, with the existing solid fallback for Reduce
  Transparency. Do not apply glass to the full editor, canvas, or sidebar.
- Popovers use `PopoverTokens` in [`DesignTokens.swift`](../Cue/Shared/Styles/DesignTokens.swift): compact menus use an 8-point content inset, 4-point item spacing, and 28-point minimum rows; property and settings panels use a 12-point content inset; transient feedback uses the compact 10×6-point inset. `PopoverMenuItemStyle` owns menu-row hover, selection, full-width content shape, and selected-state border.
- Native SwiftUI `.popover` content does not add a second material, border, clip, or shadow. Custom overlay cards and AppKit popover windows may own their surface chrome, but their padding, radii, and anchor gap come from `PopoverTokens`.
- Transient progress feedback keeps its category-specific geometry, but uses `FeedbackStyle` for semantic success, warning, error, and info tones. Floating progress cards reuse `FeedbackSurface` so material, border, fallback, and shadow behavior stay consistent with toasts and prompts.
- Persistent and inline status feedback for permissions, setup, conflicts, and sync uses `StatusBadge` for compact state labels and `FeedbackStyle` for semantic tones; keep context-specific card geometry and recovery actions local to the owning flow.
- The clipboard handoff action is the primary labeled action in the bottom
  action island; secondary actions may remain icon-only with explicit tooltips
  and accessibility labels.
- Scrolling-capture floats are content-only: the preview card shows the
  stitched image with no header, badge, caption, padding, or border (the
  image fills 100% of the card), and the control island shows only the
  Cancel / Auto Scroll / Done buttons at regular size. Session status stays
  in the region overlay guidance, toasts, and logs — never as preview chrome.

- Preferences `SettingRow` icons render at `.body` in a 24-point column with
  `.secondary` tint; titles use `.body` medium and descriptions `.caption`.
  Every `Toggle`, `Picker`, `TextField`, and `Slider` in a row carries an
  explicit `.accessibilityLabel` (the row title) even when `.labelsHidden()`
  hides its visual label.
- Preferences preview thumbnails must load bundled artwork through
  `SystemWallpaperManager.downsampledPreviewImage(at:maxPixelSize:)` (512px
  for Quick Access cards), never through full-resolution
  `NSImage(contentsOf:)`.
- `PreferencesNavigationState` persists the last visited tab under
  `preferences.selectedTab` and restores it on launch.

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
