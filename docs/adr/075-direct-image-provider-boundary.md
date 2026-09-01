# ADR 075: Direct image-provider boundary

- Status: Accepted
- Date: 2026-08-20

## Context

Cue is a personal local macOS visual-handoff tool with no server budget
or multi-user distribution model. The app already composes an annotated image
locally and needs an explicit way to copy a shareable public URL. Generic BYO
cloud storage was retired by Plan 089; the remaining feature is image hosting
for the capture → annotate → clipboard workflow.

## Decision

- Keep ImgBB as the compatibility default and allow explicit selection of
  ImageKit in Preferences → Uploads.
- Send one encoded image directly to the selected provider over HTTPS only
  after an explicit Annotate or Quick Access action.
- Store each provider credential in its own Keychain item. Store only the
  selected provider as local non-secret preference state; never export secrets.
- Keep provider adapters thin and Foundation-only. Do not add a Cue
  server, proxy, callback, upload history, automatic retry, fallback, or
  latency-based routing.
- Treat returned links as public to anyone who receives them. Do not describe
  this as private storage, encrypted storage, or guaranteed retention.
- Keep UploadThing unavailable until it documents a complete no-server desktop
  contract; Plan 098's stop is recorded in [ADR 074](074-uploadthing-direct-rest-stop.md).

## Consequences

This is acceptable for the sole local account owner, but it is not a safe
credential model for distributing the app to other users. Provider quotas,
pricing, retention, and URL behavior remain external and can change. A failed
request can still create a remote object; Cue does not provide automatic
cleanup or retry. Existing ImgBB credentials and persisted action identifiers
remain compatible.

## Revisit triggers

Reconsider this boundary if Cue is distributed to other users, private
links or remote deletion become requirements, a provider changes its
authentication/upload contract, or a trusted backend becomes available.
