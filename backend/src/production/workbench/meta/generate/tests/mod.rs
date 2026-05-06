//! Unit tests for workbench meta prompt generation.
//!
//! This module contains comprehensive tests for video prompt generation,
//! organized by feature domain for maintainability.

#![allow(unused_imports)]

mod test_helpers;

// Build prompt tests (split into multiple modules)
mod build_prompt_anchors;
mod build_prompt_compact;
mod build_prompt_constraint;
mod build_prompt_continuity;
mod build_prompt_core;
mod build_prompt_style_fragments;
mod build_prompt_style_memory;

// Other test modules
mod anchor_tests;
mod automation_mode_tests;
mod compact_tests;
mod continuity_tests;
mod diagnostics_tests;
mod memory_observation;
mod memory_style;
mod memory_trim_part1;
mod memory_trim_part2;
mod observation_tests_part1;
mod observation_tests_part2;
mod select_tests;
mod style_tests;
