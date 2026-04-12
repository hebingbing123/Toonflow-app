//! OpenAPI fragment for prompt templates and quality review HTTP routes.

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
    crate::prompting::quality::get_stage_pass_rate,
))]
pub struct PromptingHttpOpenApi;
