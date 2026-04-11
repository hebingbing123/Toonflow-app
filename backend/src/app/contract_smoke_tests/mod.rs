//! OpenAPI/HTTP contract smoke tests (no real DB): auth shape, validation order, and **503** paths.
//!
//! Modules are grouped by **surface area** (routes / domain), not by run order. Older numeric
//! `partN.rs` names were removed in favor of descriptive file names.

mod helpers;

mod asset_jobs_tasks_legacy_post;
mod health_models_billing_vendors;
mod manuals_scripts_novels;
mod production_legacy;
mod rest_projects_settings_skills;
mod skills_legacy_asset_posts;
mod storyboards_art_styles_agents;
