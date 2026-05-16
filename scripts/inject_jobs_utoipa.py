#!/usr/bin/env python3
"""Inject #[utoipa::path] for jobs/handlers.rs and append JobsOpenApi derive."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HANDLERS = ROOT / "backend/src/jobs/handlers.rs"

# (fn_name, method, openapi_path, operation_id)
OPS = [
    ("list_jobs_page", "get", "/api/v1/jobs/page", "listJobsPageV1"),
    ("get_job_task_detail_compat", "get", "/api/v1/jobs/task-detail/{task_id}", "getJobTaskDetailCompatV1"),
    ("list_job_kind_summaries", "get", "/api/v1/jobs/kinds/summary", "listJobKindSummariesV1"),
    ("list_job_kinds", "get", "/api/v1/jobs/kinds", "listJobKindsV1"),
    ("list_job_status_summaries", "get", "/api/v1/jobs/status/summary", "listJobStatusSummariesV1"),
    ("list_jobs", "get", "/api/v1/jobs", "listJobsV1"),
    ("create_job", "post", "/api/v1/jobs", "createJobV1"),
    ("get_job", "get", "/api/v1/jobs/{id}", "getJobV1"),
    ("cancel_job", "post", "/api/v1/jobs/{id}/cancel", "cancelJobV1"),
    ("retry_job", "post", "/api/v1/jobs/{id}/retry", "retryJobV1"),
]

GET_BLOCK = '''#[utoipa::path(
    get,
    path = "{path}",
    operation_id = "{oid}",
    tag = "jobs",
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 429, description = "Too many requests", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
'''

POST_BLOCK = '''#[utoipa::path(
    post,
    path = "{path}",
    operation_id = "{oid}",
    tag = "jobs",
    request_body(content = serde_json::Value, content_type = "application/json"),
    responses(
        (status = 200, description = "OK", body = serde_json::Value),
        (status = 400, description = "Bad request", body = crate::error::ErrorBody),
        (status = 401, description = "Unauthorized", body = crate::error::ErrorBody),
        (status = 403, description = "Forbidden", body = crate::error::ErrorBody),
        (status = 404, description = "Not found", body = crate::error::ErrorBody),
        (status = 409, description = "Conflict", body = crate::error::ErrorBody),
        (status = 429, description = "Too many requests", body = crate::error::ErrorBody),
        (status = 500, description = "Server error", body = crate::error::ErrorBody),
        (status = 503, description = "Unavailable", body = crate::error::ErrorBody)
    ),
    security(("bearerAuth" = []))
)]
'''


def main() -> None:
    text = HANDLERS.read_text(encoding="utf-8")
    if "utoipa::path" in text:
        print("already injected")
        return

    for fn_name, method, path, oid in OPS:
        tpl = GET_BLOCK if method == "get" else POST_BLOCK
        block = tpl.format(path=path, oid=oid)
        pat = rf"(async fn {re.escape(fn_name)}\b)"
        m = re.search(pat, text)
        if not m:
            raise SystemExit(f"missing fn {fn_name}")
        pos = m.start()
        text = text[:pos] + block + text[pos:]

    tail = '''

#[derive(utoipa::OpenApi)]
#[openapi(
    paths(
        list_jobs_page,
        get_job_task_detail_compat,
        list_job_kind_summaries,
        list_job_kinds,
        list_job_status_summaries,
        list_jobs,
        create_job,
        get_job,
        cancel_job,
        retry_job,
    ),
    components(schemas(crate::error::ErrorBody)),
    tags((name = "jobs", description = "Generation jobs"))
)]
pub struct JobsOpenApi;
'''
    text = text.rstrip() + tail + "\n"
    HANDLERS.write_text(text, encoding="utf-8")
    print("updated jobs/handlers.rs")


if __name__ == "__main__":
    main()
