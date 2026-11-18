# Spec

The source of truth every SDK is tested against.

| Path | What it is |
|---|---|
| `schema/events-post-body.schema.json` | Snapshot of the request body for `POST /v1/workspaces/{workspaceId}/events`. |
| `schema/event-data-types.json` | The API's named data types (`Cart`, `CartLine`, `Money`, …), used to name the generated `Angler*` models. |
| `fixtures/deeplinks.json` | URL → click IDs. |
| `fixtures/install-referrer.json` | Play Install Referrer string → click IDs. |
| `fixtures/payloads.json` | Track call + device state → the exact event JSON. |
| `fixtures/response-policy.json` | HTTP status → what the SDK does with the batch. |
| `fixtures/backoff.json` | Retry attempt → delay. |
| `fixtures/typed-data.json` | Typed data objects → JSON, validated against the schema. |

`npm test` checks that every fixture payload validates against the schema snapshot. To refresh
the snapshot from the API repo and regenerate the typed models:

```sh
node scripts/export-schema.mjs <path to the API repo> origin/main
node ../scripts/generate-models.mjs
```
