# Large File Refactoring Bugfix Design

## Overview

本设计文档定义了大文件拆分的技术方案。当前代码库中存在 14 个严重超标的文件（Backend: 10 个，Frontend: 4 个），最严重的达到 12,497 行（超标 15.6 倍）。这些过大的文件违反了仓库约定（≤800 行），降低了代码的可读性、可维护性和模块化程度。

本设计采用系统性的拆分策略，将每个超标文件拆分为多个符合规范的子模块，同时保持所有公共 API 和导出接口不变，确保现有代码引用不受影响。

## Glossary

- **Bug_Condition (C)**: 文件行数超过 800 行的条件
- **Property (P)**: 拆分后每个文件 ≤800 行，且功能完整保持
- **Preservation**: 所有公共 API、导出接口、测试用例、编译通过、门禁检查通过
- **Module Boundary**: 模块边界 - 按功能职责划分的代码单元
- **Public API Surface**: 公共 API 表面 - 模块对外暴露的接口
- **Test Coverage**: 测试覆盖 - 所有现有测试用例必须保持

## Bug Details

### Bug Condition

当源文件的行数超过 800 行时，该文件违反了仓库约定。当前代码库中存在 14 个这样的文件，它们的行数从 805 行到 12,497 行不等。

**Formal Specification:**
```
FUNCTION isBugCondition(file)
  INPUT: file of type SourceFile
  OUTPUT: boolean
  
  lineCount := countLines(file.path)
  RETURN lineCount > 800
END FUNCTION
```

### Examples

- **backend/src/production/workbench/video_prompt_memory/mod.rs**: 12,497 行（超标 15.6 倍）
  - 包含 200+ 函数，涉及视频提示记忆的构建、选择、优化、持久化等多个职责
  
- **backend/src/production/workbench/meta/generate/tests.rs**: 8,131 行（超标 10.2 倍）
  - 包含 300+ 测试函数，覆盖视频提示生成的各种场景
  
- **backend/src/production/workbench/video/generate.rs**: 6,163 行（超标 7.7 倍）
  - 视频生成的核心逻辑
  
- **frontend/lib/agent_workspaces/contexts/production/support.dart**: 1,675 行（超标 2.1 倍）
  - 包含多个数据类和辅助函数

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- 所有公共函数、结构体、trait 的签名和可见性必须保持不变
- 所有现有的 `pub` 和 `pub(crate)` 导出必须继续可用
- 所有测试用例必须继续通过
- 编译必须成功（`cargo build`, `flutter build`）
- 所有 lint 检查必须通过（`cargo clippy`, `flutter analyze`）
- 代码格式必须符合规范（`cargo fmt`, `dart format`）

**Scope:**
所有未被拆分的文件应该完全不受影响。拆分后的模块对外部调用者来说应该是透明的，外部代码不需要修改任何 import 语句或调用方式。

## Hypothesized Root Cause

基于代码分析，大文件产生的主要原因是：

1. **功能聚合过度**: 单个文件承担了过多的职责
   - `video_prompt_memory/mod.rs` 包含了记忆构建、选择、优化、持久化、评分等多个子系统
   - 每个子系统都有大量的辅助函数和数据结构

2. **测试文件膨胀**: 测试文件随着功能增长而线性增长
   - `meta/generate/tests.rs` 包含了 300+ 个测试函数
   - 没有按功能模块拆分测试

3. **缺乏模块化设计**: 代码没有按照清晰的模块边界组织
   - 相关函数散布在同一个大文件中
   - 缺少子模块来组织代码

4. **历史积累**: 随着功能迭代，文件不断增长但没有及时重构

## Correctness Properties

Property 1: Bug Condition - File Size Compliance

_For any_ source file in the codebase after refactoring, the file SHALL contain ≤800 lines of code, ensuring compliance with the repository convention.

**Validates: Requirements 2.1-2.14**

Property 2: Preservation - API Compatibility

_For any_ public API, exported interface, or test case that existed before refactoring, the refactored code SHALL maintain identical behavior and accessibility, preserving all external contracts and test coverage.

**Validates: Requirements 3.1-3.10**

## Fix Implementation

### Refactoring Strategy

采用**按职责拆分**的策略，将大文件拆分为多个职责单一的子模块。每个子模块负责一个清晰的功能领域。

### Backend Files Refactoring Plan

#### 1. backend/src/production/workbench/video_prompt_memory/mod.rs (12,497 lines → ~16 files)

**目标结构:**
```
video_prompt_memory/
├── mod.rs                          (~400 lines) - 模块入口，re-export 公共 API
├── types.rs                        (~300 lines) - 数据结构定义
├── builder.rs                      (~600 lines) - 记忆构建逻辑
├── selector.rs                     (~600 lines) - 记忆选择逻辑
├── optimizer.rs                    (~600 lines) - 记忆优化逻辑
├── persistence.rs                  (~500 lines) - 持久化逻辑
├── scoring.rs                      (~500 lines) - 评分和排序逻辑
├── compaction.rs                   (~600 lines) - 压缩和去重逻辑
├── style_memory.rs                 (~800 lines) - 风格记忆处理
├── role_memory.rs                  (~800 lines) - 角色记忆处理
├── delivery_memory.rs              (~600 lines) - 交付记忆处理
├── parsing.rs                      (~400 lines) - 解析和提取逻辑
├── validation.rs                   (~400 lines) - 验证和过滤逻辑
├── utils.rs                        (~500 lines) - 工具函数
├── focus.rs                        (~600 lines) - 焦点和标签处理
└── tests.rs                        (~800 lines) - 单元测试（从 4,968 行拆分）
```

**拆分原则:**
- `types.rs`: 所有 struct 定义（StoryboardPromptSeedRow, AgentMemoryRow 等）
- `builder.rs`: `build_selected_video_memory` 及相关构建函数
- `selector.rs`: `select_*_memory_notes` 系列函数
- `optimizer.rs`: `optimize_scoped_video_memory`, `plan_selected_video_memory_optimization` 等
- `persistence.rs`: `persist_selected_video_memory`, `load_*`, `delete_*`, `clear_*` 等
- `scoring.rs`: 所有 `score_*` 和 `priority_*` 函数
- `compaction.rs`: 所有 `compact_*` 函数
- `style_memory.rs`: `build_*_video_style_memory`, `select_*_video_style_memory_notes` 等
- `role_memory.rs`: `build_*_role_video_style_memories`, `select_subject_role_*` 等
- `delivery_memory.rs`: 所有与 delivery 相关的函数
- `parsing.rs`: `parse_*`, `extract_*` 函数
- `validation.rs`: `*_is_low_signal`, `*_is_valid`, `*_matches_*` 等验证函数
- `utils.rs`: `normalize_*`, `clip_*`, `strip_*`, `trim_*` 等工具函数
- `focus.rs`: `*_focus_*`, `*_tag_*`, `*_anchor_*` 等焦点处理函数

**Public API 保持策略:**
- `mod.rs` 中使用 `pub use` re-export 所有原本 `pub` 和 `pub(crate)` 的项
- 子模块中的函数保持原有的可见性修饰符
- 外部调用者继续使用 `use crate::production::workbench::video_prompt_memory::*`

#### 2. backend/src/production/workbench/meta/generate/tests.rs (8,131 lines → ~11 files)

**目标结构:**
```
meta/generate/
├── tests/
│   ├── mod.rs                      (~100 lines) - 测试模块入口
│   ├── test_helpers.rs             (~200 lines) - 测试辅助函数
│   ├── build_prompt_tests.rs      (~800 lines) - build_video_prompt 测试
│   ├── compact_tests.rs            (~700 lines) - compact_* 函数测试
│   ├── select_tests.rs             (~700 lines) - select_* 函数测试
│   ├── memory_tests.rs             (~800 lines) - 记忆相关测试
│   ├── anchor_tests.rs             (~700 lines) - anchor 相关测试
│   ├── continuity_tests.rs         (~700 lines) - continuity 相关测试
│   ├── style_tests.rs              (~800 lines) - style 相关测试
│   ├── observation_tests.rs        (~800 lines) - observation 相关测试
│   └── diagnostics_tests.rs        (~800 lines) - diagnostics 相关测试
```

**拆分原则:**
- 按测试的功能领域分组
- 每个测试文件包含相关的测试用例
- `test_helpers.rs` 包含共享的测试辅助函数（如 `grounded_low_risk_fields`, `sample_generate_video_prompt_diagnostics`）
- 保持所有测试函数的 `#[test]` 属性和函数签名不变

#### 3. backend/src/production/workbench/video/generate.rs (6,163 lines → ~8 files)

**目标结构:**
```
video/
├── generate/
│   ├── mod.rs                      (~400 lines) - 模块入口
│   ├── core.rs                     (~800 lines) - 核心生成逻辑
│   ├── prompt_builder.rs           (~800 lines) - 提示构建
│   ├── memory_integration.rs      (~800 lines) - 记忆集成
│   ├── asset_integration.rs       (~700 lines) - 资产集成
│   ├── quality_control.rs         (~700 lines) - 质量控制
│   ├── diagnostics.rs              (~600 lines) - 诊断信息
│   └── utils.rs                    (~400 lines) - 工具函数
```

#### 4. backend/src/production/workbench/video_prompt_memory/tests.rs (4,968 lines → 已包含在 #1 中)

此文件的测试将合并到 `video_prompt_memory/tests.rs` 中。

#### 5. backend/src/production/workbench/meta/generate/builder.rs (4,644 lines → ~6 files)

**目标结构:**
```
meta/generate/
├── builder/
│   ├── mod.rs                      (~300 lines) - 模块入口
│   ├── core.rs                     (~800 lines) - 核心构建逻辑
│   ├── fields.rs                   (~800 lines) - 字段处理
│   ├── validation.rs               (~700 lines) - 验证逻辑
│   ├── transformation.rs           (~800 lines) - 转换逻辑
│   └── utils.rs                    (~500 lines) - 工具函数
```

#### 6. backend/src/production/workbench/meta/generate/memory.rs (3,603 lines → ~5 files)

**目标结构:**
```
meta/generate/
├── memory/
│   ├── mod.rs                      (~300 lines) - 模块入口
│   ├── loader.rs                   (~800 lines) - 记忆加载
│   ├── selector.rs                 (~800 lines) - 记忆选择
│   ├── processor.rs                (~800 lines) - 记忆处理
│   └── utils.rs                    (~500 lines) - 工具函数
```

#### 7. backend/src/production/workbench/video_prompt_memory/rejected.rs (2,996 lines → ~4 files)

**目标结构:**
```
video_prompt_memory/
├── rejected/
│   ├── mod.rs                      (~300 lines) - 模块入口
│   ├── builder.rs                  (~800 lines) - 拒绝记忆构建
│   ├── selector.rs                 (~800 lines) - 拒绝记忆选择
│   └── merger.rs                   (~700 lines) - 拒绝记忆合并
```

#### 8. backend/src/production/workbench/meta/generate/director.rs (1,089 lines → ~2 files)

**目标结构:**
```
meta/generate/
├── director/
│   ├── mod.rs                      (~400 lines) - 模块入口和核心逻辑
│   └── cues.rs                     (~600 lines) - 导演提示处理
```

#### 9. backend/src/prompting/quality/handlers/aggregates.rs (1,013 lines → ~2 files)

**目标结构:**
```
prompting/quality/handlers/
├── aggregates/
│   ├── mod.rs                      (~500 lines) - 模块入口和核心逻辑
│   └── utils.rs                    (~500 lines) - 聚合工具函数
```

#### 10. backend/src/app/pg_contract_tests/production_suite/production_workbench_video_roundtrip.rs (915 lines → ~2 files)

**目标结构:**
```
app/pg_contract_tests/production_suite/
├── production_workbench_video_roundtrip/
│   ├── mod.rs                      (~500 lines) - 主测试逻辑
│   └── helpers.rs                  (~400 lines) - 测试辅助函数
```

### Frontend Files Refactoring Plan

#### 11. frontend/lib/agent_workspaces/contexts/production/support.dart (1,675 lines → ~3 files)

**目标结构:**
```
agent_workspaces/contexts/production/
├── support/
│   ├── support.dart                (~600 lines) - 主要数据类和入口
│   ├── recipes.dart                (~600 lines) - Recipe 相关类和函数
│   └── helpers.dart                (~500 lines) - 辅助函数
```

**拆分原则:**
- `support.dart`: 核心数据类（ProductionWorkspaceRecipe, ProductionWorkspaceStage 等）
- `recipes.dart`: Recipe 构建和处理逻辑
- `helpers.dart`: 辅助函数和工具方法

**Public API 保持策略:**
- `support.dart` 中 export 其他文件的公共类和函数
- 外部调用者继续使用 `import 'package:.../production/support.dart'`

#### 12. frontend/lib/projects/workbenches/agent_memory_view.dart (1,161 lines → ~2 files)

**目标结构:**
```
projects/workbenches/
├── agent_memory_view/
│   ├── agent_memory_view.dart      (~600 lines) - 主 Widget
│   └── memory_widgets.dart         (~600 lines) - 子 Widget 组件
```

#### 13. frontend/lib/rust_api/benchmark/api.dart (875 lines → ~2 files)

**目标结构:**
```
rust_api/benchmark/
├── api/
│   ├── api.dart                    (~500 lines) - API 接口定义
│   └── types.dart                  (~400 lines) - 类型定义
```

#### 14. frontend/lib/quality_reviews/workbench_view.dart (805 lines → ~2 files)

**目标结构:**
```
quality_reviews/
├── workbench_view/
│   ├── workbench_view.dart         (~500 lines) - 主 Widget
│   └── review_widgets.dart         (~400 lines) - 子 Widget 组件
```

### Refactoring Order and Priority

**Phase 1: Backend Core (High Priority)**
1. video_prompt_memory/mod.rs (最大，影响最广)
2. meta/generate/tests.rs (测试文件，独立性强)
3. video/generate.rs (核心功能)

**Phase 2: Backend Supporting (Medium Priority)**
4. video_prompt_memory/tests.rs (测试文件)
5. meta/generate/builder.rs
6. meta/generate/memory.rs
7. video_prompt_memory/rejected.rs

**Phase 3: Backend Remaining (Lower Priority)**
8. meta/generate/director.rs
9. prompting/quality/handlers/aggregates.rs
10. app/pg_contract_tests/.../production_workbench_video_roundtrip.rs

**Phase 4: Frontend (Lower Priority)**
11. agent_workspaces/contexts/production/support.dart
12. projects/workbenches/agent_memory_view.dart
13. rust_api/benchmark/api.dart
14. quality_reviews/workbench_view.dart

### Implementation Steps for Each File

对于每个文件，遵循以下步骤：

1. **分析阶段**
   - 读取完整文件内容
   - 识别所有公共 API（pub, pub(crate)）
   - 按职责分组函数和类型
   - 确定模块边界

2. **创建子模块结构**
   - 创建子目录（如果需要）
   - 创建 `mod.rs` 作为模块入口
   - 创建各个子模块文件

3. **迁移代码**
   - 将函数和类型移动到对应的子模块
   - 保持所有可见性修饰符不变
   - 添加必要的 `use` 语句

4. **更新 mod.rs**
   - 声明所有子模块
   - 使用 `pub use` re-export 所有公共 API
   - 确保外部调用者无需修改 import

5. **验证阶段**
   - 运行 `cargo fmt --check` 或 `dart format --set-exit-if-changed`
   - 运行 `cargo clippy -D warnings` 或 `flutter analyze`
   - 运行 `cargo test` 或 `flutter test`
   - 运行 `yarn refactor:check` 门禁检查

6. **提交**
   - 每个文件拆分完成后立即 commit
   - Commit message: `refactor: split <file_path> into <N> modules (≤800 lines each)`

## Testing Strategy

### Validation Approach

测试策略遵循两阶段方法：首先验证拆分前的代码通过所有测试，然后验证拆分后的代码保持相同的行为。

### Exploratory Bug Condition Checking

**Goal**: 在实施拆分之前，确认当前代码的行为基线。运行所有现有测试并记录结果。

**Test Plan**: 
1. 运行 `cargo test` 记录所有测试通过情况
2. 运行 `flutter test` 记录所有测试通过情况
3. 运行 `yarn refactor:check` 确认门禁通过
4. 记录所有公共 API 的签名和可见性

**Expected Baseline**:
- 所有现有测试应该通过
- 所有 lint 检查应该通过
- 编译应该成功

### Fix Checking

**Goal**: 验证拆分后的每个文件都 ≤800 行，且功能完整保持。

**Pseudocode:**
```
FOR ALL file IN refactoredFiles DO
  lineCount := countLines(file.path)
  ASSERT lineCount <= 800
  
  // 验证编译通过
  ASSERT compile(file) == SUCCESS
  
  // 验证测试通过
  ASSERT runTests(file) == ALL_PASS
END FOR
```

**Test Cases**:
1. **Line Count Test**: 使用脚本验证所有文件 ≤800 行
2. **Compilation Test**: `cargo build` 和 `flutter build` 成功
3. **Unit Test**: 所有单元测试通过
4. **Integration Test**: 所有集成测试通过

### Preservation Checking

**Goal**: 验证拆分后的代码对外部调用者来说是透明的，所有公共 API 保持不变。

**Pseudocode:**
```
FOR ALL publicAPI IN originalPublicAPIs DO
  ASSERT publicAPI.isAccessible() == TRUE
  ASSERT publicAPI.signature == originalSignature
  ASSERT publicAPI.behavior == originalBehavior
END FOR
```

**Testing Approach**: 
- 运行完整的测试套件，确保所有测试通过
- 使用 `cargo clippy` 检查是否有未使用的导入或死代码
- 验证所有 `pub use` 语句正确 re-export 了公共 API

**Test Cases**:
1. **API Compatibility Test**: 外部模块可以继续使用原有的 import 路径
2. **Test Coverage Test**: 所有原有测试用例继续通过
3. **Lint Test**: `cargo clippy -D warnings` 和 `flutter analyze` 通过
4. **Format Test**: `cargo fmt --check` 和 `dart format --set-exit-if-changed` 通过
5. **Gate Test**: `yarn refactor:check` 通过

### Unit Tests

- 每个拆分后的文件应该有对应的单元测试
- 测试文件本身也需要拆分（如 tests.rs）
- 保持所有现有测试用例不变

### Property-Based Tests

- 使用脚本验证所有文件的行数 ≤800
- 使用 `cargo test` 和 `flutter test` 验证功能保持
- 使用 `yarn refactor:check` 验证门禁通过

### Integration Tests

- 运行完整的测试套件
- 验证跨模块的功能正常工作
- 验证 API 兼容性
