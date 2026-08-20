# Sharing and cloud boundary

Notinhas keeps sharing local and explicit. Captures can be copied to the
clipboard, saved/exported locally, or uploaded to ImgBB from Annotate and
Quick Access when an ImgBB API key is configured.

The AWS S3, Cloudflare R2, and Google Drive BYO upload stack is retired. There
are no provider settings, OAuth flow, upload-history window, usage statistics,
cloud password, credential-transfer, or cloud-upload actions. The Video module
remains available; only its cloud affordances were removed.

ImgBB credentials remain in `CloudKeychainStore` and are cleared only by the
explicit ImgBB action. Capture history and `DatabaseManager` remain intact.
Legacy cloud keychain readers and persisted `cloudURL`/`cloudKey` fields remain
for migration and decoding compatibility.

Migration is non-destructive: old `[cloud]` configuration keys are ignored,
legacy fields are not erased, and Notinhas does not delete remote objects,
Keychain items, or user configuration files. See [MIGRATION.md](MIGRATION.md).

Related docs: [ANNOTATE.md](ANNOTATE.md), [QUICK_ACCESS.md](QUICK_ACCESS.md),
[HISTORY.md](HISTORY.md), [POST_CAPTURE.md](POST_CAPTURE.md),
[PREFERENCES.md](PREFERENCES.md), and [VIDEO_EDITOR.md](VIDEO_EDITOR.md).
