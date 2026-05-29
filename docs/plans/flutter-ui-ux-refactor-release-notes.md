# Flutter UI/UX 重构 — 发布说明（第二十轮）

## 用户可见

- **图表**：用量设置面板模型花费柱状图；平台状态页降级端点趋势 sparkline
- **乐观 UI**：通知标记已读即时反馈，失败自动回滚
- **传输队列**：作业托盘 Sheet 展示进行中的上传/导出（`StudioTransferQueue`）

## 开发者（续第二十轮）

- **桌面原生通知**（macOS/Windows/Linux）：高优先级 toast（成功/错误）同步系统通知
- **原生文件拖拽**：`StudioFileDropZone` 支持 OS 拖入（`desktop_drop`），浏览仍走 `file_picker`
- **离线降级**：作业队列在网络失败时展示上次成功缓存（`StudioOfflineCache`）
- **启动分片**：Benchmark 面板 `deferred` 加载，首屏不拉起重模块
- **Help Hub**：产品级快捷键参考面板（第十九轮）

## 开发者

- `state/immutable_state_template.dart` — 不可变状态手写模板（8.2，非 Freezed 全库）
- `platform/studio_isolate_json.dart` — 大 JSON `Isolate.run` 解码（9.4）
- `scripts/flutter_startup_smoke.sh` / `flutter_perf_smoke.sh` — 启动/性能冒烟（26.3 / 29.1）

## 仍推迟（⬜）

图表库、乐观 UI 全产品清单、`.frag` 毛玻璃、80% 覆盖率 KPI、`desktop_drop` 以外的传输队列统一抽象、ops 监控仪表板 — 见 [`flutter-ui-ux-refactor-signoff.md`](flutter-ui-ux-refactor-signoff.md)。
