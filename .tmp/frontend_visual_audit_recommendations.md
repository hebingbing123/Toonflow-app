# 前端视觉与可用性巡检建议

> **落地状态（2026-05）**：P0/P1 主路径已在代码中完成；真源见 [`docs/product/ux/studio-visual-guidelines.md`](../docs/product/ux/studio-visual-guidelines.md)。下文为原始审查记录，供对照与后续增量。

| 巡检项 | 状态 |
|--------|------|
| 全局热区 / `theme.dart` | 已落地 |
| token 色 / 光晕降噪 | 已落地 |
| Shell 导航 / 流程条 | 已落地 |
| `StudioEmptyState` 主路径 | 已落地 |
| UI + desktop 黄金图 | 已 `--update-goldens` |
| 登录 Hero 白字 | 保留（品牌） |

---

基于 `frontend/lib` 设计系统源码、若干核心页面实现，以及现有桌面截图/黄金图（如 `frontend/build/desktop_layouts/*.png`、`frontend/test/goldens/ui_gallery/*.png`）进行静态审查。当前结论：整体方向是统一的深色 Studio 风格，设计系统已经具备一定基础，但在视觉层级、可点击性、组件一致性和空状态表达上仍有明显可优化空间。

## 审查范围

- 设计系统与主题
  - `frontend/lib/design_system/tokens.dart`
  - `frontend/lib/design_system/theme.dart`
  - `frontend/lib/design_system/studio_typography.dart`
  - `frontend/lib/design_system/components/studio_*.dart`
- 核心页面/容器
  - `frontend/lib/home_page.dart`
  - `frontend/lib/product_shell/login_page.dart`
  - `frontend/lib/product_shell/studio_sidebar.dart`
  - `frontend/lib/product_shell/studio_pipeline_strip.dart`
  - `frontend/lib/project_studio/projects_studio_home.dart`
  - `frontend/lib/projects/section.dart`
  - `frontend/lib/product_shell/settings_hub_page.dart`
- 视觉样本
  - `frontend/build/desktop_layouts/01_login.png`
  - `frontend/build/desktop_layouts/02_product_shell_chrome.png`
  - `frontend/build/desktop_layouts/03_projects.png`
  - `frontend/build/desktop_layouts/07_settings_api.png`
  - `frontend/test/goldens/ui_gallery/studio_step_script.png`
  - `frontend/test/goldens/ui_gallery/storyboard_studio.png`

---

## 一、总体评价

### 做得比较好的点

1. **基础色板统一度较高**
   - 深色底、蓝紫主色、青色强调色的关系比较明确，见 `frontend/lib/design_system/tokens.dart`。
2. **已经有较完整的设计系统雏形**
   - 包含按钮、卡片、空状态、媒体卡、文本样式、主题 token 等，见 `frontend/lib/design_system/components/`。
3. **项目首页与设置页的框架感不错**
   - Hero 区、卡片式容器、分区标题和模块 tab 已经具备产品化质感。
4. **有桌面场景意识**
   - 字体和按钮高度按宽度分档，见 `frontend/lib/design_system/studio_typography.dart`，这点比无脑自适应缩放更稳。

### 当前最明显的问题

1. **视觉语言“统一但不完全一致”**
   - 一部分页面走了设计系统组件，一部分仍存在原生 Material 默认样式和硬编码颜色/间距混用。
2. **主次层级偏拥挤**
   - 页面上高亮容器、渐变、描边、阴影、信息块同时出现时，焦点会分散。
3. **按钮与可点击区域存在偏小风险**
   - 尤其主题里大量使用 `shrinkWrap` 和负 `visualDensity`，在桌面可勉强接受，但会削弱可点击性和容错。
4. **空状态组件本身不错，但全局使用还不均匀**
   - 某些模块仍更像“没数据的列表”而不是“有引导的空状态”。
5. **侧栏、顶部工具区、流程条都在抢注意力**
   - 导致进入页面后用户不容易快速定位“当前最重要操作”。

---

## 二、分维度问题与建议

## 1. 视觉层级

### 观察

- 主题定义了较多高亮元素：`panelGlow`、`panelGradient`、`surfaceHighlight`、玻璃质感等，见 `frontend/lib/design_system/theme.dart`、`frontend/lib/design_system/glass.dart`、`frontend/lib/design_system/components/studio_card.dart`。
- 卡片、顶部流程条、设置 Hero、登录页 Hero 都有较强视觉存在感。
- 在项目首页与工作台类页面里，**页面标题、主操作按钮、次级状态卡片**有时没有形成稳定的三级层级。

### 不舒服的点

- 用户第一眼能感知“很精致”，但第二眼会觉得**每块都想让你看**。
- 同屏多个带渐变/描边/光晕的块并列时，主任务焦点被稀释。
- 一些信息区缺少“安静背景”，导致无法承托更重要的 CTA。

### 建议

1. **收敛高亮容器数量**
   - 同一屏最多保留 1 个主视觉强调块；其他卡片回归更平的 surface。
2. **建立稳定的层级规则**
   - 一级：页面标题/当前任务状态
   - 二级：主操作按钮/当前流程节点
   - 三级：辅助说明/统计卡片/次要入口
3. **减少同屏发光元素叠加**
   - 流程条、Hero 卡、主按钮三者不必都强发光。
4. **工作台页面优先让内容区胜出**
   - 容器框架应退后，内容、结果、状态和操作优先。

### 优先级

- **高**：项目首页、脚本工作台、故事板/生产工作台、设置页 Hero。

---

## 2. 间距与密度

### 观察

- Token 中定义了 8/16/24/32 的 spacing，见 `frontend/lib/design_system/tokens.dart`，方向是对的。
- 但实际页面里仍有不少硬编码 `8 / 10 / 12 / 14 / 18 / 20 / 24 / 28` 混用。
- 例如：
  - `frontend/lib/project_studio/projects_studio_home.dart`
  - `frontend/lib/product_shell/studio_pipeline_strip.dart`
  - `frontend/lib/product_shell/settings_hub_page.dart`
  - `frontend/lib/projects/section.dart`

### 不舒服的点

- 页面局部看不出问题，但跨页面切换时会感觉**呼吸感不一致**。
- 有些区块过密，标题和说明、说明和操作之间的距离看起来像“凭感觉写的”。
- 侧栏紧凑、顶部流程条紧凑、正文也紧凑时，整体容易疲劳。

### 建议

1. **把页面 spacing 进一步模块化**
   - 建议定义：page top gap、section gap、card inner gap、title-subtitle gap、action row gap 等语义间距。
2. **限制自由数值**
   - 尽量只允许少量例外值，减少 `10/14/18` 这种游离状态。
3. **增加关键区块留白**
   - 尤其是 Hero 后、主列表前、空状态上下、表单分组之间。
4. **桌面页避免全局高密度**
   - 可在数据表/工具条局部高密度，但不要整页都压缩。

### 优先级

- **高**：项目首页、设置页、帮助/通知/工作台类复合页面。

---

## 3. 字体大小与可读性

### 观察

- `frontend/lib/design_system/studio_typography.dart` 中 compact/regular/large 三档设计合理。
- 但 compact 档里：
  - body 13
  - label 11
  - meta 11
  - hint 12
- `theme.dart` 中还搭配了较紧凑的按钮和输入框。
- 某些组件内部仍直接写 `fontSize: 10/12/14`，如：
  - `frontend/lib/product_shell/studio_sidebar.dart`
  - `frontend/lib/design_system/components/studio_media_card.dart`

### 不舒服的点

- 小字在深色背景下更容易显得发灰、发虚。
- 标签字重不够时，可读性依赖颜色和对比度，长时间使用容易累。
- 某些 badge / 元信息 / 辅助说明字偏小，桌面近看还行，稍远或缩窗就费劲。

### 建议

1. **compact 档谨慎使用 11px 级别文本**
   - label/meta 建议尽量不低于 12，重要 badge 不低于 12。
2. **正文和说明层做明显区分，但不要靠过小字体完成**
   - 可以靠字重、颜色和间距，而不是一味缩小字号。
3. **禁止组件内部随意写死字号**
   - badge、媒体标签、侧栏副标题统一走 typography token。
4. **深色主题下确保辅助文字对比度够用**
   - 尤其 `textMuted` 的使用范围要受控。

### 优先级

- **中高**：侧栏、badge、工具栏、表单辅助文案、媒体卡标签。

---

## 4. 颜色统一性

### 观察

- `tokens.dart` 已有完整语义色值。
- 但代码里仍存在一些直接写死颜色：
  - `frontend/lib/product_shell/studio_sidebar.dart` 选中背景和红色 badge
  - `frontend/lib/projects/section.dart` 使用 `Theme.colorScheme` 与产品皮肤并存
  - `frontend/lib/platform_status/section.dart`、`frontend/lib/content_compliance/section.dart` 等大概率也存在状态色直接使用（从搜索结果可见）
- 说明项目目前处于**设计 token 与业务代码混合阶段**。

### 不舒服的点

- 有些页面是“Studio 产品”，有些局部突然变回“Flutter 默认业务后台”。
- 同样是提示、状态、标签，颜色策略不完全一致。
- 红色、绿色、橙色等语义色若没有统一亮度和饱和度，会显得杂。

### 建议

1. **建立语义色使用规范**
   - 成功、警告、错误、信息、选中、悬停、禁用、描边统一从 token 出。
2. **减少组件内写死十六进制色值**
   - 尤其侧栏选中态、badge、局部 tab 卡片这类高频元素。
3. **状态色做亮度分级**
   - 深色背景里建议区分：填充色、描边色、文字色、弱提示底色。
4. **把“产品风格色”与“系统状态色”彻底分离**
   - 主品牌色不要频繁承担错误/警告语义。

### 优先级

- **高**：侧栏、tab、badge、通知、状态模块、平台状态页、审核/合规模块。

---

## 5. 按钮可点击性与操作反馈

### 观察

- `frontend/lib/design_system/theme.dart` 中：
  - `tapTargetSize: MaterialTapTargetSize.shrinkWrap`
  - `visualDensity: horizontal -1 / vertical -1`
- Filled / Outlined / TextButton 都偏紧。
- `frontend/lib/design_system/components/studio_primary_button.dart` 自定义按钮最小高度 46，尚可。
- 但全局 IconButton / TextButton / InkWell 分布很多，且不一定都套设计系统。

### 不舒服的点

- 鼠标精确点击还行，但**误差容忍度偏低**。
- 图标按钮、顶部工具区、侧栏收起态、流程 chip 容易出现“看得见，点得不够稳”。
- 桌面应用虽然不像移动端需要 44pt 严格规范，但仍需要足够命中面积。

### 建议

1. **放宽全局按钮点击区域**
   - 谨慎使用 `shrinkWrap` 作为全局默认值。
2. **IconButton 统一最小热区**
   - 顶栏、通知、搜索、列表尾部操作建议至少 32~36px 热区。
3. **收起侧栏增加 hover 与 active 反馈**
   - 目前收起态主要靠 tooltip，不够直观。
4. **流程条 chip 保证选中与 hover 差异足够明显**
   - 避免“只是亮一点点”。
5. **高风险操作按钮需要视觉分层**
   - 默认、主操作、危险操作、次级操作要更清晰。

### 代码关注点

- `frontend/lib/design_system/theme.dart`
- `frontend/lib/product_shell/studio_sidebar.dart`
- `frontend/lib/product_shell/studio_app_bar_actions.dart`
- `frontend/lib/product_shell/studio_pipeline_strip.dart`

### 优先级

- **高**：全局按钮策略、顶栏图标按钮、侧栏、流程条。

---

## 6. 空状态设计

### 观察

- `frontend/lib/design_system/components/studio_empty_state.dart` 本身质量不错：有图标、标题、副标题、CTA。
- `frontend/lib/design_system/components/studio_getting_started_steps.dart` 也提供了引导步骤。
- `frontend/lib/project_studio/projects_studio_home.dart` 中项目空状态已经用了这套设计。
- 但从代码搜索看，很多模块仍是 `isEmpty` 逻辑判断，不一定统一接入这套空状态。

### 不舒服的点

- 有的空状态是“没数据”；有的空状态应该是“第一次使用，不知道下一步做什么”。
- 如果只是白板/空列表，会让产品显得“功能还没做完”。
- 后台类模块尤其需要把空状态变成操作引导，而不是信息终点。

### 建议

1. **把空状态分成三类模板**
   - 首次使用空状态
   - 搜索/筛选无结果
   - 数据加载成功但为空
2. **每类空状态都给明确下一步**
   - CTA、步骤、示例、回退动作要齐全。
3. **统一接入设计系统空状态组件**
   - 不要让每个业务模块临时拼一个空容器。
4. **工作台和列表页优先补齐**
   - 通知、任务、搜索结果、项目子模块、资产列表、合规列表等。

### 优先级

- **中高**：搜索结果、通知、任务、资产、内容合规、平台状态等页。

---

## 三、按页面的重点建议

## 1. 登录页

参考：`frontend/lib/product_shell/login_page.dart`、`frontend/build/desktop_layouts/01_login.png`

### 问题

- Hero 区和表单区都较强，首屏视觉重心略分散。
- 背景网格、发光、文案、信号 chip、表单卡片同时发力，有点满。
- 小屏/窄窗下，文案区与表单区切换后的节奏还可以更克制。

### 建议

- 保留一侧强视觉，另一侧做更安静的承托。
- 缩减 chip 数量或减弱次级 chip 的视觉权重。
- 表单区的主按钮突出即可，背景特效不必再强。

优先级：**中高**

---

## 2. 产品 Shell 顶部与侧栏

参考：`frontend/lib/product_shell/studio_sidebar.dart`、`frontend/lib/product_shell/studio_pipeline_strip.dart`、`frontend/build/desktop_layouts/02_product_shell_chrome.png`

### 问题

- 侧栏选中态、流程条、顶栏搜索/动作都较亮，导航系统内部竞争明显。
- 收起侧栏的信息传达主要依赖图标与 tooltip，识别速度一般。
- 侧栏存在硬编码色值，与 token 体系割裂。

### 建议

- 侧栏选中态可更简洁，降低底色饱和度，强化左侧指示或边框即可。
- 顶部流程条与侧栏二选一作为主导航焦点，另一方退后。
- 收起侧栏给更明确 hover ring / active 背景。

优先级：**高**

---

## 3. 项目首页

参考：`frontend/lib/project_studio/projects_studio_home.dart`、`frontend/build/desktop_layouts/03_projects.png`

### 问题

- 首页已经是当前最成熟的页面之一，但仍有轻微“卡片都很重要”的问题。
- 最近项目、项目网格、引导提示、创建按钮都在抢首屏注意力。
- 如果项目变多，视觉密度可能迅速升高。

### 建议

- 首屏只保留一个主动作与一个主信息焦点。
- 最近项目和项目网格做更明显的主次切分。
- 当项目非空时，空状态引导块要弱化，避免和真实内容争权。

优先级：**高**

---

## 4. 设置页

参考：`frontend/lib/product_shell/settings_hub_page.dart`、`frontend/build/desktop_layouts/07_settings_api.png`

### 问题

- Hero 卡设计精致，但略偏重，可能压过实际设置内容。
- tab 卡片样式较强，和正文模块都在争取视觉中心。
- 设置类页面本应强调“清晰、稳定、可扫读”，而不是过强氛围。

### 建议

- Hero 可保留品牌感，但建议减少装饰光带和边框存在感。
- 把更多视觉预算给表单分组、模块边界和当前 tab 状态。
- API、工作区、账号等页内容最好有统一“设置表单骨架”。

优先级：**中高**

---

## 5. 工作台/故事板/脚本页

参考：`frontend/test/goldens/ui_gallery/studio_step_script.png`、`frontend/test/goldens/ui_gallery/storyboard_studio.png`

### 问题

- 这类复杂页面最容易出现信息层级混乱。
- 框架、工具栏、状态、结果、操作并置时，目前设计系统偏“每块都精致”，但复杂工具页更需要“重点明确”。
- 当数据、按钮、状态 chip 同时出现时，扫描负担大。

### 建议

- 工具页优先做“信息架构降噪”，而不是继续增加视觉装饰。
- 一级只突出：当前任务、主要结果、下一步操作。
- 二级区块统一弱化边框、减少发光、保持留白。

优先级：**最高**

---

## 四、从代码层面看，最值得优先统一的地方

## P0：先统一全局交互和样式基线

1. 调整全局按钮/文字按钮/IconButton 点击区域
   - 重点看 `frontend/lib/design_system/theme.dart`
2. 清理设计系统之外的硬编码颜色
   - 尤其 `studio_sidebar.dart` 等高频导航组件
3. 收敛工作台和首页中“多高亮容器并列”的情况

## P1：统一页面 spacing 与 typography 用法

1. 减少组件内部写死字号与间距
2. 补页面级语义 spacing token
3. badge / meta / hint 文本统一走设计系统

## P2：补齐全局空状态模板

1. 搜索无结果
2. 首次使用引导
3. 数据为空但可操作

---

## 五、建议的后续改造顺序

### 第一阶段：低风险统一

- 统一颜色 token 使用
- 放大点击热区
- 收紧硬编码 spacing/fontSize
- 统一空状态接入方式

### 第二阶段：重点页面改造

- 项目首页
- 产品 shell 导航区
- 设置页
- 工作台/故事板/脚本页

### 第三阶段：建立可持续规则

- 设计系统文档化
- 页面骨架模板化
- 视觉检查清单沉淀到 PR 流程

---

## 六、结论

当前前端已经有比较明确的产品化方向和设计系统基础，但还处于“**统一主题已建立，统一执行尚未完成**”的阶段。最不舒服的地方不是单个页面丑，而是：

- 高亮元素偏多
- 层级偶尔抢焦点
- 可点击区域偏紧
- 字号/间距/颜色在局部仍有轻微漂移
- 空状态接入不均匀

如果只做一轮最划算的优化，我建议优先处理：

1. **全局按钮与 IconButton 热区**
2. **导航区与流程条的主次关系**
3. **工作台复杂页面的层级降噪**
4. **颜色/字号/间距 token 收口**
5. **空状态统一模板化**

这五项做完，整体观感会从“有设计感的工程产品”明显进化为“成熟稳定的桌面创作工具”。
