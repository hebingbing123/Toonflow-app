//! PG-backed projects REST and legacy **`/api/v1/project/*`** routes.

pub mod legacy;
pub mod routes;

pub use routes::ProjectRow;
