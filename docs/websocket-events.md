# WebSocket events (`/api/v1/ws`)

**Normative copy:** the full wire protocol (envelopes, `session.auth`, Harness events, legacy mapping, errors) lives in the **merged OpenAPI** document: embedded **`backend/src/openapi_spec/openapi_base.yaml`** (WebSocket operation) plus handler-level utoipa paths; served at **`GET /api/v1/openapi.yaml`** or **`cargo run --bin export-openapi`** from `backend/`.

**For humans:** use **Swagger UI** at `GET /api/v1/docs` and expand **GET /api/v1/ws**, or open `openapi_base.yaml` and search for `/api/v1/ws:`.

This file stays in the repo so links from `AGENTS.md`, parity docs, and PR templates keep a stable path; when the protocol changes, update the WebSocket operation in `openapi_base.yaml` (or move it to a Rust `include_str!` + `#[utoipa::path]`) and refresh this pointer if needed.
