//! Wiremock contract tests aligned with vendor docs (no real API accounts).
//!
//! Tests share `OPENFLOW_TEST_VIDEO_API_BASE` and therefore run serially (`--test-threads=1`
//! if you filter only this module in CI).

use std::sync::{LazyLock, Mutex};

use wiremock::matchers::{header, method, path, path_regex, query_param};
use wiremock::{Mock, MockServer, ResponseTemplate};

use super::auth::VideoProviderCredentials;
use super::doc_fixtures::{fal_pika, hunyuan_vclm, kling, minimax, openai_sora, runway, seedance};
use super::{VideoGenerationRequest, VideoGenerationStatus, VideoProvider, VideoProviderClient};

static MOCK_VIDEO_ENV_LOCK: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));

struct MockVideoEnv {
    mock: MockServer,
    _lock: std::sync::MutexGuard<'static, ()>,
}

impl MockVideoEnv {
    async fn start() -> Self {
        let lock = MOCK_VIDEO_ENV_LOCK.lock().expect("mock video env lock");
        let mock = MockServer::start().await;
        std::env::set_var("OPENFLOW_TEST_VIDEO_API_BASE", mock.uri());
        Self { mock, _lock: lock }
    }
}

impl Drop for MockVideoEnv {
    fn drop(&mut self) {
        std::env::remove_var("OPENFLOW_TEST_VIDEO_API_BASE");
    }
}

fn sample_request(provider: VideoProvider, model: &str) -> VideoGenerationRequest {
    VideoGenerationRequest {
        provider,
        model: model.to_string(),
        prompt: "Openflow mock: cinematic product shot".to_string(),
        negative_prompt: None,
        duration: 5,
        resolution: "720p".to_string(),
        aspect_ratio: "16:9".to_string(),
        image_url: None,
        seed: None,
    }
}

#[tokio::test]
async fn seedance_doc_shape_submit_poll_succeeded() {
    let env = MockVideoEnv::start().await;
    let mock = &env.mock;
    std::env::remove_var(VideoProvider::Doubao.api_key_env_var());

    Mock::given(method("POST"))
        .and(path(seedance::CREATE_PATH))
        .and(header("authorization", "Bearer mock-ark-key"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(seedance::task_created("cgt-mock-seedance")),
        )
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path_regex(
            r"/api/v3/contents/generations/tasks/cgt-mock-seedance$",
        ))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(seedance::task_succeeded(
                "cgt-mock-seedance",
                "https://cdn.example.test/seedance.mp4",
            )),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let client = VideoProviderClient::new();
    let req = sample_request(VideoProvider::Doubao, "doubao-seedance-2-0-260128");

    let queued = client
        .generate_video_with_api_key(&req, Some("mock-ark-key"))
        .await
        .expect("submit");
    assert_eq!(queued.task_id, "cgt-mock-seedance");

    let done = client
        .poll_generation_with_api_key(
            VideoProvider::Doubao,
            "cgt-mock-seedance",
            Some("mock-ark-key"),
        )
        .await
        .expect("poll done");
    assert_eq!(done.status, VideoGenerationStatus::Completed);
    assert_eq!(
        done.video_url.as_deref(),
        Some("https://cdn.example.test/seedance.mp4")
    );

    mock.verify().await;
}

#[tokio::test]
async fn minimax_doc_shape_query_then_file_retrieve() {
    let env = MockVideoEnv::start().await;
    let mock = &env.mock;
    std::env::remove_var(VideoProvider::Minimax.api_key_env_var());

    Mock::given(method("POST"))
        .and(path(minimax::CREATE_PATH))
        .respond_with(ResponseTemplate::new(200).set_body_json(minimax::task_created("mm-task-42")))
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path(minimax::QUERY_PATH))
        .and(query_param("task_id", "mm-task-42"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(minimax::query_success("file-mm-99")),
        )
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path(minimax::FILE_RETRIEVE_PATH))
        .and(query_param("file_id", "file-mm-99"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(minimax::file_download(
                "file-mm-99",
                "https://cdn.example.test/hailuo.mp4",
            )),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let client = VideoProviderClient::new();
    let req = sample_request(VideoProvider::Minimax, "MiniMax-Hailuo-2.3");

    let queued = client
        .generate_video_with_api_key(&req, Some("mock-minimax-key"))
        .await
        .expect("submit");
    assert_eq!(queued.task_id, "mm-task-42");

    let done = client
        .poll_generation_with_api_key(
            VideoProvider::Minimax,
            "mm-task-42",
            Some("mock-minimax-key"),
        )
        .await
        .expect("poll");
    assert_eq!(done.status, VideoGenerationStatus::Completed);
    assert_eq!(
        done.video_url.as_deref(),
        Some("https://cdn.example.test/hailuo.mp4")
    );

    mock.verify().await;
}

#[tokio::test]
async fn openai_sora_doc_shape_completed_content_url() {
    let env = MockVideoEnv::start().await;
    let mock = &env.mock;
    std::env::remove_var(VideoProvider::OpenAi.api_key_env_var());

    Mock::given(method("POST"))
        .and(path("/v1/videos"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(openai_sora::video_queued("video_mock_1")),
        )
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path("/v1/videos/video_mock_1"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(openai_sora::video_completed("video_mock_1")),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let client = VideoProviderClient::new();
    let req = sample_request(VideoProvider::OpenAi, "sora-2");

    let queued = client
        .generate_video_with_api_key(&req, Some("mock-openai-key"))
        .await
        .expect("submit");
    assert_eq!(queued.task_id, "video_mock_1");

    let done = client
        .poll_generation_with_api_key(
            VideoProvider::OpenAi,
            "video_mock_1",
            Some("mock-openai-key"),
        )
        .await
        .expect("poll");
    assert_eq!(done.status, VideoGenerationStatus::Completed);
    assert_eq!(
        done.video_url.as_deref(),
        Some(openai_sora::content_download_url(&mock.uri(), "video_mock_1").as_str())
    );

    mock.verify().await;
}

#[tokio::test]
async fn hunyuan_vclm_tc3_submit_and_describe() {
    let env = MockVideoEnv::start().await;
    let mock = &env.mock;

    Mock::given(method("POST"))
        .and(path("/"))
        .and(header("X-TC-Action", "SubmitHunyuanToVideoJob"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(hunyuan_vclm::submit_response("hy-task-7")),
        )
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("POST"))
        .and(path("/"))
        .and(header("X-TC-Action", "DescribeHunyuanToVideoJob"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(hunyuan_vclm::describe_done(
                "https://cdn.example.test/hunyuan.mp4",
            )),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let creds = VideoProviderCredentials {
        api_key: Some("AKIDMOCK".into()),
        api_secret: Some("mock-tencent-secret".into()),
    };
    let client = VideoProviderClient::new();
    let req = sample_request(VideoProvider::Hunyuan, "hunyuan-video");

    let queued = client
        .generate_video_with_credentials(&req, Some(&creds))
        .await
        .expect("submit");
    assert_eq!(queued.task_id, "hy-task-7");

    let done = client
        .poll_generation_with_credentials(VideoProvider::Hunyuan, "hy-task-7", Some(&creds))
        .await
        .expect("poll");
    assert_eq!(done.status, VideoGenerationStatus::Completed);
    assert_eq!(
        done.video_url.as_deref(),
        Some("https://cdn.example.test/hunyuan.mp4")
    );

    mock.verify().await;
}

#[tokio::test]
async fn runway_doc_shape_text_to_video_and_poll() {
    let env = MockVideoEnv::start().await;
    let mock = &env.mock;

    Mock::given(method("POST"))
        .and(path("/v1/text_to_video"))
        .and(header("X-Runway-Version", "2024-11-06"))
        .respond_with(ResponseTemplate::new(200).set_body_json(runway::task_created("rw-task-1")))
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path("/v1/tasks/rw-task-1"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(runway::task_succeeded(
                "rw-task-1",
                "https://cdn.example.test/runway.mp4",
            )),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let client = VideoProviderClient::new();
    let req = sample_request(VideoProvider::Runway, "gen-3-alpha");
    let creds = VideoProviderCredentials::from_key_only("mock-runway-key");

    let queued = client
        .generate_video_with_credentials(&req, Some(&creds))
        .await
        .expect("submit");
    assert_eq!(queued.task_id, "rw-task-1");

    let done = client
        .poll_generation_with_credentials(VideoProvider::Runway, "rw-task-1", Some(&creds))
        .await
        .expect("poll");
    assert_eq!(done.status, VideoGenerationStatus::Completed);

    mock.verify().await;
}

#[tokio::test]
async fn kling_doc_shape_text2video_and_poll() {
    let env = MockVideoEnv::start().await;
    let mock = &env.mock;

    Mock::given(method("POST"))
        .and(path("/v1/videos/text2video"))
        .respond_with(ResponseTemplate::new(200).set_body_json(kling::task_created("kl-88")))
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path("/v1/videos/text2video/kl-88"))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(kling::task_succeeded(
                "kl-88",
                "https://cdn.example.test/kling.mp4",
            )),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let creds = VideoProviderCredentials {
        api_key: Some("ak_mock".into()),
        api_secret: Some("sk_mock".into()),
    };
    let client = VideoProviderClient::new();
    let req = sample_request(VideoProvider::Kling, "kling-v1");

    let queued = client
        .generate_video_with_credentials(&req, Some(&creds))
        .await
        .expect("submit");
    assert_eq!(queued.task_id, "text2video:kl-88");

    let done = client
        .poll_generation_with_credentials(VideoProvider::Kling, &queued.task_id, Some(&creds))
        .await
        .expect("poll");
    assert_eq!(done.status, VideoGenerationStatus::Completed);

    mock.verify().await;
}

#[tokio::test]
async fn fal_pika_queue_submit_poll_and_result() {
    let env = MockVideoEnv::start().await;
    let mock = &env.mock;
    let endpoint = fal_pika::ENDPOINT;

    Mock::given(method("POST"))
        .and(path(format!("/{endpoint}")))
        .respond_with(
            ResponseTemplate::new(200).set_body_json(fal_pika::submit_response("fal-req-1")),
        )
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path(format!("/{endpoint}/requests/fal-req-1/status")))
        .respond_with(ResponseTemplate::new(200).set_body_json(fal_pika::status_completed()))
        .expect(1)
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path(format!("/{endpoint}/requests/fal-req-1")))
        .respond_with(
            ResponseTemplate::new(200)
                .set_body_json(fal_pika::result_video("https://cdn.example.test/pika.mp4")),
        )
        .expect(1)
        .mount(&mock)
        .await;

    let creds = VideoProviderCredentials::from_key_only("mock-fal-key");
    let client = VideoProviderClient::new();
    let req = sample_request(VideoProvider::Pika, "pika-2.0");

    let queued = client
        .generate_video_with_credentials(&req, Some(&creds))
        .await
        .expect("submit");
    assert!(queued.task_id.starts_with("fal|"));

    let done = client
        .poll_generation_with_credentials(VideoProvider::Pika, &queued.task_id, Some(&creds))
        .await
        .expect("poll");
    assert_eq!(done.status, VideoGenerationStatus::Completed);

    mock.verify().await;
}

#[tokio::test]
async fn seedance_failed_status_surfaces_error() {
    let env = MockVideoEnv::start().await;
    let mock = &env.mock;

    Mock::given(method("POST"))
        .and(path(seedance::CREATE_PATH))
        .respond_with(ResponseTemplate::new(200).set_body_json(seedance::task_created("cgt-fail")))
        .mount(&mock)
        .await;

    Mock::given(method("GET"))
        .and(path_regex(r"/api/v3/contents/generations/tasks/cgt-fail$"))
        .respond_with(
            ResponseTemplate::new(200)
                .set_body_json(seedance::task_failed("cgt-fail", "content policy")),
        )
        .mount(&mock)
        .await;

    let client = VideoProviderClient::new();
    let req = sample_request(VideoProvider::Doubao, "doubao-seedance-1-0-lite");
    client
        .generate_video_with_api_key(&req, Some("k"))
        .await
        .expect("submit");

    let failed = client
        .poll_generation_with_api_key(VideoProvider::Doubao, "cgt-fail", Some("k"))
        .await
        .expect("poll");
    assert_eq!(failed.status, VideoGenerationStatus::Failed);
    assert!(failed
        .error_message
        .as_deref()
        .unwrap_or("")
        .contains("policy"));
}
