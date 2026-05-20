//! Documented vendor JSON shapes for wiremock tests (no live API keys required).
//!
//! Sources (2025–2026):
//! - Seedance 2.0 / Ark: `POST /api/v3/contents/generations/tasks`, poll until `succeeded`
//! - MiniMax: `POST /v1/video_generation`, `GET /v1/query/video_generation`, `GET /v1/files/retrieve`
//! - OpenAI Sora: `POST /v1/videos`, `GET /v1/videos/{id}`, download `GET /v1/videos/{id}/content`
//! - Hunyuan VCLM: TC3 `SubmitHunyuanToVideoJob` / `DescribeHunyuanToVideoJob` on `vclm.tencentcloudapi.com`
//! - Runway: `POST /v1/text_to_video`, `GET /v1/tasks/{id}`
//! - Kling: `POST /v1/videos/text2video`, `GET /v1/videos/text2video/{id}`
//! - Pika (fal): `POST queue.fal.run/fal-ai/pika/...`, poll `.../requests/{id}/status`

use serde_json::{json, Value};

pub mod seedance {
    use super::*;

    pub const CREATE_PATH: &str = "/api/v3/contents/generations/tasks";

    pub fn task_created(task_id: &str) -> Value {
        json!({ "id": task_id })
    }

    pub fn task_running(task_id: &str) -> Value {
        json!({
            "id": task_id,
            "status": "running",
        })
    }

    pub fn task_succeeded(task_id: &str, video_url: &str) -> Value {
        json!({
            "id": task_id,
            "status": "succeeded",
            "content": {
                "video_url": video_url,
            }
        })
    }

    pub fn task_failed(task_id: &str, message: &str) -> Value {
        json!({
            "id": task_id,
            "status": "failed",
            "error": { "message": message }
        })
    }
}

pub mod minimax {
    use super::*;

    pub const CREATE_PATH: &str = "/v1/video_generation";
    pub const QUERY_PATH: &str = "/v1/query/video_generation";
    pub const FILE_RETRIEVE_PATH: &str = "/v1/files/retrieve";

    pub fn task_created(task_id: &str) -> Value {
        json!({ "task_id": task_id })
    }

    pub fn query_success(file_id: &str) -> Value {
        json!({
            "status": "Success",
            "file_id": file_id,
        })
    }

    pub fn file_download(file_id: &str, download_url: &str) -> Value {
        json!({
            "file": {
                "file_id": file_id,
                "download_url": download_url,
            }
        })
    }
}

pub mod openai_sora {
    use super::*;

    pub fn video_queued(video_id: &str) -> Value {
        json!({
            "id": video_id,
            "object": "video",
            "status": "queued",
            "model": "sora-2",
            "progress": 0,
        })
    }

    pub fn video_completed(video_id: &str) -> Value {
        json!({
            "id": video_id,
            "object": "video",
            "status": "completed",
            "model": "sora-2",
            "progress": 100,
        })
    }

    pub fn content_download_url(base: &str, video_id: &str) -> String {
        format!("{base}/v1/videos/{video_id}/content")
    }
}

pub mod hunyuan_vclm {
    use super::*;

    pub fn submit_response(job_id: &str) -> Value {
        json!({
            "Response": {
                "JobId": job_id,
                "RequestId": "mock-req-submit",
            }
        })
    }

    pub fn describe_done(video_url: &str) -> Value {
        json!({
            "Response": {
                "Status": "DONE",
                "ResultVideoUrl": video_url,
                "ErrorCode": "",
                "ErrorMessage": "",
                "RequestId": "mock-req-describe",
            }
        })
    }
}

pub mod runway {
    use super::*;

    pub fn task_created(task_id: &str) -> Value {
        json!({ "id": task_id })
    }

    pub fn task_succeeded(task_id: &str, video_url: &str) -> Value {
        json!({
            "id": task_id,
            "status": "SUCCEEDED",
            "output": [video_url],
        })
    }
}

pub mod kling {
    use super::*;

    pub fn task_created(task_id: &str) -> Value {
        json!({
            "code": 0,
            "data": { "task_id": task_id },
        })
    }

    pub fn task_succeeded(task_id: &str, video_url: &str) -> Value {
        json!({
            "code": 0,
            "data": {
                "task_id": task_id,
                "task_status": "succeed",
                "task_result": {
                    "videos": [{ "url": video_url }],
                },
            },
        })
    }
}

pub mod fal_pika {
    use super::*;

    pub const ENDPOINT: &str = "fal-ai/pika/v2.2/text-to-video";

    pub fn submit_response(request_id: &str) -> Value {
        json!({ "request_id": request_id })
    }

    pub fn status_completed() -> Value {
        json!({ "status": "COMPLETED" })
    }

    pub fn result_video(video_url: &str) -> Value {
        json!({ "video": { "url": video_url } })
    }
}
