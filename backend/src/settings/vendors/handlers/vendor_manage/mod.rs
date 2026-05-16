//! Vendor 配置增删改与链接录入。

mod create;
mod delete;
mod update;

#[allow(unused_imports)]
pub(crate) use create::{
    __path_post_add_vendor, __path_post_vendor_code_from_link, post_add_vendor,
    post_vendor_code_from_link,
};
#[allow(unused_imports)]
pub(crate) use delete::{__path_post_delete_vendor, post_delete_vendor};
#[allow(unused_imports)]
pub(crate) use update::{
    __path_post_enable_vendor, __path_post_update_vendor, __path_post_update_vendor_code,
    post_enable_vendor, post_update_vendor, post_update_vendor_code,
};
