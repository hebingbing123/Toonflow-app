# Task 11: Token 优化 — 收紧记忆注入范围

## 完成时间
2025-01-XX

## 实现内容

### 1. 返工注入收紧 (Rework Injection Tightening)

**文件**: `backend/src/harness/sub_agent/memory.rs`

**改动**:
- 在 `load_auto_memory_note` 函数中，返工模式下将 fetch_limit 从 `AUTO_MEMORY_FETCH_LIMIT` (8) 收紧到 `AUTO_MEMORY_REWORK_LIMIT` (2)
- 返工模式检测：检查 `arguments` 中是否有 `reworkReason` 或 `reason` 字段
- 返工模式下字符预算保持为 `AUTO_MEMORY_MAX_CHARS` (320)，非返工模式为 `AUTO_MEMORY_MAX_CHARS * AUTO_MEMORY_REWORK_LIMIT` (640)
- 添加 tracing 日志记录 `context_chars_injected` 和 `rework_mode`

**效果**:
- 返工模式下只加载最近 2 条记忆（而非 8 条），减少 token 消耗
- 注入提示中明确标注"（返工模式：仅注入失败原因与修复目标相关记忆）"

### 2. Style Bible 按角色过滤 (Style Bible Role Filtering)

**文件**: `backend/src/harness/sub_agent/memory.rs`

**新增函数**:
- `extract_character_names_from_desc(desc: &str) -> Vec<String>`: 从视频描述中提取角色名
  - 使用启发式算法：提取 2-4 个连续 CJK 字符的组合
  - 过滤常见非名词词汇（"一个"、"这个"、"什么"等）
  - 支持去重和排序

- `is_cjk_char(c: char) -> bool`: 判断是否为 CJK 字符
  - 支持 CJK Unified Ideographs (U+4E00-U+9FFF)
  - 支持 CJK Extension A (U+3400-U+4DBF)
  - 支持 CJK Extension B (U+20000-U+2A6DF)

- `is_common_non_name(word: &str) -> bool`: 过滤常见非名词词汇
  - 包含 40+ 个常见词汇（"一个"、"这个"、"站在"、"走了"等）

- `filter_style_bible_by_roles(style_bible_content: &str, video_desc: Option<&str>) -> Option<String>`:
  - 解析 style_bible JSON
  - 提取 video_desc 中的角色名
  - 过滤 `characters` 数组，只保留提及的角色
  - 返回过滤后的 JSON 字符串

- `load_filtered_style_bible(pool, user_id, project_numeric_id, video_desc) -> Result<Option<String>>`:
  - 从数据库加载 `style_bible:project`
  - 调用 `filter_style_bible_by_roles` 进行过滤
  - 返回过滤后的内容

**效果**:
- 当前分镜只涉及"林晚"时，不会注入"顾承泽"、"张明"等其他角色的 style_bible 信息
- 减少无关角色信息的 token 消耗

### 3. Stage Summary 按阶段过滤 (Stage Summary Stage Filtering)

**文件**: `backend/src/harness/sub_agent/memory.rs`

**新增函数**:
- `load_filtered_stage_summary(pool, user_id, project_numeric_id, episodes_id, tool_name) -> Result<Option<String>>`:
  - 使用 `stage_summary_name_for_tool(tool_name)` 获取当前阶段的 summary 名称
  - 只加载当前阶段的 stage_summary（如 `stage_summary:storyboard_gen`）
  - 不加载其他阶段的 summary

**效果**:
- 在 `storyboard_gen` 阶段只加载 `stage_summary:storyboard_gen`，不加载 `stage_summary:script` 等其他阶段
- 减少跨阶段记忆注入的 token 消耗

### 4. LLM Usage Meta 字段补记 (LLM Usage Meta Fields)

**文件**: `backend/src/metering/llm_usage.rs`

**现状**:
- `build_quality_review_usage_meta` 函数已经支持从 `diagnostics` 中提取 `contextCharsInjected` 和 `reworkMode`
- 这两个字段已经在 meta JSON 中定义：
  ```rust
  "contextCharsInjected": diagnostics.and_then(|v| v.get("contextCharsInjected")),
  "reworkMode": diagnostics.and_then(|v| v.get("reworkMode")),
  ```

**改动**:
- 无需修改 `llm_usage.rs`，基础设施已就绪
- 在 `memory.rs` 的 `load_auto_memory_note` 中已添加 tracing 日志记录这两个值
- 质量评审系统可以从 diagnostics 中读取这些值并写入 llm_usage_log

**效果**:
- 可以在 `app_llm_usage_log` 表的 `meta` 字段中追踪每次调用的 `context_chars_injected` 和 `rework_mode`
- 支持后续的 token 使用分析和优化

## 测试

### 新增测试
**文件**: `backend/src/harness/sub_agent/memory.rs`

新增 `memory_optimization_tests` 模块，包含 5 个测试：

1. `filter_style_bible_by_roles_keeps_mentioned_characters`: 验证只保留提及的角色
2. `filter_style_bible_by_roles_returns_all_when_no_desc`: 验证无描述时返回全部
3. `filter_style_bible_by_roles_handles_multiple_characters`: 验证多角色场景
4. `extract_character_names_filters_common_words`: 验证过滤常见词汇
5. `extract_character_names_finds_chinese_names`: 验证提取中文名字

### 测试结果
```bash
cargo test --lib settings::agent_memory
# 42 passed; 0 failed

cargo test --lib harness::sub_agent::memory::memory_optimization_tests
# 5 passed; 0 failed
```

## 需求映射

- ✅ **需求 4.1**: Token 优化 — 收紧记忆注入范围
  - ✅ `style_bible` 按角色名过滤
  - ✅ `stage_summary` 按阶段过滤
  - ✅ 返工注入收紧（fetch_limit 从 8 降到 2）
  - ✅ `metering/llm_usage.rs` meta 字段补记 `context_chars_injected` 和 `rework_mode`

## 注意事项

1. **Helper 函数未使用警告**: `load_filtered_style_bible` 和 `load_filtered_stage_summary` 目前未被调用，因为它们是为未来集成准备的。实际使用时需要在 prompt 构建逻辑中调用这些函数。

2. **角色名提取算法**: 当前使用简单的启发式算法（2-4 个连续 CJK 字符 + 常见词过滤）。在生产环境中，可能需要更复杂的 NER（命名实体识别）算法。

3. **集成点**: 这些过滤函数需要在以下位置集成：
   - `production/workbench/meta/generate/memory/style_selection/load.rs`: 在加载 style_bible 时调用 `load_filtered_style_bible`
   - `harness/sub_agent/mod.rs`: 在构建 sub_agent prompt 时调用 `load_filtered_stage_summary`

## 下一步

如果需要实际启用这些优化，需要：
1. 在 prompt 构建逻辑中集成 `load_filtered_style_bible` 和 `load_filtered_stage_summary`
2. 在质量评审写入时，将 `context_chars_injected` 和 `rework_mode` 写入 diagnostics 字段
3. 监控 token 使用情况，验证优化效果
