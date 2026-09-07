# 116 — Screen Recording backends for the new preferences tab

- Status: In progress — all backends implemented except DND (dropped, awaiting UI decision in §7)
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

| Key | Default | Owner | Status |
| --- | --- | --- | --- |
| `recording.dimScreenWhileRecording` | `true` | `RecordingRegionOverlayWindow` (gated dim fill + clear; live via `UserDefaults.didChangeNotification`) | ✅ Done |
| `recording.showCountdown` | `false` | `RecordingCountdownWindow` (3-2-1, main start flow only) + `RecordingToolbarPreferences.showCountdown()` | ✅ Done |
| `recording.doNotDisturbWhileRecording` | `true` | ⛔ DROPPED — see §7 | UI row removed; key/helper/TOML kept |
| `recording.maxResolution` | `1080p` | `RecordingCaptureScale.effectiveScale` (long-edge caps 720p→1280 … 2160p→3840) threaded `prepareRecording` → `resolveCaptureGeometry` | ✅ Done |
| `recording.scaleRetinaTo1x` | `true` | Same as above (base scale 1x vs display scale) | ✅ Done |
| `recording.audioMono` | `false` | `makeAACSettings(mono:)` (mono channel layout) threaded writer inputs + mixdown output | ✅ Done |
| `recording.audioTracks` (`single`/`separate`) | `single` | `requiresMixDown(keepSeparateTracks:)` + `normalizeIfNeeded` skip; editor resolves roles by track index (system=0, mic=1, matching writer order) | ✅ Done |
| `recording.gif.frameRate` | `15` | `RecordingToolbarPreferences.gifOptions()` → `GIFConverter.Options` in `handleGIFConversion` | ✅ Done |
| `recording.gif.maxWidth` | `800` | Same; `0` = Original (source width) | ✅ Done |
| `recording.gif.optimize` | `true` | `GIFFramePlan`: exact-duplicate collapse via 8×8 FNV-1a hash, delays extended | ✅ Done |
| `recording.gif.quality` | `0.75` | `GIFPaletteQuantizer`: quality → 16…256 colors via median-cut on 15-bit histogram + bucket-LUT remap | ✅ Done |

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

## 7. DND research outcome (2026-09-07, timebox closed)

There is **no sanctioned macOS API to enable Do Not Disturb / Focus programmatically**.
What exists:
- `AppIntents` Focus collection: observe Focus state and filter *your own app's*
  notifications — cannot toggle system Focus.
- Community workarounds, all unsuitable for Cue: private frameworks (`macos-focus`
  explicitly marks `[Private API]`), AppleScript driving System Events (needs extra
  Accessibility trust for a fragile toggle), Shortcuts-app URL schemes (requires the
  user to hand-build a Shortcut), `sindresorhus/do-not-disturb` (notes it does not
  work sandboxed and asks users to file Feedback Assistant radars instead).
- Writing `com.apple.ncprefs` / Focus databases directly is SIP-adjacent, sandbox-
  breaking, and risks corrupting Focus state.

Decision: **do not implement system-wide DND**. The `recording.doNotDisturbWhileRecording`
key stays persisted (harmless) with TOML parity, but nothing reads it yet. Open UI
question for the owner: remove the `"Do Not Disturb" while recording` row from the
Screen Recording tab, or keep it dormant until Apple ships an API.

Outcome (2026-09-07): owner chose **remove the row**. The toggle row and its L10n string
are gone from `PreferencesScreenRecordingSettingsView`; the key, the
`RecordingToolbarPreferences.doNotDisturbWhileRecording()` helper, and the TOML
`do_not_disturb_while_recording` field remain for a future API.
