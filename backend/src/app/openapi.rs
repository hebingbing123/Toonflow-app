//! Browser-friendly OpenAPI：嵌入仓库根 `docs/openapi.yaml`，供 Swagger UI 加载。

use axum::http::{header, HeaderValue};
use axum::response::{Html, IntoResponse};

static OPENAPI_YAML: &str = include_str!("../../../docs/openapi.yaml");

static WEBSOCKET_EVENTS_MD: &str = include_str!("../../../docs/websocket-events.md");

const DOCS_HTML: &str = r##"<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Toonflow API — Swagger UI</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui.css" crossorigin="anonymous" />
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-bundle.js" crossorigin="anonymous"></script>
  <script src="https://unpkg.com/swagger-ui-dist@5.11.0/swagger-ui-standalone-preset.js" crossorigin="anonymous"></script>
  <script>
    window.onload = function () {
      window.ui = SwaggerUIBundle({
        url: "/api/v1/openapi.yaml",
        dom_id: "#swagger-ui",
        deepLinking: true,
        presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
        plugins: [SwaggerUIBundle.plugins.DownloadUrl],
        layout: "StandaloneLayout",
        validatorUrl: null,
        // 默认折叠 tag，页面以「接口列表」为主；Filter 便于前端按路径搜
        docExpansion: "none",
        filter: true,
        displayRequestDuration: true,
        tagsSorter: "alpha",
        operationsSorter: "alpha"
      });
    };
  </script>
</body>
</html>"##;

pub(crate) async fn openapi_yaml() -> impl IntoResponse {
    (
        [(
            header::CONTENT_TYPE,
            HeaderValue::from_static("application/yaml; charset=utf-8"),
        )],
        OPENAPI_YAML,
    )
}

/// Markdown for `GET /api/v1/ws` wire protocol; linked from OpenAPI `externalDocs` (Swagger UI).
pub(crate) async fn websocket_events_md() -> impl IntoResponse {
    (
        [(
            header::CONTENT_TYPE,
            HeaderValue::from_static("text/markdown; charset=utf-8"),
        )],
        WEBSOCKET_EVENTS_MD,
    )
}

pub(crate) async fn swagger_ui() -> Html<&'static str> {
    Html(DOCS_HTML)
}
