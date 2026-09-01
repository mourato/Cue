# Engineering security notes

Companion to the root [SECURITY.md](../SECURITY.md) policy. Describes runtime security behavior for contributors and agents.

## Threat model summary

- Local-first capture and history on disk under Application Support
- Optional outbound network only after an explicit upload action through the selected ImgBB or ImageKit image host
- No automatic update fetches, telemetry, or crash upload endpoints
- No in-app **Report a Problem** or diagnostic zip upload

## Entitlements

Review `Cue/Cue.entitlements` before adding capabilities. Document new entitlements in root SECURITY.md.

Cue does **not** ship Sparkle mach-lookup entitlements (`-spks` / `-spki`).

## Permissions

| TCC | Bundle IDs |
| --- | --- |
| Screen Recording | `com.mourato.cue`, `com.mourato.cue.debug` |
| Accessibility | same |
| Microphone | same (Video module) |

TCC grants do not migrate from legacy Snapzy bundle IDs — see [MIGRATION.md](MIGRATION.md).

## Secrets

- ImgBB API key and ImageKit private key: provider-scoped Keychain items (configured in Preferences → Uploads; the legacy ImgBB UserDefaults key is migrated on read). Secrets are never exported to TOML, diagnostics, logs, clipboard, or UI text except masked summaries.
- Copied provider URLs are public to anyone who receives them. Direct client credentials are a personal-use exception, not a multi-user distribution security model.
- Never commit keys, `.p12` files, or webhook URLs

## Deep links

Only `cue://` is registered. Legacy `snapzy://` requests are rejected by
design (see `CueTests` deep-link rejection tests).

## Dependency review

Audit `Package.resolved` when adding SPM packages. Dependencies that existed
only for the removed updater must not return.

## Contributor checklist

- [ ] No new network endpoints without user action
- [ ] No plaintext secrets in UserDefaults or TOML export
- [ ] TOML export excludes Keychain material ([CONFIGURATION.md](CONFIGURATION.md))
- [ ] Security-sensitive changes update root SECURITY.md

No automatic upload, fallback, telemetry, crash/support upload, server, or background cloud synchronization is introduced. Provider limits and terms remain external; Cue does not promise privacy, durability, free usage, or performance.
