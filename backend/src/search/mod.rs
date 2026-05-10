//! 全局搜索模块：跨项目、剧本、资产、小说章节与小说大纲事件的全文搜索。
//!
//! 基于 PostgreSQL tsvector + GIN 索引实现高性能全文搜索，支持中英文分词和权重排序。

pub mod cache;
pub mod history;
pub mod logging;
pub mod models;
mod openapi;
pub mod routes;
pub mod service;

pub use cache::SearchCache;
pub use openapi::SearchOpenApi;
