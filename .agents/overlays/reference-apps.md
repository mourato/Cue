---
kind: project-overlay
extends: reference-apps
project: Cue
precedence: project
---

# Cue reference catalog

This is the operational catalog for the references summarized in
`docs/REFERENCES.md`. The canonical source is each project's repository URL;
the catalog records consultation metadata and reuse boundaries, not copied
implementation details.

## Same-domain definition

For Notinhas, **same-domain** means a native macOS tool whose primary workflow
includes screen/window/area capture, screen recording, visual annotation,
history, or developer/product handoff. An engineering classification may be
added when the reference also provides a useful implementation pattern.
Classification does not change the license decision.

## Product touchpoints

Use these existing Notinhas surfaces when turning a reference observation into
a bounded proposal:

- `Cue/Features/Capture/` — capture entry points and selection.
- `Cue/Features/Annotate/` — pins, notes, composition, and clipboard-ready output.
- `Cue/Features/QuickAccess/` — post-capture preview and actions.
- `Cue/Features/History/` — persistence and reopen behavior.
- `Cue/Features/Recording/` — optional screen-recording capture flow.
- `Cue/Features/VideoEditor/` — optional recording playback and export.

## Catalog

### macshot

- **Classification:** UI/UX; same-domain.
- **Remote:** https://github.com/sw33tLie/macshot
- **Description:** Native capture/annotation flow, precise selection, editable history, beautify, OCR, and redaction patterns.
- **License:** GPL-3.0 — https://www.gnu.org/licenses/gpl-3.0.html
- **Reuse decision:** Inspiration and independent reimplementation only. Do not copy or adapt code/assets without a separate GPL compliance decision.
- **Cloned:** no.
- **Local path:** —
- **Consultation:** Remote GitHub repository/README, verified 2026-08-23; no local clone was needed.
- **Product touchpoints:** Capture, Annotate, QuickAccess, History.

### BetterShot

- **Classification:** UI/UX; same-domain.
- **Remote:** https://github.com/KartikLabhshetwar/better-shot
- **Description:** Floating post-capture preview, drag-to-app, compact recording status, one-key editor actions, history, and confirmation feedback.
- **License:** BSD-3-Clause — https://opensource.org/license/bsd-3-clause
- **Reuse decision:** Inspiration first. Reuse is permitted only with the license notices and attribution required by the exact version being used; no code/assets are currently reused.
- **Cloned:** no.
- **Local path:** —
- **Consultation:** Remote GitHub repository/README, verified 2026-08-23; no local clone was needed.
- **Product touchpoints:** QuickAccess, Capture, Annotate, History.

### Capso

- **Classification:** UI/UX; same-domain; engineering.
- **Remote:** https://github.com/lzhgus/Capso
- **Description:** All-in-one HUD, capture presets, OCR/translation, persistent history, webcam PiP, and BYO-storage setup patterns.
- **License:** Business Source License 1.1 — https://mariadb.com/bsl11/
- **Reuse decision:** Behavior reference only for the current competing product. Do not copy or adapt Capso code/assets; the project's competing-product restriction applies before its stated future conversion.
- **Cloned:** no.
- **Local path:** —
- **Consultation:** Remote GitHub repository/README, verified 2026-08-23; no local clone was needed.
- **Product touchpoints:** Capture, QuickAccess, History, Recording, VideoEditor.

### Screendrop

- **Classification:** UI/UX; same-domain; engineering.
- **Remote:** https://github.com/fayazara/Screendrop
- **Description:** Native screen/camera/audio recording, non-destructive masters and metadata, pointer/event editing, fragmented writer/backpressure, and Studio export patterns.
- **License:** CC0 1.0 — https://creativecommons.org/publicdomain/zero/1.0/
- **Reuse decision:** Reuse is legally permitted by CC0, but Notinhas will independently reimplement the bounded ideas and will not copy code/assets. Preserve the Cue capture → annotate → clipboard product boundary.
- **Cloned:** yes.
- **Local path:** `~/Documents/Projects/References/Screendrop/`
- **Consultation:** Local clone at commit `f4883be` (`origin/main`), README, recording sources, and root `LICENSE` verified 2026-08-23.
- **Product touchpoints:** Recording, VideoEditor, QuickAccess, History, and the frame-to-brief route into Annotate.

## Maintenance rules

- Keep the human summary and this catalog synchronized when adding or removing
  a reference; the overlay is the source for operational metadata.
- Record the exact license name and a direct license URL. If the repository has
  no clear license, record inspiration/reimplementation only and do not copy
  code or assets.
- Record `Cloned: yes` and the canonical local path only when a deep local
  study is explicitly needed. Clones belong under
  `~/Documents/Projects/References/<CanonicalName>/`; never clone into the
  Cue repository or directly under `~/Documents/Projects/`.
- Every derived plan must name both the reference URL and the affected
  Cue touchpoint. Behavioral inspiration is not evidence that the feature
  belongs in the product.
