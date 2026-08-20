# Engineering security notes

Companion to the root [SECURITY.md](../SECURITY.md) policy. Describes runtime security behavior for contributors and agents.

## Threat model summary

- Local-first capture and history on disk under Application Support
- Optional outbound network only for user-configured ImgBB image uploads
- No automatic update fetches, telemetry, or crash upload endpoints
- No in-app **Report a Problem** or diagnostic zip upload

## Entitlements

Review `Notinhas/Notinhas.entitlements` before adding capabilities. Document new entitlements in root SECURITY.md.

Notinhas does **not** ship Sparkle mach-lookup entitlements (`-spks` / `-spki`).

## Permissions

| TCC | Bundle IDs |
| --- | --- |
| Screen Recording | `com.mourato.notinhas`, `com.mourato.notinhas.debug` |
| Accessibility | same |
| Microphone | same (Video module) |

TCC grants do not migrate from legacy Snapzy bundle IDs — see [MIGRATION.md](MIGRATION.md).

## Secrets

- ImgBB API key: Keychain item `com.mourato.notinhas.cloud.imgbbAPIKey` (configured in Preferences → Uploads; legacy `notinhas.imgbb.apiKey` UserDefaults is migrated on read)
- Never commit keys, `.p12` files, or webhook URLs

## Deep links

Only `notinhas://` is registered. Legacy `snapzy://` requests are rejected by
design (see `NotinhasTests` deep-link rejection tests).

## Dependency review

Audit `Package.resolved` when adding SPM packages. Dependencies that existed
only for the removed updater must not return.

## Contributor checklist

- [ ] No new network endpoints without user action
- [ ] No plaintext secrets in UserDefaults or TOML export
- [ ] TOML export excludes Keychain material ([CONFIGURATION.md](CONFIGURATION.md))
- [ ] Security-sensitive changes update root SECURITY.md
