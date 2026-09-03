# Sharing and cloud boundary

Cue keeps sharing local and explicit. Captures can be copied to the
clipboard, saved/exported locally, or uploaded from Annotate and Quick Access
to the selected host: ImgBB, ImageKit, or the user's Cloudflare Worker. Quick Access can upload the original
GIF/video when the selected provider supports that media. If an ImageKit video
reaches the configured safe target, Quick Access offers a local MP4/H.264
derivative with selectable dimensions, quality, frame rate, and audio. The
original is never replaced; only the verified derivative is uploaded. Annotate
uploads its final composed image. The upload action is explicit; the copied URL
is public to anyone who receives it.

The generic AWS S3/R2/Google Drive BYO stack remains retired. Cloudflare is a
deliberate limited exception: the user's Worker owns R2/D1 and receives only
explicit uploads. There is no OAuth flow, upload-history window, usage statistics, cloud password,
credential-transfer, or generic cloud-upload action. The Video module remains
available, and ImageKit is the provider for explicit video uploads.

Provider credentials remain in `CloudKeychainStore` and are cleared only by the
explicit action for the selected provider. Capture history and
`DatabaseManager` remain intact. Direct credentials are intended for this
personal app only; image hosts are not a replacement for the retired generic
cloud architecture.
Cloudflare uses a fixed 95 MiB client target; the Worker streams uploads to R2
and serves a minimal public image/video page. The Worker URL is stored in
UserDefaults and its upload token only in Keychain. ImageKit does not expose the account plan's upload limit through the API. The
Uploads preferences therefore let the user select Free (100 MB), Lite (300
MB), Pro (2 GB), or enter a custom limit for an adjustable plan. Cue uses 95%
of that value as the preflight target so the multipart request has headroom.
Legacy cloud keychain readers and persisted `cloudURL`/`cloudKey` fields remain
for migration and decoding compatibility.

Migration is non-destructive: old `[cloud]` configuration keys are ignored,
legacy fields are not erased, and Cue does not delete remote objects,
Keychain items, or user configuration files. See [MIGRATION.md](MIGRATION.md).

Related docs: [ANNOTATE.md](ANNOTATE.md), [QUICK_ACCESS.md](QUICK_ACCESS.md),
[HISTORY.md](HISTORY.md), [POST_CAPTURE.md](POST_CAPTURE.md),
[PREFERENCES.md](PREFERENCES.md), and [VIDEO_EDITOR.md](VIDEO_EDITOR.md).

Provider availability and benchmark method are recorded in
[UPLOAD_PROVIDER_BENCHMARK.md](UPLOAD_PROVIDER_BENCHMARK.md). UploadThing is
not available; see [ADR 074](adr/074-uploadthing-direct-rest-stop.md). The
personal direct-credential boundary is recorded in [ADR 075](adr/075-direct-image-provider-boundary.md).
