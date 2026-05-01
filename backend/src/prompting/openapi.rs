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
))]
pub struct PromptingHttpOpenApi;
