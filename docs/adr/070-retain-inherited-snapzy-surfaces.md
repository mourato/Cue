# ADR 070: Retain Inherited Snapzy Surfaces

## Status

Superseded by Plan 089 (2026-08-20). The retention decision below is historical
context; [`docs/CLOUD.md`](../CLOUD.md) defines the current boundary.

## Context

Notinhas is a fork of [Snapzy](https://github.com/duongductrong/Snapzy) focused on
visual handoff: area capture → numbered pins/rects with notes → clipboard-ready
export. The fork inherits a broad surface area from upstream — capture modes,
annotate tools, BYO cloud providers, and distribution helpers — while explicitly
removing upstream-only channels (Sparkle auto-updates, `snapzy://` aliases,
public support endpoints, and similar).

Dead-code cleanup and product-scope reviews must not treat inherited Snapzy
features as removable by default. Some surfaces were already removed when they
duplicated or conflicted with Notinhas intent (for example, standalone
`MockupManager` in plan 075). This ADR records what stays and what does not
return.

## Decision

1. **Capture extras — RETAIN** scrolling capture, OCR/QR text capture, Smart
   Element capture, object cutout (foreground extraction), and All-In-One HUD
   (mode + area + dimensions). These remain available upstream paths; Notinhas
   handoff does not require them but designers may use them before annotate.
2. **BYO cloud — RETIRED** AWS S3, Cloudflare R2, and Google Drive upload
   providers were removed by Plan 089. ImgBB remains the handoff-oriented
   image host for briefs.
3. **Annotate toolbelt — RETAIN** watermark, combine (image stitch/canvas),
   and integrated mockup tooling in Annotate. Standalone `MockupManager` was
   already removed (plan 075); do not reintroduce a separate mockup app surface.
4. **Distribution —** manual GitHub Releases with `Notinhas-v<version>.dmg`
   only. **NO** Homebrew cask formula and **NO** Discord release bot or
   automated community release notifications. Optional `install.sh` /
   `uninstall.sh` remain convenience helpers for local install/wipe — not
   primary distribution.
5. **`install.sh` / `uninstall.sh` — KEEP** as optional convenience scripts;
   they are not the primary distribution channel.

## Consequences

- Future dead-code passes and scope reviews consult this ADR for historical
  context; Plan 089 and the current cloud boundary govern sharing behavior.
- ImgBB stays aligned with handoff; local save/copy/export remains available.
- Distribution docs and release automation must not add Homebrew cask publishing
  or Discord release bots without a new ADR superseding this one.
- Removed upstream channels (Sparkle, `snapzy://`, support endpoint, etc.)
  remain out of scope per `AGENTS.md` Product Intent — this ADR does not revive
  them.
