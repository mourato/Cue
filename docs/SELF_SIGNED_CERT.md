# Self-Signed Certificate Setup

Cue can use a stable self-signed certificate for local release testing.
This preserves macOS TCC permissions when replacing builds signed with the same
identity; it does not provide an in-app update channel or bypass the required
permission re-grant after the bundle identifier changes.

## Why This Matters

macOS tracks app permissions by **code signing identity**. Ad-hoc signing (`codesign --sign -`) produces a unique identity per build, so every update causes macOS to revoke permissions. A persistent self-signed certificate fixes this.

## One-Time Setup

### 1. Generate the Certificate

```bash
chmod +x scripts/create-signing-cert.sh
./scripts/create-signing-cert.sh
```

You'll be prompted for a password — remember it for step 2.

### 2. Add GitHub Secrets

Go to **Settings → Secrets and variables → Actions** in your GitHub repo and add:

| Secret Name | Value |
|---|---|
| `SELF_SIGNED_CERT_P12` | Base64 output from the script |
| `SELF_SIGNED_CERT_PASSWORD` | The password you entered |

### 3. Verify

Push a release and check the "Import self-signed certificate" step in the workflow logs. You should see the certificate imported successfully.

## Local Testing

Use `scripts/test-tcc-local.sh` to verify TCC permissions persist across
same-identity replacements locally. The helper defaults to an isolated install
under `/tmp/test-tcc-notinhas/Applications/Cue.app` so it does not replace
your `/Applications/Cue.app` unless you explicitly opt in.

```bash
# Step 1: Generate cert and import into login keychain
./scripts/create-signing-cert.sh

# Step 2: Build, sign with self-signed cert, install as build-v1
./scripts/test-tcc-local.sh build-v1
# → Open the reported isolated app path
# → Grant Screen Recording + Microphone manually in System Settings

# Step 3: Re-sign and reinstall from the same v1 archive
./scripts/test-tcc-local.sh build-v2
# → Open the reported app path
# → Verify permissions are STILL granted ✅

# (Optional) Compare with ad-hoc to prove the difference
./scripts/test-tcc-local.sh compare
# → Open the reported app path
# → Permissions are LOST ❌ (expected ad-hoc control)
```

Each stage writes a metadata report under `/tmp/test-tcc-notinhas/reports/`
with the stage label, archive path, install path, signing identity kind, and
verification result. Reports never include certificate passwords, private key
material, or permission database contents.

System installation is opt-in only:

```bash
./scripts/test-tcc-local.sh \
  --install-path /Applications/Cue.app \
  --allow-system-install \
  build-v1
```

Non-interactive runs refuse `/Applications` unless both flags are present.
Interactive runs also require typing the exact install path to confirm.

Clean up test artifacts when done:

```bash
./scripts/test-tcc-local.sh clean
```

## Signing Hierarchy

The release workflow uses this fallback chain:

1. **Developer ID** — best (Gatekeeper pass + TCC persist). Requires Apple Developer Program.
2. **Self-signed cert** — good (TCC persist, Gatekeeper warning on first install).
3. **Ad-hoc** — worst (TCC may be revoked when the build identity changes).

## Upgrading to Developer ID

When you enroll in Apple Developer Program:

1. Add `DEVELOPER_ID_P12`, `DEVELOPER_ID_PASSWORD` secrets
2. Optionally add `APPLE_ID`, `APPLE_ID_PASSWORD`, `APPLE_TEAM_ID` for notarization
3. Remove `SELF_SIGNED_CERT_P12` and `SELF_SIGNED_CERT_PASSWORD` (optional)
4. Users re-grant permissions **once** when switching to the new Notinhas bundle
   identity

## Certificate Renewal

The default certificate is valid for 10 years. To regenerate:

```bash
./scripts/create-signing-cert.sh "Cue Self-Signed" 3650
```

Then update the GitHub Secrets with the new values.
