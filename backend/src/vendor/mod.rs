//! Vendor credentials, static model catalog, and video provider clients.

pub mod catalog;
pub mod credential;
mod openapi;
pub mod video;

pub use openapi::VendorCatalogOpenApi;
