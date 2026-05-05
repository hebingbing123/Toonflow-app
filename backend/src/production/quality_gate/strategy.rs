//! Quality gate strategy: off/warn/block enforcement modes.

use serde::{Deserialize, Serialize};
use std::str::FromStr;
use utoipa::ToSchema;

/// Quality gate enforcement strategy.
///
/// - **off**: No quality gate enforcement (skip all checks)
/// - **warn**: Show quality warnings but allow operation to proceed
/// - **block**: Block operation if quality issues are detected (default behavior)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, ToSchema, Default)]
#[serde(rename_all = "snake_case")]
pub enum QualityGateStrategy {
    /// No quality gate enforcement - skip all quality checks
    Off,
    /// Show warnings but allow operation to proceed
    Warn,
    /// Block operation if quality issues detected (default)
    #[default]
    Block,
}

impl FromStr for QualityGateStrategy {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_lowercase().as_str() {
            "off" => Ok(Self::Off),
            "warn" => Ok(Self::Warn),
            "block" => Ok(Self::Block),
            _ => Err(format!(
                "invalid quality gate strategy: {s}; expected 'off', 'warn', or 'block'"
            )),
        }
    }
}

impl QualityGateStrategy {
    /// Returns the string representation of the strategy.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Off => "off",
            Self::Warn => "warn",
            Self::Block => "block",
        }
    }

    /// Returns true if this strategy should skip quality gate checks entirely.
    pub fn should_skip_checks(self) -> bool {
        matches!(self, Self::Off)
    }

    /// Returns true if this strategy should block on quality issues.
    pub fn should_block(self) -> bool {
        matches!(self, Self::Block)
    }

    /// Returns true if this strategy should only warn on quality issues.
    pub fn should_warn(self) -> bool {
        matches!(self, Self::Warn)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_strategy_is_block() {
        assert_eq!(QualityGateStrategy::default(), QualityGateStrategy::Block);
    }

    #[test]
    fn parse_strategy_from_string() {
        assert_eq!(
            "off".parse::<QualityGateStrategy>().unwrap(),
            QualityGateStrategy::Off
        );
        assert_eq!(
            "warn".parse::<QualityGateStrategy>().unwrap(),
            QualityGateStrategy::Warn
        );
        assert_eq!(
            "block".parse::<QualityGateStrategy>().unwrap(),
            QualityGateStrategy::Block
        );
        assert_eq!(
            "OFF".parse::<QualityGateStrategy>().unwrap(),
            QualityGateStrategy::Off
        );
        assert_eq!(
            " warn ".parse::<QualityGateStrategy>().unwrap(),
            QualityGateStrategy::Warn
        );
        assert!("invalid".parse::<QualityGateStrategy>().is_err());
    }

    #[test]
    fn strategy_as_str() {
        assert_eq!(QualityGateStrategy::Off.as_str(), "off");
        assert_eq!(QualityGateStrategy::Warn.as_str(), "warn");
        assert_eq!(QualityGateStrategy::Block.as_str(), "block");
    }

    #[test]
    fn strategy_behavior_checks() {
        assert!(QualityGateStrategy::Off.should_skip_checks());
        assert!(!QualityGateStrategy::Warn.should_skip_checks());
        assert!(!QualityGateStrategy::Block.should_skip_checks());

        assert!(!QualityGateStrategy::Off.should_block());
        assert!(!QualityGateStrategy::Warn.should_block());
        assert!(QualityGateStrategy::Block.should_block());

        assert!(!QualityGateStrategy::Off.should_warn());
        assert!(QualityGateStrategy::Warn.should_warn());
        assert!(!QualityGateStrategy::Block.should_warn());
    }
}
