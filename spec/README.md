# Spec

The source of truth for every SDK:

- Event payload schema for `POST /v1/workspaces/{workspaceId}/events` with `src` = `IOS` / `ANDROID`
- Standard device and app fields, and the persistent install ID (the app equivalent of the web `_aid`)
- Identifier names, which must match the web pixel and the backend (`gclid`, `fbclid`, `ttclid`, …)
- Attribution inputs: deep-link click IDs, Play Install Referrer, SKAdNetwork/AdAttributionKit

`fixtures/` will hold shared golden tests that every SDK's tests run against (URL → identifiers, event → payload).
