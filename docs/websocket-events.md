# WebSocket events (`/api/v1/ws`)

**Normative copy:** the full wire protocol (envelopes, `session.auth`, Harness events, legacy mapping, errors) is the **`description`** of **`GET /api/v1/ws`** in the merged OpenAPI document. The prose is maintained as **`backend/src/openapi_spec/ws_protocol_description.md`** and included from **`#[utoipa::path]`** on `crate::harness::ws::upgrade::ws_upgrade`; served at **`GET /api/v1/openapi.yaml`** or **`cargo run --bin export-openapi`** from `backend/`.

**For humans:** use **Swagger UI** at `GET /api/v1/docs` and expand **GET /api/v1/ws**, or edit **`ws_protocol_description.md`** next to the handler’s OpenAPI macro.

This file stays in the repo so links from `AGENTS.md`, parity docs, and PR templates keep a stable path; when the protocol changes, update **`ws_protocol_description.md`** and refresh this pointer if needed.
