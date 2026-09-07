# 116 — Screen Recording backends for the new preferences tab

- Status: TODO
- Priority: P1 / Effort: M
- Depends on: Screen Recording preferences tab (keys + UI landed; this plan wires behavior)
- Primary skill: `capture-annotate-export` (recording scope)
- Complementary: global `delivery-workflow` + Cue overlay (build/test gates), `test-hygiene` (quiet suite default)
- UI contract: `docs/ui.md` (explicit `.accessibilityLabel` per control; already satisfied by the tab)
- Base SHA: `ea815e0917e70b1ee7fa83c7dc6561b037ce9666` (record `git rev-parse HEAD` at execution)

## 1. Objective

Wire the new `Screen Recording` preferences keys to the recording pipeline. The tab
(`Cue/Features/Preferences/Components/PreferencesScreenRecordingSettingsView.swift`)
persists all keys today; the keys below are UI-only until this plan lands. Already
functional (no work): show controls (`recording.hoverBarVisible`), remember last
selection (`recording.rememberLastArea`), menu-bar timer (`recording.showTimeOnMenuBar`),
show cursor (`recording.showCursor`), highlight clicks (`recording.highlightClicks` +
`recording.mouseHighlight.*`), keystrokes (`recording.showKeystrokes` +
`recording.keystroke.*`), video format (`recording.format`), video frame rate
(`recording.fps`), system audio (`recording.captureAudio`).

## 2. Keys to wire (all defaults already match the reference)

| Key | Default | Owner |
| --- | --- | --- |
| `recording.dimScreenWhileRecording` | `true` | `RecordingRegionOverlayWindow` (already dims at 0.4 alpha; gate on key, observe live) |
| `recording.showCountdown` | `false` | `RecordingCoordinator` + new countdown overlay before `ScreenRecordingManager` start |
| `recording.doNotDisturbWhileRecording` | `true` | Research first: no public DND API; timebox, may become best-effort/dropped |
| `recording.maxResolution` (`720p`/`1080p`/`1440p`/`2160p`/`Original`) | `1080p` | `ScreenRecordingManager` session/video settings (downscale capture) |
| `recording.scaleRetinaTo1x` | `true` | Capture-size computation (backing-scale division) |
| `recording.audioMono` | `false` | `RecordingAudioEncodingSettings` (mono AAC variant) |
| `recording.audioTracks` (`single`/`separate`) | `single` | Writer inputs + `RecordingMetadata` roles + `VideoEditorAudioTrackRole` mapping |
| `recording.gif.frameRate` | `15` | `RecordingCoordinator` GIF flow → `GIFConverter.Options(fps:)` |
| `recording.gif.maxWidth` (`480`/`600`/`800`/`960`/`0`=Original) | `800` | `GIFConverter.Options(maxWidth:)` — note: changes current implicit `960` default, confirm |
| `recording.gif.optimize` | `true` | Define first: global color map is already on; decide palette/frame-diff work in `GIFConverter` |
| `recording.gif.quality` (`0.1`…`1.0`) | `0.75` | Map to ImageIO output properties; research `kCGImageDestinationLossyCompressionQuality` vs quantizer |

## 3. Scope

### In

- One key at a time, smallest pipeline diff per key; per-key XCTest (defaults + wiring) where the
  seam is testable without TCC (pure helpers for resolution/mono-mix/GIF options mapping).
- TOML config parity for the new keys (`CueExporter` + `CueImporter` + `CueDefaultDocument`),
  following the existing `recording.mouse_highlight` / `recording.keystrokes` sections.
- Manual gate per key: record → verify output (dims on/off, countdown shown, resolution caps,
  mono layout, track count in editor, GIF fps/size/quality deltas).

### Out (do not touch)

- No tab UI reorganization (landed); no new preferences keys beyond §2.
- No editor changes: Quality, Smart Pointer (synthetic cursor), camera overlay, click/keystroke
  effects, and per-track audio volumes already live in the Video Editor sidebar/export panels.
  Microphone *device* selection stays pre-record in the recording toolbar (capture-time only,
  correctly absent from the tab).
- DND gets a research timebox; if macOS offers no sanctioned API, document and drop rather
  than shipping private-API hacks.

## 4. Execution steps

1. Preflight: `scripts/plan-preflight.sh plans/116-screen-recording-backends.md --scope Cue/Features/Recording`.
2. Bind `delivery-contract` with base SHA, isolated worktree + branch, exact file list; PASS first.
3. Per key: map default → read site → behavior change → XCTest → quiet `./scripts/run-tests.sh`.
4. TOML parity last (exporter/importer/default doc + round-trip test).
5. `scripts/verify-local.sh --base <ref>` + `make validate`; manual recording checklist in handoff.

## 5. Acceptance

- [ ] Each §2 key changes recording/GIF output as described (DND either works or is documented-dropped).
- [ ] No behavior change for pre-existing keys; editor needs no additions.
- [ ] TOML round-trips the new keys; quiet suite + `make validate` green.

## 6. Risks / STOP conditions

- Unexpected changed paths in worktree → STOP, report, preserve.
- DND without public API → research note, drop, do not swizzle.
- GIF `maxWidth` default shift (960 → 800) needs explicit product confirm before changing converter default.
