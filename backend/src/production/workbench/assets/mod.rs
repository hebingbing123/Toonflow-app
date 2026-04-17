pub(crate) mod batch_ops;
mod common;
pub(crate) mod read_ops;
pub(crate) mod update_ops;

#[allow(unused_imports)]
pub(crate) use batch_ops::{
    __path_post_assets_batch_generate_image, __path_post_assets_delete_derivative,
};
pub(in crate::production) use batch_ops::{
    post_assets_batch_generate_image, post_assets_delete_derivative,
};
#[allow(unused_imports)]
pub(crate) use read_ops::{__path_post_assets_get_data, __path_post_assets_polling_image};
pub(in crate::production) use read_ops::{post_assets_get_data, post_assets_polling_image};
#[allow(unused_imports)]
pub(crate) use update_ops::__path_post_assets_update_url;
pub(in crate::production) use update_ops::post_assets_update_url;
