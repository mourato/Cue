# ADR 073: Prepare smaller image derivatives for uploads

- Status: Accepted
- Date: 2026-08-14

## Context

Retina captures can contain twice the logical screen dimensions and were being
sent to the direct image host at their original PNG size. Local captures and annotated source
images must remain available at their original quality.

## Decision

The Uploads preferences tab controls one shared image-upload policy:

- optimize image uploads by default;
- limit the longest physical pixel edge to 2048 px by default;
- encode optimized images as WebP by default, with JPEG and PNG alternatives;
- expose exact JPEG/WebP quality from 50% to 100% in 1% steps;
- use WebP when JPEG is selected for an image with transparency.

ImgBB and ImageKit receive a temporary derivative. The original file remains
the authoritative local source, and the derivative is removed after the
request finishes. Videos and unsupported formats pass through unchanged.

## Consequences

Direct image uploads are materially smaller while annotations and local files
retain their source dimensions. Local history retains the original filename,
but the uploaded content type and size describe the derivative. Users can
disable optimization when exact source bytes are required.

Server-side resizing and a hard byte-budget loop were not added: the local
physical-pixel limit plus user-selected format/quality is deterministic and
keeps the direct upload operation predictable. Disabling optimization passes
file-backed source bytes through unchanged; in-memory Annotate renders use a
full-size lossless PNG because no original file encoding exists.
