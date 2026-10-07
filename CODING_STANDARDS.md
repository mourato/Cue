# Cue coding standards

Read during review (Standards axis) and retro. Extends the global standards at
`${AGENT_CONFIG_HOME:-$HOME/.agents}/core/standards/CODING_STANDARDS.md` and the
`swift-conventions` skill; project rules only.

- Cue models and views colocate in `Cue/Features/Cue/`; add small protocols or
  adapters in `Services/` only to cross a platform boundary.
- Keep integration points into upstream capture/annotation flows thin; do not
  rename, move, or rewrite upstream code to match a new design.
- Move capture, file, and image processing off the main actor via value
  snapshots or focused adapters.
- SwiftUI `body` stays cheap: no synchronous Keychain/`securityd`, disk, or XPC
  in `body` or properties it reads; cache as `@Published`, refresh on mutation.
- XCTest cases live in the matching `CueTests/` area, named by behavior
  (`testPinNoteExportKeepsMarkerOrder()`).
- `Snapzy`/`Notinhas` strings are legacy compatibility only; never active
  branding.
