//! OpenAPI fragment for prompt templates, quality review, and benchmark HTTP routes.

use utoipa::OpenApi;

#[derive(OpenApi)]
#[openapi(paths(
    crate::prompting::prompts::list_prompts,
    crate::prompting::prompts::get_prompt,
    crate::prompting::prompts::patch_prompt,
    crate::prompting::quality::create_review,
    crate::prompting::quality::list_reviews,
    crate::prompting::quality::get_review,
    crate::prompting::quality::get_stats,
    crate::prompting::quality::get_token_efficiency,
    crate::prompting::quality::get_token_efficiency_samples,
    crate::prompting::quality::get_stage_pass_rate,
    crate::prompting::benchmark::registry::create_benchmark_case,
    crate::prompting::benchmark::registry::list_benchmark_cases,
    crate::prompting::benchmark::registry::update_benchmark_case,
    crate::prompting::benchmark::registry::promote_from_quality_review,
    crate::prompting::benchmark::experiments::create_experiment,
    crate::prompting::benchmark::experiments::list_experiments,
    crate::prompting::benchmark::experiments::get_experiment,
    crate::prompting::benchmark::experiments::start_experiment,
    crate::prompting::benchmark::experiments::cancel_experiment,
    crate::prompting::benchmark::judge::get_rubrics,
    crate::prompting::benchmark::judge::score_preview,
    crate::prompting::benchmark::review_queue::get_review_queue,
    crate::prompting::benchmark::review_queue::submit_review,
    crate::prompting::benchmark::review_queue::skip_review,
    crate::prompting::benchmark::observation_assets::create_observation_asset,
    crate::prompting::benchmark::observation_assets::list_observation_assets,
    crate::prompting::benchmark::observation_assets::update_observation_asset,
    crate::prompting::benchmark::observation_assets::archive_observation_asset,
    crate::prompting::benchmark::observation_assets::reject_observation_asset,
    crate::prompting::benchmark::observation_assets::increment_hit_count,
    crate::prompting::benchmark::observation_assets::increment_falsified_count,
    crate::prompting::benchmark::memory_profiles::list_memory_profiles,
    crate::prompting::benchmark::memory_profiles::get_experiment_roi,
    crate::prompting::benchmark::promotion_gate::get_promotion_gate,
    crate::prompting::benchmark::promotion_gate::decide_promotion_gate,
    crate::prompting::benchmark::promotion_gate::get_benchmark_trends,
))]
pub struct PromptingHttpOpenApi;
