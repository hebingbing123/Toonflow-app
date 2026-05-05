# F.1 Audio-Video Assembly Consistency Review

**Date**: 2025-01-XX  
**Task**: F.1 Review audio-video assembly consistency  
**Status**: ✅ Completed

## Executive Summary

Reviewed the audio-video assembly implementation to assess consistency between TTS-generated audio assets, video storyboard shots, and final assembled output. The current implementation demonstrates **strong consistency** with well-defined data flows and clear separation of concerns.

### Key Findings

✅ **Strengths**:
- Consistent metadata structure across assembly, export, and worker pipelines
- Unified text resolution logic for subtitles and voiceover
- Proper state tracking for audio asset lifecycle
- Clear fallback hierarchy (explicit narration → prompt → placeholder)

⚠️ **Minor Gaps Identified**:
1. Duration synchronization between audio and video not validated
2. No explicit audio-video timing mismatch detection
3. Missing validation for audio asset availability before assembly
4. No retry mechanism for failed voiceover generation in assembly context

## Architecture Overview

### Data Flow

```
1. Storyboard Creation
   └─> app_storyboard (video_desc, prompt, duration, file_path)

2. TTS Request (POST /production/workbench/generate-voiceover)
   └─> app_generation_job (kind: voiceover.generate)
       └─> Worker: voiceover.rs
           ├─> Resolve narration text (video_desc || prompt)
           ├─> Call TTS API (OpenAI-compatible)
           ├─> Persist audio file: {dir}/{user_id}/{job_id}.mp3
           └─> Update app_storyboard.metadata.voiceover:
               {
                 state: "completed",
                 audioUrl: "/api/v1/jobs/{job_id}/file",
                 fileName: "{job_id}.mp3",
                 voice, speed, model, sourceText, ...
               }

3. Assembly Read (GET /projects/{id}/short-video-assembly)
   └─> Fetch storyboard rows with voiceover metadata
       └─> Resolve consistency flags:
           - voiceover_script_ready: bool (text available)
           - voiceover_asset_ready: bool (state=completed && audioUrl exists)
           - subtitle_source: enum (explicit_narration | prompt_fallback | placeholder)

4. Export (POST /production/export-image)
   └─> Build assembly_plan.json with audio-video timing
       └─> Each shot includes:
           - start_ms, end_ms, duration_seconds
           - image_filename, subtitle_text
           - voiceover_audio_url, voiceover_asset_ready
```

## Consistency Analysis

### 1. Text Resolution Consistency ✅

**Location**: `backend/src/production/workbench/storyboard_ops/shot_text.rs`

Both the voiceover worker and assembly endpoint use the **same resolution logic**:

```rust
// Worker (voiceover.rs:resolve_narration_text)
video_desc.trim() || prompt.trim() || None

// Assembly (shot_text.rs:resolve_shot_script_source)
"explicit_narration" if video_desc exists
"prompt_fallback" if prompt exists
"placeholder" otherwise
```

**Verdict**: ✅ Consistent. Both paths prioritize `video_desc` over `prompt`.

### 2. Audio Asset State Tracking ✅

**Location**: `backend/src/projects/routes/handlers/detail/short_video_assembly.rs:104-108`

Assembly endpoint correctly checks:
```rust
voiceover_asset_ready = 
    voiceover_state == "completed" 
    && voiceover_audio_url.is_some_and(|u| !u.trim().is_empty())
```

**Verdict**: ✅ Consistent. Matches worker's success criteria.

### 3. Duration Handling ⚠️

**Current Behavior**:
- Storyboard stores `duration` as string (e.g., "5", "10")
- Export parses to integer seconds, defaults to 5 if missing/invalid
- Audio generation does NOT consider duration
- Assembly plan calculates timeline: `start_ms = Σ(previous durations * 1000)`

**Gap**: No validation that:
1. Generated audio duration matches storyboard duration
2. Audio file length is compatible with video shot length
3. Mismatches are flagged before assembly

**Impact**: Medium. Could result in:
- Audio cut off mid-sentence if too long
- Silence padding if too short
- Timing drift in multi-shot sequences

### 4. Assembly Readiness Validation ⚠️

**Current Behavior**:
- Assembly endpoint exposes `voiceover_asset_ready` flag
- Export includes shots regardless of audio readiness
- No blocking validation before export/publish

**Gap**: 
- No pre-assembly check that all shots have audio if required
- No warning/error if audio generation failed for critical shots
- Frontend must implement its own validation logic

**Impact**: Low-Medium. Could result in:
- Exporting incomplete assemblies
- Manual discovery of missing audio
- Inconsistent user experience

### 5. Error Recovery ⚠️

**Current Behavior**:
- Failed voiceover jobs write error to `metadata.voiceover.error`
- Assembly endpoint exposes `voiceover_error` field
- No automatic retry mechanism

**Gap**:
- No retry queue for transient TTS failures
- No bulk regeneration endpoint for failed shots
- Manual intervention required for each failure

**Impact**: Low. Operational burden but not a consistency issue.

## Data Structure Consistency

### Voiceover Metadata Schema

**Worker writes** (`voiceover.rs:95-109`):
```json
{
  "state": "completed",
  "audioUrl": "/api/v1/jobs/{job_id}/file",
  "fileName": "{job_id}.mp3",
  "contentType": "audio/mpeg",
  "voice": "alloy",
  "speed": 1.0,
  "model": "tts-1",
  "vendorId": "openai",
  "updatedAt": "2025-01-XX...",
  "sourceText": "...",
  "error": null
}
```

**Assembly reads** (`assembly_query.rs:32-34`):
```sql
sb.metadata #>> '{voiceover,state}' AS voiceover_state,
sb.metadata #>> '{voiceover,audioUrl}' AS voiceover_audio_url,
sb.metadata #>> '{voiceover,error}' AS voiceover_error
```

**Export reads** (`zip_export.rs:174-180`):
```rust
voiceover_audio_url: row.voiceover_audio_url.clone(),
voiceover_asset_ready: row.voiceover_state == "completed" 
    && row.voiceover_audio_url.is_some_and(|u| !u.trim().is_empty())
```

**Verdict**: ✅ Fully consistent. All paths use the same JSON structure.

## Recommendations

### Priority 1: Duration Validation (P1)

Add validation in assembly endpoint to detect audio-video duration mismatches:

```rust
// In short_video_assembly.rs or new validation module
fn validate_audio_video_timing(
    shot: &ShortVideoAssemblyShot,
    audio_metadata: Option<&Value>
) -> Option<String> {
    if !shot.voiceover_asset_ready {
        return None; // Skip if no audio
    }
    
    let video_duration = parse_storyboard_duration_seconds(shot.duration.as_deref());
    
    // Future: fetch actual audio file duration
    // For now, warn if duration is very short (likely truncation)
    if video_duration < 3 {
        return Some("video_duration_very_short".into());
    }
    
    None
}
```

**Benefit**: Catch timing issues before export/publish.

### Priority 2: Assembly Readiness Gate (P1)

Add optional validation mode to assembly endpoint:

```rust
// Query param: ?validate_audio=true
if validate_audio {
    let missing_audio: Vec<i32> = shots
        .iter()
        .filter(|s| s.voiceover_script_ready && !s.voiceover_asset_ready)
        .map(|s| s.storyboard_numeric_id)
        .collect();
    
    if !missing_audio.is_empty() {
        // Return warning or error with shot IDs
    }
}
```

**Benefit**: Prevent incomplete assemblies from reaching export.

### Priority 3: Bulk Retry Endpoint (P2)

Add endpoint to retry failed voiceover jobs:

```rust
// POST /api/v1/projects/{id}/voiceover/retry
// Body: { storyboard_ids?: number[], retry_all_failed?: bool }
```

**Benefit**: Reduce manual intervention for transient failures.

### Priority 4: Audio Duration Metadata (P2)

Enhance voiceover worker to store actual audio duration:

```rust
// In voiceover.rs after TTS call
let audio_duration_ms = estimate_audio_duration(&audio_bytes)?;

persist_storyboard_voiceover_metadata(
    pool,
    storyboard_id,
    &json!({
        // ... existing fields
        "durationMs": audio_duration_ms,
    }),
).await?;
```

**Benefit**: Enable precise timing validation and assembly planning.

## Conclusion

The current audio-video assembly implementation is **fundamentally sound** with strong consistency between:
- Text resolution logic (worker ↔ assembly ↔ export)
- Metadata structure (write ↔ read paths)
- State tracking (generation ↔ consumption)

The identified gaps are **operational enhancements** rather than consistency bugs:
1. Duration validation would improve quality gates
2. Readiness checks would improve UX
3. Retry mechanisms would reduce operational burden
4. Duration metadata would enable future optimizations

**No immediate breaking issues found.** The system is production-ready for the current use case (TTS audio + static video shots). Future enhancements should focus on timing precision and error recovery.

## Files Reviewed

### Core Assembly Logic
- `backend/src/projects/routes/handlers/detail/short_video_assembly.rs` - Assembly endpoint
- `backend/src/projects/routes/handlers/detail/assembly_query.rs` - Data fetching
- `backend/src/projects/routes/types.rs` - Response types

### Export Logic
- `backend/src/production/workbench/storyboard_ops/export/zip_export.rs` - Export manifest generation
- `backend/src/production/workbench/storyboard_ops/shot_text.rs` - Text resolution utilities

### TTS/Audio Pipeline
- `backend/src/jobs/worker/voiceover.rs` - Voiceover generation worker
- `backend/src/jobs/kinds.rs` - Job type definitions
- `backend/src/production/workbench/voiceover.rs` - Voiceover enqueue endpoint

### Supporting Modules
- `backend/src/short_video/defaults.rs` - TTS voice resolution
- `backend/src/production/workbench/storyboard_ops/types.rs` - Storyboard data types

## Next Steps

1. ✅ Document findings (this file)
2. ⏭️ Proceed to F.2: Review voice tone and emotion control gaps
3. 🔄 Consider implementing P1 recommendations in Phase P (UX Completeness)
