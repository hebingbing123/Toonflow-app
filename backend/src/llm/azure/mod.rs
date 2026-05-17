//! Azure Cognitive Services speech synthesis.

mod speech;

pub use speech::{azure_speech_bytes, load_azure_credentials_from_env, AzureSpeechCredentials};
