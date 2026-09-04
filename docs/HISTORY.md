# Capture History

Persistent history of screenshots, videos, and GIFs backed by GRDB SQLite, surfaced through a single floating panel (horizontal card row) and a restore-to-Quick-Access flow that reopens captures in Annotate or Video Editor with editable sessions. Code: `Cue/Features/History/` + `Cue/Services/History/`.

## Entry Points

- Status bar menu (Capture History).
- Deep link `cue://open/history` (aliases `history`, `capture-history`).
- Global shortcut `GlobalShortcutKind.history`, default ⌘⇧H (`ShortcutConfig.defaultHistory`), rebindable in Preferences → Shortcuts.

## Floating Panel

- `HistoryFloatingManager` — panel state. Position `topCenter` / `bottomCenter` (`HistoryPanelPosition.center` exists for config import, not in UI); panel width is 90% of the active display's visible area, height is 360pt when it fits, and the top position uses an 8pt top margin; background `HistoryBackgroundStyle` hud / solid.
- `HistoryFloatingPanel` keyboard: ⌘C copy selection, ⌘A select all, ⌫ delete, Return open (all suppressed while text input active).
- Single view: type pills + filename search (150ms debounce, `HistorySearchViewModel`) + time filters all / 24H / 7D / 30D (`HistoryFloatingTimeFilter`) + one horizontal card row (drag + trackpad scroll) + multi-select + selection bar.

## Card Actions

- Context menu (`HistoryContextMenu`): Open in Finder, Copy, Edit, Delete — destructive last. Cloud upload affordances were removed.
- Double-click opens the editor; cards expose a Restore pill.
- History remains local capture history; it no longer uploads captures.

## Restore Flow

```mermaid
flowchart TD
    A["History item open / Edit"] --> B["HistoryWindowController.openItem(record)"]
    B --> C["QuickAccessManager.restoreHistoryItem(record)"]
    C --> D{"Quick Access card for URL exists?"}
    D -->|Yes| E["Reuse existing card"]
    D -->|No| F["Insert restored card with history thumbnail metadata"]
    E --> G{"Capture type"}
    F --> G
    G -->|Screenshot| H["AnnotateManager.openAnnotation(for:)"]
    H --> H1{"Editable session?"}
    H1 -->|QA cache| H2["In-memory AnnotationSessionData"]
    H1 -->|Sidecar| H3["AnnotationSessionStore.load (signature-validated)"]
    H1 -->|No| H4["Open flattened image"]
    G -->|Video / GIF| I["VideoEditorManager.openEditor(for:)"]
```

- Sidecar package format and signature validation: see [ANNOTATE.md](ANNOTATE.md#session-sidecars).
- Restored saves follow the same Quick Access session behavior as fresh captures; already-saved files expose Open in the save/open slot.

## Storage

- Database: GRDB SQLite at `~/Library/Application Support/Cue/cue.db` via `DatabaseManager` (`Services/Cloud/`). Migrations: `v1_createCloudUploadRecords`, `v2_createCaptureHistoryRecords`. Launch repair/reset recovery archives db files to `DatabaseRecovery-<timestamp>/`.
- `CaptureHistoryStore` — GRDB `ValueObservation` publishes records; `add` is a no-op when `history.enabled` is off; `updateFilePath` (temp→export move), `markFileChanged`, `hasRecord(forFilePath:)`, `removeByFilePath`.
- Media files: temp captures live in Application Support temp root; saved captures in the user export folder — history only records paths.
- Thumbnails: `HistoryThumbnailGenerator` — JPEG, max dimension 208, stored in `HistoryThumbnails/`; `NSCache` memory cache 160 items / 48MB.

## Retention

- `CaptureHistoryRetentionService` — sweep at launch + every 24h timer.
- Prefs: `history.retentionDays` (default 30, 0 = forever), `history.maxCount` (default 500, 0 = unlimited).
- Sweep deletes: records older than retention, count-overflow records, unreferenced temp files, orphan thumbnails, orphan annotation sidecars (source gone / no active record / signature mismatch).
- `clearAllHistory()` deletes records + thumbnails + sidecars but keeps capture files on disk.
- `history.floating.autoClearDays` is persisted/exported but never consumed — dead setting.

## Temp File Interplay

- Launch `TempCaptureManager.cleanupOrphanedFiles` skips files referenced by active history records and keeps recent temp files while history is enabled (retention window); retention owns their eventual deletion.
- Quick Access dismiss deletes the temp file unless a history record exists; Quick Access delete removes the record first so the temp file actually goes away.

## Preferences Surface

Settings → History: enable toggle, floating panel position, display (default filter, background), retention days / max count, storage info. See [PREFERENCES.md](PREFERENCES.md).

## Dead / Legacy Code

Unused (kept in tree): `HistoryMainView` (except `HistoryBackdropView`, still used by the floating panel and preferences), `HistoryItemView`, `HistoryToolbar`, `HistoryFilterBar`, `HistoryGridView`. The live card view is `HistoryExpandedCaptureCardView`.

## Related docs

- [QUICK_ACCESS.md](QUICK_ACCESS.md) — restore target and card lifecycle
- [ANNOTATE.md](ANNOTATE.md) — editable session restore, sidecar format
- [VIDEO_EDITOR.md](VIDEO_EDITOR.md) — video/GIF restore target
- [POST_CAPTURE.md](POST_CAPTURE.md) — where history records are created
- [CLOUD.md](CLOUD.md) — ImgBB sharing and the retired upload-record boundary
- [PREFERENCES.md](PREFERENCES.md) — settings keys
