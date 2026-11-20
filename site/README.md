# site/

Pages published on the public docs site (docs.getangler.ai), which is built from the private
`angler-ai/angler-docs` repo by ReadMe.

| File | Published as |
|---|---|
| `mobile-sdk.md` | **Sending Data to Angler AI → Mobile SDK** (`/docs/mobile-sdk`) |

Edit the page here, not in ReadMe or angler-docs: when a change to `site/` reaches `main`,
`.github/workflows/sync-docs.yml` copies it to angler-docs and opens (or updates) a PR there on
the `sync/angler-mobile-sdk` branch. Changes made on the docs side are overwritten by the next
sync.

- **Format:** ReadMe Markdown (MDX). Keep the frontmatter, don't use HTML comments, and link to
  other docs pages as `/docs/<slug>`.
- **Versions** in install snippets are kept current by `node scripts/sync-version.mjs`.
- **Public:** like everything in this repo, no customer names, internal links or secrets.
- **Setup:** the workflow needs the secret `ANGLER_DOCS_TOKEN`, a fine-grained token with
  Contents and Pull requests read/write on `angler-ai/angler-docs` only.
