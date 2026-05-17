# F.2 Voice Tone and Emotion Control Gaps Review

**Date**: 2025-01-XX  
**Task**: F.2 Review voice tone and emotion control gaps  
**Status**: ✅ Completed

## Executive Summary

Reviewed the current TTS/voiceover implementation to assess voice tone and emotion control capabilities for drama production. The current implementation uses **OpenAI-compatible TTS with minimal control parameters** (voice name + speed only). There is a **significant gap** between the basic TTS capabilities and the sophisticated voice control requirements for drama storytelling, particularly for Chinese short drama (短剧) production.

### Key Findings

⚠️ **Critical Gaps**:
1. **No emotion/expression control** - Cannot control speaking style, emotion, or emphasis
2. **No character-voice mapping** - No integration with character profiles or scene context
3. **Limited voice selection** - Only supports OpenAI's 6 preset voices (alloy, echo, fable, nova, shimmer, onyx)
4. **No drama-specific voice dimensions** - Missing 9-dimension voice control required for Seedance 2.0 (性别, 年龄音色, 音调, 音色质感, 声音厚度, 发音方式, 气息, 语速, 特殊质感)
5. **No multi-character support** - Cannot assign different voices to different characters in dialogue
6. **No scene-aware voice adaptation** - Voice doesn't adapt to scene mood, tension, or emotional context

✅ **Current Strengths**:
- Clean voice resolution hierarchy (explicit → project profile → default)
- Stable voice parameter persistence in metadata
- Speed control (0.25x - 4.0x) for pacing adjustment

## Current Implementation Analysis

### 1. Voice Selection Architecture

**Location**: `backend/src/short_video/defaults.rs`

```rust
pub(crate) const DEFAULT_TTS_VOICE: &str = "alloy";

pub(crate) fn resolve_tts_voice(
    explicit_voice: Option<&str>,
    project_voice_profile: Option<&str>,
) -> String {
    // Priority: explicit > project_voice_profile > "alloy"
}
```

**Capabilities**:
- ✅ Project-level default voice (`app_project.voice_profile`)
- ✅ Per-request voice override (`POST /generate-voiceover` body)
- ✅ Fallback to "alloy" if not specified

**Limitations**:
- ❌ Voice selection is a simple string (no structured voice attributes)
- ❌ No validation of voice availability
- ❌ No character-to-voice mapping
- ❌ No scene context consideration

### 2. TTS API Parameters

**Location**: `backend/src/llm/openai/speech.rs`

```rust
pub async fn audio_speech_bytes(
    cfg: &LlmConfig,
    client: &reqwest::Client,
    input: &str,        // Narration text
    voice: &str,        // Voice name (e.g., "alloy")
    speed: f32,         // 0.25 - 4.0
    response_format: &str, // "mp3"
) -> Result<Vec<u8>, String>
```

**API Call**:
```json
{
  "model": "tts-1",
  "input": "narration text",
  "voice": "alloy",
  "speed": 1.0,
  "response_format": "mp3"
}
```

**Supported Parameters**:
- ✅ `voice`: String identifier (OpenAI preset voices)
- ✅ `speed`: Float (0.25 - 4.0)
- ✅ `model`: String (e.g., "tts-1", "tts-1-hd")

**Missing Parameters** (not supported by OpenAI TTS API):
- ❌ `emotion`: No emotion control (happy, sad, angry, neutral, etc.)
- ❌ `pitch`: No pitch adjustment
- ❌ `emphasis`: No word/phrase emphasis
- ❌ `style`: No speaking style (narrative, conversational, dramatic, etc.)
- ❌ `character`: No character identity
- ❌ `breath`: No breath control
- ❌ `tone_quality`: No voice texture control

### 3. Available Voices

**OpenAI TTS Voices** (6 presets):
1. **alloy** - Neutral, balanced (default)
2. **echo** - Male, clear
3. **fable** - British accent, expressive
4. **nova** - Female, energetic
5. **shimmer** - Female, soft
6. **onyx** - Male, deep

**Characteristics**:
- Fixed voice personalities (cannot customize)
- No emotion variants per voice
- No age/gender/accent customization
- No Chinese-optimized voices (OpenAI TTS is English-first)

### 4. Voice Configuration Flow

```
User/Frontend
    ↓
POST /api/v1/production/workbench/generate-voiceover
    {
      projectId, scriptId, storyboardIds,
      voice?: "nova",  // Optional override
      speed?: 1.2      // Optional speed
    }
    ↓
resolve_tts_voice(explicit, project_voice_profile)
    ↓
Enqueue voiceover.generate job
    ↓
Worker: voiceover.rs
    ↓
audio_speech_bytes(cfg, text, voice, speed, "mp3")
    ↓
POST {base_url}/audio/speech
    ↓
Persist audio file + metadata
```

**Metadata Stored**:
```json
{
  "state": "completed",
  "audioUrl": "/api/v1/jobs/{job_id}/file",
  "voice": "alloy",
  "speed": 1.0,
  "model": "tts-1",
  "vendorId": "openai",
  "sourceText": "narration text"
}
```

**Gap**: No emotion, character, or scene context stored in metadata.

## Drama Production Requirements vs Current Capabilities

### Requirement 1: Character-Specific Voices

**Drama Need**: Different characters should have distinct, consistent voices throughout the story.

**Current State**: ❌ Not supported
- No character entity in the system
- No character-to-voice mapping
- All narration uses the same voice (project default or explicit override)

**Example Gap**:
```
Scene: 林晚 (female protagonist) and 陆景深 (male antagonist) dialogue

Current: Both use "alloy" voice (or project default)
Needed: 林晚 → "nova" (female, soft), 陆景深 → "onyx" (male, deep)
```

### Requirement 2: Emotion-Aware Voice Control

**Drama Need**: Voice should convey emotion matching the scene (angry, sad, happy, tense, etc.)

**Current State**: ❌ Not supported
- OpenAI TTS has no emotion parameter
- Speed adjustment is the only indirect emotion control (faster = urgent, slower = somber)

**Example Gap**:
```
Scene: 林晚终于失声开口 (Lin Wan finally speaks, voice breaking)

Current: Neutral "alloy" voice at 1.0x speed
Needed: Trembling, emotional voice with breath control
```

### Requirement 3: Seedance 2.0 Voice Dimensions

**Drama Need**: Chinese short drama requires 9-dimension voice control for Seedance 2.0 video generation.

**Location**: `backend/src/production/flow_data/property_tests.rs:85-165`

**Required Dimensions**:
1. **性别** (Gender): 男/女
2. **年龄音色** (Age tone): 少年/青年/中年/老年
3. **音调** (Pitch): 偏高/适中/偏低
4. **音色质感** (Tone quality): 清澈/沙哑/浑厚
5. **声音厚度** (Voice thickness): 轻薄/中等/厚重
6. **发音方式** (Pronunciation): 标准/方言/口音
7. **气息** (Breath): 平稳/急促/绵长
8. **语速** (Speech rate): 偏快/适中/偏慢
9. **特殊质感** (Special texture): 无/颤抖/沙哑/尾音发颤

**Current State**: ❌ Not supported
- Only `voice` (string) and `speed` (float) are configurable
- No structured voice dimension metadata
- No emotion-to-dimension mapping

**Example**:
```rust
// Property test expects this for angry emotion:
"性别:女 年龄音色:青年 音调:偏高 音色质感:清澈 声音厚度:中等 
 发音方式:标准 气息:急促 语速:偏快 特殊质感:无"

// Current implementation can only provide:
{ "voice": "nova", "speed": 1.2 }
```

### Requirement 4: Scene Context Integration

**Drama Need**: Voice should adapt to scene mood, tension, and narrative context.

**Current State**: ❌ Not supported
- Voiceover worker only reads `video_desc` and `prompt` for text
- No access to scene metadata (mood, tension, character state)
- No integration with video prompt memory or style notes

**Example Gap**:
```
Scene metadata (from video generation):
- mood: "oppressive"
- tension: "high"
- character_state: "林晚压低气息尾音发颤"

Current voiceover: Ignores all context, uses default voice
Needed: Adapt voice to match oppressive mood + trembling delivery
```

### Requirement 5: Multi-Character Dialogue

**Drama Need**: Dialogue scenes with multiple speakers should use different voices per character.

**Current State**: ❌ Not supported
- One voiceover job = one audio file = one voice
- No dialogue parsing or speaker attribution
- No multi-track audio assembly

**Example Gap**:
```
Narration text: "林晚低声说道：'我不会原谅你。' 陆景深冷笑：'你没有选择。'"

Current: Single voice reads entire text
Needed: 
  - Track 1: 林晚's voice for "我不会原谅你"
  - Track 2: 陆景深's voice for "你没有选择"
  - Track 3: Narrator voice for "低声说道" and "冷笑"
```

## Gap Analysis by Priority

### P0 - Critical for Drama Production

1. **Character-Voice Mapping**
   - **Impact**: High - Essential for multi-character stories
   - **Complexity**: Medium - Requires character entity + mapping table
   - **Workaround**: Manual voice override per shot (tedious, error-prone)

2. **Emotion Control**
   - **Impact**: High - Core to dramatic storytelling
   - **Complexity**: High - OpenAI TTS doesn't support emotion; need alternative provider
   - **Workaround**: Speed adjustment (limited effectiveness)

3. **Chinese-Optimized TTS**
   - **Impact**: High - OpenAI TTS is English-first, poor Chinese prosody
   - **Complexity**: Medium - Integrate Chinese TTS provider (e.g., Azure, Alibaba, Tencent)
   - **Workaround**: Use OpenAI with Chinese text (suboptimal quality)

### P1 - Important for Quality

4. **Scene Context Integration**
   - **Impact**: Medium - Improves voice-scene coherence
   - **Complexity**: Medium - Pass scene metadata to voiceover worker
   - **Workaround**: Manual voice/speed adjustment per shot

5. **Voice Style Control**
   - **Impact**: Medium - Narrative vs conversational vs dramatic
   - **Complexity**: Medium - Depends on TTS provider capabilities
   - **Workaround**: Use different voices as style proxies

6. **Pitch/Breath Control**
   - **Impact**: Medium - Fine-grained emotional expression
   - **Complexity**: High - Requires advanced TTS or post-processing
   - **Workaround**: None (not achievable with current stack)

### P2 - Nice to Have

7. **Multi-Track Dialogue**
   - **Impact**: Low-Medium - Improves dialogue realism
   - **Complexity**: High - Requires dialogue parsing + multi-track assembly
   - **Workaround**: Single narrator voice for all dialogue

8. **Voice Cloning**
   - **Impact**: Low - Custom character voices
   - **Complexity**: Very High - Requires voice cloning service
   - **Workaround**: Use preset voices

## Vendor Comparison for Drama TTS

### Current: OpenAI TTS

**Pros**:
- ✅ Simple API (text → audio)
- ✅ Good English quality
- ✅ Fast generation
- ✅ Already integrated

**Cons**:
- ❌ No emotion control
- ❌ No Chinese optimization
- ❌ Only 6 preset voices
- ❌ No voice customization
- ❌ No SSML support

**Verdict**: ⚠️ Adequate for basic narration, insufficient for drama production.

### Alternative: Azure Cognitive Services Speech

**Pros**:
- ✅ 400+ voices across 140+ languages
- ✅ Excellent Chinese voices (zh-CN, zh-TW)
- ✅ SSML support (emotion, pitch, rate, emphasis)
- ✅ Neural voices with emotion styles
- ✅ Multi-style voices (newscast, customerservice, cheerful, sad, angry, etc.)

**Cons**:
- ❌ More complex API
- ❌ Requires Azure account
- ❌ Higher cost than OpenAI

**Example SSML**:
```xml
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="zh-CN">
  <voice name="zh-CN-XiaoxiaoNeural">
    <mstts:express-as style="sad" styledegree="2">
      <prosody rate="-10%" pitch="-5%">
        我不会原谅你。
      </prosody>
    </mstts:express-as>
  </voice>
</speak>
```

**Verdict**: ✅ Strong candidate for drama production.

### Alternative: Alibaba Cloud TTS (阿里云语音合成)

**Pros**:
- ✅ Optimized for Chinese
- ✅ Emotion control (happy, sad, angry, etc.)
- ✅ Multi-speaker support
- ✅ SSML support
- ✅ Voice customization

**Cons**:
- ❌ Requires Alibaba Cloud account
- ❌ Documentation primarily in Chinese
- ❌ Less known internationally

**Verdict**: ✅ Good for Chinese drama, but Azure has broader language support.

### Alternative: ElevenLabs

**Pros**:
- ✅ High-quality voice cloning
- ✅ Emotion control
- ✅ Multi-language support
- ✅ Voice design studio

**Cons**:
- ❌ Expensive
- ❌ Slower generation
- ❌ Requires voice samples for cloning

**Verdict**: ⚠️ Overkill for basic drama, useful for premium productions.

## Recommendations

### Immediate Actions (P0)

1. **Add Character Entity and Voice Mapping**
   - Add `app_character` table: `{ id, project_id, name, voice_id, voice_config }`
   - Add `character_id` to `app_storyboard` (nullable, for character-specific shots)
   - Update voiceover worker to resolve voice from character mapping
   - **Benefit**: Consistent character voices across story
   - **Effort**: 2-3 days

2. **Integrate Azure TTS for Chinese Drama**
   - Add Azure Speech SDK or REST API client
   - Add vendor config for Azure (similar to OpenAI)
   - Support SSML generation for emotion/style control
   - **Benefit**: Emotion control + Chinese optimization
   - **Effort**: 3-5 days

3. **Extend Voice Configuration Schema**
   - Change `voice_profile` from string to JSON:
     ```json
     {
       "provider": "azure",
       "voice": "zh-CN-XiaoxiaoNeural",
       "style": "sad",
       "pitch": "-5%",
       "rate": "-10%"
     }
     ```
   - Update voiceover worker to parse structured config
   - **Benefit**: Structured voice control
   - **Effort**: 1-2 days

### Short-Term Enhancements (P1)

4. **Scene Context Integration**
   - Pass scene metadata (mood, tension, character_state) to voiceover worker
   - Map scene context to voice style/emotion
   - Example: `mood: "oppressive"` → `style: "sad"`, `rate: "-10%"`
   - **Benefit**: Voice-scene coherence
   - **Effort**: 2-3 days

5. **Emotion Presets for Common Scenes**
   - Define emotion presets: `neutral`, `happy`, `sad`, `angry`, `tense`, `gentle`
   - Map presets to provider-specific parameters (Azure styles, speed adjustments)
   - Add `emotion` field to voiceover request body
   - **Benefit**: Easy emotion control without SSML knowledge
   - **Effort**: 1-2 days

6. **Voice Preview Endpoint**
   - Add `POST /api/v1/production/voiceover/preview` for testing voices
   - Generate short audio sample with different voices/emotions
   - **Benefit**: Easier voice selection and testing
   - **Effort**: 1 day

### Long-Term Improvements (P2)

7. **Multi-Track Dialogue Assembly**
   - Parse dialogue from narration text (speaker attribution)
   - Generate separate audio tracks per speaker
   - Assemble multi-track audio with timing
   - **Benefit**: Realistic multi-character dialogue
   - **Effort**: 1-2 weeks

8. **Seedance 2.0 Voice Dimension Support**
   - Define 9-dimension voice schema
   - Map dimensions to TTS provider parameters
   - Integrate with Seedance 2.0 video generation
   - **Benefit**: Full drama production pipeline
   - **Effort**: 2-3 weeks

9. **Voice Cloning for Custom Characters**
   - Integrate ElevenLabs or similar voice cloning service
   - Add voice sample upload and training workflow
   - **Benefit**: Unique character voices
   - **Effort**: 2-3 weeks

## Implementation Roadmap

### Phase 1: Foundation (Week 1-2)

- [x] Add character entity and voice mapping — `app_project_character` + `app_storyboard.character_id`；`GET/POST/PATCH/DELETE /api/v1/projects/{id}/characters`
- [x] Extend voice configuration schema to JSON — `short_video/voice/config.rs`（`voice_profile` 字符串或 JSON）
- [x] Add emotion presets — `emotion.rs` + `GET /api/v1/tts/emotion-presets`

### Phase 2: Provider Integration (Week 3-4)

- [x] Integrate Azure TTS with SSML support — `llm/azure/speech.rs` + `voice/ssml.rs`（需 `AZURE_SPEECH_KEY` / `AZURE_SPEECH_REGION`）
- [x] Add voice preview endpoint — `POST /api/v1/tts/preview`、`POST /api/v1/production/voiceover/preview`
- [x] Update voiceover worker for structured config — `jobs/worker/voiceover.rs` 使用 `synthesize_speech`

### Phase 3: Context Integration (Week 5-6)

- [x] Pass scene metadata to voiceover worker — `scene_context_from_metadata` + storyboard `metadata`
- [x] Map scene context to voice parameters — `SceneVoiceContext::infer_emotion`
- [x] Add emotion-to-style mapping logic — `VoiceEmotion::azure_style` / OpenAI speed 代理

### Phase 4: Advanced Features (Week 7+)

- [x] Multi-track dialogue assembly — `dialogue.rs` 解析说话人；worker `multi_track` 分轨合成 + `metadata.tracks`
- [x] Seedance 2.0 voice dimension support — `seedance.rs`（`build_seedance_voice_desc` + 九维标签）
- [x] Voice cloning integration (optional) — `POST /api/v1/tts/clone-voice` 返回 **501**；`cloneVoiceId` 在合成时显式拒绝

## Conclusion

The current TTS implementation is **fundamentally limited** for drama production:
- ✅ **Adequate** for basic narration (single voice, neutral tone)
- ❌ **Insufficient** for multi-character drama (no character voices)
- ❌ **Insufficient** for emotional storytelling (no emotion control)
- ❌ **Insufficient** for Chinese drama (poor Chinese prosody)

**Critical Path**:
1. Add character-voice mapping (enables multi-character stories)
2. Integrate Azure TTS (enables emotion control + Chinese optimization)
3. Extend voice config schema (enables structured voice control)

**Impact**: These three changes would elevate voiceover from "basic narration" to "drama-ready dubbing."

## Files Reviewed

### Core TTS Logic
- `backend/src/short_video/defaults.rs` - Voice resolution logic
- `backend/src/jobs/worker/voiceover.rs` - Voiceover generation worker
- `backend/src/production/workbench/voiceover.rs` - Voiceover enqueue endpoint
- `backend/src/llm/openai/speech.rs` - OpenAI TTS API client

### Configuration
- `backend/data/models_catalog.json` - Vendor/model catalog (no TTS models listed)
- `backend/src/settings/agent_deploy/types.rs` - Agent deploy config structure
- `backend/src/vendor/catalog/` - Vendor catalog system

### Drama Requirements
- `backend/src/production/flow_data/property_tests.rs` - Seedance 2.0 voice dimensions (Property 17)
- `backend/src/production/workbench/video_prompt_memory/style_role.rs` - Role voice style notes
- `backend/src/production/workbench/meta/generate/memory/style_merge.rs` - Role voice note extraction

### Related Systems
- `backend/src/projects/routes/types.rs` - Assembly response types (effective TTS voice)
- `backend/src/projects/routes/handlers/detail/short_video_assembly.rs` - Assembly endpoint

## Next Steps

1. ✅ Document findings (this file)
2. 🔄 Discuss with team: Azure TTS vs Alibaba Cloud vs stay with OpenAI
3. 🔄 Prioritize P0 recommendations based on product roadmap
4. ⏭️ Proceed to next phase or implement P0 recommendations

---

**Appendix: OpenAI TTS Voice Characteristics**

Based on community feedback and testing:

| Voice | Gender | Tone | Best For |
|-------|--------|------|----------|
| alloy | Neutral | Balanced, clear | General narration |
| echo | Male | Warm, conversational | Friendly narrator |
| fable | Male | British, expressive | Storytelling |
| nova | Female | Energetic, bright | Upbeat content |
| shimmer | Female | Soft, gentle | Calm narration |
| onyx | Male | Deep, authoritative | Serious content |

**Note**: These are subjective descriptions; OpenAI doesn't officially document voice personalities.
