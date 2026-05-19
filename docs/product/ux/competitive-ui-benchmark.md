# Studio 竞品 UI 对标矩阵（Wave 0a）

> 可测目标：首条成片路径点击数相对基线 **−20%**；全局主导航 **≤4 项**；任意 AI/渲染任务 **≤2s** 内出现进度反馈。

## 1. 导航与信息架构

| 维度 | waoowaoo | LumenX | huobao-drama | Openflow（当前 Harness） | Openflow（目标 Studio） |
|------|----------|--------|--------------|--------------------------|-------------------------|
| 顶层入口数 | ~功能域侧栏 | 六步 SOP | 4 路由（列表/剧/集/设置） | 15+ Chip/面板 | **4**（项目/通知/设置/帮助） |
| 项目内结构 | features 域 | 步骤条嵌路由 | 单集控制台一页 | short_video_space 平铺 | **ProjectStudio 六步** + 可选 EpisodeConsole |
| 深链 | Next App Router | 步骤 URL | `/drama/:id/episode/:n` | 部分 `/product/*` | **go_router** 全路径 |
| 首启配置 | 设置中心配 Key | 百炼 Key | settings.vue | 分散探针 | **设置中心唯一入口** |

## 2. 首条成片旅程（点击基线 — 待手测填数）

| 步骤 | waoowaoo | LumenX | huobao | Openflow Harness | Openflow Studio（目标） |
|------|----------|--------|--------|------------------|-------------------------|
| 启动 → 已登录工作台 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | ≤3 |
| 创建/打开项目 | _TBD_ | _TBD_ | _TBD_ | _TBD_ | 1 |
| 剧本 → 实体就绪 | _TBD_ | _TBD_ | 1（extractor） | _TBD_ | 1 主 CTA |
| 分镜 → 有图 | _TBD_ | _TBD_ | 控制台内 | _TBD_ | 全屏编辑 ≤2 |
| 视频 → 主选 | _TBD_ | _TBD_ | 控制台内 | _TBD_ | 抽卡 ≤2 |
| 成片导出 | _TBD_ | Merge | 合成+整集 | _TBD_ | **单 CTA** |
| 发布/质检 | — | — | — | 有 API | **差异化 Tab** |

**基线测量日期**：_待填_  
**负责人**：_待填_

## 3. 任务反馈

| 竞品 | 方式 | Openflow 目标 |
|------|------|----------------|
| huobao | 任务进度追踪 | **StudioJobCenter** + WS `generation.job.updated` |
| waoowaoo/LumenX | 队列/模糊 loading | Tray + 步骤内 inline 进度 |

## 4. 差异化（Studio 必须可见）

- 质量门策略与发布前校验
- 九平台发布矩阵（常用 + 展开）
- 工作区 / 团队协作（account、team workspaces 收进设置）

## 5. 截图位（手测时补齐）

1. waoowaoo README 产品图  
2. LumenX 六步说明  
3. huobao 单集工作台（episode 页）  
4. Openflow Harness vs `main_product` / Studio Shell  

## 6. 参考链接

- [waoowaoo](https://github.com/waooAI/waoowaoo)
- [LumenX](https://github.com/alibaba/lumenx)
- [huobao-drama](https://github.com/chatfire-AI/huobao-drama)
