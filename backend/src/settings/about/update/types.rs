use serde::{Deserialize, Serialize};

use super::constants::{
    ENV_UPDATE_ATOMGIT_URL, ENV_UPDATE_GITEE_URL, ENV_UPDATE_GITHUB_URL, ENV_UPDATE_OPENFLOW_URL,
};

#[derive(Debug, Deserialize)]
#[serde(rename_all = "lowercase")]
pub(in crate::settings::about) enum CheckUpdateSource {
    Openflow,
    Github,
    Gitee,
    Atomgit,
}

impl CheckUpdateSource {
    pub(in crate::settings::about) fn url_env_key(&self) -> &'static str {
        match self {
            Self::Openflow => ENV_UPDATE_OPENFLOW_URL,
            Self::Github => ENV_UPDATE_GITHUB_URL,
            Self::Gitee => ENV_UPDATE_GITEE_URL,
            Self::Atomgit => ENV_UPDATE_ATOMGIT_URL,
        }
    }
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub(crate) struct CheckUpdateBody {
    pub(in crate::settings::about) source: CheckUpdateSource,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub(crate) struct CheckUpdateResponse {
    pub need_update: bool,
    pub latest_version: String,
    pub reinstall: bool,
    pub time: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub url: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub(in crate::settings::about) struct ReleaseVersion {
    pub(in crate::settings::about) major: u64,
    pub(in crate::settings::about) minor: u64,
    pub(in crate::settings::about) patch: u64,
}

impl ReleaseVersion {
    pub(in crate::settings::about) fn parse(raw: &str) -> Option<Self> {
        let trimmed = raw.trim();
        let core = trimmed.split_once('-').map(|(v, _)| v).unwrap_or(trimmed);
        let mut parts = core.split('.');
        let major = parts.next()?.parse().ok()?;
        let minor = parts.next()?.parse().ok()?;
        let patch = parts.next()?.parse().ok()?;
        if parts.next().is_some() {
            return None;
        }
        Some(Self {
            major,
            minor,
            patch,
        })
    }
}
