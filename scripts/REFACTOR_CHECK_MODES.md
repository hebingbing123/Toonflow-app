# Refactor Check Modes

`scripts/refactor-check.sh` 支持三种运行模式，以优化开发效率。

## 使用方式

### 1. 完整检查（默认）

运行所有检查，包括测试。适用于提交前的最终验证和 CI。

```bash
yarn refactor:check
# 或
bash scripts/refactor-check.sh
```

**包含**:
- ✅ OpenAPI 导出和验证
- ✅ OpenAPI drift 检测
- ✅ rust_api 契约一致性
- ✅ Backend: fmt, clippy, **test**
- ✅ Frontend: pub get, analyze, **test**

**耗时**: ~5-10 分钟（取决于测试数量）

### 2. 快速检查（跳过测试）

运行所有 lint 和验证，但跳过测试。适用于快速验证代码格式和类型检查。

```bash
yarn refactor:quick
# 或
bash scripts/refactor-check.sh --quick
```

**包含**:
- ✅ OpenAPI 导出和验证
- ✅ OpenAPI drift 检测
- ✅ rust_api 契约一致性
- ✅ Backend: fmt, clippy
- ✅ Frontend: pub get, analyze

**跳过**:
- ❌ Backend tests
- ❌ Frontend tests

**耗时**: ~2-3 分钟

### 3. 增量检查（仅检查修改的文件）

只检查修改过的组件。最快的验证方式，适用于开发过程中的频繁检查。

```bash
yarn refactor:incremental
# 或
bash scripts/refactor-check.sh --incremental
```

**智能检测**:
- 如果只修改了 `backend/` 文件 → 只运行 backend 检查
- 如果只修改了 `frontend/` 文件 → 只运行 frontend 检查
- 如果修改了 OpenAPI 相关文件 → 运行 OpenAPI 检查
- 如果没有修改 → 跳过所有检查

**包含**（根据修改的文件）:
- ✅ Backend: fmt, clippy（如果 backend 有修改）
- ✅ Frontend: pub get, analyze（如果 frontend 有修改）
- ✅ OpenAPI 检查（如果 OpenAPI 相关文件有修改）

**跳过**:
- ❌ 所有测试
- ❌ 未修改的组件

**耗时**: ~30 秒 - 2 分钟（取决于修改的组件）

## 推荐使用场景

| 场景 | 推荐模式 | 原因 |
|------|---------|------|
| 开发过程中频繁验证 | `--incremental` | 最快，只检查修改的部分 |
| 提交前快速检查 | `--quick` | 验证格式和类型，跳过耗时的测试 |
| 提交前最终验证 | 完整检查 | 确保所有测试通过 |
| CI/CD | 完整检查 | 保证代码质量 |
| 修复 lint 错误后验证 | `--incremental` | 快速确认修复有效 |

## 示例工作流

### 开发新功能

```bash
# 1. 开发过程中频繁检查
yarn refactor:incremental

# 2. 功能完成后快速验证
yarn refactor:quick

# 3. 提交前完整检查
yarn refactor:check
```

### 修复 lint 错误

```bash
# 1. 修复错误
vim backend/src/some_file.rs

# 2. 快速验证修复
yarn refactor:incremental

# 3. 如果通过，继续开发
```

### 大规模重构

```bash
# 1. 重构过程中使用快速检查
yarn refactor:quick

# 2. 重构完成后运行完整检查
yarn refactor:check
```

## 技术细节

### 增量检查的文件检测

增量模式使用 `git diff` 检测修改的文件：

```bash
# 检测未暂存的修改
git diff --name-only HEAD

# 检测已暂存的修改
git diff --cached --name-only
```

**检测规则**:
- `backend/*` → 触发 backend 检查
- `frontend/*` → 触发 frontend 检查
- `backend/*` 中包含 `openapi`、`routes`、`handlers` → 触发 OpenAPI 检查
- `scripts/check_openapi_drift.sh` 或 `scripts/check_rust_api_consistency.sh` → 触发 OpenAPI 检查

### 性能对比

基于 Toonflow 项目的实际测试（2024-01）：

| 模式 | Backend | Frontend | OpenAPI | 总耗时 |
|------|---------|----------|---------|--------|
| 完整检查 | ~4 分钟 | ~3 分钟 | ~1 分钟 | ~8 分钟 |
| 快速检查 | ~1 分钟 | ~1 分钟 | ~1 分钟 | ~3 分钟 |
| 增量检查（仅 backend） | ~1 分钟 | 跳过 | 跳过 | ~1 分钟 |
| 增量检查（仅 frontend） | 跳过 | ~1 分钟 | 跳过 | ~1 分钟 |
| 增量检查（无修改） | 跳过 | 跳过 | 跳过 | ~1 秒 |

*注：实际耗时取决于硬件性能和项目规模*

## 注意事项

1. **增量检查不是完整验证**
   - 增量检查只验证修改的组件，不保证整体一致性
   - 提交前务必运行完整检查

2. **CI 始终使用完整检查**
   - `.github/workflows/ci.yml` 应始终使用完整检查
   - 不要在 CI 中使用 `--quick` 或 `--incremental`

3. **测试覆盖率**
   - 快速检查和增量检查跳过测试
   - 定期运行完整检查以确保测试通过

4. **OpenAPI 检查**
   - 修改 backend routes/handlers 时会触发 OpenAPI 检查
   - 即使在增量模式下也会运行（因为 OpenAPI 是契约）

## 故障排除

### 增量检查报告"无修改"但实际有修改

**原因**: 文件已提交到 git

**解决**: 使用快速检查或完整检查

```bash
yarn refactor:quick
```

### 增量检查跳过了应该检查的文件

**原因**: 文件路径不在检测规则中

**解决**: 手动运行相应的检查或使用完整检查

```bash
# 手动运行 backend 检查
cd backend && cargo clippy

# 或使用完整检查
yarn refactor:check
```

### 快速检查通过但完整检查失败

**原因**: 测试失败

**解决**: 运行测试并修复失败的测试

```bash
# Backend 测试
cd backend && cargo test

# Frontend 测试
cd frontend && flutter test
```

## 相关文档

- **CI 配置**: `.github/workflows/ci.yml`
- **OpenAPI 检查**: `scripts/check_openapi_drift.sh`
- **rust_api 检查**: `scripts/check_rust_api_consistency.sh`
- **仓库约定**: `AGENTS.md`
