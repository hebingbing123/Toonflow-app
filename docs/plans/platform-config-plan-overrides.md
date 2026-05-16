# Platform Config Plan Override Guide

更新时间：2026-05-09

关联：
- [`platform-capabilities-backlog.md`](./platform-capabilities-backlog.md) `P-A4`
- [`toonflow-platform-progress.md`](./toonflow-platform-progress.md)

## 目标

为 `GET /api/v1/settings/platform-config` 提供一层**只读的 plan override**，让服务端可以按 `plan_tier` 统一收口平台能力，再继续叠加 workspace / user 覆盖层。

**边界提醒**：这里的 `plan_tier` 仅作为平台能力开关合成输入使用；它不单独表示当前产品已经启用 workspace-scope quota 或 billing attribution。

当前合成顺序：

1. `defaults`
2. `plan override`
3. `current workspace override`
4. `user override`

即：

```text
effective = defaults
         <- plan override
         <- current workspace override
         <- user override
```

## 环境变量

使用环境变量：

```text
TOONFLOW_PLATFORM_CONFIG_PLAN_OVERRIDES_JSON
```

格式要求：**JSON object**，key 为 `plan_tier`，value 为完整 toggle 集合。

示例：

```json
{
  "free": {
    "helpHubEnabled": true,
    "qualityDashboardEnabled": false,
    "qualityRefreshControlsEnabled": false,
    "workspaceActivityEnabled": false,
    "benchmarkPaneEnabled": false,
    "jobsPaneEnabled": true
  },
  "pro": {
    "helpHubEnabled": true,
    "qualityDashboardEnabled": true,
    "qualityRefreshControlsEnabled": false,
    "workspaceActivityEnabled": true,
    "benchmarkPaneEnabled": false,
    "jobsPaneEnabled": true
  },
  "enterprise": {
    "helpHubEnabled": true,
    "qualityDashboardEnabled": true,
    "qualityRefreshControlsEnabled": true,
    "workspaceActivityEnabled": true,
    "benchmarkPaneEnabled": true,
    "jobsPaneEnabled": true
  }
}
```

## 匹配规则

后端当前按以下顺序匹配 plan override：

1. 精确 key：`plan_tier`
2. 小写 key：`plan_tier.to_ascii_lowercase()`
3. `default`
4. `*`

例子：

- `plan_tier = "free"` 时，优先匹配 `free`
- `plan_tier = "Enterprise"` 时，若没有精确 key，会继续匹配 `enterprise`
- 若没有对应 tier，但配置了 `default` 或 `*`，则落到通配默认层

## 返回形状

`GET /api/v1/settings/platform-config` 当前会额外返回：

- `planTier`
- `planOverride`
- `hasPlanOverride`
- `scope`

其中：

- `hasPlanOverride = true` 表示当前 `effective` 已吃到 plan 层
- `scope` 可能为：
  - `defaults`
  - `plan`
  - `workspace`
  - `user`
  - `plan+workspace`
  - `plan+user`
  - `workspace+user`
  - `plan+workspace+user`

## 运维建议

推荐流程：

1. 先只配置 `free` / `enterprise` 两档，确认主路径行为正确
2. staging 先观察 `planTier`、`hasPlanOverride`、`scope`
3. 再决定是否把 `pro` / `team` / `beta` 等 tier 单独拆出来

不建议：

- 在 `workspace override` 或 `user override` 还没梳理前，直接把所有差异都塞进 plan 层
- 把 plan override 当成一次性实验开关堆场；长期应保持“少量、稳定、可解释”

## 当前边界

本轮只实现：

- plan 层只读 override
- workspace 层可写 override
- user 层可写 override
- `reset=true` 撤销 workspace / user 覆盖层

本轮**未**实现：

- plan override 的数据库持久化
- 后台可视化编辑 plan override
- 按 workspace 套餐直接派生 `plan_tier`
- 更细粒度的 per-feature rollout percentage / cohort targeting
