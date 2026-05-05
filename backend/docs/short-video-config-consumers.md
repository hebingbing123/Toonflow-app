# Short Video Configuration Consumers

**Task**: B3 - 后端：消费方只读接入至少两处  
**Requirements**: 需求 2 - "单一配置源" (single source of truth)  
**Status**: ✅ Implemented

## Overview

This document describes the consumer integration points that read from the project-level short video configuration, demonstrating the "single source of truth" principle. Downstream systems read from the centralized `app_project` table configuration rather than maintaining their own copies.

## Consumer Integration Points

### 1. Storyboard Generation Parameters Reader

**Location**: `backend/src/production/workbench/video/generate/short_video_config.rs`

**Function**: `load_storyboard_generation_config(pool, project_id)`

**Purpose**: Provides read-only access to project-level configuration for storyboard generation workflows.

**Configuration Fields Consumed**:
- `video_ratio` - Determines aspect ratio for video generation requests (9:16, 16:9, 1:1)
- `mode` - Applies mode-specific prompt presets (animated vs live-action)
- `target_market` - Influences content style (domestic, overseas, both)
- `target_platforms` - Applies platform-specific constraints
- `duration_strategy` - Determines default video duration (short, medium, long)
- `voice_profile` - Configures narration voice
- `subtitle_style` - Configures subtitle appearance
- `bgm_strategy` - Configures background music

**Usage Example**:
```rust
use crate::production::workbench::video::generate::load_storyboard_generation_config;

let config = load_storyboard_generation_config(pool, project_id).await?;

// Use video_ratio for generation request
let aspect_ratio = config.video_ratio.as_deref().unwrap_or("16:9");

// Apply mode-specific prompt adjustments
if let Some(mode) = &config.mode {
    if mode.contains("live_action") {
        // Apply live-action specific settings
    }
}

// Apply platform-specific constraints
for platform in &config.target_platforms {
    match platform.as_str() {
        "douyin" => { /* Douyin constraints */ },
        "tiktok" => { /* TikTok constraints */ },
        _ => {}
    }
}
```

**Integration Points**:
- Video generation job creation
- Prompt preprocessing
- Quality gate validation
- Platform constraint checking

### 2. Export Default Settings Reader

**Location**: `backend/src/jobs/worker/video/export_config.rs`

**Function**: `load_export_default_config(pool, project_id)`

**Purpose**: Provides read-only access to project-level configuration for export workflows.

**Configuration Fields Consumed**:
- `video_ratio` - Determines export resolution (1080x1920, 1920x1080, 1080x1080)
- `target_platforms` - Applies platform-specific export constraints
- `target_market` - Influences encoding settings for CDN delivery
- `duration_strategy` - Affects export optimization

**Helper Functions**:
- `resolve_export_resolution(video_ratio)` - Maps ratio to concrete resolution
- `platform_has_export_constraints(platform)` - Checks if platform needs special handling

**Usage Example**:
```rust
use crate::jobs::worker::video::export_config::{
    load_export_default_config,
    resolve_export_resolution,
    platform_has_export_constraints,
};

let config = load_export_default_config(pool, project_id).await?;

// Determine export resolution from project video_ratio
let resolution = resolve_export_resolution(config.video_ratio.as_deref());
// Returns: "1080x1920" for 9:16, "1920x1080" for 16:9, etc.

// Apply platform-specific constraints
for platform in &config.target_platforms {
    if platform_has_export_constraints(platform) {
        match platform.as_str() {
            "douyin" => {
                // Max 60s, specific bitrate
                bitrate = "4M";
            },
            "youtube_shorts" => {
                // Higher quality for YouTube
                bitrate = "8M";
            },
            _ => {}
        }
    }
}
```

**Integration Points**:
- Video export job execution
- Multi-platform export variant generation
- Batch export operations
- Platform-specific encoding

## Single Source of Truth Verification

Both consumer integration points demonstrate the "single source of truth" principle:

1. **No Configuration Duplication**: Consumers read directly from `app_project` table, not from separate configuration tables or hardcoded values.

2. **Consistent Behavior**: All storyboard generation and export operations use the same project-level configuration, ensuring consistency across the system.

3. **Centralized Updates**: When project configuration is updated via the API (Task B2), all consumers automatically see the new values on their next read.

4. **Type-Safe Access**: Both consumers provide strongly-typed Rust structs (`StoryboardGenerationConfig`, `ExportDefaultConfig`) that map directly to database fields.

## Testing

### Unit Tests
- `backend/src/production/workbench/video/generate/short_video_config.rs` - Config structure tests
- `backend/src/jobs/worker/video/export_config.rs` - Resolution mapping and platform constraint tests

### Integration Tests
- `backend/src/production/workbench/video/generate/tests/short_video_config_integration.rs` - Consumer usage patterns

### Example Code
- `backend/src/production/workbench/video/generate/consumer_examples.rs` - Storyboard generation examples
- `backend/src/jobs/worker/video/export_consumer_examples.rs` - Export workflow examples

## Future Consumer Integration Points

Additional consumers that could read from this configuration:

1. **Publishing Workflow** (Task E1-E13): Read `target_platforms` and `target_market` for platform-specific publishing
2. **Quality Gate** (Task D3): Read configuration to apply mode-specific quality thresholds
3. **Batch Operations** (Task L1): Read configuration for batch generation parameters
4. **Assembly Workflow** (Task D1): Read `subtitle_style`, `voice_profile`, `bgm_strategy` for assembly defaults

## Related Tasks

- **B1**: Database schema for project short video configuration
- **B2**: API endpoints for reading/writing configuration
- **B4**: Frontend UI for configuration management
- **B5**: OpenAPI specification for configuration models

## Verification Checklist

- ✅ Consumer 1 (Storyboard Generation) implemented and documented
- ✅ Consumer 2 (Export Defaults) implemented and documented
- ✅ Both consumers read from `app_project` table (single source)
- ✅ Type-safe Rust structs for configuration
- ✅ Helper functions for common operations
- ✅ Unit tests for configuration structures
- ✅ Integration tests for consumer patterns
- ✅ Example code demonstrating usage
- ✅ Documentation explaining integration points
