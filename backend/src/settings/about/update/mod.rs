pub(in crate::settings::about) mod constants;
mod handler;
pub(in crate::settings::about) mod resolve;
pub(in crate::settings::about) mod types;

#[allow(unused_imports)]
pub(crate) use handler::__path_post_check_update;
pub(crate) use handler::post_check_update;
