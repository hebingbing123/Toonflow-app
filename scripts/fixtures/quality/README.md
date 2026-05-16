# Quality Fixtures — Golden 集更新流程

本目录存放 Bad_Case_Fixture 文件，用于 CI 发版前回归对比（`quality-regression.yml`）。

## 文件命名规范

```
<stage>_<YYYYMMDD>.json
```

示例：
- `storyboard_panel_20260601.json`
- `video_prompt_20260601.json`

合法的 `stage` 取值：`story_skeleton`、`adaptation_strategy`、`director_planning`、`storyboard_table`、`storyboard_panel`、`video_prompt`。

## Fixture 用途

每个 fixture 文件包含一批经人工确认的评审记录快照（`quality_review_id` + `passed` 状态）。CI job 在发版前读取这些文件，与数据库当前状态对比，若退化率超过 10% 则阻断发版。

## Golden 集更新流程

### 第一步：运行 Export_Tool 生成新 fixture

```bash
# 通过 --ids 指定评审 ID（逗号分隔）
cargo run --bin quality-export -- \
  --ids <id1>,<id2>,<id3> \
  --output scripts/fixtures/quality/<stage>_<YYYYMMDD>.json

# 或通过 --ids-file 从文件读取换行分隔的 ID 列表
cargo run --bin quality-export -- \
  --ids-file path/to/ids.txt \
  --output scripts/fixtures/quality/<stage>_<YYYYMMDD>.json

# 可选：通过 --stage 过滤特定阶段
cargo run --bin quality-export -- \
  --ids-file path/to/ids.txt \
  --stage storyboard_panel \
  --output scripts/fixtures/quality/storyboard_panel_20260601.json
```

Export_Tool 为只读操作，不修改任何数据库记录。

### 第二步：提交 PR 并请求 CODEOWNER review

本目录（`scripts/fixtures/quality/`）受 `.github/CODEOWNERS` 保护，任何文件变更须经指定 CODEOWNER review 后方可合并。

提交 PR 时：

```bash
git add scripts/fixtures/quality/<新文件>.json
git commit -m "chore(fixtures): update quality golden set for <stage> <YYYYMMDD>"
git push -u origin <branch-name>
```

然后在 GitHub 上创建 PR，并 `@` 对应 CODEOWNER 请求 review。

### 第三步：在 PR 描述中说明变更原因

PR 描述须包含以下信息：

```
## Quality Fixture 变更说明

### 新增的 quality_review_id
- `<uuid-1>`：原因（例：新增坏例，grade=D，lip_sync 分值=2）
- `<uuid-2>`：原因

### 移除的 quality_review_id
- `<uuid-3>`：原因（例：该记录已删除 / 不再具有代表性）

### 变更背景
（简述本次更新的业务背景，例：本周抽检发现新类型坏例，补充到 storyboard_panel 守卫集）
```

## 注意事项

- **只读原则**：Export_Tool 不修改数据库，fixture 文件仅为快照，不作为数据源。
- **版本追踪**：fixture 文件一旦合并入主线，历史版本通过 git 记录追溯，不要覆盖已有文件（使用新日期命名）。
- **CI 暂停**：如需临时禁用定时回归检查，将 `.github/workflows/quality-regression.yml` 中的 `schedule` 触发器注释掉即可，`workflow_dispatch` 手动触发保持可用。
- **schemaVersion**：当前 fixture 格式版本为 `"1"`，未来格式升级时向后兼容。
