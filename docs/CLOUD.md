# Sharing and cloud boundary

Notinhas keeps sharing local and explicit. Captures can be copied to the
clipboard, saved/exported locally, or uploaded from Annotate and Quick Access
to the selected image host: ImgBB or ImageKit. The upload action is explicit;
the copied URL is public to anyone who receives it.

The AWS S3, Cloudflare R2, and Google Drive BYO upload stack is retired. There
is no OAuth flow, upload-history window, usage statistics, cloud password,
credential-transfer, or generic cloud-upload action. The Video module
remains available; only its cloud affordances were removed.

Provider credentials remain in `CloudKeychainStore` and are cleared only by the
explicit action for the selected provider. Capture history and
`DatabaseManager` remain intact. Direct credentials are intended for this
personal app only; image hosts are not a replacement for the retired generic
cloud architecture.
Legacy cloud keychain readers and persisted `cloudURL`/`cloudKey` fields remain
for migration and decoding compatibility.

Migration is non-destructive: old `[cloud]` configuration keys are ignored,
legacy fields are not erased, and Notinhas does not delete remote objects,
Keychain items, or user configuration files. See [MIGRATION.md](MIGRATION.md).

Related docs: [ANNOTATE.md](ANNOTATE.md), [QUICK_ACCESS.md](QUICK_ACCESS.md),
[HISTORY.md](HISTORY.md), [POST_CAPTURE.md](POST_CAPTURE.md),
[PREFERENCES.md](PREFERENCES.md), and [VIDEO_EDITOR.md](VIDEO_EDITOR.md).

Provider availability and benchmark method are recorded in
[UPLOAD_PROVIDER_BENCHMARK.md](UPLOAD_PROVIDER_BENCHMARK.md). UploadThing is
not available; see [ADR 074](adr/074-uploadthing-direct-rest-stop.md).
