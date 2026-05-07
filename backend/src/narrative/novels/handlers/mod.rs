pub mod crawl_preview;
pub mod crawl_schedule;
mod create;
mod get;
mod list;
mod update_delete;

pub(super) use crawl_preview::post_novel_crawl_import;
pub(super) use crawl_preview::post_novel_crawl_import_batch;
pub(super) use crawl_preview::post_novel_crawl_preview;
pub(super) use crawl_schedule::{list_novel_crawl_schedules, post_novel_crawl_schedule_create};
pub(super) use create::create_novel_for_project;
pub(super) use get::get_novel_for_project;
pub(super) use list::list_novels_for_project;
pub(super) use update_delete::{delete_novel_for_project, patch_novel_for_project};
