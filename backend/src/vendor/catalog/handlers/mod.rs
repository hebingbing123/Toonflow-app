//! 静态模型目录 HTTP 处理器。

mod list_detail;
mod text_default;

#[allow(unused_imports)]
pub(crate) use list_detail::{__path_list_models, __path_model_detail, list_models, model_detail};
#[allow(unused_imports)]
pub(crate) use text_default::{
    __path_patch_text_model_default, __path_text_model_default, patch_text_model_default,
    text_model_default,
};
