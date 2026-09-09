# ADR 073: Prepare smaller image derivatives for uploads

- Status: Accepted
- Date: 2026-08-14
- Updated: 2026-09-09

## Context

Retina captures can contain twice the logical screen dimensions and were being
sent to the direct image host at their original PNG size. Local captures and annotated source
images must remain available at their original quality.

## Decision

Cue applies one shared image-upload encoding policy before sending static images
to ImgBB or ImageKit:

- optimize image uploads by default;
- limit the longest physical pixel edge to 2048 px by default;
- encode optimized images as WebP by default, with JPEG and PNG alternatives;
- JPEG/WebP quality ranges from 50% to 100%;
- use WebP when JPEG is selected for an image with transparency.

Those values live under `PreferencesKeys.upload*` / `config.toml` `[uploads]`
and are read by `CueUploadEncodingSettings`. The **Uploads** Settings destination
configures provider and credentials only; it does not currently expose encoding
controls in the UI. Operators change encoding through configuration import /
`config.toml` until a Settings surface is added.

Static image uploads receive a temporary derivative. GIFs and supported videos
pass through unchanged so animation and playback are preserved. The original
file remains the authoritative local source, and any temporary derivative is
removed after the request finishes.

## Consequences

Direct image uploads are materially smaller while annotations and local files
retain their source dimensions. Local history retains the original filename,
but the uploaded content type and size describe the derivative. GIFs and
videos retain their original content type and bytes. Disabling optimization
(via configuration) passes file-backed source bytes through unchanged; in-memory
Annotate renders use a full-size lossless PNG because no original file encoding
exists.

Server-side resizing and a hard byte-budget loop were not added: the local
physical-pixel limit plus selected format/quality is deterministic and keeps
the direct upload operation predictable.
