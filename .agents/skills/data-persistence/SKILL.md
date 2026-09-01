---
name: data-persistence
description: Cue and annotation session persistence — PersistedCueNotesSession, UserDefaults keys, and session restore.
---

# Data Persistence

Use when changing saved Cue notes, annotation session restore, UserDefaults keys, or ImgBB configuration storage.

## Invariants

- Cue notes persist inside annotation sessions via `PersistedCueNotesSession` on `PersistedAnnotationSession`.
- ImgBB API key UserDefaults key: `notinhas.imgbb.apiKey` (`CueImgBBConfiguration.apiKeyUserDefaultsKey`) — store key name only in docs/logs; never commit or log secret values.
- Notes panel side: `PreferencesKeys.notinhasNotesPanelSide` / `CueImgBBConfiguration.panelSideUserDefaultsKey`.
- Prefer additive Codable evolution (new fields with defaults) over silent key renames.
- Decoding should fail soft on corrupt JSON — do not crash Annotate on bad session data.

## Checklist

- Does a normal annotate session with Cue notes round-trip across save/reopen?
- Does panel side preference survive relaunch?
- Are migrations additive and backward-compatible with older sessions?

## Validation

- Save annotated screenshot with notes, close Annotate, reopen from history — notes restore.
- Change panel side in preferences, export — side matches preference.

## Related

- UI binding → `macos-app-engineering`
- Tests for encode/decode → `testing-xctest`
- ImgBB upload flow → `capture-annotate-export` (when present)
