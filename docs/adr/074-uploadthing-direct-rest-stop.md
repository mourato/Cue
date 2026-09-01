# ADR 074: Stop direct UploadThing REST integration

- Status: Stopped — not viable under the no-server constraint
- Date: 2026-08-20

## Context

Plan 098 evaluated whether the personal local macOS app could upload one
encoded image directly to UploadThing, without a Cue server, file router,
callback, webhook, browser session, or new dependency. The provider was not
implemented because the official contract did not pass that feasibility gate.

## Official contract record

Verified against the official documentation on 2026-08-20:

```text
API version: v7 is current for the server-side token/configuration model;
  the OpenAPI page also lists versioned v6 operations and /v7/prepareUpload.
Endpoint(s): /v7/prepareUpload is documented as a REST helper for generating
  file keys; server-side upload is exposed through UTApi.uploadFiles.
Authentication header/shape: x-uploadthing-api-key for the REST API; v7 also
  uses an UPLOADTHING_TOKEN containing app/account information and an API key.
Request content type: not sufficiently specified for a supported direct
  desktop upload contract.
Required fields: not sufficiently specified for a supported direct desktop
  upload contract.
Public-link/ACL fields: public-read and inline are documented as server-side
  upload options; no complete direct desktop publication contract was found.
Response URL field: server-side upload responses contain file information, but
  no direct desktop response contract was documented for this flow.
Second-stage request, if any: presigned storage upload is described, but the
  supported client flow requires a backend/file-router boundary and registration
  can require a callback URL.
Timeout/async behavior: no bounded, supported no-server flow was documented.
Official source URLs and access date: the URLs below, 2026-08-20.
Reason no server/callback is required: not established; official docs instead
  assign client presigning to a server and UTApi uploads to a server.
```

Sources:

- [OpenAPI Specification](https://docs.uploadthing.com/api-reference/openapi-spec)
- [Uploading Files](https://docs.uploadthing.com/uploading-files)
- [v7 migration guide](https://docs.uploadthing.com/v7)
- [UTApi](https://docs.uploadthing.com/api-reference/ut-api)
- [Regions and ACL](https://docs.uploadthing.com/concepts/regions-acl)
- [UploadThing](https://uploadthing.com/)

## Decision

Do not add UploadThing to Cue. The current official client-side flow
requests presigned URLs from an application backend/file router. The official
server-side flow assumes the file has already reached a server and uses
`UTApi.uploadFiles`; it is not a desktop-client upload contract. The
documentation also describes upload registration and callback handling for the
client-side route flow.

Implementing from the undocumented parts would require guessing request fields,
file identity/signing, final URL publication, or account permissions. That
violates Plan 098's gate and could create orphaned remote files. No manual
account upload was attempted because the official contract failed first.

ImgBB and ImageKit remain the available direct providers from Plan 097. Plan
099 may document those providers and this feasibility result; it must not
assume UploadThing is available.
