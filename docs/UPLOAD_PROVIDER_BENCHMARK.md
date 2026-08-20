# Upload provider benchmark

Status: not run with real provider credentials. No timings, failure rates, or
URL-usability claims are recorded.

## Decision

- Available direct providers: ImgBB and ImageKit.
- UploadThing is unavailable and feasibility-stopped; see [ADR 074](adr/074-uploadthing-direct-rest-stop.md).
- ImgBB remains the persisted compatibility default. A user may explicitly select ImageKit in Preferences → Uploads; the app does not auto-route, fall back, or silently migrate an existing selection.
- With no comparable local runs, there is no performance winner. Keep ImgBB as the conservative compatibility recommendation until a credentialed benchmark is completed.

## Safe benchmark method

Use a disposable, non-sensitive screenshot and the same encoded bytes/settings
for every provider and entry point. Record only pixel dimensions, format,
encoded byte count, optimization settings, approximate date/region/network,
provider/account region if non-secret, and one row per run. Do not commit the
fixture, credentials, private response bodies, or full URLs.

For each available provider, run five cold and five warm attempts from each
entry point: Annotate final-image upload and Quick Access file upload. Measure
manually from the explicit action: local encoding, provider request, any
second-stage work, total action, clipboard completion, success/failure category,
and whether the copied HTTPS URL opens later. Compare medians; treat failures
and URL usability as first-class results. Do not retry a timeout automatically.

| Provider | Entry point | Cold total | Warm totals | Median request | Median total | Failures | URL usable |
|---|---|---:|---:|---:|---:|---:|---|
| ImgBB | Annotate | n/a | n/a | n/a | n/a | n/a | not checked |
| ImgBB | Quick Access | n/a | n/a | n/a | n/a | n/a | not checked |
| ImageKit | Annotate | n/a | n/a | n/a | n/a | n/a | not checked |
| ImageKit | Quick Access | n/a | n/a | n/a | n/a | n/a | not checked |
| UploadThing | Annotate | n/a | n/a | n/a | n/a | n/a | unavailable |
| UploadThing | Quick Access | n/a | n/a | n/a | n/a | n/a | unavailable |

## Why the gate is unavailable here

This executor has no authorized disposable provider credentials or manual
account/UI session. Network access to official documentation is available, but
that does not prove an upload. No remote files were created and no secrets were
requested. The benchmark remains a manual gate for a user with both accounts.

Before recommending ImageKit, recheck its official [upload contract](https://imagekit.io/docs/api-reference/upload-file/upload-file)
and [plans](https://imagekit.io/plans), including current storage, bandwidth,
upload-size, rate, retention, public-link, and overage terms. These external
terms can change and are not encoded in Swift. This document intentionally
avoids treating plan values as permanent.

## Manual readiness matrix

Manual checks remain open for both available providers: configure/save and
masked state after relaunch; Annotate and Quick Access upload; copied URL open;
clear, missing, invalid, and offline credential behavior; Light/Dark appearance;
video/GIF exclusion; and inspection that export/diagnostics contain no secret.
Also verify no upload occurs when a card/window appears, no fallback occurs,
the previous successful URL survives failure, and provider switching does not
cross-save credential text.
