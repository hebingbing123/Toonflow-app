//! Vendor credentials, static model catalog, and video provider clients.

pub mod catalog;
pub mod credential;
pub mod gateway;
pub(crate) mod http_extract;
pub(crate) mod kling_jwt;
mod openapi;
pub(crate) mod tencent_tc3;
pub mod user_credentials;
pub mod video;

pub use openapi::VendorCatalogOpenApi;
