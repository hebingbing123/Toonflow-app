//! OpenAPI/HTTP 契约冒烟测试（无真实数据库）：认证格式、验证顺序和 **503** 路径。
//!
//! 模块按**功能面**（路由/域）分组，而不是按运行顺序。旧的数字 `partN.rs` 名称被删除，改为描述性文件名。

mod helpers;

mod asset_jobs_tasks_smoke;
mod health_models_billing_vendors;
mod manuals_scripts_novels;
mod production_http_smoke;
mod rest_projects_settings_skills;
mod skills_workbench_asset_posts;
mod storyboards_art_styles_agents;
