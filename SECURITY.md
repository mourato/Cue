# Security Policy

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues, discussions, or pull requests.**

Report them privately using:

1. **GitHub Security Advisory** — [github.com/mourato/Cue/security/advisories/new](https://github.com/mourato/Cue/security/advisories/new)

Please include:

- Description of the vulnerability
- Steps to reproduce or a proof-of-concept
- Affected version(s) and macOS version
- Potential impact

You should receive an initial acknowledgment within **72 hours**. A fix or mitigation will be communicated before public disclosure when applicable.

## Supported Versions

| Version | Supported |
| ------- | --------- |
| Latest release | ✅ |
| Older releases | ❌ — install the current DMG from [Releases](https://github.com/mourato/Cue/releases) |

Cue does not ship in-app automatic updates. Security fixes are delivered as new GitHub Release DMGs.

## App Sandbox & Permissions

Cue runs with **hardened runtime**. Entitlements are limited to what capture, optional cloud upload, and diagnostics require.

| Permission | Required | Why |
| --- | --- | --- |
| Screen Recording | Yes | Core functionality — ScreenCaptureKit capture |
| Microphone | Optional | Voice in recordings when the Video module is enabled |
| Accessibility | Optional | Global shortcuts, Fn bindings, keystroke overlays |

Permissions are requested through standard macOS prompts and can be revoked in **System Settings → Privacy & Security**.

## Data Handling

- **Local-first** — Captures and history stay on disk under `~/Library/Application Support/Cue/`.
- **No telemetry** — No analytics, tracking, or usage data is collected.
- **No accounts** — No sign-in or registration.
- **Network usage** — Limited to user-initiated cloud uploads (when configured) and local loopback OAuth for Google Drive. No automatic update checks.
- **Diagnostics** — Optional local log files in `~/Library/Logs/Cue/`; never uploaded automatically.

## Cloud Credentials

When cloud upload is configured:

- Credentials and OAuth tokens live in the macOS Keychain (`com.mourato.cue.cloud`).
- Optional password protection uses SHA-256 hashing; plaintext passwords are not stored.
- Encrypted export/import requires a user-supplied archive passphrase.
- Uploads go directly to the user's storage; Cue does not proxy files.

## Third-Party Dependencies

Cue relies primarily on Apple frameworks (SwiftUI, AppKit, ScreenCaptureKit, Vision, AVFoundation). Optional packages are vendored through Swift Package Manager for specific features (for example image encoding). There is **no Sparkle** or other auto-update framework.

## Security Best Practices for Contributors

- Do not hard-code secrets, keys, or tokens in source.
- Do not introduce new entitlements without documenting the reason.
- Do not weaken hardened runtime or sandbox boundaries without explicit review.
- Follow Apple's [Secure Coding Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/) for new platform integrations.

## License

This security policy is part of the [Notinhas](https://github.com/mourato/Cue) project, licensed under the [BSD 3-Clause License](LICENSE).
