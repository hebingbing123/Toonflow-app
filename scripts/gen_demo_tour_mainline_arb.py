#!/usr/bin/env python3
"""One-off generator for demo tour mainline arb keys (en + zh)."""
from __future__ import annotations

import json

# beat_id -> { en: {title, position?, goal, bullets[], demoNote?, nextHint?}, zh: {...} }
BEATS: dict[str, dict[str, dict]] = {
    "Script1": {
        "en": {
            "title": "Script · ① Content & import",
            "position": "Main line step 1/6: everything starts with script and scenes.",
            "goal": "Confirm this project has shootable script content (preloaded in the demo).",
            "bullets": [
                "Left rail: novel import, script list, and scene entry points",
                "Open the script workbench to see outline vs body layout",
                "Agent sidebar on the right is read-only sample chat",
            ],
            "demoNote": "Saves are blocked in demo mode—browse freely.",
            "nextHint": "Next: model routing and quick actions on this step.",
        },
        "zh": {
            "title": "剧本 · ① 内容与导入",
            "position": "制作主线第 1/6 步：一切从剧本和场次开始。",
            "goal": "确认本项目已有可拍的剧本/场次（演示已预填）。",
            "bullets": [
                "左侧：小说导入、剧本列表与场次入口",
                "可打开剧本工作台查看大纲与正文布局",
                "右侧 Agent 区：演示对话为只读样例",
            ],
            "demoNote": "演示模式下保存会被拦截，可放心浏览。",
            "nextHint": "下一步：认识本步的模型与快捷操作区。",
        },
    },
    "Script2": {
        "en": {
            "title": "Script · ② Models & starters",
            "goal": "See how model routing is set up before AI generation (real projects need API keys in Settings).",
            "bullets": [
                "Top or setup area: vendor routing bar",
                "Starter templates and quick actions for common flows",
                "Project cockpit: progress and suggested next actions",
            ],
            "demoNote": "In production, finish Settings → Model vendors before generating.",
            "nextHint": "When script is ready, continue to Art for visual direction.",
        },
        "zh": {
            "title": "剧本 · ② 模型与起步",
            "goal": "了解如何为后续 AI 生成配置模型路由（真项目需在设置里填 API Key）。",
            "bullets": [
                "顶部或设置区：模型厂商 / 路由条",
                "起步模板与快捷动作：一键进入常见工作流",
                "项目驾驶舱：进度与下一步建议",
            ],
            "demoNote": "真环境生成前请完成「设置 → 模型厂商」。",
            "nextHint": "剧本就绪后进入「美术」定视觉风格。",
        },
    },
    "Art1": {
        "en": {
            "title": "Art · ① Style & boards",
            "position": "Main line step 2/6: align the visual language for the whole piece.",
            "goal": "Pick art and story style packs so later images stay consistent.",
            "bullets": [
                "Style pack picker and reference notes",
                "Readiness card with a summary of current style",
                "Open full project settings when you need more control",
            ],
            "demoNote": "Edits in the demo are not persisted.",
            "nextHint": "Next: use the readiness checklist to close gaps.",
        },
        "zh": {
            "title": "美术 · ① 风格与画板",
            "position": "制作主线第 2/6 步：统一全片视觉语言。",
            "goal": "选定美术/叙事风格包，让后续出图一致。",
            "bullets": [
                "风格包选择器与参考说明",
                "可读性卡片：当前风格摘要",
                "需要时可打开完整项目设置",
            ],
            "demoNote": "演示中修改不会保存到真实项目。",
            "nextHint": "下一步：对照就绪度清单补缺口。",
        },
    },
    "Art2": {
        "en": {
            "title": "Art · ② Readiness",
            "goal": "Clear blockers on the Art step before Assets and Storyboard.",
            "bullets": [
                "Readiness score and progress bar",
                "Checklist items jump to the related action (sample in demo)",
                "When ready, the top “Next” control aims at Assets",
            ],
            "nextHint": "Continue to Assets for characters and references.",
        },
        "zh": {
            "title": "美术 · ② 就绪度",
            "goal": "把美术步的阻塞项清掉，再进资产与分镜。",
            "bullets": [
                "就绪度分数与进度条",
                "检查清单：点条目可跳到对应操作（演示为样例）",
                "完成后顶栏「下一步」会指向资产步",
            ],
            "nextHint": "进入「资产」准备角色与参考素材。",
        },
    },
    "Assets1": {
        "en": {
            "title": "Assets · ① Character library",
            "position": "Main line step 3/6: prepare reusable media before storyboard generation.",
            "goal": "Browse character and prop assets available in the sample project.",
            "bullets": [
                "Character asset cards and counts",
                "Open the asset step or asset editor for details",
                "Agent sidebar shows sample collaboration (read-only)",
            ],
            "demoNote": "The sample may deliberately show a “pending anchor” hint.",
            "nextHint": "Next: complete lead character anchors (required in real projects).",
        },
        "zh": {
            "title": "资产 · ① 角色库",
            "position": "制作主线第 3/6 步：为分镜出图准备可复用素材。",
            "goal": "浏览角色/道具资产，确认演示项目里有哪些可用素材。",
            "bullets": [
                "角色资产卡片与数量统计",
                "打开资产步 / 资产编辑器查看详情",
                "Agent 侧栏：示例协作对话（只读）",
            ],
            "demoNote": "示例项目可能故意保留「待锚点」提示。",
            "nextHint": "下一步：补齐主角锚点（真项目必做）。",
        },
    },
    "Assets2": {
        "en": {
            "title": "Assets · ② Anchors",
            "goal": "Anchors lock face and wardrobe so batch storyboard generation stays consistent.",
            "bullets": [
                "Pending-anchor hints and “N anchors left” copy",
                "After anchors, you can batch-generate storyboard frames",
                "Use the journey strip to jump to Storyboard anytime",
            ],
            "nextHint": "When assets are ready, continue to Storyboard (four short beats in this tour).",
        },
        "zh": {
            "title": "资产 · ② 锚点",
            "goal": "理解「锚点」：锁定脸型/服装，分镜批量出图才稳定。",
            "bullets": [
                "待锚点提示与「还差 N 个锚点」文案",
                "补齐后可进入分镜批量出图",
                "顶栏旅程条可随时切到分镜",
            ],
            "nextHint": "资产就绪后进入「分镜」（导览会分 4 小步介绍）。",
        },
    },
    "Storyboard1": {
        "en": {
            "title": "Storyboard · ① Pick episode",
            "position": "Main line step 4/6: turn script into an actionable shot list.",
            "goal": "Select the episode to work on at the top of Storyboard Studio (preselected in the demo).",
            "bullets": [
                "Episode / script dropdown",
                "If the list is empty, go back to Script to add scenes",
            ],
            "demoNote": "The demo does not change real shot data.",
            "nextHint": "Next: the shot list on the left.",
        },
        "zh": {
            "title": "分镜 · ① 选集",
            "position": "制作主线第 4/6 步：把剧本变成可操作的镜头列表。",
            "goal": "在分镜工作室顶部选好要做的那一集（演示已预选示例集）。",
            "bullets": [
                "集数 / 剧本下拉",
                "若列表为空，需先回剧本步补场次",
            ],
            "demoNote": "演示不会修改真实镜头数据。",
            "nextHint": "下一步：认识左侧镜头列表。",
        },
    },
    "Storyboard2": {
        "en": {
            "title": "Storyboard · ② Shot list",
            "goal": "Review each shot’s index, thumbnail, and status (pending, generated, etc.).",
            "bullets": [
                "Left: shot list—tap a row to select",
                "Center: preview for the active shot",
                "Right: prompt, duration, and properties (read-only in demo)",
            ],
            "nextHint": "When the list looks good, use the toolbar for grid batch generation.",
        },
        "zh": {
            "title": "分镜 · ② 镜头列表",
            "goal": "逐镜检查编号、缩略图与状态（待出图 / 已出图等）。",
            "bullets": [
                "左侧：镜头列表，点一条选中",
                "中间：当前镜预览",
                "右侧：提示词、时长等属性（演示只读）",
            ],
            "nextHint": "列表齐全后，用工具栏做「网格批量出图」。",
        },
    },
    "Storyboard3": {
        "en": {
            "title": "Storyboard · ③ Batch images",
            "goal": "Generate frames for many shots at once (demo simulates enqueue—no real billed render).",
            "bullets": [
                "Toolbar: grid storyboard / batch image generation",
                "Pick rows and columns in the dialog, then confirm",
                "Track progress later in Tasks",
            ],
            "demoNote": "Configure model vendor API keys before real generation.",
            "nextHint": "For a single weak frame, open the image workbench next.",
        },
        "zh": {
            "title": "分镜 · ③ 批量出图",
            "goal": "一次为多镜生成画面（演示模拟入队，不扣费真渲染）。",
            "bullets": [
                "工具栏：网格分镜 / 批量出图",
                "弹窗选择行列数后确认",
                "进度可在后面的「任务中心」查看",
            ],
            "demoNote": "真项目出图前请配置模型厂商 API Key。",
            "nextHint": "某一镜不满意时，可进单镜/出图工作台精修。",
        },
    },
    "Storyboard4": {
        "en": {
            "title": "Storyboard · ④ Shot workbench",
            "goal": "Tune prompts, swap images, or regenerate one shot until it is usable.",
            "bullets": [
                "Entries such as “Open image workbench” on a shot row",
                "Workbench: prompts, references, generation history (samples)",
                "Production workspace shows cross-project agent output later",
            ],
            "nextHint": "When frames are stable, continue to Video to assemble the piece.",
        },
        "zh": {
            "title": "分镜 · ④ 单镜精修",
            "goal": "对单镜改提示词、换图或重新生成，直到画面可用。",
            "bullets": [
                "列表中的「打开出图工作台」等入口",
                "工作台：提示词、参考图、生成记录（演示样例）",
                "也可从制作工作台跨项目查看 Agent 输出",
            ],
            "nextHint": "分镜画面稳定后进入「视频」步拼成片。",
        },
    },
    "Video1": {
        "en": {
            "title": "Video · ① Assembly mode",
            "position": "Main line step 5/6: assemble storyboard frames into deliverable video.",
            "goal": "Choose how video is assembled: first frame, last frame, storyboard board, etc.",
            "bullets": [
                "Segmented control for assembly mode",
                "Choice is remembered per project",
                "Demo does not enqueue real renders",
            ],
            "nextHint": "Next: open the production pipeline for generation and export.",
        },
        "zh": {
            "title": "视频 · ① 成片策略",
            "position": "制作主线第 5/6 步：把分镜画面拼成可交付的视频。",
            "goal": "选择成片策略：首帧 / 尾帧 / 分镜板等模式（按项目需要）。",
            "bullets": [
                "分段按钮切换成片模式",
                "选择会按项目记住",
                "演示不触发真实渲染队列",
            ],
            "nextHint": "下一步：进入制作流水线查看生成与导出。",
        },
    },
    "Video2": {
        "en": {
            "title": "Video · ② Production pipeline",
            "goal": "Use the production workspace to track video jobs, writebacks, and task status.",
            "bullets": [
                "Open Production from this step when available",
                "Tasks aggregates render and export queues",
                "In real projects, wait here for the master to finish",
            ],
            "nextHint": "After video is ready, open Deliver for pre-export checks.",
        },
        "zh": {
            "title": "视频 · ② 制作流水线",
            "goal": "在制作工作台跟踪视频生成、写回与任务状态。",
            "bullets": [
                "本步可跳转「打开制作 / Production」",
                "任务中心汇总渲染与导出队列",
                "真项目里在此等待成片完成",
            ],
            "nextHint": "成片后进入「交付」做导出前检查。",
        },
    },
    "Deliver1": {
        "en": {
            "title": "Deliver · ① Export checklist",
            "position": "Main line step 6/6: confirm the piece is ready to hand off.",
            "goal": "Work through the deliver checklist: audio, subtitles, rights, and blockers.",
            "bullets": [
                "Deliver checklists and readiness",
                "Journey strip links to Review pack",
                "Quality sub-tab shows stage scores (sample data)",
            ],
            "demoNote": "This is a quality gate before launch—not a decorative screen.",
            "nextHint": "Next: use Review pack for feedback and blockers.",
        },
        "zh": {
            "title": "交付 · ① 导出清单",
            "position": "制作主线第 6/6 步：确认可以交出成片。",
            "goal": "对照交付清单，处理音乐、字幕、权限等阻塞项。",
            "bullets": [
                "交付步检查清单与准备度",
                "旅程条可打开「审片包」里程碑",
                "质量子页可看阶段评分（演示为样例）",
            ],
            "demoNote": "这是上线前的质量闸口，不是可跳过的装饰页。",
            "nextHint": "下一步：用审片包收反馈、清阻塞。",
        },
    },
    "Deliver2": {
        "en": {
            "title": "Deliver · ② Review & export",
            "goal": "Open Review pack from the journey strip or menu, collect feedback, and clear export blockers.",
            "bullets": [
                "Deliver tab: export readiness and blocker summary",
                "Review pack: thumbnails, feedback, filters, and row detail",
                "Move to publish checks only after blockers are cleared",
            ],
            "nextHint": "Next: Short video for readiness and publish gates.",
        },
        "zh": {
            "title": "交付 · ② 过片与导出",
            "goal": "从旅程条或菜单打开「审片包」，收齐反馈并清掉导出阻塞。",
            "bullets": [
                "交付页：导出准备度与阻塞摘要",
                "审片包：缩略图、反馈状态、筛选与展开",
                "全部通过后，才进入发布检查",
            ],
            "nextHint": "下一步进入「短视频空间」，走完就绪度与发布检查。",
        },
    },
    "LaunchReadiness": {
        "en": {
            "position": "From “master done” to “ready to publish”: Short video handles pre-launch checks.",
            "goal": "Check master readiness—missing assets, duration, cover, etc. surface here.",
            "bullets": [
                "Switch overview, timeline, publish, and other tabs",
                "Readiness metrics and blocker explanations",
                "Demo does not connect to real distribution channels",
            ],
            "demoNote": "Production accounts connect channels here; the demo is walkthrough only.",
            "nextHint": "Next: the publish checklist.",
        },
        "zh": {
            "position": "从「做出片」到「能上线」：短视频空间负责发布前检查。",
            "goal": "看成片就绪度：缺素材、时长、封面等问题会在这里汇总。",
            "bullets": [
                "切换概览 / 时间线 / 发布等子页签",
                "就绪度指标与阻塞说明",
                "演示数据不会连接真实发布渠道",
            ],
            "demoNote": "真账号在此对接渠道；演示只走流程。",
            "nextHint": "下一步：发布检查单。",
        },
    },
    "LaunchPublish": {
        "en": {
            "goal": "Complete pre-publish gates before going live.",
            "bullets": [
                "Publish checklist and statuses",
                "Timeline for shots and audio alignment",
                "Finishing this completes the script-to-launch sample path",
            ],
            "nextHint": "After the main path, optional beats cover Tasks, notifications, and more.",
        },
        "zh": {
            "goal": "走完发布前检查单，确认可以对外上线。",
            "bullets": [
                "发布检查项与状态",
                "时间线核对镜头与配音",
                "通过后即完成「做片并上线」示范线",
            ],
            "nextHint": "主线结束后，导览会简短介绍任务、通知等辅助功能（可跳过）。",
        },
    },
}


def key_prefix(beat_id: str) -> str:
    # Script1 -> demoTourScript1
    return f"demoTour{beat_id}"


def arb_lines(locale: str) -> list[str]:
    lines: list[str] = []
    for beat_id, locales in BEATS.items():
        data = locales[locale]
        prefix = key_prefix(beat_id)
        if "title" in data:
            lines.append(f'  "{prefix}Title": {json.dumps(data["title"], ensure_ascii=False)},')
        if "position" in data:
            lines.append(
                f'  "{prefix}Position": {json.dumps(data["position"], ensure_ascii=False)},'
            )
        if "goal" in data:
            lines.append(f'  "{prefix}Goal": {json.dumps(data["goal"], ensure_ascii=False)},')
        for i, bullet in enumerate(data.get("bullets", []), start=1):
            lines.append(
                f'  "{prefix}Bullet{i}": {json.dumps(bullet, ensure_ascii=False)},'
            )
        if "demoNote" in data:
            lines.append(
                f'  "{prefix}DemoNote": {json.dumps(data["demoNote"], ensure_ascii=False)},'
            )
        if "nextHint" in data:
            lines.append(
                f'  "{prefix}NextHint": {json.dumps(data["nextHint"], ensure_ascii=False)},'
            )
    return lines


def dart_getter(beat_id: str, field: str, bullet_index: int | None = None) -> str:
    prefix = key_prefix(beat_id)
    if field == "title":
        return f"{prefix}Title"
    if field == "position":
        return f"{prefix}Position"
    if field == "goal":
        return f"{prefix}Goal"
    if field == "bullet":
        return f"{prefix}Bullet{bullet_index}"
    if field == "demoNote":
        return f"{prefix}DemoNote"
    if field == "nextHint":
        return f"{prefix}NextHint"
    raise ValueError(field)


def main() -> None:
    for loc in ("en", "zh"):
        print(f"=== {loc} ===")
        for line in arb_lines(loc):
            print(line)
        print()


if __name__ == "__main__":
    main()
