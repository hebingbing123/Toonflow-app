-- Migration: Add memory_config JSONB column to app_user_profile for persistent RAG/summary settings
ALTER TABLE app_user_profile
ADD COLUMN IF NOT EXISTS memory_config JSONB DEFAULT NULL;

COMMENT ON COLUMN app_user_profile.memory_config IS 'User memory/RAG configuration (RAG topK, summary limits, ONNX paths) as JSONB. NULL falls back to server defaults.';
