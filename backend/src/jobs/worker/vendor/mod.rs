//! 设置页「厂商模型探针」任务（`JOB_KIND_SETTINGS_VENDOR_MODEL_TEST`）。

mod llm_config;
mod model_test;
mod preview;
mod resolve;
mod secret;

pub(crate) use model_test::run_vendor_model_test;

#[cfg(test)]
mod tests;
