# section_production_assembly.dart 重构方案

## 文件现状

**文件**: `short_video_space/section_production_assembly.dart`  
**行数**: 2594 行  
**类型**: Extension on `_ShortVideoSpaceSectionState`  
**方法数**: 22 个

## 问题分析

1. **单文件过大**: 2594 行，超出目标 3.2 倍
2. **职责混杂**: 包含 Job 追踪、导出流程、UI 构建、对话框等多种职责
3. **可维护性差**: 单个方法过长（最长的方法超过 800 行）

## 拆分方案

### 方案 A：按功能域拆分（推荐）

将文件拆分为 4 个 extension 文件：

```
short_video_space/
├── section_production_assembly.dart              # 保留（主入口，~100 行）
├── section_production_assembly_job_tracking.dart # Job 追踪（~600 行）
├── section_production_assembly_export.dart       # 导出流程（~500 行）
├── section_production_assembly_clip_desk.dart    # Clip Desk 操作（~800 行）
├── section_production_assembly_ui.dart           # UI 构建（~600 行）
```

#### 文件 1: `section_production_assembly_job_tracking.dart` (~600 行)
**职责**: Job 状态追踪和轮询

**包含方法** (行 1-600):
- `_refreshActiveExportTaskDetails()` (Line 16)
- `_refreshActiveAssemblyJob()` (Line 33)
- `_beginAssemblyJobTracking()` (Line 55)
- `_pollActiveAssemblyJobOnce()` (Line 84)
- `_cancelActiveAssemblyJob()` (Line 121)
- `_retryActiveAssemblyJob()` (Line 146)
- `_createDraftFromPreAssemblyJob()` (Line 172)
- `_startPreAssemblyFlow()` (Line 193)

**常量**:
- `_terminalJobStatuses`
- `_preAssemblyJobKind`
- `_exportJobKind`

#### 文件 2: `section_production_assembly_export.dart` (~500 行)
**职责**: 导出流程管理

**包含方法** (行 270-800):
- `_startExportFlow()` (Line 270)
- `_openExportHistoryFlow()` (Line 393)
- `_syncLatestSuccessfulExportFromJob()` (Line 404)
- `_refreshLatestSuccessfulExport()` (Line 420)
- `_downloadLatestSuccessfulExport()` (Line 457)
- `_applyExportHistoryDialogResult()` (Line 491)
- `_showOperationFeedback()` (Line 526)
- `_promptReplacementVideoUrl()` (Line 543)
- `_showAudioPreviewDialog()` (Line 584)

#### 文件 3: `section_production_assembly_clip_desk.dart` (~800 行)
**职责**: Clip Desk 操作和 TTS 任务中心

**包含方法** (行 605-2000):
- `_openAssemblyClipDeskOps()` (Line 605) - 超大方法，~800 行
- `_openTtsTaskCenterDialog()` (Line 1434) - 超大方法，~560 行

**注意**: 这两个方法都非常大，可能需要进一步拆分内部逻辑

#### 文件 4: `section_production_assembly_ui.dart` (~600 行)
**职责**: UI 构建和渲染

**包含方法** (行 2000-2594):
- `_buildVirtualScrollList()` (Line 1996)
- `_buildShotCard()` (Line 2083) - 大方法，~330 行
- `_openAssemblyDefaultsEditor()` (Line 2421)

#### 主文件: `section_production_assembly.dart` (~100 行)
**职责**: 导入和文档说明

```dart
part of 'section.dart';

// ignore_for_file: invalid_use_of_protected_member

/// Assembly and clip desk operations for ShortVideoSpaceSection
/// 
/// This extension is split into multiple files for maintainability:
/// - job_tracking: Job status tracking and polling
/// - export: Export flow management
/// - clip_desk: Clip desk operations and TTS task center
/// - ui: UI building and rendering

part 'section_production_assembly_job_tracking.dart';
part 'section_production_assembly_export.dart';
part 'section_production_assembly_clip_desk.dart';
part 'section_production_assembly_ui.dart';
```

### 方案 B：按方法大小拆分（备选）

如果方案 A 中的某些文件仍然过大，可以进一步拆分：

1. **拆分 `_openAssemblyClipDeskOps()`** (~800 行)
   - 提取内部的 UI 构建逻辑为独立方法
   - 提取事件处理逻辑为独立方法

2. **拆分 `_openTtsTaskCenterDialog()`** (~560 行)
   - 提取 TTS 任务列表构建
   - 提取 TTS 任务操作逻辑

3. **拆分 `_buildShotCard()`** (~330 行)
   - 提取卡片内容构建
   - 提取交互逻辑

## 实施步骤

### 阶段 1: 创建新文件（1 小时）

1. 创建 4 个新的 part 文件
2. 添加 part of 声明
3. 创建 extension 声明

### 阶段 2: 迁移方法（2 小时）

1. **Job Tracking** (600 行)
   - 复制行 1-600 到 `section_production_assembly_job_tracking.dart`
   - 包含常量定义

2. **Export** (500 行)
   - 复制行 270-800 到 `section_production_assembly_export.dart`

3. **Clip Desk** (800 行)
   - 复制行 605-2000 到 `section_production_assembly_clip_desk.dart`

4. **UI** (600 行)
   - 复制行 2000-2594 到 `section_production_assembly_ui.dart`

### 阶段 3: 更新主文件（30 分钟）

1. 删除已迁移的方法
2. 添加 part 声明
3. 保留文档注释

### 阶段 4: 更新 section.dart（10 分钟）

在 `section.dart` 中添加新的 part 声明：

```dart
part 'section_production_assembly.dart';
part 'section_production_assembly_job_tracking.dart';
part 'section_production_assembly_export.dart';
part 'section_production_assembly_clip_desk.dart';
part 'section_production_assembly_ui.dart';
```

### 阶段 5: 验证（30 分钟）

1. 运行 `yarn refactor:agent`
2. 检查编译错误
3. 修复任何引用问题

## 预期收益

### 文件大小
- 主文件: 2594 行 → 100 行 (减少 96%)
- 最大子文件: 800 行 (符合目标)
- 平均子文件: 625 行

### 可维护性
- ✅ 职责单一：每个文件专注一个功能域
- ✅ 易于定位：根据功能快速找到对应文件
- ✅ 降低风险：修改一个功能不影响其他功能

### 代码质量
- ✅ 符合 ≤800 行目标
- ✅ Extension 模式保持不变
- ✅ 不改变运行时行为

## 风险评估

### 低风险
- ✅ 仅文件拆分，不改变逻辑
- ✅ Extension 方法保持不变
- ✅ 编译器自动处理 part 文件

### 需要注意
- ⚠️ 确保所有 part 声明正确
- ⚠️ 检查方法之间的依赖关系
- ⚠️ 验证常量定义的位置

## 后续优化建议

### 进一步拆分超大方法

1. **`_openAssemblyClipDeskOps()`** (800 行)
   ```dart
   // 拆分为：
   - _buildClipDeskDialog() // UI 构建
   - _handleClipDeskAction() // 事件处理
   - _updateClipDeskState() // 状态更新
   ```

2. **`_openTtsTaskCenterDialog()`** (560 行)
   ```dart
   // 拆分为：
   - _buildTtsTaskList() // 任务列表
   - _handleTtsTaskAction() // 任务操作
   - _refreshTtsTaskStatus() // 状态刷新
   ```

3. **`_buildShotCard()`** (330 行)
   ```dart
   // 拆分为：
   - _buildShotCardHeader() // 卡片头部
   - _buildShotCardContent() // 卡片内容
   - _buildShotCardActions() // 卡片操作
   ```

## 时间估算

- **总时间**: 4-5 小时
- **阶段 1**: 1 小时（创建文件）
- **阶段 2**: 2 小时（迁移方法）
- **阶段 3**: 30 分钟（更新主文件）
- **阶段 4**: 10 分钟（更新 section.dart）
- **阶段 5**: 30 分钟（验证）
- **缓冲时间**: 1 小时（处理意外问题）

## 验证清单

拆分完成后必须验证：

- [ ] `yarn refactor:agent` 通过
- [ ] 所有 part 声明正确
- [ ] 没有编译错误
- [ ] 没有新的 lint 警告
- [ ] Git diff 确认只是文件移动
- [ ] 方法调用关系正确
- [ ] 常量定义位置正确

## 提交信息模板

```
refactor(frontend): 拆分 section_production_assembly.dart 为多个文件

AI decision: 采用方案 A（按功能域拆分），因为职责清晰、易于维护。

完成内容：
- 将 2594 行的 section_production_assembly.dart 拆分为 5 个文件
- Job Tracking (600 行): Job 状态追踪和轮询
- Export (500 行): 导出流程管理
- Clip Desk (800 行): Clip Desk 操作和 TTS 任务中心
- UI (600 行): UI 构建和渲染
- 主文件 (100 行): 导入和文档说明

收益：
- 主文件从 2594 行减少到 100 行（减少 96%）
- 每个子文件 ≤800 行，符合目标
- 职责单一，易于维护和定位问题

验证：
- yarn refactor:agent 通过
- 所有编译错误已修复
- 功能完整性保持不变
```

---

**推荐**: 采用方案 A，按功能域拆分为 4 个子文件 + 1 个主文件。
