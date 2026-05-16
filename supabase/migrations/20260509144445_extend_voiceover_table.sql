-- 扩展配音表，添加 TTS 相关字段（基表见 20260509144443_app_voiceover_table.sql）
ALTER TABLE public.app_voiceover
  ADD COLUMN IF NOT EXISTS tts_provider VARCHAR(50),
  ADD COLUMN IF NOT EXISTS tts_voice_id VARCHAR(50),
  ADD COLUMN IF NOT EXISTS tts_emotion VARCHAR(20),
  ADD COLUMN IF NOT EXISTS tts_speed FLOAT DEFAULT 1.0 CHECK (tts_speed >= 0.5 AND tts_speed <= 2.0),
  ADD COLUMN IF NOT EXISTS task_id UUID;

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_voiceover_task_id ON public.app_voiceover (task_id);
CREATE INDEX IF NOT EXISTS idx_voiceover_tts_provider ON public.app_voiceover (tts_provider);

-- 添加注释
COMMENT ON COLUMN public.app_voiceover.tts_provider IS 'TTS 供应商: openai, azure, google';
COMMENT ON COLUMN public.app_voiceover.tts_voice_id IS 'TTS 声线 ID';
COMMENT ON COLUMN public.app_voiceover.tts_emotion IS 'TTS 情绪: neutral, happy, sad, angry';
COMMENT ON COLUMN public.app_voiceover.tts_speed IS 'TTS 语速: 0.5-2.0';
COMMENT ON COLUMN public.app_voiceover.task_id IS 'TTS 任务 ID';
