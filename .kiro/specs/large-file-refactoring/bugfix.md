# Bugfix Requirements Document

## Introduction

本文档定义了大文件拆分的 bugfix 需求。根据仓库约定 (AGENTS.md)，单文件体量应该 ≤800 行，以保持代码可维护性。当前代码库中存在多个严重超标的文件，最严重的达到 12,497 行（超标 15.6 倍）。这些过大的文件违反了仓库约定，降低了代码的可读性、可维护性和模块化程度，增加了 code review 的难度。

本 bugfix 将系统性地识别和拆分这些超标文件，确保所有源文件符合 800 行的限制。

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN 文件 `backend/src/production/workbench/video_prompt_memory/mod.rs` 存在时 THEN 该文件包含 12,497 行代码（超标 15.6 倍）

1.2 WHEN 文件 `backend/src/production/workbench/meta/generate/tests.rs` 存在时 THEN 该文件包含 8,131 行代码（超标 10.2 倍）

1.3 WHEN 文件 `backend/src/production/workbench/video/generate.rs` 存在时 THEN 该文件包含 6,163 行代码（超标 7.7 倍）

1.4 WHEN 文件 `backend/src/production/workbench/video_prompt_memory/tests.rs` 存在时 THEN 该文件包含 4,968 行代码（超标 6.2 倍）

1.5 WHEN 文件 `backend/src/production/workbench/meta/generate/builder.rs` 存在时 THEN 该文件包含 4,644 行代码（超标 5.8 倍）

1.6 WHEN 文件 `backend/src/production/workbench/meta/generate/memory.rs` 存在时 THEN 该文件包含 3,603 行代码（超标 4.5 倍）

1.7 WHEN 文件 `backend/src/production/workbench/video_prompt_memory/rejected.rs` 存在时 THEN 该文件包含 2,996 行代码（超标 3.7 倍）

1.8 WHEN 文件 `backend/src/production/workbench/meta/generate/director.rs` 存在时 THEN 该文件包含 1,089 行代码（超标 1.4 倍）

1.9 WHEN 文件 `backend/src/prompting/quality/handlers/aggregates.rs` 存在时 THEN 该文件包含 1,013 行代码（超标 1.3 倍）

1.10 WHEN 文件 `backend/src/app/pg_contract_tests/production_suite/production_workbench_video_roundtrip.rs` 存在时 THEN 该文件包含 915 行代码（超标 1.1 倍）

1.11 WHEN 文件 `frontend/lib/agent_workspaces/contexts/production/support.dart` 存在时 THEN 该文件包含 1,675 行代码（超标 2.1 倍）

1.12 WHEN 文件 `frontend/lib/projects/workbenches/agent_memory_view.dart` 存在时 THEN 该文件包含 1,161 行代码（超标 1.5 倍）

1.13 WHEN 文件 `frontend/lib/rust_api/benchmark/api.dart` 存在时 THEN 该文件包含 875 行代码（超标 1.1 倍）

1.14 WHEN 文件 `frontend/lib/quality_reviews/workbench_view.dart` 存在时 THEN 该文件包含 805 行代码（超标 1.0 倍）

### Expected Behavior (Correct)

2.1 WHEN 文件 `backend/src/production/workbench/video_prompt_memory/mod.rs` 被拆分后 THEN 该模块的所有文件 SHALL 各自不超过 800 行，且功能完整保持

2.2 WHEN 文件 `backend/src/production/workbench/meta/generate/tests.rs` 被拆分后 THEN 该测试文件 SHALL 被拆分为多个测试模块文件，每个不超过 800 行，且所有测试用例保持

2.3 WHEN 文件 `backend/src/production/workbench/video/generate.rs` 被拆分后 THEN 该文件 SHALL 被拆分为多个子模块，每个不超过 800 行，且视频生成功能完整保持

2.4 WHEN 文件 `backend/src/production/workbench/video_prompt_memory/tests.rs` 被拆分后 THEN 该测试文件 SHALL 被拆分为多个测试模块文件，每个不超过 800 行，且所有测试用例保持

2.5 WHEN 文件 `backend/src/production/workbench/meta/generate/builder.rs` 被拆分后 THEN 该文件 SHALL 被拆分为多个子模块，每个不超过 800 行，且 builder 功能完整保持

2.6 WHEN 文件 `backend/src/production/workbench/meta/generate/memory.rs` 被拆分后 THEN 该文件 SHALL 被拆分为多个子模块，每个不超过 800 行，且 memory 功能完整保持

2.7 WHEN 文件 `backend/src/production/workbench/video_prompt_memory/rejected.rs` 被拆分后 THEN 该文件 SHALL 被拆分为多个子模块，每个不超过 800 行，且 rejected 处理功能完整保持

2.8 WHEN 文件 `backend/src/production/workbench/meta/generate/director.rs` 被拆分后 THEN 该文件 SHALL 被拆分为多个子模块，每个不超过 800 行，且 director 功能完整保持

2.9 WHEN 文件 `backend/src/prompting/quality/handlers/aggregates.rs` 被拆分后 THEN 该文件 SHALL 被拆分为多个子模块，每个不超过 800 行，且 aggregates 处理功能完整保持

2.10 WHEN 文件 `backend/src/app/pg_contract_tests/production_suite/production_workbench_video_roundtrip.rs` 被拆分后 THEN 该测试文件 SHALL 被拆分为多个测试模块文件，每个不超过 800 行，且所有测试用例保持

2.11 WHEN 文件 `frontend/lib/agent_workspaces/contexts/production/support.dart` 被拆分后 THEN 该文件 SHALL 被拆分为多个 Dart 文件，每个不超过 800 行，且 production support 功能完整保持

2.12 WHEN 文件 `frontend/lib/projects/workbenches/agent_memory_view.dart` 被拆分后 THEN 该文件 SHALL 被拆分为多个 widget 文件，每个不超过 800 行，且 agent memory view 功能完整保持

2.13 WHEN 文件 `frontend/lib/rust_api/benchmark/api.dart` 被拆分后 THEN 该文件 SHALL 被拆分为多个 API 文件，每个不超过 800 行，且 benchmark API 功能完整保持

2.14 WHEN 文件 `frontend/lib/quality_reviews/workbench_view.dart` 被拆分后 THEN 该文件 SHALL 被拆分为多个 widget 文件，每个不超过 800 行，且 workbench view 功能完整保持

### Unchanged Behavior (Regression Prevention)

3.1 WHEN 文件已经符合 ≤800 行限制时 THEN 系统 SHALL CONTINUE TO 保持这些文件不变

3.2 WHEN 拆分后的模块被其他代码引用时 THEN 系统 SHALL CONTINUE TO 保持所有公共 API 和导出接口不变

3.3 WHEN 运行现有测试套件时 THEN 系统 SHALL CONTINUE TO 通过所有现有测试用例

3.4 WHEN 执行 `cargo fmt --check` 时 THEN 系统 SHALL CONTINUE TO 符合 Rust 代码格式规范

3.5 WHEN 执行 `cargo clippy -D warnings` 时 THEN 系统 SHALL CONTINUE TO 不产生任何 clippy 警告

3.6 WHEN 执行 `flutter analyze` 时 THEN 系统 SHALL CONTINUE TO 不产生任何分析错误或警告

3.7 WHEN 构建 backend 项目时 THEN 系统 SHALL CONTINUE TO 成功编译

3.8 WHEN 构建 frontend 项目时 THEN 系统 SHALL CONTINUE TO 成功编译

3.9 WHEN 文件被拆分为子模块时 THEN 系统 SHALL CONTINUE TO 保持原有的模块可见性和访问控制（pub/private）

3.10 WHEN 执行 `yarn refactor:check` 门禁检查时 THEN 系统 SHALL CONTINUE TO 通过所有检查项
