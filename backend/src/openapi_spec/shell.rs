//! OpenAPI document shell: `info`, `servers`, `tags`, and `components.securitySchemes` only.
//!
//! Reusable JSON Schemas live in [`super::merge`] via `embedded/legacy_component_schemas.json` until
//! they are fully expressed as Rust `ToSchema` types.

use utoipa::openapi::{
    security::{HttpAuthScheme, HttpBuilder, SecurityScheme},
    ComponentsBuilder, InfoBuilder, OpenApi, Paths, ServerBuilder, Tag,
};

pub(super) fn openapi_shell() -> OpenApi {
    let mut api = OpenApi::new(
        InfoBuilder::new()
            .title("Toonflow API")
            .version("1.0.0")
            .description(Some(
                "HTTP under `/api/v1` (use tags below). Typical calls: `Authorization: Bearer <Supabase access_token>`.",
            ))
            .build(),
        Paths::new(),
    );

    api.servers = Some(vec![ServerBuilder::new()
        .url("http://127.0.0.1:8666")
        .description(Some("Local dev (default `PORT`; override with env)"))
        .build()]);

    api.tags = Some(vec![
        tag(
            "system",
            "Health, readiness, and lightweight probes (incl. Electron-era test-route parity)",
        ),
        tag("session", "Auth probe (Supabase JWT)"),
        tag("projects", "User-owned projects (Postgres + RLS)"),
        tag(
            "assets",
            "Script-linked assets per project (`app_asset`, `app_script_asset`; Postgres + RLS); corner-scape listing for Electron-era UI parity",
        ),
        tag("scripts", "Scripts under owned projects (Postgres + RLS)"),
        tag(
            "storyboards",
            "Storyboards under owned scripts (Postgres + RLS)",
        ),
        tag(
            "production",
            "Legacy Electron production workbench parity over Postgres-backed storyboards, assets, edit-image flow, and video workbench routes",
        ),
        tag(
            "novels",
            "Novel source chapters per project (`app_novel`; Postgres + RLS)",
        ),
        tag(
            "art_styles",
            "Per-user art style presets (`app_art_style`; Postgres + RLS); Electron `o_artStyle` subset with local base64 cover persistence instead of OSS upload",
        ),
        tag(
            "skills",
            "Markdown skills under `backend/data/skills` (read; PUT overwrite; POST create; DELETE remove one file); visual manual (`GET`/`POST /api/v1/visual-manual`) from bundled `art_skills`",
        ),
        tag(
            "websocket",
            "Real-time JSON on `GET /api/v1/ws` (Upgrade); full wire protocol is the **description** of that operation below",
        ),
        tag(
            "harness",
            "Harness tool catalog over HTTP; tool execution over WebSocket (`harness.tool.invoke` — see **`GET /api/v1/ws`** in this spec)",
        ),
        tag(
            "jobs",
            "Long-running generation jobs (`app_generation_job`; Postgres + RLS)",
        ),
        tag(
            "usage",
            "Per-user usage counts (`app_usage_event`; Postgres + RLS)",
        ),
        tag(
            "prompts",
            "Per-user prompt templates (`app_user_prompt`; Postgres + RLS); Electron `/api/setting/promptManage/getPrompt` / `updatePrompt`",
        ),
        tag(
            "models",
            "Static vendor/model catalog (`backend/data/models_catalog.json`); Electron `modelSelect` parity without `o_vendorConfig`",
        ),
        tag(
            "agents",
            "Per-user agent memory (`app_agent_memory`; Postgres + RLS); Electron `/api/agents/getMemory` / `clearMemory` parity",
        ),
        tag(
            "webhooks",
            "Server-to-server billing webhooks (HMAC); not browser CORS flows",
        ),
        tag(
            "settings",
            "Server-backed settings without SQLite `o_setting` (env-driven, in-memory snapshots, or future Postgres)",
        ),
    ]);

    let bearer = HttpBuilder::new()
        .scheme(HttpAuthScheme::Bearer)
        .bearer_format("JWT")
        .description(Some(
            "Supabase-issued access token (`Authorization: Bearer <jwt>`).\n\n\
             Rust validates signature/claims per Supabase project settings (see architecture plan 4.2).\n",
        ))
        .build();

    api.components = Some(
        ComponentsBuilder::new()
            .security_scheme("bearerAuth", SecurityScheme::Http(bearer))
            .build(),
    );

    api
}

fn tag(name: &str, description: &str) -> Tag {
    let mut t = Tag::new(name);
    t.description = Some(description.to_string());
    t
}
