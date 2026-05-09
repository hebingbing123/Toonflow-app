# Implementation Plan: 短视频轻量剪辑工作台增强功能

## Overview

本实现计划将短视频轻量剪辑工作台增强功能分解为可执行的编码任务。实现将分为以下几个主要阶段：

1. **数据库迁移与后端基础设施**：创建新表、扩展现有表、实现 TTS 和导出服务
2. **后端 API 实现**：实现批量操作、TTS 生成、导出任务等 API 端点
3. **前端组件开发**：实现预览播放器、批量操作工具栏、过滤面板等 UI 组件
4. **前端状态管理**：实现操作历史、版本管理、过滤状态等
5. **集成与优化**：性能优化、错误处理、快捷键支持

## Tasks

- [x] 1. 数据库迁移与模型定义
  - [x] 1.1 创建 app_export_task 表
    - 创建数据库迁移文件 `supabase/migrations/YYYYMMDDHHMMSS_create_export_task_table.sql`
    - 定义表结构（id, project_id, version_id, status, stage, progress, format, quality, output_url, error, started_at, completed_at, created_at, updated_at）
    - 创建索引 `idx_export_task_project_id` 和 `idx_export_task_status`
    - _Requirements: 13, 14, 26_

  - [x] 1.2 扩展 app_voiceover 表
    - 创建数据库迁移文件添加 TTS 相关字段
    - 添加字段：tts_provider, tts_voice_id, tts_emotion, tts_speed, task_id
    - 创建索引 `idx_voiceover_task_id`
    - _Requirements: 3, 4_

  - [x] 1.3 定义 Rust 数据模型
    - 在 `backend/src/projects/models/` 创建 `export_task.rs`
    - 定义 ExportTask, ExportQuality, ExportStatus 等结构体
    - 实现 Serialize/Deserialize traits
    - 在 `backend/src/projects/models/voiceover.rs` 扩展 Voiceover 模型
    - _Requirements: 3, 13, 14_

- [x] 2. Checkpoint - 确认数据库迁移
  - 运行数据库迁移并验证表结构
  - 确保所有测试通过，询问用户是否有问题

- [x] 3. 后端 TTS 服务实现
  - [x] 3.1 实现 TTS 服务接口
    - 在 `backend/src/services/` 创建 `tts_service.rs`
    - 定义 TtsService trait 和 VoiceProfile 结构体
    - 实现 OpenAI TTS provider
    - 实现异步任务队列（使用 tokio）
    - _Requirements: 3, 4_

  - [x] 3.2 实现 TTS 状态管理
    - 实现任务状态跟踪（pending/running/completed/failed）
    - 实现任务结果存储到 app_voiceover 表
    - 实现错误处理和重试逻辑
    - _Requirements: 3_

  - [x] 3.3 编写 TTS 服务单元测试
    - 测试 TTS 生成成功场景
    - 测试 TTS 生成失败场景
    - 测试任务状态转换
    - _Requirements: 3, 4_

- [x] 4. 后端导出服务实现
  - [x] 4.1 实现导出任务管理
    - 在 `backend/src/services/` 创建 `export_service.rs`
    - 实现导出任务创建、状态更新、取消功能
    - 实现任务队列管理（最多 3 个并发）
    - _Requirements: 13, 26_

  - [x] 4.2 实现视频编码逻辑
    - 实现 MP4/MOV/WebM 格式支持
    - 实现质量参数配置（分辨率、码率、帧率）
    - 实现进度跟踪和阶段更新
    - _Requirements: 15, 16_

  - [x] 4.3 编写导出服务单元测试
    - 测试任务创建和状态管理
    - 测试并发限制
    - 测试取消功能
    - _Requirements: 13, 26_

- [x] 5. 后端 API 端点实现 - TTS
  - [x] 5.1 实现 POST /api/v1/tts/generate
    - 在 `backend/src/projects/routes/` 创建 `tts_routes.rs`
    - 实现单个镜头 TTS 生成端点
    - 实现请求验证和错误处理
    - 添加 JWT 认证和项目权限检查
    - _Requirements: 3_

  - [x] 5.2 实现 POST /api/v1/tts/batch-generate
    - 实现批量 TTS 生成端点
    - 实现并发控制（最多 5 个并发）
    - 实现批量结果返回
    - _Requirements: 25_

  - [x] 5.3 编写 TTS API 集成测试
    - 测试单个生成 API
    - 测试批量生成 API
    - 测试错误场景（无效参数、权限不足等）
    - _Requirements: 3, 25_

- [x] 6. 后端 API 端点实现 - 导出
  - [x] 6.1 实现 POST /api/v1/export/start
    - 在 `backend/src/projects/routes/` 创建 `export_routes.rs`
    - 实现导出任务启动端点
    - 实现格式和质量参数验证
    - _Requirements: 13, 15, 16_

  - [x] 6.2 实现 GET /api/v1/export/tasks
    - 实现导出任务列表查询
    - 实现按状态和时间过滤
    - 实现分页支持
    - _Requirements: 14, 26_

  - [x] 6.3 实现 POST /api/v1/export/cancel
    - 实现导出任务取消功能
    - 实现任务清理逻辑
    - _Requirements: 13, 26_

  - [x] 6.4 编写导出 API 集成测试
    - 测试导出启动 API
    - 测试任务列表查询
    - 测试任务取消
    - _Requirements: 13, 14, 26_

- [x] 7. 后端 API 端点实现 - 批量操作
  - [x] 7.1 实现 POST /api/v1/workbench/batch-select
    - 在 `backend/src/projects/routes/workbench.rs` 添加批量选择端点
    - 实现并发处理（最多 10 个并发）
    - 实现批量结果统计（成功/失败）
    - _Requirements: 10, 12_

  - [x] 7.2 实现 POST /api/v1/workbench/batch-delete
    - 实现批量禁用镜头端点
    - 实现并发处理和结果统计
    - _Requirements: 10_

  - [x] 7.3 实现 POST /api/v1/workbench/batch-update-duration
    - 实现批量时长对齐端点
    - 实现时长验证（1-300 秒）
    - 实现并发处理和结果统计
    - _Requirements: 11_

  - [x] 7.4 编写批量操作 API 集成测试
    - 测试批量选择 API
    - 测试批量禁用 API
    - 测试批量时长对齐 API
    - 测试并发限制和错误处理
    - _Requirements: 10, 11, 12_

- [x] 8. Checkpoint - 后端 API 验证
  - 使用 Postman 或 curl 测试所有新增 API 端点
  - 确保所有测试通过，询问用户是否有问题

- [x] 9. 前端预览播放器组件
  - [x] 9.1 创建 PreviewPlayer 组件
    - 在 `frontend/lib/short_video_space/components/` 创建 `preview_player.dart`
    - 使用 video_player package 实现视频播放
    - 实现播放控制（播放/暂停/停止）
    - 实现进度条和时间显示
    - _Requirements: 1_

  - [x] 9.2 实现成片连续播放功能
    - 实现播放列表管理
    - 实现镜头切换逻辑
    - 实现上一个/下一个镜头控制
    - 实现总进度和当前镜头进度显示
    - _Requirements: 2_

  - [x] 9.3 集成预览按钮到镜头列表
    - 在 `section_production_assembly.dart` 添加预览按钮
    - 实现预览对话框弹出
    - 实现镜头信息显示
    - _Requirements: 1, 2_

  - [x] 9.4 编写预览播放器单元测试
    - 测试播放状态管理
    - 测试进度跟踪
    - 测试镜头切换逻辑
    - _Requirements: 1, 2_

- [x] 10. 前端批量操作工具栏组件
  - [x] 10.1 创建 BatchOperationToolbar 组件
    - 在 `frontend/lib/short_video_space/components/` 创建 `batch_operation_toolbar.dart`
    - 实现多选框和全选功能
    - 实现选中数量显示
    - 实现范围选择（Shift+点击）
    - _Requirements: 9_

  - [x] 10.2 实现批量操作按钮
    - 实现批量启用/禁用按钮
    - 实现批量时长对齐按钮
    - 实现批量替换按钮
    - 实现批量配音生成按钮
    - _Requirements: 10, 11, 12, 25_

  - [x] 10.3 实现批量操作进度对话框
    - 实现进度显示（百分比、成功/失败统计）
    - 实现失败项列表显示
    - 实现重试失败项功能
    - _Requirements: 10, 11, 12, 25_

  - [x] 10.4 编写批量操作工具栏单元测试
    - 测试选择逻辑
    - 测试批量操作调用
    - 测试进度跟踪
    - _Requirements: 9, 10, 11, 12, 25_

- [x] 11. 前端过滤和搜索组件
  - [x] 11.1 创建 FilterPanel 组件
    - 在 `frontend/lib/short_video_space/components/` 创建 `filter_panel.dart`
    - 实现搜索输入框（防抖 300ms）
    - 实现状态过滤下拉菜单
    - 实现质量过滤下拉菜单
    - _Requirements: 20, 21, 22, 23_

  - [x] 11.2 实现过滤逻辑
    - 实现字幕和旁白全文搜索
    - 实现多条件组合过滤（AND 逻辑）
    - 实现过滤结果高亮显示
    - 实现过滤条件标签显示
    - _Requirements: 22, 23, 24_

  - [x] 11.3 实现过滤预设功能
    - 实现保存常用过滤组合
    - 实现快速应用过滤预设
    - 实现清除所有过滤
    - _Requirements: 24_

  - [x] 11.4 编写过滤组件单元测试
    - 测试搜索逻辑
    - 测试过滤条件组合
    - 测试防抖功能
    - _Requirements: 20, 21, 22, 23, 24_

- [x] 12. 前端版本管理组件
  - [x] 12.1 创建 VersionManager 组件
    - 在 `frontend/lib/short_video_space/components/` 创建 `version_manager.dart`
    - 实现版本列表显示
    - 实现创建新版本功能
    - 实现切换版本功能
    - _Requirements: 6_

  - [x] 12.2 实现草稿管理功能
    - 实现保存草稿到 flow_data
    - 实现草稿列表显示
    - 实现恢复草稿功能
    - 实现草稿数量限制（最多 10 个）
    - _Requirements: 7_

  - [x] 12.3 实现版本对比功能
    - 实现版本对比视图
    - 实现差异高亮显示
    - 实现差异统计
    - 实现导出对比报告
    - _Requirements: 8_

  - [x] 12.4 编写版本管理单元测试
    - 测试版本创建和切换
    - 测试草稿保存和恢复
    - 测试版本对比逻辑
    - _Requirements: 6, 7, 8_

- [x] 13. 前端操作历史管理
  - [x] 13.1 实现 OperationHistory 类
    - 在 `frontend/lib/short_video_space/state/` 创建 `operation_history.dart`
    - 实现撤销栈和重做栈
    - 实现操作记录功能
    - 实现历史数量限制（最多 50 条）
    - _Requirements: 17_

  - [x] 13.2 实现撤销/重做功能
    - 实现撤销操作（Ctrl+Z / Cmd+Z）
    - 实现重做操作（Ctrl+Shift+Z / Cmd+Shift+Z）
    - 实现操作描述显示
    - 实现按钮启用/禁用状态管理
    - _Requirements: 18, 19_

  - [x] 13.3 集成操作历史到主界面
    - 在 `section_production_assembly.dart` 添加撤销/重做按钮
    - 为所有编辑操作添加历史记录
    - 实现操作历史查看功能
    - _Requirements: 17, 18, 19_

  - [x] 13.4 编写操作历史单元测试
    - 测试撤销/重做逻辑
    - 测试历史栈管理
    - 测试操作记录
    - _Requirements: 17, 18, 19_

- [x] 14. 前端 TTS 配音功能
  - [x] 14.1 创建配音参数编辑对话框
    - 在 `frontend/lib/short_video_space/dialogs/` 创建 `voiceover_settings_dialog.dart`
    - 实现 TTS 供应商选择
    - 实现声线 ID 选择
    - 实现情绪和语速调整
    - _Requirements: 4_

  - [x] 14.2 实现配音生成功能
    - 在 `section_production_assembly.dart` 添加生成配音按钮
    - 实现调用 TTS API
    - 实现生成进度显示
    - 实现错误处理和重试
    - _Requirements: 3_

  - [x] 14.3 实现配音音频预览
    - 实现音频播放器组件
    - 实现播放控制和音量调节
    - 实现音频波形或进度条显示
    - _Requirements: 5_

  - [x] 14.4 编写 TTS 功能单元测试
    - 测试参数编辑逻辑
    - 测试配音生成调用
    - 测试音频预览功能
    - _Requirements: 3, 4, 5_

- [x] 15. 前端导出功能
  - [x] 15.1 创建导出设置对话框
    - 在 `frontend/lib/short_video_space/dialogs/` 创建 `export_settings_dialog.dart`
    - 实现格式选择（MP4/MOV/WebM）
    - 实现质量设置（分辨率、码率、帧率）
    - 实现预估文件大小显示
    - _Requirements: 15, 16_

  - [x] 15.2 实现导出进度跟踪
    - 创建导出进度对话框
    - 实现进度轮询（每 2 秒）
    - 实现阶段和百分比显示
    - 实现取消导出功能
    - _Requirements: 13_

  - [x] 15.3 实现导出历史查看
    - 创建导出历史对话框
    - 实现历史记录列表显示
    - 实现按状态和时间过滤
    - 实现重新下载功能
    - _Requirements: 14_

  - [x] 15.4 编写导出功能单元测试
    - 测试导出设置逻辑
    - 测试进度跟踪
    - 测试历史查看
    - _Requirements: 13, 14, 15, 16_

- [x] 16. Checkpoint - 前端组件集成验证
  - 在开发环境中测试所有新增前端组件
  - 确保 UI 交互流畅，询问用户是否有问题

- [x] 17. 性能优化实现
  - [x] 17.1 实现虚拟滚动
    - 在 `section_production_assembly.dart` 使用 flutter_list_view
    - 配置虚拟滚动参数（cacheExtent: 500）
    - 实现动态高度支持
    - 在镜头数量 > 100 时自动启用
    - _Requirements: 29_

  - [x] 17.2 实现操作防抖和节流
    - 为搜索输入添加 300ms 防抖
    - 为过滤条件变更添加 200ms 防抖
    - 为批量操作添加 1000ms 节流
    - 实现操作执行中的按钮禁用
    - _Requirements: 30_

  - [x] 17.3 编写性能优化测试
    - 测试虚拟滚动性能（1000+ 镜头）
    - 测试防抖和节流功能
    - 测试按钮状态管理
    - _Requirements: 29, 30_

- [x] 18. 快捷键和确认对话框
  - [x] 18.1 实现快捷键支持
    - 在 `section_production_assembly.dart` 添加快捷键监听
    - 实现撤销/重做快捷键（Ctrl+Z / Cmd+Z, Ctrl+Shift+Z / Cmd+Shift+Z）
    - 实现保存快捷键（Ctrl+S / Cmd+S）
    - 实现全选快捷键（Ctrl+A / Cmd+A）
    - 实现搜索快捷键（Ctrl+F / Cmd+F）
    - _Requirements: 27_

  - [x] 18.2 实现操作确认对话框
    - 为删除版本添加确认对话框
    - 为批量禁用添加确认对话框
    - 为恢复草稿添加确认对话框
    - 为取消导出添加确认对话框
    - 实现"不再提示"选项
    - _Requirements: 28_

  - [x] 18.3 编写快捷键和确认对话框测试
    - 测试快捷键触发
    - 测试确认对话框显示
    - 测试"不再提示"功能
    - _Requirements: 27, 28_

- [x] 19. 错误处理和日志
  - [x] 19.1 实现前端错误处理
    - 为所有 API 调用添加 try-catch
    - 实现友好的错误消息显示
    - 实现错误重试逻辑
    - _Requirements: 所有_

  - [x] 19.2 实现后端错误处理
    - 为所有 API 端点添加统一错误处理
    - 实现错误日志记录（使用 tracing）
    - 实现错误响应格式化
    - _Requirements: 所有_

  - [x] 19.3 添加监控和日志
    - 添加前端操作日志（logger package）
    - 添加后端操作日志（tracing）
    - 添加关键指标记录（TTS 成功率、导出时长等）
    - _Requirements: 所有_

- [x] 20. 集成测试和文档
  - [x] 20.1 编写端到端集成测试
    - 测试完整的预览播放流程
    - 测试完整的批量操作流程
    - 测试完整的导出流程
    - 测试完整的版本管理流程
    - _Requirements: 所有_

  - [x] 20.2 更新 API 文档
    - 在 `backend/src/openapi_spec/` 更新 OpenAPI 规范
    - 添加新增 API 端点的文档
    - 添加请求/响应示例
    - _Requirements: 所有_

  - [x] 20.3 更新用户文档
    - 在 `docs/` 创建功能使用指南
    - 添加快捷键说明
    - 添加常见问题解答
    - _Requirements: 27_

- [x] 21. Final Checkpoint - 完整功能验证
  - 运行所有测试（backend: cargo test, frontend: flutter test）
  - 在开发环境中进行完整功能测试
  - 确保所有需求都已实现，询问用户是否有问题

## Notes

- 任务标记 `*` 的为可选测试任务，可根据项目进度跳过以加快 MVP 交付
- 每个任务都引用了具体的需求编号，便于追溯
- Checkpoint 任务确保增量验证，及时发现问题
- 后端使用 Rust + Axum，前端使用 Flutter (Dart)
- 数据库使用 PostgreSQL，通过 Supabase 管理
- TTS 服务和导出任务使用异步队列处理
- 操作历史仅在前端内存中维护，不持久化
- 版本管理和草稿存储在 flow_data JSON 字段中
- 批量操作使用并发处理（最多 10 个并发）
- 虚拟滚动在镜头数量 > 100 时自动启用
- 所有 API 端点需要 JWT 认证和项目权限检查

## Task Dependency Graph

```json
{
  "waves": [
    {
      "id": 0,
      "tasks": ["1.1", "1.2"]
    },
    {
      "id": 1,
      "tasks": ["1.3"]
    },
    {
      "id": 2,
      "tasks": ["3.1", "4.1"]
    },
    {
      "id": 3,
      "tasks": ["3.2", "3.3", "4.2", "4.3"]
    },
    {
      "id": 4,
      "tasks": ["5.1", "6.1", "7.1"]
    },
    {
      "id": 5,
      "tasks": ["5.2", "5.3", "6.2", "6.3", "6.4", "7.2", "7.3", "7.4"]
    },
    {
      "id": 6,
      "tasks": ["9.1", "10.1", "11.1", "12.1", "13.1", "14.1"]
    },
    {
      "id": 7,
      "tasks": ["9.2", "9.4", "10.2", "10.4", "11.2", "11.4", "12.2", "12.4", "13.2", "13.4", "14.2", "14.4", "15.1", "15.4"]
    },
    {
      "id": 8,
      "tasks": ["9.3", "10.3", "11.3", "12.3", "13.3", "14.3", "15.2", "15.3"]
    },
    {
      "id": 9,
      "tasks": ["17.1", "17.2", "17.3", "18.1", "18.3"]
    },
    {
      "id": 10,
      "tasks": ["18.2", "19.1", "19.2"]
    },
    {
      "id": 11,
      "tasks": ["19.3", "20.1", "20.2", "20.3"]
    }
  ]
}
```
