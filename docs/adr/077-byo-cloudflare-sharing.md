# ADR 077: Bring-your-own Cloudflare Worker sharing

Status: accepted

Cue supports an explicit, user-triggered Cloudflare Worker upload alongside
ImgBB (the default) and ImageKit. The Worker URL is non-secret UserDefaults
configuration; `UPLOAD_TOKEN` is stored only in the macOS Keychain.

The app sends the original or the existing reusable encoded/transcoded
derivative with `Authorization: Bearer`, `Content-Type`, and `X-Filename`
headers using file-backed `URLSession.upload(for:fromFile:)`. Uploads are
limited to 95 MiB, validate HTTP/HTTPS endpoints and JSON public URLs, and
clean up temporary derivatives without deleting originals.

This is not the companion Worker implementation. Deployment, token creation,
authentication policy, storage, and public URL behavior remain the user's
responsibility. Cue does not create Cloudflare resources or provide a central
backend. The stable action persistence identifier remains `uploadToImgBB`; its
display label follows the selected provider.
