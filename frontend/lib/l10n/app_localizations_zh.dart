// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'OpenFlow';

  @override
  String get localeSectionTitle => '界面语言';

  @override
  String get localeSystem => '跟随系统';

  @override
  String get localeEnglish => 'English';

  @override
  String get localeChinese => '简体中文';

  @override
  String get workspaceModeTitle => '工作区模式';

  @override
  String get workspaceModeProduct => '产品工作区';

  @override
  String get workspaceModeDebug => '运维与调试';

  @override
  String get workspaceModeDescriptionProduct => '当前聚焦用户工作流：项目、Agent 工作区、任务与质量。';

  @override
  String get workspaceModeDescriptionDebug =>
      '当前聚焦运维探针：Harness 工具目录、WS 探测与系统诊断。';

  @override
  String errorLine(String detail) {
    return '错误：$detail';
  }

  @override
  String get workspaceContextLoading => '正在加载工作区…';

  @override
  String get workspaceContextNoWorkspace => '无工作区';

  @override
  String get workspaceContextNoProject => '未选择项目';

  @override
  String get workspaceBillingTitle => '工作区计费';

  @override
  String get workspaceBillingUnlimited => '无限制';

  @override
  String get workspaceBillingUnknownTier => '未知';

  @override
  String workspaceBillingPlan(String tier) {
    return '套餐：$tier';
  }

  @override
  String workspaceBillingDailyQuota(String quota) {
    return '每日配额：$quota';
  }

  @override
  String workspaceBillingPercentUsed(String percent) {
    return '已用 $percent%';
  }

  @override
  String get shortVideoSpaceCannotSaveNoProject => '无法保存：未选择项目或未登录';

  @override
  String get shortVideoSpaceSavingInProgress => '正在保存中，请稍候...';

  @override
  String get shortVideoSpaceSelectAllAvailable =>
      '全选快捷键 (Ctrl+A / Cmd+A) 在镜头操作面板中可用';

  @override
  String get shortVideoSpaceSearchFocused => '已聚焦搜索框';

  @override
  String get shortVideoSpaceSearchNotAvailable => '搜索框不可用（请先打开镜头操作面板）';

  @override
  String get shortVideoSpaceSaveProjectConfig => '保存项目配置';

  @override
  String get shortVideoSpaceSelectAllShots => '全选镜头（在批量操作模式下）';

  @override
  String get shortVideoSpaceFocusSearch => '聚焦搜索框';

  @override
  String get shortVideoSpaceUndoOperation => '撤销上一步操作';

  @override
  String get shortVideoSpaceRedoOperation => '重做上一步操作';

  @override
  String get shortVideoSpaceFileOperations => '文件操作';

  @override
  String get shortVideoSpaceSelectionOperations => '选择操作';

  @override
  String get shortVideoSpaceNavigation => '导航';

  @override
  String get shortVideoSpaceEditOperations => '编辑操作';

  @override
  String get shortVideoSpaceKeyboardShortcuts => '键盘快捷键';

  @override
  String get shortVideoSpaceClose => '关闭';

  @override
  String get shortVideoSpaceCurrentProjectOverview => '当前项目概览';

  @override
  String get shortVideoSpaceRecentBadCaseTrends => '最近坏例倾向';

  @override
  String get shortVideoSpaceRecentTaskFlow => '最近任务流';

  @override
  String get shortVideoSpaceAssetsOverview => '资产总览';

  @override
  String get shortVideoSpaceAssemblySnapshot => '成片装配快照';

  @override
  String get shortVideoSpaceQualityReview => '成片候选验收（质量评审）';

  @override
  String get shortVideoSpaceMultiTrackExportDecision => '受限多轨导出决策（K5）';

  @override
  String get shortVideoSpaceOpenProductionWorkspace => '打开制作工作区';

  @override
  String get shortVideoSpaceBasicShotOperations => '镜头基础操作';

  @override
  String get shortVideoSpaceAssemblyStyleAdjustment => '成片样式调整';

  @override
  String get shortVideoSpaceExportPreCheck => '导出前检查';

  @override
  String get shortVideoSpaceQualityGateBlockingReasons => '质量门禁阻断原因';

  @override
  String get shortVideoSpaceBlockingItems => '阻塞项（按接口顺序节选）';

  @override
  String get shortVideoSpaceWarningItems => '警告项（按接口顺序节选）';

  @override
  String get shortVideoSpaceExporting => '导出中…';

  @override
  String get shortVideoSpaceStartExport => '开始导出';

  @override
  String get shortVideoSpaceExportHistory => '导出历史';

  @override
  String get shortVideoSpacePublishJobs => '发布作业';

  @override
  String get shortVideoSpaceScheduleCalendar => '排程月历（按本地日历日计数；点选某日批量写入定时）';

  @override
  String get shortVideoSpaceTargetConfiguration => '短视频目标配置';

  @override
  String get shortVideoSpaceConfigurationDescription =>
      '把创作模式和画幅直接写回项目,后面的脚本与制作流程就能基于同一份项目配置继续工作。';

  @override
  String get shortVideoSpaceTargetProject => '目标项目';

  @override
  String get shortVideoSpaceLoading => '读取中';

  @override
  String get shortVideoSpaceRefreshProjects => '刷新项目';

  @override
  String get shortVideoSpaceRestoreRiskyConfirmation => '恢复高风险确认提示';

  @override
  String get shortVideoSpacePortrait916 => '竖屏 9:16';

  @override
  String get shortVideoSpaceLandscape169 => '横屏 16:9';

  @override
  String get notificationsCenterTitle => '通知中心';

  @override
  String get notificationsCenterSubtitle => '统一汇总任务完成、工作区邀请与技能变更，并保留已读状态。';

  @override
  String get notificationsMarkAllRead => '全部已读';

  @override
  String get notificationsRiskyPrefsTooltip => '本机客户端偏好（短视频等高风险「不再提示」）。';

  @override
  String notificationsFilterUnread(int count) {
    return '未读 $count';
  }

  @override
  String get notificationsTypeFilterLabel => '类型';

  @override
  String get notificationsTypeAll => '全部';

  @override
  String get notificationsTypeJob => '任务';

  @override
  String get notificationsTypeWorkspace => '团队';

  @override
  String get notificationsTypeSkill => '技能';

  @override
  String get notificationsTypeCompliance => '合规';

  @override
  String get notificationsSearchLabel => '搜索标题 / 内容 / file / job';

  @override
  String get notificationsRefresh => '刷新';

  @override
  String get notificationsLoadMore => '加载更多';

  @override
  String get notificationsEmptyFiltered => '当前筛选条件下没有通知。';

  @override
  String get notificationsUnreadBadge => '未读';

  @override
  String get notificationsMarkRead => '标记已读';

  @override
  String get notificationsOpen => '打开';

  @override
  String get notificationsRecordJobSucceeded => '任务完成';

  @override
  String get notificationsRecordJobFailed => '任务失败';

  @override
  String get notificationsRecordJobCancelled => '任务取消';

  @override
  String get notificationsRecordWorkspaceInviteCreated => '邀请已创建';

  @override
  String get notificationsRecordWorkspaceInviteResent => '邀请已重发';

  @override
  String get notificationsRecordWorkspaceInviteRevoked => '邀请已撤销';

  @override
  String get notificationsRecordWorkspaceInviteAccepted => '邀请已接受';

  @override
  String get notificationsRecordSkillChange => '技能变更';

  @override
  String get notificationsRecordContentComplianceAlert => '内容合规告警';

  @override
  String get notificationsRecordContentComplianceCleared => '内容合规告警清除';

  @override
  String get notificationsComplianceClearedThrottleTitle => '合规 cleared 节流（分钟）';

  @override
  String get notificationsComplianceMinutesHint => '1–1440';

  @override
  String get notificationsComplianceSavePolicy => '保存策略';

  @override
  String get notificationsComplianceSaveAsTemplate => '保存为模板';

  @override
  String get notificationsComplianceSaveToWorkspaceShared => '保存到工作区共享';

  @override
  String get notificationsComplianceExportTemplatesJson => '导出模板 JSON';

  @override
  String get notificationsComplianceImportTemplatesJson => '导入模板 JSON';

  @override
  String get notificationsComplianceClearedHelpShort =>
      '同一 stage 在窗口内只发一次 cleared，降低抖动噪音。';

  @override
  String get notificationsComplianceCustomTemplatesOnly => '仅自定义模板';

  @override
  String notificationsComplianceTemplateChip(String name) {
    return '模板：$name';
  }

  @override
  String notificationsComplianceSharedChip(String name) {
    return '共享：$name';
  }

  @override
  String get notificationsComplianceTooltipMoveUp => '上移';

  @override
  String get notificationsComplianceTooltipMoveDown => '下移';

  @override
  String get notificationsComplianceTooltipEditTemplate => '编辑模板';

  @override
  String get notificationsComplianceTooltipDeleteTemplate => '删除模板';

  @override
  String get notificationsComplianceWorkspaceSharedHeader => '工作区共享模板';

  @override
  String get notificationsComplianceTooltipEditSharedTemplate => '编辑共享模板';

  @override
  String get notificationsComplianceTooltipDeleteSharedTemplate => '删除共享模板';

  @override
  String notificationsComplianceStageOverrideLabel(String stage) {
    return '$stage 覆盖值';
  }

  @override
  String get notificationsComplianceStageOverrideHint => '留空=跟随全局';

  @override
  String get notificationsComplianceSharedAuditTitle => '共享模板审计';

  @override
  String get notificationsComplianceFilterTemplateId => '模板 ID 过滤';

  @override
  String get notificationsComplianceFilterAction => '动作过滤';

  @override
  String get notificationsComplianceFilterStartIso => '开始时间(ISO8601)';

  @override
  String get notificationsComplianceFilterEndIso => '结束时间(ISO8601)';

  @override
  String get notificationsComplianceApplyFilters => '应用筛选';

  @override
  String get notificationsComplianceDownloadAuditJson => '下载审计 JSON';

  @override
  String get notificationsComplianceDownloadAuditCsv => '下载审计 CSV';

  @override
  String get notificationsComplianceAsyncJson => '异步 JSON';

  @override
  String get notificationsComplianceAsyncCsv => '异步 CSV';

  @override
  String get notificationsComplianceCloseTooltip => '关闭';

  @override
  String get notificationsComplianceExportHistoryTitle => '导出历史';

  @override
  String get notificationsComplianceExportFormatFilter => '导出格式筛选';

  @override
  String get notificationsComplianceExportedStartIso => '导出时间起(ISO)';

  @override
  String get notificationsComplianceExportedEndIso => '导出时间止(ISO)';

  @override
  String get notificationsComplianceFilterExports => '筛选导出历史';

  @override
  String get notificationsComplianceReuseExportFiltersTooltip => '复用该次筛选到上方';

  @override
  String get notificationsComplianceMoreExportRecords => '更多导出记录';

  @override
  String get notificationsComplianceLoadMoreAudit => '加载更多审计';

  @override
  String get notificationsComplianceThrottleInvalidGlobal =>
      '请输入 1–1440 的整数分钟值。';

  @override
  String notificationsComplianceThrottleStageInvalid(String stage) {
    return '$stage：请输入 1–1440 的整数分钟值，或留空。';
  }

  @override
  String get notificationsDialogSaveClearedTemplateTitle => '保存 cleared 模板';

  @override
  String get notificationsDialogSaveWorkspaceSharedTemplateTitle => '保存工作区共享模板';

  @override
  String notificationsDialogEditTemplateTitle(String id) {
    return '编辑模板：$id';
  }

  @override
  String notificationsDialogDeleteTemplateTitle(String label) {
    return '删除模板：$label';
  }

  @override
  String get notificationsDialogDeleteTemplateBody => '删除后不可恢复，是否继续？';

  @override
  String notificationsDialogDeleteSharedTemplateTitle(String label) {
    return '删除共享模板：$label';
  }

  @override
  String get notificationsDialogDeleteSharedTemplateBody =>
      '删除后会影响当前工作区所有成员，是否继续？';

  @override
  String notificationsDialogEditSharedTemplateTitle(String id) {
    return '编辑共享模板：$id';
  }

  @override
  String get notificationsFieldTemplateIdAscii => '模板 ID（英文）';

  @override
  String get notificationsFieldTemplateName => '模板名称';

  @override
  String get notificationsFieldTemplateDescription => '模板说明';

  @override
  String get notificationsFieldImportMode => '导入模式';

  @override
  String get notificationsFieldPasteTemplatesJson => '粘贴模板 JSON';

  @override
  String get notificationsImportModeReplace => 'replace（覆盖）';

  @override
  String get notificationsImportModeMerge => 'merge（合并）';

  @override
  String get notificationsActionCancel => '取消';

  @override
  String get notificationsActionSave => '保存';

  @override
  String get notificationsActionDelete => '删除';

  @override
  String get notificationsActionImport => '导入';

  @override
  String get notificationsSnackTemplateIdAndNameRequired => '模板 ID 和名称不能为空。';

  @override
  String get notificationsSnackExportFiltersReused => '已复用该次导出的筛选并刷新审计列表。';

  @override
  String notificationsSnackDownloadedByHistory(String path) {
    return '已按历史条件下载：$path';
  }

  @override
  String notificationsSnackExportQueued(int taskId) {
    return '后台导出已排队（任务 #$taskId）。导出历史会在任务完成后自动刷新。';
  }

  @override
  String notificationsSnackSharedAuditJsonSaved(String path) {
    return '共享审计 JSON 已下载：$path';
  }

  @override
  String notificationsSnackSharedAuditCsvSaved(String path) {
    return '共享审计 CSV 已下载：$path';
  }

  @override
  String get notificationsSnackTemplatesJsonCopied => '模板 JSON 已复制到剪贴板。';

  @override
  String get notificationsDialogImportTemplatesJsonTitle => '导入模板 JSON';

  @override
  String notificationsSnackImportDone(int count) {
    return '导入完成：$count 条模板。';
  }

  @override
  String get notificationsUnknownTime => '未知时间';

  @override
  String notificationsPrefsAuditUpdatedLine(
    String time,
    String by,
    String source,
  ) {
    return '策略最近更新：$time · $by · $source';
  }

  @override
  String get notificationsAuditActionUpsert => '新增/更新';

  @override
  String get notificationsAuditActionDelete => '删除';

  @override
  String get notificationsAuditAllActions => '全部动作';

  @override
  String get notificationsAuditAllTemplates => '全部模板';

  @override
  String get notificationsExportRecordLeadIn => '导出记录：';

  @override
  String get notificationsExportDownloadAsyncArtifact => '下载该次后台导出落盘的文件';

  @override
  String get notificationsExportRedownloadSync => '按相同条件再次下载（同步生成）';

  @override
  String get notificationsExportDeliveryAsync => ' · 异步';

  @override
  String notificationsExportDeliveryAsyncWithJob(String jobId) {
    return ' · 异步(job:$jobId)';
  }

  @override
  String get notificationsExportDeliverySync => ' · 同步';

  @override
  String get riskyPrefsMenuDefaultTooltip => '本机客户端偏好';

  @override
  String get riskyPrefsTooltipSameAsMainPanelHeaders =>
      '本机客户端偏好（与各主面板标题旁 ⋯ 相同）';

  @override
  String get riskyPrefsMenuViewSilencesTitle => '查看已静默的高风险确认';

  @override
  String get riskyPrefsMenuViewSilencesSubtitle => '只读列表，不影响设置';

  @override
  String get riskyPrefsMenuResetTitle => '恢复高风险操作确认提示';

  @override
  String get riskyPrefsMenuResetSubtitle => '仅本机，与服务器配置无关';

  @override
  String get riskyPrefsSummaryDialogTitle => '已静默的高风险确认';

  @override
  String get riskyPrefsSummaryEmptyBody => '当前没有勾选「不再提示」的记录。';

  @override
  String get riskyPrefsSummaryNonEmptyIntro =>
      '以下操作在本机将不再弹出确认框（可随时在「恢复高风险操作确认提示」中清除）：';

  @override
  String get riskyPrefsSummaryClose => '关闭';

  @override
  String get riskyPrefsResetDialogTitle => '恢复快风险确认框';

  @override
  String get riskyPrefsResetBody =>
      '将清除本机「不再提示」记录。此后删除版本、归档、取消导出等操作会重新弹出确认（仅影响当前设备上的本应用）。';

  @override
  String get riskyPrefsResetNoSavedLabel => '当前无已保存的「不再提示」条目。仍可清除可能的残留键。';

  @override
  String get riskyPrefsResetHasItemsLabel => '当前已静默确认的项目：';

  @override
  String get riskyPrefsResetCancel => '取消';

  @override
  String get riskyPrefsResetConfirm => '清除并恢复';

  @override
  String get riskyPrefsResetSuccessSnack => '已清除本机高风险操作的「不再提示」偏好；后续将重新弹出确认。';

  @override
  String get riskyPrefsLabelDeleteVersion => '删除成片版本';

  @override
  String get riskyPrefsLabelBatchDisable => '批量禁用镜头';

  @override
  String get riskyPrefsLabelRestoreDraft => '恢复草稿覆盖';

  @override
  String get riskyPrefsLabelCancelExport => '取消成片导出';

  @override
  String get riskyPrefsLabelBatchArchivePublish => '批量归档发布草稿';

  @override
  String get platformConfigSectionTitle => '平台配置';

  @override
  String get platformConfigSectionSubtitle =>
      '管理产品壳层的功能开关与运营面可见性。effective 现按 defaults <- plan override <- current workspace override <- user override 合成。';

  @override
  String get platformConfigLocalPrefsDescription =>
      '下列项仅影响当前设备上的本应用本地存储，与服务器侧平台配置无关。需要恢复删除版本、归档、导出等二次确认时，请点上方标题栏 ⋯ 菜单。';

  @override
  String get platformConfigButtonRefreshing => '加载中…';

  @override
  String get platformConfigButtonRefresh => '刷新配置';

  @override
  String get platformConfigButtonSaving => '保存中…';

  @override
  String get platformConfigButtonSaveUser => '保存用户配置';

  @override
  String get platformConfigButtonResetUser => '重置用户覆盖';

  @override
  String get platformConfigButtonSaveWorkspace => '保存 workspace 配置';

  @override
  String get platformConfigButtonResetWorkspace => '重置 workspace 覆盖';

  @override
  String get platformConfigButtonCopyJson => '复制 JSON';

  @override
  String get platformConfigToggleHelpHubTitle => '帮助 Hub';

  @override
  String get platformConfigToggleHelpHubSubtitle => '控制帮助 / 文档产品入口的可见性';

  @override
  String get platformConfigToggleQualityMainTitle => '质量主面板';

  @override
  String get platformConfigToggleQualityMainSubtitle => '控制质量运营看板与主面板摘要区';

  @override
  String get platformConfigToggleQualityRefreshTitle => '质量刷新控制';

  @override
  String get platformConfigToggleQualityRefreshSubtitle =>
      '控制物化读模型 refresh 相关按钮与入口';

  @override
  String get platformConfigTogglePlatformStatusTitle => '平台状态';

  @override
  String get platformConfigTogglePlatformStatusSubtitle =>
      '控制平台状态（Health/Ready/SLI/Metrics）入口';

  @override
  String get platformConfigToggleWorkspaceActivityTitle => '工作区动态';

  @override
  String get platformConfigToggleWorkspaceActivitySubtitle =>
      '控制 Agent Workspace Activity 导航入口';

  @override
  String get platformConfigToggleBenchmarkTitle => '评测基线';

  @override
  String get platformConfigToggleBenchmarkSubtitle => '控制 benchmark / 评测相关产品入口';

  @override
  String get platformConfigToggleJobsTitle => '任务作业';

  @override
  String get platformConfigToggleJobsSubtitle => '控制 jobs 面板导航入口';

  @override
  String get platformConfigPlanLayerIntro =>
      '套餐层是只读覆盖层，来自服务端环境配置；适合先做分层收口，再由 workspace / user 继续细调。';

  @override
  String get platformConfigPlanStateActive => '当前状态：plan override 已生效';

  @override
  String get platformConfigPlanStateInactive =>
      '当前状态：未配置 plan override，直接继承 defaults';

  @override
  String get platformConfigWorkspaceEnterpriseIntro =>
      '当前 enterprise workspace 的公共覆盖层，会先于个人配置参与 effective 合成。';

  @override
  String get platformConfigWorkspaceViewOnlyIntro =>
      '当前 workspace 仅展示公共覆盖层；只有 enterprise owner/admin 可以修改。';

  @override
  String get platformConfigWorkspaceStateWritten =>
      '当前状态：已写入 workspace override';

  @override
  String get platformConfigWorkspaceStateInherit => '当前状态：继承 defaults，再叠个人覆盖';

  @override
  String get platformConfigWorkspaceNoDraftEnterprise =>
      '当前 workspace 没有可编辑的公共覆盖层。请先切到 enterprise owner/admin 身份，或等待公共覆盖配置下发。';

  @override
  String get platformConfigWorkspaceNoDraftPersonal =>
      '当前 workspace 为 personal。workspace 级公共覆盖层仅对 enterprise workspace 开放。';

  @override
  String get platformConfigUserOverrideIntro => '个人覆盖层始终最后生效，适合放自己的运营视图与工具偏好。';

  @override
  String get platformConfigUserStateWritten => '当前状态：已写入 user override';

  @override
  String get platformConfigUserStateInherit => '当前状态：直接继承 workspace/defaults';

  @override
  String get platformConfigSnackUserSaved => '已保存用户平台配置';

  @override
  String get platformConfigSnackUserReset => '已重置用户覆盖层';

  @override
  String get platformConfigSnackWorkspaceSaved => '已保存当前 workspace 平台配置';

  @override
  String get platformConfigSnackWorkspaceReset => '已重置 workspace 覆盖层';

  @override
  String get platformConfigSnackCopyJsonDone => '已复制平台配置 JSON';

  @override
  String get platformConfigPleaseSignIn => '请先登录';

  @override
  String get productNavSectionTitle => '产品导航';

  @override
  String get productNavShortVideoSpace => '短视频 Space';

  @override
  String get productNavProjects => '项目';

  @override
  String get productNavAccount => '账户';

  @override
  String get productNavApiKeys => 'API 密钥';

  @override
  String get productNavNotifications => '通知中心';

  @override
  String get productNavContentCompliance => '内容合规';

  @override
  String get productNavPlatformStatus => '平台状态';

  @override
  String get productNavTeamWorkspaces => '团队工作区';

  @override
  String get productNavScriptWorkspace => '脚本工作区';

  @override
  String get productNavProductionWorkspace => '制作工作区';

  @override
  String get productNavWorkspaceActivity => '工作区动态';

  @override
  String get productNavBenchmark => '评测基线';

  @override
  String get productNavTasks => '任务中心';

  @override
  String get productNavJobs => '任务作业';

  @override
  String get productNavQuality => '质量评审';

  @override
  String get productNavPlatformConfig => '平台配置';

  @override
  String get productNavHelp => '帮助';

  @override
  String get productAgentScriptWorkspaceTitle => '剧本工作区';

  @override
  String get productAgentScriptWorkspaceSubtitle =>
      '专注剧本 Agent 工作流：上下文探测、子 Agent 编排与正文/计划回写。';

  @override
  String get productAgentProductionWorkspaceTitle => '制作工作区';

  @override
  String get productAgentProductionWorkspaceSubtitle =>
      '专注 production Agent 工作流：flow 数据读取、资产/分镜工具执行与安全回写。';

  @override
  String get productAgentActivityTitle => '执行动态';

  @override
  String get productAgentActivitySubtitle =>
      '集中查看最近 WS 事件、工具回执与回写状态，作为统一执行日志面板。';

  @override
  String get productPaneDisabledHelpHub => '当前平台配置已关闭帮助 Hub，可在「平台配置」中重新开启。';

  @override
  String get productPaneDisabledQuality => '当前平台配置已关闭质量主面板，可在「平台配置」中重新开启。';

  @override
  String get productPaneDisabledPlatformStatus =>
      '当前平台配置已关闭平台状态入口，可在「平台配置」中重新开启。';

  @override
  String get productPaneDisabledWorkspaceActivity =>
      '当前平台配置已关闭执行动态面板，可在「平台配置」中重新开启。';

  @override
  String get productPaneDisabledBenchmark => '当前平台配置已关闭评测基线入口，可在「平台配置」中重新开启。';

  @override
  String get productPaneDisabledJobs => '当前平台配置已关闭 jobs 面板，可在「平台配置」中重新开启。';

  @override
  String get productComplianceSnackAccountPanel => '已切到账户面板；用户治理仍建议在内部管理台处理。';

  @override
  String get productComplianceSnackNotSignedIn => '当前未登录，无法打开目标上下文。';

  @override
  String productComplianceTeamContext(String detail) {
    return '该举报已切到团队工作区上下文；$detail';
  }

  @override
  String get productComplianceNoProjectContext => '该举报没有可打开的项目上下文。';

  @override
  String productComplianceOpenTargetFailed(String detail) {
    return '打开目标失败：$detail';
  }

  @override
  String get platformConfigPlanOverrideTitle => 'Plan 覆盖';

  @override
  String get platformConfigWorkspaceOverrideTitle => 'Workspace 覆盖';

  @override
  String get platformConfigUserOverrideTitle => '用户覆盖';

  @override
  String get helpHubDocsTitle => '帮助 / 文档';

  @override
  String get helpHubLocalRiskLine =>
      '本机：需要重新显示删除版本、归档、取消导出等高风险二次确认时，请点标题栏 ⋯ 菜单（与服务器配置无关）。';

  @override
  String get helpHubRefresh => '刷新';

  @override
  String get helpHubManageEntries => '管理入口';

  @override
  String get helpHubLoading => '加载中…';

  @override
  String get helpHubSearchLabel => '搜索帮助文档（title / id / url）';

  @override
  String get helpHubNoEffectiveLinks => '当前没有可用的帮助入口，请检查 settings/help/hub 配置。';

  @override
  String get helpHubSearchEmpty => '当前搜索没有命中文档入口，请调整关键词后重试。';

  @override
  String get helpHubCopyLinkTooltip => '复制链接';

  @override
  String get helpHubCopied => '已复制';

  @override
  String get helpHubCopyTitleUrlTooltip => '复制标题+链接';

  @override
  String get helpHubCopiedHandoff => '已复制文档 handoff';

  @override
  String get helpHubManageDialogTitle => '管理帮助入口（个人 / 工作区）';

  @override
  String get helpHubManagePrecedence => '生效顺序：个人覆盖 > 工作区覆盖 > 环境默认。';

  @override
  String get helpHubManageWorkspaceLocked => '（当前工作区不可配置工作区级入口；仅个人覆盖可用。）';

  @override
  String get helpHubTabPersonal => '个人覆盖';

  @override
  String get helpHubTabWorkspace => '工作区覆盖';

  @override
  String get helpHubFieldId => 'id（用于去重/覆盖）';

  @override
  String get helpHubFieldTitle => '标题';

  @override
  String get helpHubFieldUrl => 'URL';

  @override
  String get helpHubHintId => 'runbook-quality';

  @override
  String get helpHubHintUrl => 'https://docs.example.com/runbook';

  @override
  String get helpHubAdd => '添加';

  @override
  String get helpHubValidationRequired => 'id、title、url 不能为空。';

  @override
  String get helpHubNoCustomInScope => '当前范围没有自定义入口。';

  @override
  String get helpHubDialogClose => '关闭';

  @override
  String get helpHubSave => '保存';

  @override
  String get helpHubSaving => '保存中…';

  @override
  String get helpHubCategoryRunbook => 'Runbook';

  @override
  String get helpHubCategoryBillingWebhook => 'Billing / Webhook';

  @override
  String get helpHubCategoryWorkspace => 'Workspace';

  @override
  String get helpHubCategoryQuality => '质量';

  @override
  String get helpHubCategoryStatus => '状态';

  @override
  String get helpHubCategoryGeneral => '通用';

  @override
  String helpHubSummary(int total, int filtered, String extra) {
    return '共 $total · 筛选后 $filtered$extra';
  }

  @override
  String helpHubSummaryCategoryCount(String name, int count) {
    return '$name:$count';
  }

  @override
  String get opsWhSectionTitle => '出站 Webhook';

  @override
  String get opsWhErrorUrlRequired => 'URL 不能为空';

  @override
  String get opsWhErrorWorkspaceId => 'workspaceId 须为合法 UUID，或留空';

  @override
  String get opsWhErrorWorkspaceIdPatch => 'workspaceId 须为合法 UUID，或清空后保存以改为全局';

  @override
  String get opsWhSnackCreated => '已创建；secret 已复制到剪贴板';

  @override
  String get opsWhSnackEventsUpdated => '已更新订阅事件';

  @override
  String opsWhSnackDeliverOk(String status) {
    return '投递成功（HTTP $status）';
  }

  @override
  String opsWhSnackDeliverFail(String detail) {
    return '投递失败：$detail';
  }

  @override
  String get opsWhSnackScopeGlobal => '已改为全局（无 workspace 过滤）';

  @override
  String get opsWhSnackScopeWorkspaceUpdated => '已更新 workspaceId';

  @override
  String get opsWhDeleteTitle => '删除 Webhook';

  @override
  String opsWhDeleteBody(String id) {
    return '即将删除 webhook：$id\n此操作会移除该目标地址。';
  }

  @override
  String get opsWhDeleteConfirm => '删除';

  @override
  String get opsWhDeleteConfirmButton => '确认删除';

  @override
  String opsWhLastTestOk(String status) {
    return '最近测试：成功（HTTP $status）';
  }

  @override
  String opsWhLastTestFail(String status, String error) {
    return '最近测试：失败（HTTP $status）$error';
  }

  @override
  String opsWhInventoryLine(
    int total,
    int filtered,
    int ok,
    int fail,
    String latestPart,
  ) {
    return '共 $total · 筛选 $filtered · 本会话测试成功 $ok · 失败 $fail$latestPart';
  }

  @override
  String opsWhInventoryLatestPart(String id) {
    return ' · 最近：$id';
  }

  @override
  String get opsWhEmptyNone => '当前还没有配置任何出站 Webhook。可直接在上方创建，并在此处测试投递与删除。';

  @override
  String get opsWhEmptyFiltered =>
      '当前筛选没有命中任何 Webhook，请调整 URL / id / createdAt 搜索关键字。';

  @override
  String get opsWhUrlLabel => 'Webhook URL';

  @override
  String get opsWhUrlHint => 'https://example.com/webhook';

  @override
  String get opsWhSecretLabel => 'Secret（可空，留空则服务端生成）';

  @override
  String get opsWhWorkspaceIdLabel => 'workspaceId（可空）';

  @override
  String get opsWhWorkspaceIdHint => '仅投递属于该工作区的事件；须为 UUID';

  @override
  String get opsWhSubscribeHint => '订阅事件（全选=默认全部；可取消不需要的类型）';

  @override
  String get opsWhTestEventTypeLabel => '测试 eventType';

  @override
  String get opsWhTestEventTypeHint => 'test.ping';

  @override
  String get opsWhLatestCreatedTitle => '最近创建的 Webhook 凭据';

  @override
  String get opsWhCopyId => '复制 ID';

  @override
  String get opsWhCopyUrl => '复制 URL';

  @override
  String get opsWhCopySecret => '复制 Secret';

  @override
  String get opsWhCreate => '创建';

  @override
  String get opsWhCreating => '请求中…';

  @override
  String get opsWhRefreshList => '刷新列表';

  @override
  String get opsWhSearchLabel => '搜索 Webhook（URL / id / createdAt）';

  @override
  String get opsWhRecentActivity => '最近操作';

  @override
  String get opsWhCopyActivityTooltip => '复制记录';

  @override
  String get opsWhActivityRecordSuffix => ' Webhook 操作记录';

  @override
  String get opsWhChipLatestCreated => '最近创建';

  @override
  String get opsWhChipDisabled => '已停用';

  @override
  String get opsWhSubscribeHeading => '订阅事件';

  @override
  String get opsWhScopeHeading => '作用域 workspaceId（留空保存 = 全局）';

  @override
  String get opsWhScopeFieldHint => 'UUID，留空表示不按工作区过滤';

  @override
  String get opsWhSaveScope => '保存作用域';

  @override
  String get opsWhSavingScope => '保存中…';

  @override
  String get opsWhClearInput => '清空输入';

  @override
  String get opsWhRecentDeliveries => '最近投递';

  @override
  String get opsWhTooltipCopyUrl => '复制 URL';

  @override
  String get opsWhUrlCopiedSnack => '已复制 Webhook URL';

  @override
  String get opsWhTestDeliver => '测试投递';

  @override
  String get opsWhBusy => '处理中…';

  @override
  String get opsWhDeliveryLog => '投递记录';

  @override
  String get opsWhLoading => '加载中…';

  @override
  String get opsWhDelete => '删除';

  @override
  String get billingAuditTitle => 'Billing Webhook 审计';

  @override
  String get billingAuditProviderLabel => 'Provider';

  @override
  String get billingAuditAll => '全部';

  @override
  String get billingAuditSortLabel => '排序';

  @override
  String get billingAuditSortNewest => '最新优先';

  @override
  String get billingAuditSortOldest => '最早优先';

  @override
  String get billingAuditOnlyInformational => '仅 informational';

  @override
  String get billingAuditOnlyStateful => '仅 stateful';

  @override
  String get billingAuditEventTypeHint =>
      '例如 invoice.paid / subscription.expired';

  @override
  String get billingAuditProviderEventIdHint => '例如 stripe:evt_123';

  @override
  String get billingAuditRawEventIdHint => '例如 evt_123';

  @override
  String get billingAuditProviderPrefixHint => '例如 stripe:evt_';

  @override
  String get billingAuditRawPrefixHint => '例如 evt_';

  @override
  String get billingAuditEventCreatedFromHint => '2026-04-01T00:00:00Z';

  @override
  String get billingAuditEventCreatedToHint => '2026-04-30T23:59:59Z';

  @override
  String get billingAuditQuery => '查询审计';

  @override
  String get billingAuditQuerying => '读取中…';

  @override
  String get billingAuditResetRefresh => '重置并刷新';

  @override
  String get billingAuditCopyCsv => '复制 CSV';

  @override
  String get billingAuditCsvCopiedSnack => '已复制当前 billing 审计 CSV';

  @override
  String get billingAuditCopyQuerySummary => '复制查询摘要';

  @override
  String get billingAuditCopyQueryUrl => '复制查询 URL';

  @override
  String get billingAuditQueryUrlCopiedSnack => '已复制当前查询 URL';

  @override
  String get billingAuditCopyFullCsv => '复制全量 CSV';

  @override
  String get billingAuditExporting => '导出中…';

  @override
  String get billingAuditLoading => '加载 billing 审计中…';

  @override
  String billingAuditPageStats(int total, int loaded, String hasMore) {
    return 'total=$total · loaded=$loaded · has_more=$hasMore';
  }

  @override
  String get billingEmptyQuery =>
      '当前查询没有命中任何 billing webhook 审计事件，可调整 provider、event id、时间窗或 informational 条件后重试。';

  @override
  String get billingAuditQuerySummaryCopied => '已复制当前查询摘要';

  @override
  String get billingAuditSnapshotCopied => '已复制当前审计摘要';

  @override
  String billingCopiedWithLabel(String label) {
    return '已复制$label';
  }

  @override
  String billingAuditFullCsvCopied(int count) {
    return '已复制全量 billing 审计 CSV（$count 条）';
  }

  @override
  String billingSnapLoaded(int count) {
    return '已加载：$count';
  }

  @override
  String billingSnapInformational(int count) {
    return 'informational：$count';
  }

  @override
  String billingSnapStateful(int count) {
    return 'stateful：$count';
  }

  @override
  String billingSnapProviders(String list) {
    return 'providers：$list';
  }

  @override
  String billingSnapEventTypes(String list) {
    return 'event types：$list';
  }

  @override
  String get billingAuditCurrentLoadTitle => '当前加载摘要';

  @override
  String get billingAuditCopySnapshot => '复制审计摘要';

  @override
  String get billingAuditCopyProviderEventId => '复制 provider_event_id';

  @override
  String get billingAuditCopyRawEventId => '复制 raw_event_id';

  @override
  String billingAuditFilterByProvider(String provider) {
    return '按 $provider 过滤';
  }

  @override
  String billingAuditFilterByEventType(String eventType) {
    return '按 $eventType 过滤';
  }

  @override
  String get billingAuditOnlyThisEvent => '仅看这一事件';

  @override
  String get billingAuditLoadMore => '加载更多审计';

  @override
  String billingMetaProvider(String value) {
    return 'provider=$value';
  }

  @override
  String billingMetaType(String value) {
    return 'type=$value';
  }

  @override
  String billingMetaCreated(String value) {
    return 'created=$value';
  }

  @override
  String billingMetaEventCreated(String value) {
    return 'event_created=$value';
  }

  @override
  String get billingMetaInformational => 'informational';

  @override
  String get billingMetaStateful => 'stateful';

  @override
  String billingRowRawEventId(String value) {
    return 'raw_event_id=$value';
  }

  @override
  String billingRowId(String value) {
    return 'id=$value';
  }

  @override
  String billingChipCount(String label, int count) {
    return '$label $count';
  }

  @override
  String get projectsListTitle => '项目列表';

  @override
  String get projectsListSubtitle => '查看项目、摘要、美术风格与创作手册，并进入项目详情继续编辑。';

  @override
  String get projectsSnackProjectCreated => '已创建项目';

  @override
  String get projectsSnackSignInArtStyles => '当前未登录，无法读取美术风格';

  @override
  String get projectsSnackSignInCreativeManuals => '当前未登录，无法读取创作手册';

  @override
  String get projectsSnackSignInAgentMemory => '当前未登录，无法读取 Agent 记忆';

  @override
  String get projectsEnterpriseEmptyTitle => '当前团队空间还没有项目';

  @override
  String get projectsEnterpriseEmptyUnnamedFallback => '这个 enterprise 空间';

  @override
  String projectsEnterpriseEmptyBody(String displayName) {
    return '$displayName 还没有任何项目。可以先创建一个空项目作为团队母项目，再到团队工作区继续邀请成员和分配协作范围。';
  }

  @override
  String get projectsCreateFirstEmpty => '先创建空项目';

  @override
  String get projectsOpenTeamWorkspaces => '打开团队工作区';

  @override
  String get projectsLoadProjectList => '加载项目列表';

  @override
  String get projectsViewSummary => '查看项目摘要';

  @override
  String get projectsLoadArtStyles => '加载美术风格';

  @override
  String get projectsOpenArtStylesWorkbench => '打开画风工作台';

  @override
  String get projectsOpenCreativeManualsWorkbench => '打开创作手册工作台';

  @override
  String get projectsOpenAgentMemoryWorkbench => '打开记忆工作台';

  @override
  String get projectsCreateEmptyProject => '新建空项目';

  @override
  String get projectsLoading => '加载中…';

  @override
  String get projectsCreating => '创建中…';

  @override
  String get projectsRequesting => '请求中…';

  @override
  String get projectsCompatibilityTitle => '兼容性检查';

  @override
  String get projectsCompatibilitySubtitle =>
      '保留首项目 Agent memory probe 作为回归入口，默认折叠';

  @override
  String get projectsCompatibilityProbeMemory => '查询首个项目记忆';

  @override
  String get projectsSummaryLinePrefix => '项目摘要：';

  @override
  String get projectsArtStylesLinePrefix => '美术风格：';

  @override
  String projectsArtStyleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条画风',
    );
    return '$_temp0';
  }

  @override
  String get projectsArtStylesManage => '管理';

  @override
  String projectsProjectCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目',
    );
    return '$_temp0';
  }

  @override
  String projectsUnnamedProject(int numericId) {
    return '项目 #$numericId';
  }

  @override
  String get projectsAgentMemoryPrefix => '项目记忆：';

  @override
  String get projectsAccessModeRestricted => '显式 ACL';

  @override
  String get projectsAccessModeInherited => '继承 workspace';

  @override
  String get projectsRoleWorkspaceOwner => 'workspace owner';

  @override
  String get projectsRoleWorkspaceAdmin => 'workspace admin';

  @override
  String get projectsRoleProjectOwner => '项目 owner';

  @override
  String get projectsRoleEditor => 'editor';

  @override
  String get projectsRoleViewer => 'viewer';

  @override
  String get projectsRoleMember => 'member';

  @override
  String get projectsDialogCreateTitle => '新建项目';

  @override
  String get projectsDialogFieldName => '项目名';

  @override
  String get projectsDialogFieldIntro => '项目简介';

  @override
  String get projectsDialogSectionBrief => '项目立项';

  @override
  String get projectsDialogFieldPremise => 'Premise';

  @override
  String get projectsDialogFieldTargetAudience => 'Target audience';

  @override
  String get projectsDialogFieldEmotionalTone => 'Emotional tone';

  @override
  String get projectsDialogFieldCoreHook => 'Core hook';

  @override
  String get projectsDialogFieldVisualDirection => 'Visual direction';

  @override
  String get projectsDialogSectionBrand => '品牌圣经';

  @override
  String shortVideoSpaceErrorTimeout(String context) {
    return '请求超时$context，请检查网络连接后重试。';
  }

  @override
  String shortVideoSpaceErrorOperationFailed(String context, String error) {
    return '操作失败$context：$error';
  }

  @override
  String shortVideoSpaceErrorConcurrentLimitExceeded(String context) {
    return '同时进行的工作区审计导出已达上限，请等待已有任务完成或结束后再试$context。';
  }

  @override
  String shortVideoSpaceErrorRateLimitWithWait(
    String context,
    String waitText,
  ) {
    return '请求过于频繁$context，$waitText。';
  }

  @override
  String shortVideoSpaceErrorNotFound(String context) {
    return '未找到对应记录$context。';
  }

  @override
  String shortVideoSpaceErrorPermissionDenied(String context) {
    return '权限不足$context，请检查登录状态。';
  }

  @override
  String get shortVideoSpaceErrorBadRequest => '请求参数错误';

  @override
  String shortVideoSpaceErrorBadRequestWithContext(
    String message,
    String context,
  ) {
    return '$message$context';
  }

  @override
  String shortVideoSpaceErrorServerError(String context) {
    return '服务器错误$context，请稍后重试。';
  }

  @override
  String shortVideoSpaceErrorDetailedMessage(String message, String context) {
    return '$message$context';
  }

  @override
  String shortVideoSpaceErrorDefaultMessage(String context, String error) {
    return '操作失败$context：$error';
  }

  @override
  String get shortVideoSpaceErrorRetryButton => '重试';

  @override
  String get shortVideoSpaceDialogExportHistoryTitle => '导出历史';

  @override
  String get shortVideoSpaceDialogExportHistoryRefresh => '刷新';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusLabel => '状态';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeLabel => '时间';

  @override
  String get shortVideoSpaceDialogExportHistoryClose => '关闭';

  @override
  String get shortVideoSpaceDialogExportHistoryRetry => '重试';

  @override
  String get shortVideoSpaceDialogExportHistoryNoRecords => '暂无导出记录';

  @override
  String get shortVideoSpaceDialogExportHistoryNoRecordsHint =>
      '导出视频后，记录将显示在这里';

  @override
  String get shortVideoSpaceDialogExportHistoryDownload => '下载';

  @override
  String get shortVideoSpaceDialogExportHistoryDownloading => '下载中...';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeFilterAll => '全部时间';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeFilterToday => '今天';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeFilterWeek => '最近一周';

  @override
  String get shortVideoSpaceDialogExportHistoryTimeFilterMonth => '最近一月';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusFilterAll => '全部状态';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusFilterCompleted => '已完成';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusFilterFailed => '失败';

  @override
  String get shortVideoSpaceDialogExportHistoryStatusFilterCancelled => '已取消';

  @override
  String get shortVideoSpaceDialogExportHistoryFileSizeUnknown => '未知';

  @override
  String shortVideoSpaceDialogExportHistoryFileSizeKB(String size) {
    return '$size KB';
  }

  @override
  String shortVideoSpaceDialogExportHistoryFileSizeMB(String size) {
    return '$size MB';
  }

  @override
  String shortVideoSpaceDialogExportHistoryFileSizeGB(String size) {
    return '$size GB';
  }

  @override
  String shortVideoSpaceDialogExportHistoryDurationSeconds(int seconds) {
    return '$seconds 秒';
  }

  @override
  String shortVideoSpaceDialogExportHistoryDurationMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String shortVideoSpaceDialogExportHistoryDurationHours(
    int hours,
    int minutes,
  ) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String shortVideoSpaceDialogExportHistoryCreatedAt(String time) {
    return '创建时间: $time';
  }

  @override
  String shortVideoSpaceDialogExportHistoryCompletedAt(
    String time,
    String duration,
  ) {
    return '完成时间: $time · 耗时: $duration';
  }

  @override
  String shortVideoSpaceDialogExportHistoryFileSize(String size) {
    return '文件大小: $size';
  }

  @override
  String shortVideoSpaceDialogExportHistorySettings(
    String bitrate,
    int framerate,
  ) {
    return '设置: $bitrate · $framerate FPS';
  }

  @override
  String shortVideoSpaceDialogExportHistoryLoadError(String error) {
    return '加载导出历史失败: $error';
  }

  @override
  String get shortVideoSpaceDialogExportHistorySessionExpired => '会话已失效，请重新登录';

  @override
  String shortVideoSpaceDialogExportHistoryDownloadLinkCopied(String format) {
    return '已复制下载链接（$format）';
  }

  @override
  String shortVideoSpaceDialogExportHistoryDownloadFailed(String error) {
    return '下载失败: $error';
  }

  @override
  String get shortVideoSpaceDialogExportHistoryTimeJustNow => '刚刚';

  @override
  String shortVideoSpaceDialogExportHistoryTimeMinutesAgo(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String shortVideoSpaceDialogExportHistoryTimeHoursAgo(int hours) {
    return '$hours 小时前';
  }

  @override
  String shortVideoSpaceDialogExportHistoryTimeDaysAgo(int days) {
    return '$days 天前';
  }

  @override
  String get projectsDialogFieldBrandName => 'Brand name';

  @override
  String get projectsDialogFieldBrandPromise => 'Brand promise';

  @override
  String get projectsDialogFieldVisualMotifsMultiline => 'Visual motifs (每行一个)';

  @override
  String get projectsDialogFieldForbiddenElementsMultiline =>
      'Forbidden elements (每行一个)';

  @override
  String get projectsDialogFieldContinuityRulesMultiline =>
      'Continuity rules (每行一个)';

  @override
  String get projectsDialogCreateButton => '创建';

  @override
  String get projectsBusyProcessing => '处理中…';

  @override
  String get projectsArtWorkbenchTitle => '画风工作台';

  @override
  String get projectsArtWorkbenchIntro =>
      '在同一入口内完成画风列表刷新、封面查看、CRUD 与 prompt 抽取，不再只停留在列表加载与回归探针。';

  @override
  String get projectsArtWorkbenchReloadList => '刷新列表';

  @override
  String get projectsArtWorkbenchViewCover => '查看封面';

  @override
  String get projectsArtWorkbenchReadingCover => '读取中…';

  @override
  String get projectsArtWorkbenchNew => '新建画风';

  @override
  String get projectsArtWorkbenchSave => '保存当前画风';

  @override
  String get projectsArtWorkbenchDelete => '删除当前画风';

  @override
  String get projectsArtWorkbenchCurrentStyle => '当前画风';

  @override
  String get projectsArtWorkbenchEmptyHint => '当前还没有画风，填写下面表单后可直接新建。';

  @override
  String get projectsArtWorkbenchFieldName => '名称';

  @override
  String get projectsArtWorkbenchFieldTags => '标签';

  @override
  String get projectsArtWorkbenchFieldCoverUrl => '封面 URL / data URI';

  @override
  String get projectsArtWorkbenchFieldCoverUrlHelper =>
      '可填写可访问 URL，或 data:image/...;base64,...';

  @override
  String get projectsArtWorkbenchFieldPrompt => 'Prompt';

  @override
  String get projectsArtWorkbenchExtractTitle => 'Prompt 抽取';

  @override
  String get projectsArtWorkbenchExtractImagesLabel => '图片输入';

  @override
  String get projectsArtWorkbenchExtractImagesHelper =>
      '按换行或逗号分隔多个图片 URL / data URI。';

  @override
  String get projectsArtWorkbenchExtractButton => '抽取 Prompt 到编辑区';

  @override
  String get projectsArtWorkbenchCoverPreview => '当前封面预览';

  @override
  String get projectsCreativeManualTitle => '创作手册工作台';

  @override
  String get projectsCreativeManualIntro =>
      '把导演手册与视觉手册从首页探针收口到同一工作台，可直接刷新、查看、创建、更新和删除。';

  @override
  String get projectsCreativeManualSegmentDirector => '导演手册';

  @override
  String get projectsCreativeManualSegmentVisual => '视觉手册';

  @override
  String get projectsCreativeManualReloadAll => '刷新全部手册';

  @override
  String get projectsCreativeManualPathDirectorFolder => 'directorManual 文件夹';

  @override
  String get projectsCreativeManualPathVisual => 'stylePath';

  @override
  String get projectsCreativeManualSelectionDirector => '当前导演手册';

  @override
  String get projectsCreativeManualSelectionVisual => '当前视觉手册';

  @override
  String get projectsCreativeManualCreateDirector => '新建导演手册';

  @override
  String get projectsCreativeManualCreateVisual => '新建视觉手册';

  @override
  String get projectsCreativeManualSaveDirector => '保存当前导演手册';

  @override
  String get projectsCreativeManualSaveVisual => '保存当前视觉手册';

  @override
  String get projectsCreativeManualDeleteDirector => '删除当前导演手册';

  @override
  String get projectsCreativeManualDeleteVisual => '删除当前视觉手册';

  @override
  String get projectsCreativeManualEmptyKind => '当前类型还没有手册，可直接填写下方表单新建。';

  @override
  String get projectsCreativeManualFieldName => '名称';

  @override
  String get projectsCreativeManualFieldImagesList => '图片列表';

  @override
  String get projectsCreativeManualFieldImagesHelper =>
      '按换行或逗号分隔多个图片 URL / 路径。';

  @override
  String get projectsCreativeManualFieldSlots => '数据槽位';

  @override
  String get projectsCreativeManualFieldSlotsHelper =>
      '每行一个槽位，格式为 label|value|data';

  @override
  String get projectsCreativeManualSummaryTitle => '当前摘要';

  @override
  String projectsCreativeManualSummaryLine(
    String name,
    String path,
    int imageCount,
    int slotCount,
  ) {
    return '$name · 路径 $path · 图片 $imageCount 张 · 槽位 $slotCount 个';
  }

  @override
  String get projectsCreativeManualStatusRefreshing => '刷新创作手册中…';

  @override
  String projectsCreativeManualStatusReloadOk(
    int directorCount,
    int visualCount,
    int getCount,
    int postCount,
  ) {
    return '导演手册 $directorCount 条 · 视觉手册 $visualCount 条 · visual GET/POST=$getCount/$postCount';
  }

  @override
  String projectsCreativeManualStatusReloadFail(String detail) {
    return '刷新失败：$detail';
  }

  @override
  String get projectsCreativeManualStatusCreateNeedFields => '新建失败：名称与路径不能为空。';

  @override
  String get projectsCreativeManualStatusCreating => '新建手册中…';

  @override
  String projectsCreativeManualStatusCreated(String kind, String path) {
    return '已新建 $kind：$path';
  }

  @override
  String get projectsCreativeManualStatusSaveNeedSelect => '保存失败：请先选择一条手册。';

  @override
  String get projectsCreativeManualStatusSaveNeedFields => '保存失败：名称与路径不能为空。';

  @override
  String get projectsCreativeManualStatusSaving => '保存手册中…';

  @override
  String projectsCreativeManualStatusSaved(String kind, String path) {
    return '已保存 $kind：$path';
  }

  @override
  String get projectsCreativeManualStatusDeleteNeedSelect => '删除失败：请先选择一条手册。';

  @override
  String get projectsCreativeManualStatusDeleting => '删除手册中…';

  @override
  String projectsCreativeManualStatusDeleted(String kind, String path) {
    return '已删除 $kind：$path';
  }

  @override
  String projectsCreativeManualStatusOpFail(String verb, String detail) {
    return '$verb失败：$detail';
  }

  @override
  String get projectsCreativeManualKindDirector => '导演手册';

  @override
  String get projectsCreativeManualKindVisual => '视觉手册';

  @override
  String projectsCreativeManualInvalidSlotLine(String line) {
    return '槽位格式无效（应为 label|value|data）：$line';
  }

  @override
  String get agentMemoryWorkbenchTitle => 'Agent 记忆工作台';

  @override
  String get agentMemoryWorkbenchIntro =>
      '针对项目级 script/production Agent 记忆执行查询、追加和清理，不再只依赖首页首项目 probe。';

  @override
  String get agentMemoryReloadProjects => '刷新项目列表';

  @override
  String get agentMemoryQueryMemory => '查询记忆';

  @override
  String get agentMemoryLoadCostOverview => '加载成本概览';

  @override
  String get agentMemoryOptimizeVideo => '自动优化视频记忆';

  @override
  String agentMemoryProjectsPreviewLine(
    int count,
    String preview,
    String ellipsis,
  ) {
    return '$count 个项目 · $preview$ellipsis';
  }

  @override
  String get agentMemoryUnnamedProject => '未命名项目';

  @override
  String get agentMemoryFieldProjectNumericId => '项目 numeric ID';

  @override
  String get agentMemoryFieldAgentType => 'agent type';

  @override
  String get agentMemoryFieldEpisodesIdOptional => 'episodes id（可空）';

  @override
  String get agentMemoryFieldScopeSignatureOptional =>
      'scopeSignature JSON（可空）';

  @override
  String get agentMemoryFieldScopeSignatureHelper =>
      'JSON 对象；常见键：episodeId、storyboardIds、focusSections';

  @override
  String get agentMemoryFieldQueryType => 'query type';

  @override
  String get agentMemoryFieldQueryTypeHelper => 'summary / message / all';

  @override
  String get agentMemoryFieldMemoryTier => 'memory tier';

  @override
  String get agentMemoryFieldMemoryTierHelper =>
      'all / style_bible / stage_summary / delta_memory / message';

  @override
  String get agentMemoryFieldAutomationMode => 'automation mode';

  @override
  String get agentMemoryFieldAutomationModeHelper => 'standard / lean / off';

  @override
  String get agentMemoryIsolateHint =>
      '自动记忆按 项目 numeric ID + agent type + episodes id 独立隔离。';

  @override
  String get agentMemoryOptimizeScopeHint =>
      '自动优化只处理 productionAgent + episodes id 范围内的 selected video memory，不共享到别的用户、项目或短剧。';

  @override
  String get agentMemoryOptimizeEnableHint =>
      '要启用自动优化，请把 agent type 设为 productionAgent，并填写 episodes id。';

  @override
  String get agentMemoryRecommendationPrefix => '建议：';

  @override
  String get agentMemoryCopyChecklistTooltip => '复制记忆执行清单';

  @override
  String get agentMemoryChecklistCopiedSnack => '已复制记忆执行清单';

  @override
  String get agentMemoryAppendSection => '追加记忆';

  @override
  String get agentMemoryFieldAppendType => 'append type';

  @override
  String get agentMemoryFieldAppendTypeHelper => 'message / summary';

  @override
  String get agentMemoryFieldAppendMemoryTier => 'append memory tier';

  @override
  String get agentMemoryFieldAppendMemoryTierHelper =>
      'style_bible / stage_summary / delta_memory / message';

  @override
  String get agentMemoryFieldRole => 'role';

  @override
  String get agentMemoryFieldNameOptional => 'name（可空）';

  @override
  String get agentMemoryAppendButton => '按当前 scope 追加记忆';

  @override
  String get agentMemoryFieldMemoryContent => '记忆内容';

  @override
  String get agentMemoryClearSection => '清理记忆';

  @override
  String get agentMemoryFieldClearType => 'clear type';

  @override
  String get agentMemoryFieldClearTypeHelper => 'summary / message / all';

  @override
  String get agentMemoryClearRun => '执行清理';

  @override
  String get agentMemoryDuplicateChip => '重复';

  @override
  String agentMemoryTierGroupHeader(String label, int count, String last) {
    return '$label · $count 条 · 最近注入 $last';
  }

  @override
  String agentMemoryMemoryRowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条记忆',
    );
    return '$_temp0';
  }

  @override
  String agentMemoryCharsAbbr(int n) {
    return '$n chars';
  }

  @override
  String agentMemorySubjectLabel(String value) {
    return 'subject $value';
  }

  @override
  String agentMemorySignalsLabel(String value) {
    return 'signals $value';
  }

  @override
  String get agentMemoryTierAll => '全部层级';

  @override
  String get agentMemoryTierStyleBible => '风格圣经';

  @override
  String get agentMemoryTierStageSummary => '阶段摘要';

  @override
  String get agentMemoryTierDeltaMemory => '增量记忆';

  @override
  String get agentMemoryTierMessage => '普通消息';

  @override
  String get agentMemoryClassNegative => '坏例约束';

  @override
  String get agentMemoryClassDeliveryVisual => '表演+视觉';

  @override
  String get agentMemoryClassDeliveryFirst => '表演优先';

  @override
  String get agentMemoryClassVisualHeavy => '视觉偏重';

  @override
  String get agentMemoryClassVideoMemory => '视频记忆';

  @override
  String get agentMemoryActionMergeNegative => '合并坏例';

  @override
  String get agentMemoryActionObserve => '待观察';

  @override
  String get agentMemoryActionCompress => '待压缩';

  @override
  String get agentMemoryActionKeep => '优先保留';

  @override
  String agentMemoryInsightCore(
    String roles,
    String typesPart,
    int totalChars,
    int longestChars,
    String dupPart,
  ) {
    return '角色分布：$roles$typesPart · 约 $totalChars chars · 最长 $longestChars chars$dupPart';
  }

  @override
  String agentMemoryInsightTypesPart(String detail) {
    return ' · 类型 $detail';
  }

  @override
  String agentMemoryInsightDupPart(int count) {
    return ' · 重复 $count 条';
  }

  @override
  String agentMemoryVideoInsight(
    int dRows,
    int dChars,
    int vRows,
    int vChars,
    int nRows,
    int nChars,
  ) {
    return '视频记忆：delivery $dRows/$dChars chars · visual $vRows/$vChars chars · negative $nRows/$nChars chars';
  }

  @override
  String agentMemoryEfficiencyInsight(
    int kRows,
    int kChars,
    int tRows,
    int tChars,
    int mRows,
    int mChars,
  ) {
    return '处理建议：保留 $kRows/$kChars chars · 压缩 $tRows/$tChars chars · 合并坏例 $mRows/$mChars chars';
  }

  @override
  String agentMemoryBucketPriorityLine(String detail) {
    return '记忆桶优先级：$detail';
  }

  @override
  String agentMemoryBucketPriorityItem(
    String action,
    String name,
    int rows,
    int chars,
  ) {
    return '$action $name · $rows条/$chars chars';
  }

  @override
  String get agentMemoryCostNever => '暂无';

  @override
  String agentMemoryCostOverviewLine(
    String scope,
    int sb,
    int ss,
    int dm,
    int msg,
    int avgInj,
    int avgHit,
    String last,
  ) {
    return 'scope=$scope · 成本概览：风格圣经 $sb 条 · 阶段摘要 $ss 条 · 增量记忆 $dm 条 · 普通消息 $msg 条 · 近 30 次平均注入 $avgInj 字 · 近 30 次平均命中层级 $avgHit 个 · 最近注入 $last';
  }

  @override
  String get agentMemoryChecklistTitle => '记忆执行清单：';

  @override
  String agentMemoryChecklistScope(String scope) {
    return '范围：只处理 $scope 的记忆，不跨用户、项目或短剧复用。';
  }

  @override
  String get agentMemoryChecklistScopeFallback => '当前查询 scope';

  @override
  String agentMemoryChecklistCompress(String name) {
    return '压缩 $name 的镜头/光影/氛围套话，优先保留表演、语气、情绪和人物一致性片段。';
  }

  @override
  String agentMemoryChecklistMerge(String name) {
    return '合并 $name 的重复 risk/avoid 约束，保留最能防止穿帮、口型僵硬和身份漂移的坏例。';
  }

  @override
  String agentMemoryChecklistKeep(String name) {
    return '保留 $name 里最具体的表演/情绪锚点，避免删掉能让人物不读稿、不木的 delivery 记忆。';
  }

  @override
  String agentMemoryChecklistObserve(String name) {
    return '观察 $name 的新增条目，避免继续堆重复记忆。';
  }

  @override
  String agentMemoryChecklistReminder(String text) {
    return '当前提醒：$text';
  }

  @override
  String get agentMemoryRecDup => '检测到重复表述，先去重旧记忆，避免同一约束反复注入。';

  @override
  String get agentMemoryRecVisualOnly =>
      '当前视频记忆几乎只有镜头/光影，先补一条表演、语气或情绪锚点，再决定删哪条视觉记忆。';

  @override
  String get agentMemoryRecVisualBudget =>
      '视觉偏重记忆吃掉了更多预算，先清理只保留镜头/光影的旧条目，把 chars 留给表演、语气和情绪。';

  @override
  String get agentMemoryRecNegativeMerge =>
      '坏例约束累计较多，先合并重复 risk/avoid 片段，避免 negative memory 自己膨胀。';

  @override
  String agentMemoryRecBucketHot(String name, int count) {
    return '$name 已累计 $count 条，先压缩这个记忆桶，避免它单独吃掉预算。';
  }

  @override
  String get agentMemoryRecLong => '当前记忆偏长，优先压缩长记忆，再决定是否继续追加。';

  @override
  String get agentMemoryRecManyRows =>
      '条数偏多，先读取 summary 或清理旧 message，给当前镜头约束留预算。';

  @override
  String get agentMemoryRecAssistantHeavy => 'assistant 记忆偏多，先清旧总结，只保留最新执行约束。';

  @override
  String get agentMemorySignalSubject => '人物';

  @override
  String get agentMemorySignalEmotion => '情绪';

  @override
  String get agentMemorySignalCamera => '镜头';

  @override
  String get agentMemorySignalVisual => '视觉';

  @override
  String get agentMemorySignalIdentity => '身份';

  @override
  String get agentMemorySignalDialogue => '台词';

  @override
  String get agentMemorySignalPerformance => '表演';

  @override
  String agentMemorySignalNegative(String n) {
    return '坏例$n';
  }

  @override
  String agentMemoryStatusProjectsRefreshed(int count) {
    return '已刷新 $count 个项目。';
  }

  @override
  String get agentMemoryErrFillProjectAndAgent =>
      '请填写合法的项目 ID（numeric 或列表中可选 UUID）和 agent type。';

  @override
  String get agentMemoryErrFillAgentType => '请填写 agent type。';

  @override
  String agentMemoryQuerySummaryLine(
    int count,
    String memoryType,
    String tier,
  ) {
    return '已读取 $count 条 $memoryType 记忆 · 层级 $tier。';
  }

  @override
  String get agentMemoryErrCostOverviewFields =>
      '加载成本概览前请填写合法的项目 ID 和 agent type。';

  @override
  String get agentMemoryStatusCostOverviewLoaded => '已加载记忆成本概览。';

  @override
  String get agentMemoryErrAppendProjectFields =>
      '追加记忆前请填写项目 ID、agent type、role 和内容。';

  @override
  String get agentMemoryErrAppendAgentRoleContent =>
      '追加记忆前请填写 agent type、role 和内容。';

  @override
  String agentMemoryStatusAppended(String id) {
    return '已追加记忆 $id。';
  }

  @override
  String get agentMemoryErrClearProjectFields => '清理记忆前请填写项目 ID 和 agent type。';

  @override
  String agentMemoryStatusCleared(String clearType) {
    return '已执行记忆清理：$clearType。';
  }

  @override
  String get agentMemoryErrOptimizeProjectFields =>
      '自动优化前请填写项目 ID、agent type 和 episodes id。';

  @override
  String get agentMemoryErrOptimizeAgentEpisodes =>
      '自动优化前请填写 agent type 和 episodes id。';

  @override
  String agentMemoryStatusOptimized(
    String mode,
    int removedRows,
    int removedChars,
    int dupRows,
    int visRows,
  ) {
    return '已自动优化视频记忆（$mode）：删除 $removedRows 条 / $removedChars chars，其中重复 $dupRows 条、纯视觉 $visRows 条。';
  }

  @override
  String get agentMemoryErrScopeNotObject => 'scopeSignature 必须是 JSON 对象';

  @override
  String get agentMemoryErrScopeNeedsDimension => 'scopeSignature 至少需要一个非空范围维度';

  @override
  String agentMemoryErrScopeTierRequires(String action) {
    return '$action 需要填写非空的 scopeSignature JSON。';
  }

  @override
  String get agentMemoryActionLabelQueryScoped => '查询 scoped 记忆';

  @override
  String get agentMemoryActionLabelAppendScoped => '追加 scoped 记忆';

  @override
  String get taskCenterErrNotLoggedIn => '当前未登录，无法读取任务中心';

  @override
  String get taskCenterProjectsNotLoaded => '尚未加载任务项目';

  @override
  String get taskCenterTaskListNotLoaded => '尚未加载任务列表';

  @override
  String get taskCenterLocalClientPrefs => '本机客户端偏好';

  @override
  String get taskCenterSectionIntro =>
      '用正式工作台完成任务项目、分类、筛选列表和详情查看，主区不再依赖首条/UUID probe 按钮。';

  @override
  String get taskCenterOpenWorkbench => '打开任务工作台';

  @override
  String get taskCenterRefreshSummary => '刷新任务摘要';

  @override
  String get taskCenterCompatibilityCheck => '兼容性检查';

  @override
  String get taskCenterCompatibilityHint => '保留旧式加载/详情 probe 作为回归入口，默认折叠';

  @override
  String get taskCenterLoadTaskProjects => '加载任务项目';

  @override
  String get taskCenterLoadTaskCategories => '加载任务分类';

  @override
  String get taskCenterLoadTaskList => '加载任务列表';

  @override
  String get taskCenterViewFirstTaskDetails => '查看首条任务详情';

  @override
  String get taskCenterFieldTaskUuidTapToFill => '任务 UUID（点下方列表可自动填入）';

  @override
  String get taskCenterViewByUuid => '按 UUID 查看详情';

  @override
  String taskCenterJobsCount(int count) {
    return '$count 条任务';
  }

  @override
  String taskCenterCategoriesLine(String line) {
    return '分类摘要：$line';
  }

  @override
  String taskCenterNumericIdDetailsLine(String line) {
    return '任务详情（numeric ID）：$line';
  }

  @override
  String taskCenterUuidDetailsLine(String line) {
    return 'UUID 详情：$line';
  }

  @override
  String get taskCenterPhasePrep => '素材准备';

  @override
  String get taskCenterPhaseImage => '出图';

  @override
  String get taskCenterPhaseVideo => '出视频';

  @override
  String get taskCenterPhaseExport => '导出成片';

  @override
  String get taskCenterPhaseQuality => '质检';

  @override
  String get taskCenterWorkbenchTitle => '任务工作台';

  @override
  String taskCenterWorkbenchIntro(String realtime) {
    return '在一个对话框内完成任务项目/分类读取、按项目或分类筛选列表，以及按 numeric task id 或 UUID 查看详情。$realtime';
  }

  @override
  String get taskCenterWorkbenchRealtimeConnected => ' 当前已接入实时任务更新。';

  @override
  String get taskCenterWorkbenchFilterAndList => '筛选与列表';

  @override
  String get taskCenterReloadTaskProjects => '刷新任务项目';

  @override
  String get taskCenterReloadTaskCategories => '刷新任务分类';

  @override
  String get taskCenterLoadTasksByFilters => '按筛选加载任务';

  @override
  String get taskCenterFieldPage => '页码';

  @override
  String get taskCenterFieldPageSize => '每页数量';

  @override
  String get taskCenterFieldProjectNumericIdOptional => '项目 numeric ID（可空）';

  @override
  String get taskCenterFieldTaskClassOptional => '任务分类（可空）';

  @override
  String get taskCenterFieldTaskStatusOptional => '任务状态（可空）';

  @override
  String get taskCenterFieldProductionPhaseOptional =>
      '短视频阶段（可空：prep/image/video/export/quality）';

  @override
  String taskCenterFailureReason(String text) {
    return '失败原因=$text';
  }

  @override
  String get taskCenterRetry => '重试';

  @override
  String get taskCenterCancel => '取消';

  @override
  String get taskCenterTaskDetailsSection => '任务详情';

  @override
  String get taskCenterFieldNumericTaskId => 'numeric task id';

  @override
  String get taskCenterLoadNumericIdDetails => '读取任务详情（numeric ID）';

  @override
  String get taskCenterFieldTaskUuid => '任务 UUID';

  @override
  String get taskCenterLoadUuidDetails => '读取 UUID 详情';

  @override
  String taskCenterStatusLine(String line) {
    return '状态：$line';
  }

  @override
  String taskCenterStructuredFailure(String label) {
    return '结构化失败 · $label';
  }

  @override
  String get taskCenterOpenProductionWorkspace => '打开制作工作区';

  @override
  String get taskCenterOpenScriptWorkspace => '打开剧本工作区';

  @override
  String get taskCenterRegenerate => '重新生成';

  @override
  String get taskCenterPartialRework => '局部返工';

  @override
  String get taskCenterWritebackCompensation => '回写补偿';

  @override
  String get taskCenterOpenSpacePublish => '打开短视频 Space（发布）';

  @override
  String get taskCenterOpenProductionStoryboard => '打开制作工作区（分镜）';

  @override
  String get taskCenterOpenScriptScript => '打开剧本工作区（脚本）';

  @override
  String get taskCenterOpenSpaceProject => '打开短视频 Space（项目）';

  @override
  String taskCenterStatusLoadedTaskProjects(int count) {
    return '已读取 $count 个任务项目。';
  }

  @override
  String taskCenterStatusLoadedTaskCategories(int count) {
    return '已读取 $count 个任务分类。';
  }

  @override
  String taskCenterStatusRefreshedTasks(int count) {
    return '已刷新 $count 条任务。';
  }

  @override
  String get taskCenterErrInvalidNumericTaskId => '请填写合法的任务 numeric ID。';

  @override
  String get taskCenterErrFillTaskUuid => '请填写任务 UUID。';

  @override
  String get taskCenterOriginRetrySubmitted => '已提交重试';

  @override
  String get taskCenterOriginTaskCancelled => '已取消任务';

  @override
  String get taskCenterStatusEnteredWritebackCompensation =>
      '已进入回写补偿：先读取任务 UUID 详情并校验写回状态。';

  @override
  String get taskCenterOriginRealtimeUpdate => '收到实时更新';

  @override
  String taskCenterStatusMergedUpdate(
    String origin,
    int taskId,
    String kind,
    String status,
  ) {
    return '$origin：#$taskId $kind -> $status';
  }

  @override
  String get taskCenterProjectsEmpty => '当前没有任务项目';

  @override
  String taskCenterProjectsSummary(int count, String preview, String ellipsis) {
    return '$count 个项目 · $preview$ellipsis';
  }

  @override
  String get taskCenterCategoriesEmpty => '当前没有任务分类';

  @override
  String taskCenterCategoriesSummary(
    int count,
    String preview,
    String ellipsis,
  ) {
    return '$count 个分类 · $preview$ellipsis';
  }

  @override
  String get taskCenterJobsEmpty => '当前没有任务记录';

  @override
  String taskCenterJobsSummary(int count, String preview, String ellipsis) {
    return '$count 条任务 · $preview$ellipsis';
  }

  @override
  String get taskCenterFailurePayloadMissingSourceUrl => '缺少 source_url';

  @override
  String get taskCenterFailurePayloadSourceUrlEmpty => '成片 URL 为空';

  @override
  String get taskCenterFailurePayloadFormatInvalid => '导出格式无效';

  @override
  String get taskCenterFailureLocalExportDirUnset => '服务端未配置导出目录';

  @override
  String get taskCenterFailureExportProviderFailed => '导出提供方失败';

  @override
  String get taskCenterFailureExportDirectoryCreateFailed => '创建导出目录失败';

  @override
  String get taskCenterFailureExportFilePersistFailed => '写入导出文件失败';

  @override
  String get taskCenterFailureVideoDownloadHttp => '源视频 HTTP 失败';

  @override
  String get taskCenterFailureVideoDownloadStream => '源视频下载中断';

  @override
  String get taskCenterFailureVideoFormatMismatchNoTranscode => '格式不一致（未转码）';

  @override
  String get taskCenterFailureVideoContentLengthExceedsLimit => '源视频过大（长度头）';

  @override
  String get taskCenterFailureVideoBodyExceedsLimit => '源视频过大（正文）';

  @override
  String get taskCenterFailureUnknownCode => '未知原因码';

  @override
  String get projectsCreativeManualVerbCreate => '新建';

  @override
  String get projectsCreativeManualVerbSave => '保存';

  @override
  String get projectsCreativeManualVerbDelete => '删除';

  @override
  String get projectsArtWorkbenchStatusRefreshing => '刷新画风列表中…';

  @override
  String projectsArtWorkbenchStatusRefreshed(int count) {
    return '已刷新 $count 条画风。';
  }

  @override
  String projectsArtWorkbenchStatusRefreshFailed(String error) {
    return '刷新失败：$error';
  }

  @override
  String get projectsArtWorkbenchStatusReadingCover => '读取封面中…';

  @override
  String projectsArtWorkbenchStatusReadCover(int id) {
    return '已读取画风 #$id 封面。';
  }

  @override
  String projectsArtWorkbenchStatusReadCoverFailed(String error) {
    return '读取封面失败：$error';
  }

  @override
  String get projectsArtWorkbenchStatusCreateNeedName => '新建失败：名称不能为空。';

  @override
  String get projectsArtWorkbenchStatusCreating => '新建画风中…';

  @override
  String projectsArtWorkbenchStatusCreated(int id) {
    return '已新建画风 #$id。';
  }

  @override
  String projectsArtWorkbenchStatusCreateFailed(String error) {
    return '新建失败：$error';
  }

  @override
  String get projectsArtWorkbenchStatusSaveNeedSelect => '保存失败：请先选择画风。';

  @override
  String get projectsArtWorkbenchStatusSaving => '保存画风中…';

  @override
  String projectsArtWorkbenchStatusSaved(int id) {
    return '已更新画风 #$id。';
  }

  @override
  String projectsArtWorkbenchStatusSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get projectsArtWorkbenchStatusDeleteNeedSelect => '删除失败：请先选择画风。';

  @override
  String get projectsArtWorkbenchStatusDeleting => '删除画风中…';

  @override
  String projectsArtWorkbenchStatusDeleted(int id) {
    return '已删除画风 #$id。';
  }

  @override
  String projectsArtWorkbenchStatusDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String get projectsArtWorkbenchStatusExtractNeedInput =>
      '抽取失败：请至少输入一个图片 URL 或 data URI。';

  @override
  String get projectsArtWorkbenchStatusExtracting => '抽取画风 prompt 中…';

  @override
  String get projectsArtWorkbenchStatusExtracted => '已生成画风 prompt，可直接保存到当前画风。';

  @override
  String projectsArtWorkbenchStatusExtractFailed(String error) {
    return '抽取失败：$error';
  }

  @override
  String get globalSearchErrSignInFirst => '请先登录';

  @override
  String globalSearchErrSearchFailed(String error) {
    return '搜索失败：$error';
  }

  @override
  String get globalSearchCopiedDeepLink => '已复制当前搜索深链';

  @override
  String get globalSearchAllTypes => '全部';

  @override
  String get globalSearchTimeStart => '起始';

  @override
  String get globalSearchTimeNow => '至今';

  @override
  String get globalSearchAllTime => '全部时间';

  @override
  String get globalSearchNeverUsed => '未使用';

  @override
  String get globalSearchSaveViewTitle => '保存搜索视图';

  @override
  String get globalSearchViewNameField => '视图名称';

  @override
  String get globalSearchViewNameHint => '例如：近 30 天剧本搜索';

  @override
  String get globalSearchCancel => '取消';

  @override
  String get globalSearchSave => '保存';

  @override
  String get globalSearchViewNameRequired => '视图名称不能为空';

  @override
  String get globalSearchViewSaved => '已保存搜索视图';

  @override
  String get globalSearchNoSavedViews => '当前没有已保存的搜索视图。';

  @override
  String get globalSearchPinned => '已固定';

  @override
  String get globalSearchUnpin => '取消固定';

  @override
  String get globalSearchPinToSearchBar => '固定到搜索栏';

  @override
  String get globalSearchUnpinnedView => '已取消固定搜索视图';

  @override
  String get globalSearchPinnedToSearchBar => '已固定到搜索栏';

  @override
  String get globalSearchDelete => '删除';

  @override
  String get globalSearchViewDeleted => '已删除搜索视图';

  @override
  String get globalSearchTypeProject => '项目';

  @override
  String get globalSearchTypeScript => '剧本';

  @override
  String get globalSearchTypeAsset => '资产';

  @override
  String get globalSearchTypeNovel => '小说章节';

  @override
  String get globalSearchTypeNovelEvent => '小说事件';

  @override
  String globalSearchTitle(String query) {
    return '搜索：$query';
  }

  @override
  String get globalSearchTooltipSaveCurrentView => '保存当前视图';

  @override
  String get globalSearchTooltipSavedViews => '已保存视图';

  @override
  String get globalSearchTooltipCopyDeepLink => '复制搜索深链';

  @override
  String get globalSearchTooltipFilter => '过滤';

  @override
  String globalSearchFoundResults(int count) {
    return '找到 $count 个结果';
  }

  @override
  String get globalSearchClearFilters => '清除过滤';

  @override
  String globalSearchTimeChip(String from, String to) {
    return '时间 $from ~ $to';
  }

  @override
  String get globalSearchErrorTitle => '搜索出错';

  @override
  String get globalSearchUnknownError => '未知错误';

  @override
  String get globalSearchRetry => '重试';

  @override
  String get globalSearchNoResultsTitle => '未找到匹配结果';

  @override
  String get globalSearchNoResultsHint => '请尝试其他关键词';

  @override
  String get globalSearchPrevPage => '上一页';

  @override
  String globalSearchCurrentPage(int page) {
    return '第 $page 页';
  }

  @override
  String get globalSearchNextPage => '下一页';

  @override
  String get globalSearchTimeJustNow => '刚刚';

  @override
  String globalSearchTimeMinutesAgo(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String globalSearchTimeHoursAgo(int hours) {
    return '$hours 小时前';
  }

  @override
  String globalSearchTimeDaysAgo(int days) {
    return '$days 天前';
  }

  @override
  String get globalSearchChooseStartDate => '选择起始日期';

  @override
  String get globalSearchChooseEndDate => '选择结束日期';

  @override
  String get globalSearchConfirm => '确定';

  @override
  String globalSearchAppliedFilters(int count) {
    return '已应用 $count 个过滤条件';
  }

  @override
  String get globalSearchClearedAllFilters => '已清除所有过滤条件';

  @override
  String get globalSearchAdvancedFilterTitle => '高级过滤';

  @override
  String get globalSearchResultTypeSection => '结果类型';

  @override
  String get globalSearchCreatedTimeSection => '创建时间';

  @override
  String get globalSearchTypeNovelEventOutline => '小说大纲事件';

  @override
  String globalSearchStartDateLabel(String date) {
    return '起始: $date';
  }

  @override
  String globalSearchEndDateLabel(String date) {
    return '结束: $date';
  }

  @override
  String get globalSearchClearTimeRange => '清除时间范围';

  @override
  String get globalSearchApplyFilter => '应用过滤';

  @override
  String get globalSearchWorkspaceUnlabeled => '未标注 workspace';

  @override
  String get globalSearchWorkspaceCurrent => '当前 workspace';

  @override
  String get globalSearchViewActions => '视图操作';

  @override
  String get globalSearchRename => '重命名';

  @override
  String get globalSearchDeleteView => '删除视图';

  @override
  String get globalSearchRenameViewTitle => '重命名搜索视图';

  @override
  String get globalSearchRenameViewHint => '输入新的视图名称';

  @override
  String get globalSearchRenamedView => '已重命名搜索视图';

  @override
  String get globalSearchDeleteViewTitle => '删除搜索视图';

  @override
  String globalSearchDeleteViewConfirmRemote(String title) {
    return '确定删除「$title」吗？已登录时将同步从所有已保存该视图数据的客户端移除。';
  }

  @override
  String globalSearchDeleteViewConfirmLocal(String title) {
    return '确定删除「$title」吗？此操作只会移除本机保存的视图。';
  }

  @override
  String get globalSearchPinnedViewsTitle => '固定视图';

  @override
  String get globalSearchRecentViewsTitle => '最近常用视图';

  @override
  String get globalSearchQuickTemplatesTitle => '快捷模板';

  @override
  String get globalSearchLiveSuggestionsTitle => '实时建议';

  @override
  String get globalSearchRecentSearchTitle => '最近搜索';

  @override
  String get globalSearchClearHistory => '清除历史';

  @override
  String get globalSearchNoPreviewHint => '暂无匹配预览，按 Enter 查看完整结果';

  @override
  String get globalSearchMinCharsHint => '输入至少 2 个字符以搜索';

  @override
  String get globalSearchHistoryCleared => '搜索历史已清除';

  @override
  String globalSearchClearHistoryFailed(String error) {
    return '清除历史失败: $error';
  }

  @override
  String globalSearchEnterAtLeastChars(int count) {
    return '请输入至少 $count 个字符';
  }

  @override
  String globalSearchMaxCharsHint(int count) {
    return '搜索关键词过长，请限制在$count字符以内';
  }

  @override
  String get globalSearchInputHint => '搜索项目、剧本、资产...';

  @override
  String get globalSearchActionSearch => '搜索';

  @override
  String get globalSearchLocalClientPrefsTooltip => '本机客户端偏好（查看已静默 / 恢复确认）';

  @override
  String globalSearchSavedUsed(int count) {
    return 'used=$count';
  }

  @override
  String get globalSearchTemplateRecent7d => '近 7 天';

  @override
  String get globalSearchTemplateProjects30d => '项目近 30 天';

  @override
  String get globalSearchTemplateScripts30d => '剧本近 30 天';

  @override
  String get globalSearchClearSearchHistoryTitle => '清除搜索历史';

  @override
  String get globalSearchClearSearchHistoryConfirm => '确定要清除所有搜索历史吗？此操作无法撤销。';

  @override
  String get globalSearchLoadHistoryFailed => '加载历史失败';

  @override
  String get globalSearchNoSearchHistory => '暂无搜索历史';

  @override
  String globalSearchResultRows(int count) {
    return '$count 条结果';
  }

  @override
  String get qualityReviewsErrNotLoggedIn => '当前未登录，无法读取质量评审';

  @override
  String get qualityReviewsSummaryNotLoaded => '尚未加载评审列表';

  @override
  String get qualityReviewsSectionIntro =>
      '查看评审列表、坏例与阶段通过率；低分坏例会回写负向记忆，高分通过会晋升正向记忆。';

  @override
  String get qualityReviewsOpsDashboardTitle => '质量运营看板';

  @override
  String get qualityReviewsCopiedDashboardSummary => '已复制质量看板摘要';

  @override
  String get qualityReviewsCopyDashboardSummary => '复制看板摘要';

  @override
  String get qualityReviewsFieldReviewId => '评审 ID（点下方列表可自动填入）';

  @override
  String get qualityReviewsViewReviewDetails => '查看评审详情';

  @override
  String qualityReviewsSummaryReviewDetails(String value) {
    return '评审详情：$value';
  }

  @override
  String qualityReviewsSummaryStats(String value) {
    return '质量统计：$value';
  }

  @override
  String qualityReviewsSummaryStagePassRate(String value) {
    return '阶段通过率：$value';
  }

  @override
  String qualityReviewsSummaryStageGrade(String value) {
    return '阶段等级分布：$value';
  }

  @override
  String qualityReviewsSummaryScopeInsights(String value) {
    return 'Scope榜单：$value';
  }

  @override
  String qualityReviewsSummaryTokenEfficiency(String value) {
    return 'Token效率：$value';
  }

  @override
  String qualityReviewsSummaryBadCaseHotspots(String value) {
    return '坏例热点：$value';
  }

  @override
  String get qualityReviewsOpenWorkbench => '打开质量工作台';

  @override
  String get qualityReviewsLoadCurrentDashboard => '读取当前看板';

  @override
  String get qualityReviewsRefreshReadModel => '刷新底层读模型';

  @override
  String get qualityReviewsLoadReviewList => '加载评审列表';

  @override
  String get qualityReviewsViewBadCases => '查看坏例';

  @override
  String get qualityReviewsViewStats => '查看质量统计';

  @override
  String get qualityReviewsViewStagePassRate => '查看阶段通过率';

  @override
  String get qualityReviewsDashboardNotLoadedRefreshEnabled =>
      '质量看板尚未加载。可直接刷新聚合统计、坏例热点、阶段分布与 token 效率。';

  @override
  String get qualityReviewsDashboardNotLoadedRefreshDisabled =>
      '质量看板尚未加载。当前平台配置已关闭刷新入口，可读取当前看板查看已有聚合统计与坏例热点。';

  @override
  String get qualityReviewsTargetType => '目标类型';

  @override
  String qualityReviewsTargetTypeChip(String target, String pass, int count) {
    return '$target $pass% · $count条';
  }

  @override
  String get qualityReviewsStageGrade => '阶段等级';

  @override
  String get qualityReviewsBadCaseHotspots => '坏例热点';

  @override
  String qualityReviewsBadCaseChip(String category, int count) {
    return '$category $count';
  }

  @override
  String get qualityReviewsUncategorized => '未分类';

  @override
  String get qualityReviewsScopeLeaderboard => 'Scope 榜单';

  @override
  String get qualityReviewsTokenEfficiency => 'Token 效率';

  @override
  String get qualityReviewsCompatibilityCheck => '兼容性检查';

  @override
  String get qualityReviewsCompatibilityCheckIntro =>
      '保留只读回归入口，确认评审列表与详情查询仍可正常工作';

  @override
  String get qualityReviewsReadProbeLabel => 'Quality review read probe';

  @override
  String get qualityReviewsRunReadOnlyRegressionCheck => '运行只读回归检查';

  @override
  String qualityReviewsCount(int count) {
    return '$count 条评审';
  }

  @override
  String get qualityReviewsFilterBadCase => '坏例';

  @override
  String get qualityReviewsFilterDeliveryPriorityHit => '命中表演/语气优先';

  @override
  String qualityReviewsFilterStage(String value) {
    return '阶段 $value';
  }

  @override
  String qualityReviewsFilterGrade(String value) {
    return '等级 $value';
  }

  @override
  String qualityReviewsStatusLoadedReviews(int count) {
    return '已加载 $count 条评审';
  }

  @override
  String qualityReviewsStatusLoadedReviewsWithLabels(int count, String labels) {
    return '已加载 $count 条$labels评审';
  }

  @override
  String get qualityReviewsStatusRefreshedStats => '已刷新质量统计';

  @override
  String get qualityReviewsStatusRefreshedScopeLeaderboard => '已刷新 scope 榜单';

  @override
  String get qualityReviewsStatusRefreshedStageAndGrade => '已刷新阶段通过率与等级分布';

  @override
  String get qualityReviewsNoBadCaseData => '暂无坏例数据';

  @override
  String qualityReviewsBadCaseStatsLine(
    String category,
    int count,
    String pass,
  ) {
    return '$category $count条 pass=$pass';
  }

  @override
  String get qualityReviewsStatusRefreshedBadCaseDistribution => '已刷新坏例分布';

  @override
  String get qualityReviewsStatusRefreshedTokenAggregate => '已刷新 token 聚合';

  @override
  String get qualityReviewsStatusRefreshedTokenSavingSamples => '已刷新省 token 样本';

  @override
  String get qualityReviewsErrInputReviewIdFirst => '请先输入评审 ID';

  @override
  String get qualityReviewsStatusLoadedReviewDetails => '已读取评审详情';

  @override
  String get qualityReviewsErrTargetTypeSourceRequired =>
      'targetType 和 source 不能为空';

  @override
  String get qualityReviewsErrScriptNeedsProject =>
      '填写 scriptId 时必须同时填写 projectId';

  @override
  String get qualityReviewsErrStoryboardTargetIdPositive =>
      '创建 storyboard 评审时，targetId 必须是正整数镜头 ID';

  @override
  String qualityReviewsStatusCreated(String id) {
    return '已创建评审 $id';
  }

  @override
  String qualityReviewsStatusCreatedWithScopedWriteback(String id) {
    return '已创建评审 $id，本条会回写项目/剧本隔离记忆';
  }

  @override
  String get qualityReviewsWorkbenchTitle => '质量工作台';

  @override
  String get qualityReviewsWorkbenchIntro => '用同一入口完成评审筛选、坏例查看、统计读取、详情查询和手动创建。';

  @override
  String get qualityReviewsOnlyBadCases => '只看坏例';

  @override
  String get qualityReviewsOnlyDeliveryPriorityHit => '只看命中表演/语气优先';

  @override
  String get qualityReviewsOnlyAutoSamples => '只看 auto 样本';

  @override
  String get qualityReviewsFilterAutoSamples => 'auto 样本';

  @override
  String qualityReviewsFilterQueryLine(String value) {
    return '筛选查询：$value';
  }

  @override
  String get qualityReviewsCopyFilterQuery => '复制筛选查询';

  @override
  String get qualityReviewsCopiedFilterQuery => '已复制筛选查询';

  @override
  String get qualityReviewsCopyApiUrl => '复制完整 API URL';

  @override
  String get qualityReviewsCopiedApiUrl => '已复制 API URL';

  @override
  String get qualityReviewsFilterAndReadSection => '筛选与读取';

  @override
  String get qualityReviewsFilterProjectId => '筛选 projectId';

  @override
  String get qualityReviewsFilterScriptId => '筛选 scriptId';

  @override
  String get qualityReviewsFilterTargetType => '筛选 targetType';

  @override
  String get qualityReviewsFilterTargetId => '筛选 targetId';

  @override
  String get qualityReviewsFilterJobId => '筛选 jobId';

  @override
  String get qualityReviewsFilterStageLabel => '阶段筛选';

  @override
  String get qualityReviewsFilterGradeLabel => '等级筛选';

  @override
  String get qualityReviewsAll => '全部';

  @override
  String get qualityReviewsSummarizing => '汇总中…';

  @override
  String get qualityReviewsLoading => '读取中…';

  @override
  String get qualityReviewsLoadStats => '读取质量统计';

  @override
  String get qualityReviewsLoadScopeLeaderboard => '读取Scope榜单';

  @override
  String get qualityReviewsLoadTokenEfficiency => '读取Token效率';

  @override
  String get qualityReviewsLoadTokenSavingSamples => '读取省Token样本';

  @override
  String get qualityReviewsLoadStagePassRate => '读取阶段通过率';

  @override
  String get qualityReviewsLoadBadCaseDistribution => '读取坏例分布';

  @override
  String get qualityReviewsDetailsQuerySection => '详情查询';

  @override
  String get qualityReviewsReviewId => '评审 ID';

  @override
  String get qualityReviewsCreateReviewSection => '创建评审';

  @override
  String get qualityReviewsCreateProjectIdOptional => 'projectId（可空）';

  @override
  String get qualityReviewsCreateProjectIdHelper => '填写后低分/坏例可自动写入项目隔离记忆';

  @override
  String get qualityReviewsCreateScriptIdOptional => 'scriptId（可空）';

  @override
  String get qualityReviewsCreateScriptIdHelper => '与 projectId 一起填写，才会落到脚本级记忆';

  @override
  String get qualityReviewsCreating => '创建中…';

  @override
  String get qualityReviewsCreateReview => '创建评审';

  @override
  String qualityReviewsStatusLine(String value) {
    return '状态：$value';
  }

  @override
  String qualityReviewsSummaryTokenAggregate(String value) {
    return 'Token聚合：$value';
  }

  @override
  String qualityReviewsSummaryMemoryAction(String value) {
    return '记忆动作：$value';
  }

  @override
  String get qualityReviewsCopyExecutionChecklist => '复制执行清单';

  @override
  String get qualityReviewsCopiedExecutionChecklist => '已复制执行清单';

  @override
  String qualityReviewsSummaryTokenSavingSamples(String value) {
    return '省Token样本：$value';
  }

  @override
  String qualityReviewsSummaryBadCaseDistribution(String value) {
    return '坏例分布：$value';
  }

  @override
  String get qualityReviewsGradeDistribution => '等级分布';

  @override
  String qualityReviewsTotalAndPassRate(int total, String rate) {
    return '总计 $total · A+B 通过率 $rate%';
  }

  @override
  String qualityReviewsPromptDiagnostics(String value) {
    return 'Prompt诊断：$value';
  }

  @override
  String qualityReviewsScopePressure(String value) {
    return 'Scope压力：$value';
  }

  @override
  String qualityReviewsMemorySlimming(String value) {
    return '记忆瘦身：$value';
  }

  @override
  String qualityReviewsPriorityFix(String value) {
    return '优先修复：$value';
  }

  @override
  String qualityReviewsRepairSuggestions(String value) {
    return '修复建议：$value';
  }

  @override
  String qualityReviewsFilterCountLine(String filters, int count) {
    return '$filters $count 条';
  }

  @override
  String qualityReviewsSuggestions(String value) {
    return '建议：$value';
  }

  @override
  String get qualityReviewsEmptyForCurrentFilters => '当前筛选条件下无评审记录';

  @override
  String get qualityReviewsNoTokenEfficiencyStats => '当前没有 token 效率统计';

  @override
  String get qualityReviewsActionKeepDeliveryMemory => '动作=保留表演记忆';

  @override
  String get qualityReviewsActionReuseNegativeMemory => '动作=复用坏例约束';

  @override
  String get qualityReviewsActionTrimGenericStyle => '动作=压项目泛风格';

  @override
  String get qualityReviewsActionPromoteSelectedMemory => '动作=晋升优质镜头';

  @override
  String get qualityReviewsFocusLabel => '焦点';

  @override
  String get qualityReviewsNoTokenEfficiencySamples => '当前没有 token 效率样本';

  @override
  String get qualityReviewsDeliveryPriority => 'delivery优先';

  @override
  String get qualityReviewsRegular => '常规';

  @override
  String get qualityReviewsNoReviews => '当前没有质量评审';

  @override
  String qualityReviewsSummaryLine(int total, int autoCount, String details) {
    return '评审 $total 条 · auto $autoCount 条 · $details';
  }

  @override
  String get qualityReviewsNoQualityStats => '当前没有质量统计';

  @override
  String get qualityReviewsNoScopeLeaderboard => '当前没有 scope 榜单';

  @override
  String get qualityReviewsItemUnit => '条';

  @override
  String get qualityReviewsEmotionRisk => '情绪';

  @override
  String get qualityReviewsRealismRisk => '真实感';

  @override
  String get qualityReviewsPromotionsLabel => '晋升';

  @override
  String get qualityReviewsBadCaseWriteback => '坏例回写';

  @override
  String get qualityReviewsSummaryWriteback => '摘要回写';

  @override
  String get qualityReviewsWritebackSlim => '回写slim';

  @override
  String get qualityReviewsFocusWatch => '关注';

  @override
  String get qualityReviewsNoStagePassRate => '当前没有阶段通过率';

  @override
  String get qualityReviewsNoStageGradeDistribution => '当前没有阶段等级分布';

  @override
  String get qualityReviewsNoBadCaseHotspots => '当前没有坏例热点';

  @override
  String get qualityReviewsSummaryStatsPrefix => '统计';

  @override
  String get qualityReviewsSummaryStagePrefix => '阶段';

  @override
  String get qualityReviewsSummaryGradePrefix => '等级';

  @override
  String get qualityReviewsSummaryBadCasePrefix => '坏例';

  @override
  String get qualityReviewsDiagnosticLabel => '诊断';

  @override
  String get qualityReviewsWritebackLabel => '回写';

  @override
  String get qualityReviewsSuggestionsLabel => '建议';

  @override
  String get qualityReviewsNegativeConstraintReviewAndBadCase => '负向约束=评审+坏例记忆';

  @override
  String get qualityReviewsNegativeConstraintRecentReviews => '负向约束=近期评审';

  @override
  String get qualityReviewsNegativeConstraintBadCaseMemory => '负向约束=坏例记忆';

  @override
  String get qualityReviewsNegativeConstraintPendingBadCase => '负向约束=待观察坏例';

  @override
  String get qualityReviewsNegativeConstraintPendingRejected => '负向约束=待观察拒绝项';

  @override
  String qualityReviewsNegativeConstraintGeneric(String source) {
    return '负向约束=$source';
  }

  @override
  String qualityReviewsBucketCount(String bucket, int count) {
    return '$bucket$count次';
  }

  @override
  String get qualityReviewsFeedbackTagDeliveryRealism => '台词真实';

  @override
  String get qualityReviewsFeedbackTagEmotionArc => '情绪层次';

  @override
  String get qualityReviewsFeedbackTagIdentityContinuity => '人物一致';

  @override
  String get qualityReviewsFeedbackTagLightingRealism => '光影真实';

  @override
  String qualityReviewsScopeProject(int count) {
    return '项目$count';
  }

  @override
  String qualityReviewsScopeScript(int count) {
    return '剧本$count';
  }

  @override
  String qualityReviewsScopeRole(int count) {
    return '角色$count';
  }

  @override
  String get qualityReviewsFocusSelectedVideoMemory => '镜头级精选记忆';

  @override
  String get qualityReviewsFocusRejectedVideoNegativeMemory => '坏例记忆';

  @override
  String get qualityReviewsFocusProjectVideoStyleMemory => '项目级风格记忆';

  @override
  String get qualityReviewsFocusCurrentMemory => '当前记忆';

  @override
  String get qualityReviewsSuggestionReferenceFrame =>
      '先补参考帧和上一镜衔接，锁定脸、服化道和站位连续性。';

  @override
  String get qualityReviewsSuggestionContinuity =>
      '把连续性约束压成 1-2 条硬规则，只留机位、服化道和角色位置。';

  @override
  String get qualityReviewsSuggestionDelivery =>
      '保留表演/语气记忆，补可演的情绪动作，别先删 delivery 记忆。';

  @override
  String get qualityReviewsSuggestionTrimGeneric =>
      '继续压动作/光影这类泛句，把预算留给表情、口型和人物一致性。';

  @override
  String get qualityReviewsSuggestionNegativeReuse =>
      '沿用现有坏例负向约束，手动补词前先去重，避免同义词重复烧 token。';

  @override
  String get qualityReviewsSuggestionDirectorTrim =>
      '导演描述已经让位给记忆，优先回收重复导演句，不动关键表演锚点。';

  @override
  String get qualityReviewsSuggestionProjectScopeTrim =>
      '当前主要命中项目级记忆，继续压词时先缩通用风格句，别动人物表演。';

  @override
  String get qualityReviewsSuggestionRoleScopeKeep =>
      '已经命中角色级记忆，优先加强角色表演动作，不要回退成泛项目描述。';

  @override
  String get qualityReviewsSuggestionEmotion => '下一轮把情绪弧线写成可观察动作，避免只剩解释性台词。';

  @override
  String get qualityReviewsSuggestionVisual => '优先补人物外观和镜头真实感约束，再决定是否继续加风格描述。';

  @override
  String get qualityReviewsSuggestionGeneral => '先锁定人物情绪、连续性和坏例约束，再做下一轮生成。';

  @override
  String qualityReviewsRepairPlanCount(String suggestion, int count) {
    return '$suggestion $count次';
  }

  @override
  String get qualityReviewsCurrentFilterScope => '当前筛选范围';

  @override
  String qualityReviewsActionPlanKeepDelivery(String targetType, String focus) {
    return '$targetType 保留$focus的表演/情绪记忆，继续压泛风格句，别先删 delivery 片段。';
  }

  @override
  String qualityReviewsActionPlanReuseNegative(
    String targetType,
    String focus,
  ) {
    return '$targetType 先复用$focus做坏例隔离约束，锁住穿帮/假感后再决定是否补 prompt。';
  }

  @override
  String qualityReviewsActionPlanTrimGeneric(String targetType, String focus) {
    return '$targetType 优先压$focus里的动作/光影/氛围套话，把 token 留给人物表演、口型和连续性。';
  }

  @override
  String qualityReviewsActionPlanPromoteSelected(
    String targetType,
    String focus,
  ) {
    return '$targetType 从高分样本晋升一条$focus，复用人物情绪和镜头执行，减少重复描述。';
  }

  @override
  String qualityReviewsScopedMemorySuggestion(String scope, String value) {
    return '$scope 独立记忆建议：$value';
  }

  @override
  String qualityReviewsChecklistKeepDelivery(String focus) {
    return '保留$focus里的表演、语气、口型和情绪记忆，只压泛风格套话。';
  }

  @override
  String qualityReviewsChecklistReuseNegative(String focus) {
    return '先复用$focus里的坏例约束，锁住穿帮、假感和冷场，再决定是否补 prompt。';
  }

  @override
  String qualityReviewsChecklistTrimGeneric(String focus) {
    return '清掉$focus里的动作、光影、氛围套话，把 token 留给人物表演和连续性。';
  }

  @override
  String qualityReviewsChecklistPromoteSelected(String focus) {
    return '把高分样本晋升为$focus，复用人物情绪和镜头执行，减少重复导演描述。';
  }

  @override
  String qualityReviewsChecklistTitle(String scope) {
    return '$scope 执行清单：';
  }

  @override
  String qualityReviewsChecklistScope(String scope) {
    return '范围：记忆只在 $scope 生效，不跨用户、项目或短剧复用。';
  }

  @override
  String qualityReviewsAutoSampleSummary(
    int count,
    String prompt,
    String memory,
    String visual,
    String delivery,
    String hitRate,
  ) {
    return 'auto样本 $count 条 · 平均 prompt=$prompt chars · memory=$memory (visual=$visual, delivery=$delivery) · delivery优先命中 $hitRate%';
  }

  @override
  String qualityReviewsAutoDiagnosticsCount(int count) {
    return 'auto诊断 $count 条';
  }

  @override
  String qualityReviewsAveragePrompt(String prompt) {
    return '平均 prompt=$prompt chars';
  }

  @override
  String qualityReviewsDeliveryPriorityRate(String rate) {
    return 'delivery优先 $rate%';
  }

  @override
  String get qualityReviewsTimesUnit => ' 次';

  @override
  String qualityReviewsHitMemoryBuckets(String value) {
    return '命中记忆 $value';
  }

  @override
  String qualityReviewsSuppressedBuckets(String value) {
    return '压缩桶 $value';
  }

  @override
  String qualityReviewsDirectorYieldCount(int hit, int total) {
    return '导演让位 $hit/$total';
  }

  @override
  String qualityReviewsContinuityConstraintCount(int hit, int total) {
    return '连续性约束 $hit/$total';
  }

  @override
  String qualityReviewsReferenceFrameCount(int hit, int total) {
    return '参考帧 $hit/$total';
  }

  @override
  String qualityReviewsHitBucketsInline(String value) {
    return '命中=$value';
  }

  @override
  String qualityReviewsSuppressedBucketsInline(String value) {
    return '压缩=$value';
  }

  @override
  String get qualityReviewsDirectorYield => '导演让位';

  @override
  String qualityReviewsSavedChars(int chars) {
    return '省下$chars chars';
  }

  @override
  String qualityReviewsNegativeSlim(int fragments, int chars) {
    return '负向精简=$fragments条/$chars chars';
  }

  @override
  String qualityReviewsMemoryScopeLevel(String value) {
    return '记忆层级=$value';
  }

  @override
  String qualityReviewsContinuityCount(int count) {
    return '连续性$count';
  }

  @override
  String get qualityReviewsReferenceFrame => '参考帧';

  @override
  String get qualityReviewsWritebackPromotedSelected => '正向记忆晋升';

  @override
  String get qualityReviewsWritebackRejectedMemory => '坏例记忆回写';

  @override
  String get qualityReviewsWritebackSummaryMemory => '评审摘要回写';

  @override
  String get qualityReviewsWritebackMissingPromptSeed => '正向记忆待补 prompt seed';

  @override
  String get qualityReviewsWritebackEmptySelectedMemory => '正向记忆未提炼出有效片段';

  @override
  String qualityReviewsShotId(int id) {
    return '镜头$id';
  }

  @override
  String qualityReviewsWriteMemory(String name) {
    return '写入=$name';
  }

  @override
  String qualityReviewsClearMemory(String name) {
    return '清理=$name';
  }

  @override
  String qualityReviewsSlimSummary(int chars, int rows, int dup, int visual) {
    return 'slim $chars chars / $rows条（重复 $dup / 纯视觉 $visual）';
  }

  @override
  String qualityReviewsFocusWatchTag(String value) {
    return '关注=$value';
  }

  @override
  String qualityReviewsHitSummary(String value) {
    return '命中 $value';
  }

  @override
  String qualityReviewsSuppressedSummary(String value) {
    return '压缩 $value';
  }

  @override
  String qualityReviewsMemoryOptimizationScopeLine(
    String scope,
    int reviews,
    int chars,
    int rows,
    int dup,
    int visual,
  ) {
    return '$scope $reviews条 · slim $chars chars / $rows条（重复 $dup / 纯视觉 $visual）';
  }

  @override
  String qualityReviewsBadCaseCount(int count) {
    return '坏例 $count';
  }

  @override
  String qualityReviewsDialogueRiskCount(int count) {
    return '情绪/台词 $count';
  }

  @override
  String qualityReviewsVisualRiskCount(int count) {
    return '真实感 $count';
  }

  @override
  String qualityReviewsNextStep(String value) {
    return '下一步 $value';
  }

  @override
  String get qualityReviewsEmpty => '（空）';

  @override
  String qualityReviewsDashboardRefreshPerformed(
    int rows,
    int reviews,
    int usage,
    String time,
  ) {
    return '底层快照已刷新 $rows 条 review fact · reviews=$reviews · usage=$usage · $time';
  }

  @override
  String qualityReviewsDashboardRefreshSkipped(String time) {
    return '底层快照保持现状 · fresh snapshot skipped refresh · $time';
  }

  @override
  String get qualityReviewsFreshnessUnknownAge => 'unknown_age';

  @override
  String get qualityReviewsFreshnessNever => 'never';

  @override
  String get qualityReviewsFreshnessNone => 'none';

  @override
  String get qualityReviewsFreshnessStale => 'STALE';

  @override
  String get qualityReviewsFreshnessFresh => 'fresh';

  @override
  String get qualityReviewsStageStorySkeleton => '故事骨架';

  @override
  String get qualityReviewsStageAdaptationStrategy => '改编策略';

  @override
  String get qualityReviewsStageDirectorPlanning => '导演规划';

  @override
  String get qualityReviewsStageStoryboardTable => '分镜表';

  @override
  String get qualityReviewsStageStoryboardPanel => '分镜面板';

  @override
  String get qualityReviewsStageVideoPrompt => '视频提示词';

  @override
  String get qualityReviewsSourceAuto => 'source=auto';

  @override
  String get qualityReviewsFieldTargetType => 'targetType';

  @override
  String get qualityReviewsFieldTargetId => 'targetId';

  @override
  String get qualityReviewsFieldSource => 'source';

  @override
  String get qualityReviewsFieldOverallScore => 'overallScore';

  @override
  String get qualityReviewsFieldStage => 'stage';

  @override
  String get qualityReviewsFieldGrade => 'grade';

  @override
  String get qualityReviewsFieldComments => 'comments';

  @override
  String get qualityReviewsFieldPassed => 'passed';

  @override
  String get qualityReviewsFieldIsBadCase => 'isBadCase';

  @override
  String get qualityReviewsFieldBadCaseCategory => 'badCaseCategory';

  @override
  String get qualityReviewsDeliveryTag => 'delivery';

  @override
  String get qualityReviewsAutoTag => 'auto';

  @override
  String get qualityReviewsMemoryTag => 'memory';

  @override
  String get qualityReviewsNotAvailable => '无';

  @override
  String qualityReviewsReviewRowTitle(
    String targetType,
    String source,
    String score,
  ) {
    return '$targetType · $source · score=$score';
  }

  @override
  String qualityReviewsStageGradeRow(String stage, int a, int b, int c, int d) {
    return '$stage · A $a / B $b / C $c / D $d';
  }

  @override
  String get teamWorkspaceInviteTokenAutofillHint =>
      '已从链接自动填入邀请 token，可直接点击“接受邀请”。';

  @override
  String get teamWorkspaceOnlyPersonalTitle => '当前只有 Personal 工作区';

  @override
  String get teamWorkspaceOnlyPersonalBody =>
      '若要开始团队协作，可先创建一个 enterprise 空间，再去成员管理里发邀请。创建后就能把项目、任务和 Agent 上下文切到同一个团队范围。';

  @override
  String get teamWorkspaceArchivedFlag => '，已归档';

  @override
  String get teamWorkspaceCurrentFlag => '，当前工作区';

  @override
  String teamWorkspaceRowSemantics(
    String name,
    String type,
    String role,
    String archived,
    String current,
  ) {
    return '$name，$type 空间，你的角色是 $role$archived$current';
  }

  @override
  String teamWorkspaceActionTooltip(String action, String workspace) {
    return '$action $workspace';
  }

  @override
  String get teamWorkspaceEnterEnterpriseName => '请输入企业空间名称';

  @override
  String get teamWorkspaceCreated => '已创建企业空间';

  @override
  String teamWorkspaceCreateFailed(String error) {
    return '创建失败：$error';
  }

  @override
  String get teamWorkspaceEnterInviteToken => '请输入邀请 token';

  @override
  String get teamWorkspaceInviteAcceptedAndJoined => '已接受邀请并加入工作区';

  @override
  String teamWorkspaceAcceptInviteFailed(String error) {
    return '接受邀请失败：$error';
  }

  @override
  String get teamWorkspaceArchiveDialogTitle => '归档企业空间？';

  @override
  String get teamWorkspaceArchiveDialogBody =>
      '归档后该空间将从默认列表隐藏；若其为当前工作区，将自动回到 Personal。';

  @override
  String get teamWorkspaceArchiveAction => '归档';

  @override
  String get teamWorkspaceArchived => '已归档';

  @override
  String get teamWorkspaceRestored => '已恢复';

  @override
  String teamWorkspaceOpFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String teamWorkspaceSwitchedTo(String name) {
    return '已切换到 $name';
  }

  @override
  String teamWorkspaceSwitchFailed(String error) {
    return '切换失败：$error';
  }

  @override
  String get teamWorkspaceLoginRequired => '登录后可管理企业工作区。';

  @override
  String get teamWorkspaceTitle => '团队工作区';

  @override
  String get teamWorkspaceIntro =>
      '列出你可访问的空间（含 Personal），创建 enterprise 空间；owner/admin 可归档或恢复企业空间。';

  @override
  String get teamWorkspaceCreating => '创建中…';

  @override
  String get teamWorkspaceCreateAction => '创建';

  @override
  String get teamWorkspaceJoining => '加入中…';

  @override
  String get teamWorkspaceAcceptInviteAction => '接受邀请';

  @override
  String get teamWorkspaceShowArchivedToggle => '显示已归档企业空间';

  @override
  String get teamWorkspaceLoading => '加载中…';

  @override
  String get teamWorkspaceRefreshList => '刷新列表';

  @override
  String get teamWorkspaceNoListDataHint => '尚无列表数据；点「刷新列表」。';

  @override
  String get teamWorkspaceNoWorkspacesHint => '暂无空间（异常）；通常至少有 Personal。';

  @override
  String get teamWorkspaceArchivedBadge => '已归档';

  @override
  String get teamWorkspaceCurrentBadge => '当前';

  @override
  String get teamWorkspaceManageMembersAction => '管理成员';

  @override
  String get teamWorkspaceMembersShortAction => '成员';

  @override
  String get teamWorkspaceManageInvitesAction => '管理邀请';

  @override
  String get teamWorkspaceInvitesShortAction => '邀请';

  @override
  String get teamWorkspaceSwitchActionLabel => '切换到工作区';

  @override
  String get teamWorkspaceSwitchHereAction => '切换到此';

  @override
  String get teamWorkspaceArchiveActionLabel => '归档工作区';

  @override
  String get teamWorkspaceRestoreActionLabel => '恢复工作区';

  @override
  String get teamWorkspaceRestoreAction => '恢复';

  @override
  String teamWorkspaceInviteMetaLine(String status, String expiry) {
    return '状态: $status · 过期: $expiry';
  }

  @override
  String get teamWorkspaceInviteStatusRevoked => '已撤销';

  @override
  String get teamWorkspaceInviteStatusExpired => '已过期';

  @override
  String get teamWorkspaceInviteStatusValid => '有效';

  @override
  String get teamWorkspaceInviteStatusAccepted => '已接受';

  @override
  String get teamWorkspaceAuditMemberUpserted => '成员已添加或更新';

  @override
  String get teamWorkspaceAuditMemberRoleChanged => '成员角色已变更';

  @override
  String get teamWorkspaceAuditMemberRemoved => '成员已移除';

  @override
  String get teamWorkspaceAuditMemberLeft => '成员主动离开';

  @override
  String get teamWorkspaceAuditOwnerTransferred => 'owner 已转让';

  @override
  String get teamWorkspaceAuditInviteCreated => '邀请已创建';

  @override
  String get teamWorkspaceAuditInviteResent => '邀请已重发';

  @override
  String get teamWorkspaceAuditInviteRevoked => '邀请已撤销';

  @override
  String get teamWorkspaceAuditInviteAccepted => '邀请已接受';

  @override
  String get teamWorkspaceTransferOwnerTitle => '转让 owner';

  @override
  String teamWorkspaceTransferOwnerBody(
    String workspace,
    String fromUser,
    String toUser,
  ) {
    return '将把 $workspace 的主 owner 从 $fromUser\n转给 $toUser。\n\n提交后当前主 owner 会自动降为 admin，目标成员会升为 owner。';
  }

  @override
  String get teamWorkspaceConfirmTransferOwner => '确认转让';

  @override
  String teamWorkspaceMembersDialogTitle(String workspace) {
    return '成员管理 · $workspace';
  }

  @override
  String get teamWorkspaceUserUuidLabel => '用户 UUID';

  @override
  String get teamWorkspaceRoleLabel => '角色';

  @override
  String get teamWorkspaceEnterUserUuid => '请输入用户 UUID';

  @override
  String get teamWorkspaceAddingMember => '添加中…';

  @override
  String get teamWorkspaceAddMemberAction => '添加成员';

  @override
  String get teamWorkspaceRefreshAction => '刷新';

  @override
  String get teamWorkspaceInviteEmailLabel => '邀请邮箱';

  @override
  String get teamWorkspaceEnterInviteEmail => '请输入邀请邮箱';

  @override
  String get teamWorkspaceGeneratingInvite => '生成邀请中…';

  @override
  String get teamWorkspaceGenerateInviteLinkAction => '生成邀请链接';

  @override
  String get teamWorkspaceOpsStatsTitle => '内部运维统计';

  @override
  String get teamWorkspaceReading => '读取中…';

  @override
  String get teamWorkspaceRefreshStats => '刷新统计';

  @override
  String teamWorkspaceStatsMembers(int count) {
    return '成员 $count';
  }

  @override
  String teamWorkspaceStatsProjects(int count) {
    return '项目 $count';
  }

  @override
  String teamWorkspaceStatsActiveJobs(int count) {
    return '活跃任务 $count';
  }

  @override
  String get teamWorkspacePlatformInvitesTitle => '平台邀请（服务端）';

  @override
  String get teamWorkspaceIncludeRevokedInvites => '包含已撤销邀请';

  @override
  String get teamWorkspaceShowExpiredInvites => '显示已过期邀请';

  @override
  String get teamWorkspaceSearchInvitesHint => '搜索邀请（邮箱 / 角色 / 状态）';

  @override
  String get teamWorkspaceNoInviteRecords => '暂无邀请记录。生成或从服务端加载更多。';

  @override
  String teamWorkspaceInviteTokenLine(String token) {
    return 'invite token: $token';
  }

  @override
  String get teamWorkspaceRefreshInviteLinkTooltip => '刷新链接（延期并更换 token）';

  @override
  String get teamWorkspaceRevokeInviteTooltip => '撤销邀请';

  @override
  String get teamWorkspaceCopyInviteInfoTooltip => '复制邀请信息';

  @override
  String teamWorkspaceCopiedInvite(String email) {
    return '已复制邀请：$email';
  }

  @override
  String get teamWorkspaceLoadMoreInvites => '加载更多邀请';

  @override
  String get teamWorkspaceActivityRecordsTitle => '活动记录';

  @override
  String get teamWorkspaceSearchActivityHint =>
      '搜索活动（动作 / actor / target / role / email）';

  @override
  String get teamWorkspaceNoActivityRecords => '暂无活动记录。';

  @override
  String get teamWorkspaceLoadMoreActivity => '加载更多活动';

  @override
  String teamWorkspaceCurrentOwnerLine(String userId) {
    return '当前主 owner: $userId';
  }

  @override
  String get teamWorkspaceSearchMembersHint => '搜索成员（UUID / 角色）';

  @override
  String get teamWorkspaceNoMembers => '暂无成员（异常）。';

  @override
  String get teamWorkspaceTransferOwnerTooltip => '转让 owner';

  @override
  String get teamWorkspaceRemoveMemberTooltip => '移除成员';

  @override
  String get teamWorkspaceLeftWorkspace => '已退出该空间';

  @override
  String get teamWorkspaceLeaving => '退出中…';

  @override
  String get teamWorkspaceLeaveWorkspaceAction => '退出该空间';

  @override
  String get teamWorkspaceRoleOptionMember => 'member';

  @override
  String get teamWorkspaceRoleOptionAdmin => 'admin';

  @override
  String get teamWorkspaceStatusOptionPending => 'pending';

  @override
  String get teamWorkspaceStatusOptionAccepted => 'accepted';

  @override
  String get teamWorkspaceStatusOptionRevoked => 'revoked';

  @override
  String get teamWorkspaceStatusOptionAll => 'all';

  @override
  String teamWorkspaceInvitesDialogTitle(String workspace) {
    return '邀请管理 · $workspace';
  }

  @override
  String get teamWorkspaceGenerating => '生成中…';

  @override
  String get teamWorkspaceGenerateInviteAction => '生成邀请';

  @override
  String get teamWorkspaceRefreshInvitesAction => '刷新邀请';

  @override
  String teamWorkspaceCopiedInviteCount(int count) {
    return '已复制 $count 条邀请';
  }

  @override
  String get teamWorkspaceBulkCopyAction => '批量复制';

  @override
  String get teamWorkspaceClearSelectionAction => '清空选择';

  @override
  String get teamWorkspaceStatusLabel => '状态';

  @override
  String get teamWorkspacePageSizeLabel => '每页条数';

  @override
  String get teamWorkspaceNoInvitesForCurrentFilters => '当前筛选条件下暂无邀请。';

  @override
  String teamWorkspacePagingLine(int page, int pages, int total) {
    return '第 $page / $pages 页 · 共 $total 条';
  }

  @override
  String get teamWorkspacePrevPageAction => '上一页';

  @override
  String get teamWorkspaceNextPageAction => '下一页';

  @override
  String get teamWorkspaceResendInviteLinkAction => '重发链接';

  @override
  String get teamWorkspaceRevokeAction => '撤销';

  @override
  String get teamWorkspaceRoleOptionOwner => 'owner';

  @override
  String teamWorkspaceMemberPrimaryOwnerLine(String role) {
    return '$role · primary owner';
  }

  @override
  String get teamWorkspaceEnterpriseNameLabel => '企业空间名称';

  @override
  String get teamWorkspaceInviteTokenInputLabel => '邀请 token（接受加入）';

  @override
  String get platformStatusRecoveredHealthy => '平台状态已恢复健康';

  @override
  String get platformStatusDegradedWarning => '平台状态出现降级，请关注 SLI 与热点端点';

  @override
  String get platformStatusNotRefreshed => '未刷新';

  @override
  String get platformStatusTitle => '平台状态';

  @override
  String platformStatusWindowMinutes(int minutes) {
    return '$minutes 分钟窗口';
  }

  @override
  String platformStatusWindowHours(int hours) {
    return '$hours 小时窗口';
  }

  @override
  String get platformStatusRefreshAction => '刷新';

  @override
  String get platformStatusIntro => '查看健康检查、就绪状态、版本、SLI 健康度与端点请求概览。';

  @override
  String platformStatusLastRefreshed(String time) {
    return '最近刷新：$time';
  }

  @override
  String get platformStatusAutoRefresh => '自动轮询';

  @override
  String get platformStatusHealthy => 'healthy';

  @override
  String get platformStatusDegraded => 'degraded';

  @override
  String platformStatusVersionLine(
    String service,
    String version,
    String gitSha,
  ) {
    return '版本：$service $version$gitSha';
  }

  @override
  String get platformStatusSliSnapshot => 'SLI 快照';

  @override
  String get platformStatusHotEndpoints => '热点端点';

  @override
  String get platformStatusChipHealth => 'Health';

  @override
  String get platformStatusChipReady => 'Ready';

  @override
  String get platformStatusChipSli => 'SLI';

  @override
  String get platformStatusChipEndpoints => 'Endpoints';

  @override
  String get platformStatusChipDegraded => 'Degraded';

  @override
  String platformStatusSliTileSubtitle(
    String path,
    String p95Ms,
    String successRate,
  ) {
    return '$path · P95 ${p95Ms}ms · 成功率 $successRate%';
  }

  @override
  String platformStatusRequests(int count) {
    return '请求 $count';
  }

  @override
  String platformStatusEndpointTileSubtitle(
    int total,
    String successRate,
    String p95Ms,
  ) {
    return '总请求 $total · 成功率 $successRate% · P95 ${p95Ms}ms';
  }

  @override
  String platformStatusServerErrors(int count) {
    return '5xx $count';
  }

  @override
  String get adminConsoleTitle => '管理台';

  @override
  String get adminConsoleIntro =>
      '内部治理面。统一检索用户、workspace、project、job；支持用户治理、workspace 上下文修复、成员修复，以及 workspace / project ownership / 归档 / 内部备注治理。';

  @override
  String get adminConsoleSearchLabel => '搜索 email / workspace / project / job';

  @override
  String get adminConsoleSearchHint =>
      '支持 UUID 前缀、project numeric_id、status / kind 关键词';

  @override
  String get adminConsoleSearchAction => '搜索';

  @override
  String get adminConsoleClearDetailAction => '清空详情';

  @override
  String get adminConsoleGroupUsers => '用户';

  @override
  String get adminConsoleEmptyUsers => '没有匹配用户';

  @override
  String get adminConsoleGroupWorkspaces => 'Workspace';

  @override
  String get adminConsoleEmptyWorkspaces => '没有匹配 workspace';

  @override
  String get adminConsoleGroupProjects => 'Project';

  @override
  String get adminConsoleEmptyProjects => '没有匹配 project';

  @override
  String get adminConsoleGroupJobs => 'Job';

  @override
  String get adminConsoleEmptyJobs => '没有匹配 job';

  @override
  String adminConsoleUserHitSummary(
    String plan,
    String status,
    int workspaces,
    int projects,
    int activeJobs,
  ) {
    return 'plan $plan · $status · ws $workspaces · project $projects · active job $activeJobs';
  }

  @override
  String adminConsoleWorkspaceHitSummary(
    String workspaceType,
    int members,
    int projects,
    int activeJobs,
    String archivedSuffix,
  ) {
    return '$workspaceType · member $members · project $projects · active job $activeJobs$archivedSuffix';
  }

  @override
  String get adminConsoleArchivedSuffix => ' · archived';

  @override
  String get adminConsoleNoWorkspace => 'no workspace';

  @override
  String adminConsoleProjectHitSummary(
    int numericId,
    String workspaceName,
    String owner,
    String archivedSuffix,
  ) {
    return '#$numericId · $workspaceName · $owner$archivedSuffix';
  }

  @override
  String adminConsoleJobHitTitle(String kind, String status) {
    return '$kind · $status';
  }

  @override
  String adminConsoleJobHitSummary(
    String owner,
    String projectNumericId,
    String createdAt,
  ) {
    return '$owner · project $projectNumericId · $createdAt';
  }

  @override
  String adminConsoleChipPlan(String value) {
    return 'plan $value';
  }

  @override
  String adminConsoleChipWorkspace(int value) {
    return 'workspace $value';
  }

  @override
  String adminConsoleChipProject(int value) {
    return 'project $value';
  }

  @override
  String adminConsoleChipActiveJob(int value) {
    return 'active job $value';
  }

  @override
  String adminConsoleChipApiKey(int value) {
    return 'api key $value';
  }

  @override
  String adminConsoleChipUnreadNotif(int value) {
    return 'unread notif $value';
  }

  @override
  String get adminConsoleSectionMemberships => '成员归属';

  @override
  String get adminConsoleSectionRecentJobs => '最近作业';

  @override
  String get adminConsoleSectionGovernanceAudit => '治理审计';

  @override
  String get adminConsoleGovernanceActionsTitle => '治理动作';

  @override
  String get adminConsoleStatusActive => '正常';

  @override
  String get adminConsoleStatusSuspended => '暂停';

  @override
  String get adminConsoleSuspendReasonLabel => '暂停原因';

  @override
  String get adminConsoleSuspendReasonHint => '例如：滥用、退款争议、人工风控命中';

  @override
  String get adminConsoleSuspendReasonDisabledHint => '用户为正常状态时不保存暂停原因';

  @override
  String get adminConsoleInternalNoteLabel => '内部备注';

  @override
  String get adminConsoleInternalNoteHint => '写给运营 / 支持 / 风控同事看的上下文';

  @override
  String get adminConsoleDailyQuotaOverrideTitle => '日配额覆写';

  @override
  String get adminConsoleDailyQuotaNotOverridden => '当前未覆写，沿用套餐默认配额。';

  @override
  String adminConsoleDailyQuotaCurrentOverride(int value) {
    return '当前覆写值：$value';
  }

  @override
  String get adminConsoleQuotaActionPreserve => '保留当前';

  @override
  String get adminConsoleQuotaActionClear => '清除覆写';

  @override
  String get adminConsoleQuotaActionSet => '设置配额';

  @override
  String get adminConsoleDailyQuotaInputExample => '例如 500';

  @override
  String get adminConsoleDailyQuotaInputDisabledHint => '仅在“设置配额”时生效';

  @override
  String get adminConsoleSaving => '保存中…';

  @override
  String get adminConsoleSaveGovernanceSettings => '保存治理设置';

  @override
  String get adminConsoleWorkspaceContextRepairTitle => 'Workspace 上下文修复';

  @override
  String get adminConsoleWorkspaceContextRepairIntro =>
      '用于处理 current_workspace 指向失效、成员已变更后仍停在旧 workspace 的场景。';

  @override
  String get adminConsoleWorkspaceContextRebuildAndSwitchPersonal =>
      '补建并切回 Personal';

  @override
  String get adminConsoleWorkspaceContextSwitchPersonal => '切回 Personal';

  @override
  String adminConsoleWorkspaceContextSwitchTo(String workspaceName) {
    return '切到 $workspaceName';
  }

  @override
  String get adminConsoleWorkspaceContextRepairing => '正在修复 workspace 上下文…';

  @override
  String get adminConsoleWorkspaceGovernanceTitle => 'Workspace 治理';

  @override
  String get adminConsoleWorkspaceGovernancePersonalHint =>
      '个人 workspace 不可归档；可维护内部备注（metadata.internalOps）。';

  @override
  String get adminConsoleWorkspaceGovernanceEnterpriseHint =>
      '企业 workspace：可归档（软冻结）或解档；内部备注写入 metadata.internalOps。';

  @override
  String get adminConsoleLifecyclePreserve => '不动归档状态';

  @override
  String get adminConsoleLifecycleArchive => '归档';

  @override
  String get adminConsoleLifecycleRestore => '解档';

  @override
  String get adminConsoleNoteActionPreserve => '不变';

  @override
  String get adminConsoleNoteActionClear => '清除';

  @override
  String get adminConsoleNoteActionSet => '写入/更新';

  @override
  String get adminConsoleInternalNoteBodyLabel => '内部备注正文';

  @override
  String get adminConsoleInternalNoteBodySubmitHint => '仅在选择「写入/更新」时提交';

  @override
  String get adminConsoleInternalNoteBodyEditableHint => '选择「写入/更新」后可编辑';

  @override
  String get adminConsoleSaveGovernance => '保存治理';

  @override
  String get adminConsoleWorkspaceMemberRemediationTitle => '成员修复';

  @override
  String get adminConsoleWorkspaceMemberRemediationHint =>
      '支持 internal ops 直接补成员、改角色、移除成员；移除时会顺带回退 current workspace 并清理该 workspace 下的项目 ACL 残留。';

  @override
  String get adminConsoleMemberUserIdLabel => '成员 userId';

  @override
  String get adminConsoleMemberUserIdHint => '输入要补成员或修角色的用户 UUID';

  @override
  String get adminConsoleRoleMember => 'member';

  @override
  String get adminConsoleRoleAdmin => 'admin';

  @override
  String get adminConsoleProcessing => '处理中…';

  @override
  String get adminConsoleUpsertMemberAction => '补成员 / 改角色';

  @override
  String get adminConsoleSetAsMember => '设为 member';

  @override
  String get adminConsoleSetAsAdmin => '设为 admin';

  @override
  String get adminConsoleRemoveAction => '移除';

  @override
  String get adminConsoleOwnerTransferHint => 'owner 请走 owner transfer';

  @override
  String get adminConsoleWorkspaceOwnerRemediationTitle => 'Owner 补救';

  @override
  String get adminConsoleWorkspaceOwnerRemediationPersonalHint =>
      'personal workspace 不允许 owner transfer。';

  @override
  String get adminConsoleWorkspaceOwnerRemediationHint =>
      'internal ops 可直接修复 workspace owner；目标用户必须已是该 workspace 成员，原 owner 会自动降为 admin。';

  @override
  String get adminConsoleTargetOwnerUserIdLabel => '目标 owner userId';

  @override
  String get adminConsoleTargetOwnerUserIdHint => '输入目标成员 UUID';

  @override
  String get adminConsoleTransferOwnerAction => '转让 owner';

  @override
  String get adminConsoleSetAsOwner => '设为 owner';

  @override
  String get adminConsoleAclSummaryTitle => 'ACL 摘要';

  @override
  String adminConsoleRoleCountOwner(int count) {
    return 'owner $count';
  }

  @override
  String adminConsoleRoleCountAdmin(int count) {
    return 'admin $count';
  }

  @override
  String adminConsoleRoleCountMember(int count) {
    return 'member $count';
  }

  @override
  String get adminConsoleNoProjectAclSummary =>
      '当前 workspace 暂无 project ACL 摘要';

  @override
  String adminConsoleExplicitAclCount(int count) {
    return 'explicit $count';
  }

  @override
  String adminConsoleEditorCount(int count) {
    return 'editor $count';
  }

  @override
  String adminConsoleViewerCount(int count) {
    return 'viewer $count';
  }

  @override
  String get adminConsoleViewAction => '查看';

  @override
  String get adminConsoleBatchProjectGovernanceTitle => '批量 Project 治理';

  @override
  String get adminConsoleBatchProjectGovernanceHint =>
      '对当前 workspace 下选中的 project 批量执行 archive / restore / 内部备注写入，用于集中处理同类 ACL 与治理问题。';

  @override
  String get adminConsoleBatchLifecyclePreserve => '不动归档';

  @override
  String get adminConsoleBatchLifecycleArchive => '批量归档';

  @override
  String get adminConsoleBatchLifecycleRestore => '批量解档';

  @override
  String get adminConsoleBatchNotePreserve => '备注不变';

  @override
  String get adminConsoleBatchNoteClear => '清除备注';

  @override
  String get adminConsoleBatchNoteSet => '写入备注';

  @override
  String get adminConsoleBatchNoteBodyLabel => '批量内部备注';

  @override
  String get adminConsoleBatchNoteBodySubmitHint => '仅在选择「写入备注」时提交';

  @override
  String get adminConsoleBatchNoteBodyEditableHint => '选择「写入备注」后可编辑';

  @override
  String adminConsoleBatchApplyAction(int count) {
    return '批量应用到 $count 个 project';
  }

  @override
  String get adminConsoleSectionMembers => '成员';

  @override
  String get adminConsoleSectionRecentProjects => '最近项目';

  @override
  String get adminConsoleProjectOwnerRemediationTitle => 'Project Owner 补救';

  @override
  String get adminConsoleProjectOwnerRemediationHint =>
      'internal ops 可直接修复 project owner；目标用户必须已是该 project 所属 workspace 成员。若该项目已启用 ACL，旧 owner 为普通 member 时会自动保留 editor 访问。';

  @override
  String get adminConsoleTargetProjectOwnerUserIdHint =>
      '输入目标 workspace 成员 UUID';

  @override
  String get adminConsoleRepairProjectOwnerAction => '修复 project owner';

  @override
  String get adminConsoleProjectGovernanceTitle => 'Project 治理';

  @override
  String get adminConsoleProjectGovernanceHint =>
      '归档后该项目从成员列表与汇总统计中隐藏，且所有需 project scope 的 API 返回 403；解档恢复。内部备注写入 metadata.internalOps。';

  @override
  String adminConsoleProjectTitleWithName(String name, int numericId) {
    return '$name (#$numericId)';
  }

  @override
  String adminConsoleProjectTitle(int numericId) {
    return 'Project #$numericId';
  }

  @override
  String get adminConsoleSectionExplicitAclMembers => '显式 ACL 成员';

  @override
  String get adminConsoleSectionWorkspaceCandidates => 'Workspace 候选成员';

  @override
  String get adminConsoleNoData => '暂无数据';

  @override
  String get adminConsoleErrSearchAtLeast2Chars => '请输入至少 2 个字符';

  @override
  String get adminConsoleErrSuspendReasonRequired => '暂停用户时必须填写暂停原因';

  @override
  String get adminConsoleErrDailyQuotaPositiveRequired => '设置日配额时必须填写大于 0 的整数';

  @override
  String get adminConsoleErrInternalNoteRequired => '设置内部备注时必须填写内容';

  @override
  String get adminConsoleErrMemberUserIdRequired => '成员 userId 不能为空';

  @override
  String get adminConsoleErrMemberRoleRequired => '新增或更新成员时必须指定角色';

  @override
  String get adminConsoleErrTargetOwnerUserIdRequired => '目标 owner userId 不能为空';

  @override
  String get adminConsoleErrAtLeastOneProjectRequired => '至少选择一个 project';

  @override
  String get adminConsoleErrBatchNoteRequired => '批量写备注时必须填写内容';

  @override
  String get contentComplianceWorkspacePersonalScope => '个人 / 直连用户范围';

  @override
  String get contentComplianceOpenProject => '打开项目';

  @override
  String get contentComplianceOpenScriptProject => '打开剧本项目';

  @override
  String get contentComplianceOpenStoryboardProject => '打开分镜项目';

  @override
  String get contentComplianceOpenAssetProject => '打开资产项目';

  @override
  String get contentComplianceOpenNovelProject => '打开小说项目';

  @override
  String get contentComplianceOpenUserContext => '查看用户上下文';

  @override
  String get contentComplianceOpenContext => '打开上下文';

  @override
  String get contentComplianceOwnerUnclaimed => '未认领';

  @override
  String get contentComplianceEscalationCriticalUnclaimed => 'critical 未认领';

  @override
  String get contentComplianceEscalationStalledClaimed => 'claimed 停滞';

  @override
  String get contentComplianceEscalationOverCapacity => 'reviewer 超载';

  @override
  String get contentComplianceEscalationEscalated72h => '72h 升级';

  @override
  String get contentComplianceEscalationUrgent => '紧急';

  @override
  String get contentComplianceEscalationClosed => '已关闭';

  @override
  String get contentComplianceEscalationWatch => '观察';

  @override
  String get contentComplianceAlertHintCriticalUnclaimed =>
      '建议先一键批量 claim critical 未认领项';

  @override
  String get contentComplianceAlertHintOverCapacity => '建议先预览或执行自动再平衡';

  @override
  String get contentComplianceAlertHintStalledClaimed =>
      '建议先处理停滞 claimed 项（改派或收敛）';

  @override
  String get contentComplianceAlertHintEscalated72h => '建议优先清理 72h 未收敛项';

  @override
  String get contentComplianceAlertHintDefault => '建议先查看该分层并处理高风险项';

  @override
  String get contentComplianceSnackNoCriticalUnclaimedBulkClaim =>
      '当前没有可批量 claim 的 critical 未认领项';

  @override
  String contentComplianceSnackSelectedStalledClaimed(int count) {
    return '已选中 $count 条 claimed 停滞项，可直接改派或处理';
  }

  @override
  String contentComplianceSnackSelected72hUnconverged(int count) {
    return '已选中 $count 条 72h 未收敛项，可直接改派/处理';
  }

  @override
  String contentComplianceSnackSelectedCriticalUnclaimed(int count) {
    return '已选中 $count 条 critical 未认领项';
  }

  @override
  String contentComplianceSnackSelected72hItems(int count) {
    return '已选中 $count 条 72h 未收敛项';
  }

  @override
  String get contentComplianceSnackRestoredDefaultActionOrder => '已恢复默认动作顺序';

  @override
  String get contentComplianceBulkClaim => '批量 claim';

  @override
  String get contentComplianceBulkResolve => '批量 resolve';

  @override
  String get contentComplianceBulkDismiss => '批量 dismiss';

  @override
  String get contentComplianceBulkGeneric => '批量操作';

  @override
  String contentComplianceBulkConfirmBody(String verb, int count) {
    return '确定对 $count 条举报执行 $verb 吗？';
  }

  @override
  String get contentComplianceBulkConfirmNoteReuse =>
      '\n\n会复用当前 resolution note。';

  @override
  String contentComplianceBulkResult(
    String verb,
    int succeeded,
    int failed,
    int remainingAlerts,
    int criticalAlerts,
  ) {
    return '$verb 完成：成功 $succeeded，失败 $failed；当前告警 $remainingAlerts 条（高优先级 $criticalAlerts 条）';
  }

  @override
  String contentComplianceCsvCopied(int count) {
    return '已复制当前筛选结果 CSV（$count 条）';
  }

  @override
  String get contentComplianceFillReviewerFirst => '请先填写目标 reviewer';

  @override
  String get contentComplianceReassignTitle => '批量改派';

  @override
  String contentComplianceReassignBody(int count, String assignee) {
    return '确定将 $count 条举报改派给 $assignee 吗？';
  }

  @override
  String contentComplianceReassignResult(
    String assignee,
    int succeeded,
    int failed,
  ) {
    return '已改派给 $assignee：成功 $succeeded，失败 $failed';
  }

  @override
  String get contentComplianceAutoRebalanceNoOverload =>
      '当前没有超载 reviewer，无需自动再平衡';

  @override
  String get contentComplianceAutoRebalanceTitlePreview => '预览自动再平衡';

  @override
  String get contentComplianceAutoRebalanceTitleExecute => '执行自动再平衡';

  @override
  String contentComplianceAutoRebalanceBodyPreview(int limit) {
    return '按容量阈值（$limit）预览改派计划，不会写入。';
  }

  @override
  String contentComplianceAutoRebalanceBodyExecute(int limit) {
    return '按容量阈值（$limit）执行自动改派，并写入审计。';
  }

  @override
  String get contentComplianceStartPreview => '开始预览';

  @override
  String get contentComplianceExecuteNow => '立即执行';

  @override
  String contentComplianceAutoRebalanceResultPreview(
    int planned,
    int capacity,
  ) {
    return '自动再平衡预览：建议 $planned 条（capacity $capacity）';
  }

  @override
  String contentComplianceAutoRebalanceResultExecute(
    int planned,
    int executed,
    int overCapacityRemaining,
    int remainingAlerts,
  ) {
    return '自动再平衡完成：计划 $planned 条，执行 $executed 条；剩余 over_capacity $overCapacityRemaining 条，告警共 $remainingAlerts 条';
  }

  @override
  String contentComplianceAuditTitle(String reportId) {
    return '举报审计 · $reportId';
  }

  @override
  String get contentComplianceAuditEmpty => '当前没有可展示的审计记录。';

  @override
  String get contentComplianceTitle => '内容与合规';

  @override
  String get contentComplianceIntro =>
      '同一入口支持用户提交内容举报，以及 internal ops 的 claim / resolve 审核队列。';

  @override
  String get contentComplianceSubmitReportTitle => '提交举报';

  @override
  String get contentComplianceTargetUuidHint => '输入被举报对象 UUID';

  @override
  String get contentComplianceDetailLabel => '补充说明';

  @override
  String get contentComplianceDetailHint => '可填写上下文、时间线或风险描述';

  @override
  String get contentComplianceSubmitting => '提交中…';

  @override
  String get contentComplianceSubmitReport => '提交举报';

  @override
  String get contentComplianceQueueTitle => '审核队列';

  @override
  String get contentComplianceClearFilters => '清空筛选';

  @override
  String get contentComplianceRefresh => '刷新';

  @override
  String get contentComplianceCopyCsv => '复制 CSV';

  @override
  String contentComplianceTopActionSummary(
    String title,
    int count,
    String hint,
  ) {
    return '首要动作：$title（$count）\n$hint';
  }

  @override
  String get contentComplianceViewLayer => '查看该分层';

  @override
  String get contentComplianceRestoreDefaultActionOrder => '恢复默认动作顺序';

  @override
  String get contentCompliancePreviewRebalanceShort => '预览再平衡';

  @override
  String get contentComplianceExecuteRebalanceShort => '执行再平衡';

  @override
  String contentComplianceSnackSelectedCriticalReadyClaim(int count) {
    return '已选中 $count 条 critical 未认领项，可直接批量 claim';
  }

  @override
  String get contentComplianceSelectCriticalUnclaimed => '选中 critical 未认领';

  @override
  String get contentComplianceSnackNoCriticalUnclaimedInList =>
      '当前列表没有可批量 claim 的 critical 未认领项';

  @override
  String get contentComplianceBulkClaimOneClick => '一键批量 claim';

  @override
  String get contentComplianceSelectStalled => '选中停滞项';

  @override
  String get contentCompliancePreviewStalledRebalance => '预览停滞再平衡';

  @override
  String get contentComplianceSelect72hUnconverged => '选中72h未收敛项';

  @override
  String get contentComplianceClaimedOnly => '仅已 claim';

  @override
  String get contentComplianceOwnerChipUnclaimed => 'owner: 未认领';

  @override
  String contentComplianceOwnerChip(String owner) {
    return 'owner: $owner';
  }

  @override
  String contentComplianceEscalationChipPrefix(String stage) {
    return '升级: $stage';
  }

  @override
  String contentComplianceSlaUnclaimedCritical(int count) {
    return 'critical未claim $count';
  }

  @override
  String contentComplianceOverloadedReviewers(int count) {
    return '超载 reviewer $count';
  }

  @override
  String contentComplianceRebalanceNeeded(int count) {
    return '需再平衡 $count';
  }

  @override
  String get contentComplianceReviewerOwnerLoad => 'reviewer / owner 负载';

  @override
  String contentComplianceOverCapacitySuffix(int by) {
    return ' · 超载 +$by';
  }

  @override
  String get contentComplianceEscalationRhythm => '升级节奏';

  @override
  String get contentComplianceWorkspaceHotspots => 'workspace 热点';

  @override
  String get contentComplianceQueueEmpty => '当前没有待处理举报';

  @override
  String get contentComplianceCopyTarget => '复制 target';

  @override
  String get contentComplianceCopiedTargetUuid => '已复制 target UUID';

  @override
  String get contentComplianceCopyReport => '复制 report';

  @override
  String get contentComplianceCopiedReportUuid => '已复制 report UUID';

  @override
  String get contentComplianceAdminConsoleContext => '管理台上下文';

  @override
  String get contentComplianceLoadingAudit => '加载审计中…';

  @override
  String get contentComplianceViewAudit => '查看审计';

  @override
  String get contentComplianceBulkReassignReviewerLabel => '批量改派 reviewer';

  @override
  String get contentComplianceBulkReassignReviewerHint =>
      '例如 internal_ops_cn_shift_b';

  @override
  String contentComplianceSelectedCount(int count) {
    return '已选 $count';
  }

  @override
  String get contentComplianceSelectAllOpen => '全选开放项';

  @override
  String get contentComplianceClearSelection => '清空选择';

  @override
  String get contentComplianceBulkReassign => '批量改派';

  @override
  String get contentComplianceResolutionNoteHint => 'claim / resolve 时可复用这段说明';

  @override
  String get contentComplianceTopSecondaryPendingOnly => '仅选中待处理项';

  @override
  String get contentComplianceTopSecondaryRunRebalance => '执行自动再平衡';

  @override
  String get contentComplianceTopSecondaryPreviewStalledRebalance => '预览停滞再平衡';

  @override
  String get contentComplianceTopSecondarySelect72hOnly => '仅选中72h未收敛项';

  @override
  String get contentComplianceDialogContinue => '继续';

  @override
  String get contentComplianceLabelSelect72hUnconverged => '选中72h未收敛项';

  @override
  String get contentComplianceErrAssigneeRequired => '改派 reviewer 不能为空';

  @override
  String get taskCenterFieldProjectUuidOptional => '项目 UUID（可选）';

  @override
  String qualityReviewsScopeSeedLine(String line) {
    return '范围种子：$line';
  }

  @override
  String get projectEditorAssetHistoryTitle => '资产历史图工作台';

  @override
  String get projectEditorAssetHistoryTypeFilterLabel => '类型过滤（可选）';

  @override
  String get projectEditorAssetHistoryTypeFilterHelper =>
      '逗号分隔，例如 role,clip,props；留空表示全部';

  @override
  String get projectEditorAssetHistoryLoading => '加载中…';

  @override
  String get projectEditorAssetHistoryQueryButton => '查询历史图资产';

  @override
  String get projectEditorAssetHistoryClearFilter => '清空类型过滤';

  @override
  String get projectEditorAssetHistoryLoadingAssets => '正在加载历史图资产…';

  @override
  String get projectEditorAssetHistoryEmptyState => '暂无数据，点击「查询历史图资产」开始。';

  @override
  String get projectEditorAssetHistoryImageDropdownLabel => '历史图片';

  @override
  String get projectEditorAssetHistoryNoImages => '该资产暂无历史图片';

  @override
  String projectEditorAssetHistoryCurrentImage(int sortIndex, String state) {
    return '当前图片：sort=$sortIndex · state=$state';
  }

  @override
  String get projectEditorAssetHistoryNoPreview =>
      '当前图片没有可用预览（可能仅存路径占位或远程资源暂不可达）';

  @override
  String get projectEditorAssetHistoryClose => '关闭';

  @override
  String get projectEditorAssetGenerationTitle => '资产出图工作台';

  @override
  String get projectEditorAssetGenerationDescription =>
      '把 production 资产摘要、批量出图、状态轮询、衍生图清理和封面 URL 更新收口到项目资产主流程，不再只依赖 system probe。';

  @override
  String get projectEditorAssetGenerationClose => '关闭';

  @override
  String get projectEditorScriptsBatchAddTitle => '批量新增剧本';

  @override
  String get projectEditorScriptsBatchAddCountLabel => '数量（1-20）';

  @override
  String get projectEditorScriptsBatchAddCountHelper => '单次最多创建 20 条，避免误操作。';

  @override
  String get projectEditorScriptsBatchAddNamePrefixLabel => '名称前缀';

  @override
  String get projectEditorScriptsBatchAddContentLabel => '剧本默认内容';

  @override
  String get projectEditorScriptsBatchAddCancel => '取消';

  @override
  String get projectEditorScriptsBatchAddCreate => '创建';

  @override
  String get projectEditorScriptsBatchAddCountError => '数量必须是 1-20 的整数';

  @override
  String get projectEditorScriptsBatchAddDefaultPrefix => '新剧本';

  @override
  String get projectEditorScriptsBatchAddDefaultContent => '剧情梗概待补充。';

  @override
  String projectEditorScriptsBatchAddSuccess(int count) {
    return '已批量创建 $count 条剧本';
  }

  @override
  String get projectEditorProbeTasksZeroItems => '0 项';

  @override
  String get projectEditorProbeTasksZeroClasses => '0 类';

  @override
  String projectEditorProbeTasksCompatGetTaskApi(int total, int count) {
    return 'compat get-task-api（GET jobs/page）：total=$total · $count 条本页';
  }

  @override
  String get projectEditorProbeProjectsZeroItems => '0 项';

  @override
  String projectEditorProbeProjectsCompatList(String line) {
    return 'GET …/projects（compat 列表）：$line';
  }

  @override
  String get projectEditorProbeScriptsZeroItems => '0 条';

  @override
  String get projectEditorProbeScriptsEmpty => '（empty：均在提取中或 idle）';

  @override
  String get projectEditorProbeScriptsGetFirstScript =>
      'GET projects/…/scripts (首条)';

  @override
  String get projectEditorProbeScriptsLoading => 'script…';

  @override
  String projectEditorProbeScriptsPostGetScriptApi(
    int count,
    String sample,
    Object id,
  ) {
    return 'POST …/projects/$id/scripts/get-script-api：$count 条 · $sample';
  }

  @override
  String get projectEditorProbeTasksBusyLabel => 'tasks…';

  @override
  String get projectEditorProbeTasksButtonCompatGetProject =>
      'compat tasks get-project';

  @override
  String projectEditorProbeTasksCompatGetProjectResult(String line) {
    return 'compat getProject（GET projects）：$line';
  }

  @override
  String get projectEditorProbeTasksButtonCompatCategories =>
      'compat tasks categories';

  @override
  String projectEditorProbeTasksCompatCategoriesResult(String line) {
    return 'compat categories（GET jobs/kinds）：$line';
  }

  @override
  String get projectEditorProbeTasksButtonCompatList => 'compat tasks list';

  @override
  String get projectEditorProbeTasksButtonCompatTaskDetails =>
      'compat task-details int';

  @override
  String projectEditorProbeTasksCompatTaskDetailsResult(
    int taskId,
    String kind,
    String status,
  ) {
    return 'compat task-details（GET jobs/task-detail）：#$taskId -> $kind/$status';
  }

  @override
  String get projectEditorProbeProjectBusyLabel => 'project…';

  @override
  String get projectEditorProbeProjectButtonGetProject =>
      'POST project get-project';

  @override
  String projectEditorProbeProjectEditNoopResult(
    int numericId,
    String message,
  ) {
    return 'POST …/project/edit-project noop #$numericId：$message';
  }

  @override
  String get projectEditorProbeProjectButtonEditNoop =>
      'POST project edit (noop)';

  @override
  String get projectEditorProbeProjectButtonDeleteZero =>
      'POST project delete id=0';

  @override
  String get projectEditorProbeProjectDeleteUnexpected200 =>
      'POST …/project/delete-project：unexpected 200';

  @override
  String get projectEditorProbeProjectDeleteExpected400 =>
      'POST …/project/delete-project id=0 -> 400（预期）';

  @override
  String get projectEditorProbeProjectButtonEditZero =>
      'POST project edit id=0';

  @override
  String get projectEditorProbeProjectEditUnexpected200 =>
      'POST …/project/edit-project：unexpected 200';

  @override
  String get projectEditorProbeProjectEditExpected400 =>
      'POST …/project/edit-project id=0 -> 400（预期）';

  @override
  String get projectEditorProbeProjectButtonAddDelete => 'POST project add→del';

  @override
  String projectEditorProbeProjectAddMissingAfterList(String name) {
    return 'add-project 成功但 get-project 未找到 name=\"$name\"';
  }

  @override
  String projectEditorProbeProjectAddDeleteOk(int numericId) {
    return 'POST add-project → 已删除 project#$numericId';
  }

  @override
  String projectEditorProbeScriptsBatchAddProbeResult(int inserted) {
    return 'POST …/projects/:id/scripts/batch-add：inserted=$inserted';
  }

  @override
  String get projectEditorProbeScriptsButtonBatchAdd =>
      'POST projects/…/scripts/batch-add';

  @override
  String get projectEditorProbeScriptsButtonPostGetScriptApi =>
      'POST get-script-api';

  @override
  String projectEditorProbeScriptsGetByNumericResult(int sid, String name) {
    return 'GET …/projects/:id/scripts/$sid：$name';
  }

  @override
  String get projectEditorProbeScriptsPatchNameNoopBusy => 'script…';

  @override
  String get projectEditorProbeScriptsButtonPatchNameNoop =>
      'PATCH projects/…/scripts（name noop）';

  @override
  String projectEditorProbeScriptsPatchNameNoopResult(int sid, String name) {
    return 'PATCH …/projects/:id/scripts/$sid name noop → $name';
  }

  @override
  String get projectEditorProbeScriptsExportZipBusy => 'export…';

  @override
  String get projectEditorProbeScriptsButtonExportZip =>
      'POST scripts/export（ZIP）';

  @override
  String projectEditorProbeScriptsExportZipResult(int bytes, int count) {
    return 'POST …/scripts/export：$bytes 字节 · $count 个 numeric id';
  }

  @override
  String get projectEditorProbeScriptsPollExtractBusy => 'poll…';

  @override
  String get projectEditorProbeScriptsButtonPollExtract =>
      'POST extract-state/poll';

  @override
  String projectEditorProbeScriptsPollExtractResult(
    int rowCount,
    String sample,
  ) {
    return 'POST …/extract-state/poll：$rowCount 行 $sample';
  }

  @override
  String get projectEditorProbeScriptsExtractAssetsBusy => 'extract…';

  @override
  String get projectEditorProbeScriptsButtonExtractAssets =>
      'POST extract-assets';

  @override
  String projectEditorProbeScriptsExtractAssetsResult(
    String status,
    String message,
  ) {
    return 'POST …/extract-assets：$status — $message';
  }

  @override
  String projectEditorNovelsEventsDefaultCreateName(int stamp) {
    return '事件_$stamp';
  }

  @override
  String get projectEditorNovelsEventsDefaultCreateDetail => '在这里描述事件。';

  @override
  String get projectEditorNovelsEventsInfoNoEvents => '当前项目还没有事件。';

  @override
  String projectEditorNovelsEventsInfoLoaded(int count) {
    return '已载入 $count 条事件。';
  }

  @override
  String get projectEditorNovelsEventsInfoListEmpty => '事件列表为空。';

  @override
  String projectEditorNovelsEventsInfoRefreshed(int count) {
    return '已刷新，共 $count 条事件。';
  }

  @override
  String projectEditorNovelsEventsInfoSearchDual(int restTotal, int wbTotal) {
    return 'REST 命中 $restTotal 条，workbench 命中 $wbTotal 条。';
  }

  @override
  String get projectEditorNovelsEventsInfoCreated => '已新增事件。';

  @override
  String projectEditorNovelsEventsInfoCreatedWithId(int id) {
    return '已新增事件；编号为 $id。';
  }

  @override
  String projectEditorNovelsEventsInfoUpdated(int eventId, String message) {
    return '已更新事件 $eventId：$message';
  }

  @override
  String projectEditorNovelsEventsInfoDeleted(int eventId, String message) {
    return '已删除事件 $eventId：$message';
  }

  @override
  String projectEditorNovelsEventsInfoBatchDeleted(int count, String message) {
    return '已批量删除 $count 条事件：$message';
  }

  @override
  String get projectEditorNovelsEventsWorkbenchTitle => '事件工作台';

  @override
  String get projectEditorNovelsEventsPreviewSectionTitle => '当前事件预览';

  @override
  String projectEditorNovelsEventsPreviewRow(
    int numericId,
    String name,
    String indexesLine,
  ) {
    return '$numericId · $name · 章节索引 $indexesLine';
  }

  @override
  String get projectEditorNovelsEventsSearchLabel => '搜索事件关键字';

  @override
  String get projectEditorNovelsEventsSearchHelper =>
      '同时调用 REST 与 workbench get-events 搜索';

  @override
  String get projectEditorNovelsEventsSearchButton => '搜索事件';

  @override
  String get projectEditorNovelsEventsRefreshListButton => '刷新列表';

  @override
  String get projectEditorNovelsEventsNewEventHeading => '新增事件';

  @override
  String get projectEditorNovelsEventsFieldEventName => '事件名称';

  @override
  String get projectEditorNovelsEventsFieldEventDescription => '事件描述';

  @override
  String get projectEditorNovelsEventsFieldChapterIdsLabel => '关联章节 IDs';

  @override
  String get projectEditorNovelsEventsFieldChapterIdsHelper =>
      '用逗号分隔，按章节 numeric ID 填写';

  @override
  String get projectEditorNovelsEventsCreateButton => '新增事件';

  @override
  String get projectEditorNovelsEventsUpdateHeading => '更新事件';

  @override
  String get projectEditorNovelsEventsFieldNumericId => '事件 numeric ID';

  @override
  String get projectEditorNovelsEventsFieldUpdatedName => '更新后的事件名称';

  @override
  String get projectEditorNovelsEventsFieldUpdatedDescription => '更新后的事件描述';

  @override
  String get projectEditorNovelsEventsFieldUpdatedChapterIds => '更新后的章节 IDs';

  @override
  String get projectEditorNovelsEventsFieldUpdatedChapterIdsHelper =>
      '按章节 numeric ID 填写；内部会映射为 chapterIds';

  @override
  String get projectEditorNovelsEventsSaveButton => '保存事件';

  @override
  String get projectEditorNovelsEventsDeleteHeading => '删除 / 批量删除';

  @override
  String get projectEditorNovelsEventsDeleteCurrentButton => '删除当前事件';

  @override
  String get projectEditorNovelsEventsBatchDeleteIdsLabel => '批量删除事件 IDs';

  @override
  String get projectEditorNovelsEventsBatchDeleteIdsHelper =>
      'POST …/novel-events/batch-delete；用逗号分隔';

  @override
  String get projectEditorNovelsEventsBatchDeleteButton => '批量删除事件';

  @override
  String get projectEditorNovelsEventsCloseButton => '关闭';

  @override
  String get projectEditorNovelsAndEventsTitle => '小说与事件';

  @override
  String get projectEditorNovelsEventsGenerateEmptyAdmitted =>
      '没有可生成事件的 admitted 章节，请先准入章节。';

  @override
  String projectEditorNovelsEventsGenerateTriggered(
    String ids,
    String message,
  ) {
    return '已为章节 $ids 触发事件生成：$message';
  }

  @override
  String get projectEditorNovelsChapterWorkbenchTitle => '章节工作台';

  @override
  String get projectEditorNovelsChapterWorkbenchPreviewTitle => '当前章节预览';

  @override
  String projectEditorNovelsChapterWorkbenchPreviewRow(
    int numericId,
    String chapter,
    String intakeSource,
    String intakeStatus,
    String eventState,
  ) {
    return '$numericId · $chapter · $intakeSource / $intakeStatus · 事件状态 $eventState';
  }

  @override
  String get projectEditorNovelsChapterWorkbenchCloseButton => '关闭';

  @override
  String get projectEditorNovelsChapterWorkbenchInfoNoChapters => '当前项目还没有章节。';

  @override
  String projectEditorNovelsChapterWorkbenchInfoLoaded(int count) {
    return '已载入 $count 条章节。';
  }

  @override
  String get projectEditorNovelsChapterWorkbenchInfoListEmpty => '章节列表为空。';

  @override
  String projectEditorNovelsChapterWorkbenchInfoRefreshed(int count) {
    return '已刷新，共 $count 条章节。';
  }

  @override
  String get projectEditorNovelsActionErrorUrlEmpty => '请先输入抓取 URL';

  @override
  String get projectEditorNovelsActionErrorUrlInvalid =>
      '抓取 URL 必须是合法的 http/https 地址';

  @override
  String projectEditorNovelsActionErrorCrawlHttp(int code) {
    return '抓取失败，HTTP $code';
  }

  @override
  String projectEditorNovelsActionCrawlImportPreviewEmpty(String title) {
    return '已抓取 $title，但没有抽出可导入正文。';
  }

  @override
  String projectEditorNovelsActionCrawlImportPreviewOk(
    String title,
    int count,
  ) {
    return '已抓取 $title，抽出 $count 条可导入章节。';
  }

  @override
  String get projectEditorNovelsActionCrawlSideServer => 'server-side crawl';

  @override
  String get projectEditorNovelsActionCrawlSideClient => 'client-side crawl';

  @override
  String projectEditorNovelsActionCrawlDoneInfo(
    String side,
    String title,
    String mode,
    int pageCount,
    int chapterUrlCount,
    int bodyCharCount,
  ) {
    return '$side 已完成：$title（模式 $mode，抓取 $pageCount 页，候选章节链接 $chapterUrlCount，正文 $bodyCharCount 字）';
  }

  @override
  String projectEditorNovelsActionSearchHit(int total, int shown) {
    return '搜索命中 $total 条，当前展示 $shown 条。';
  }

  @override
  String projectEditorNovelsActionSearchFiltered(
    int total,
    String filters,
    int shown,
  ) {
    return '筛选命中 $total 条（$filters），当前展示 $shown 条。';
  }

  @override
  String get projectEditorNovelsActionErrorPreparseRequired => '请先预解析整本内容';

  @override
  String projectEditorNovelsActionErrorImportQuality(String blockers) {
    return '导入质量门未通过：$blockers';
  }

  @override
  String projectEditorNovelsActionImportQualityHint(String warnings) {
    return '导入质量提示：$warnings';
  }

  @override
  String get projectEditorNovelsActionErrorBatchSizePositive => '批次大小必须大于 0';

  @override
  String projectEditorNovelsActionErrorChapterBodyEmpty(int index) {
    return '第 $index 条章节正文为空，请先在预解析预览里修正后再导入';
  }

  @override
  String projectEditorNovelsActionImportProgress(int end, int total) {
    return '已导入 $end/$total 条章节…';
  }

  @override
  String projectEditorNovelsActionImportComplete(int count) {
    return '整本导入完成，共新增 $count 条章节。';
  }

  @override
  String projectEditorNovelsActionServerImportDone(
    String title,
    int chaptersCreated,
    String mode,
    int pageCount,
    int chapterUrlCount,
    int bodyCharCount,
  ) {
    return 'server 托管导入完成：$title（新增 $chaptersCreated 条章节，模式 $mode，抓取 $pageCount 页，候选章节链接 $chapterUrlCount，正文 $bodyCharCount 字）';
  }

  @override
  String get projectEditorNovelsActionErrorBatchUrlsEmpty =>
      '请先在批量托管 URL 里填入至少 1 行 URL';

  @override
  String projectEditorNovelsActionBatchImportDone(
    int succeeded,
    int total,
    int failed,
    String detail,
  ) {
    return '批量托管导入完成：成功 $succeeded/$total，失败 $failed。$detail';
  }

  @override
  String get projectEditorNovelsActionBatchImportFailuresPrefix => ' 失败样例：';

  @override
  String projectEditorNovelsActionCrawlScheduleCreated(
    int taskId,
    String status,
    int delayMinutes,
    int repeatMinutes,
  ) {
    return '已创建托管抓取计划：任务 $taskId（$status；延迟 $delayMinutes 分钟；重复间隔 $repeatMinutes 分钟）';
  }

  @override
  String get projectEditorNovelsActionCrawlSchedulesEmpty =>
      '暂无托管抓取计划（仅显示本项目最近 100 条）。';

  @override
  String projectEditorNovelsActionCrawlSchedulesSummary(
    int count,
    String head,
  ) {
    return '本项目托管抓取计划 $count 条，最近：$head';
  }

  @override
  String projectEditorNovelsActionCrawlObservability(
    int totalChapters,
    String topSources,
    String topStatuses,
    String jobs,
    String recent,
  ) {
    return '托管统计：章节总数 $totalChapters；source[$topSources]；status[$topStatuses]；crawlJobs[$jobs]。$recent';
  }

  @override
  String projectEditorNovelsActionCrawlObservabilityRecentImports(String ids) {
    return ' 最近 server 导入：$ids';
  }

  @override
  String projectEditorNovelsActionChapterReadOk(int id) {
    return '已读取章节 #$id。';
  }

  @override
  String projectEditorNovelsActionChapterSaveOk(int id) {
    return '已更新章节 #$id。';
  }

  @override
  String projectEditorNovelsActionChapterDeleteOk(int id) {
    return '已删除章节 #$id。';
  }

  @override
  String get projectEditorNovelsActionErrorIdsEmpty => '至少提供一个章节 ID';

  @override
  String projectEditorNovelsActionEventsGenerateOk(String message) {
    return '已触发事件生成：$message';
  }

  @override
  String get projectEditorNovelsActionListLabelEmpty => '空列表';

  @override
  String get projectEditorNovelsActionListLabelAllZero => '当前均为 0';

  @override
  String projectEditorNovelsActionWorkbenchDataResult(
    int count,
    String sample,
  ) {
    return 'workbench get-novel-data 返回 $count 条：$sample';
  }

  @override
  String projectEditorNovelsActionWorkbenchIndexResult(
    int count,
    String sample,
  ) {
    return 'workbench get-novel-index 返回 $count 条：$sample';
  }

  @override
  String projectEditorNovelsActionWorkbenchEventStateResult(
    int count,
    String sample,
  ) {
    return 'workbench get-novel-event-state 返回 $count 条：$sample';
  }

  @override
  String projectEditorNovelsActionBatchDeleteOk(int count, String message) {
    return '已批量删除 $count 条章节：$message';
  }

  @override
  String get projectEditorNovelsActionErrorAdmissionStatusEmpty => '请先选择目标准入状态';

  @override
  String projectEditorNovelsActionBatchAdmissionOk(int count, String status) {
    return '已批量更新 $count 条章节到 $status。';
  }

  @override
  String get projectEditorNovelsChapterWorkbenchValueUnknown => 'unknown';

  @override
  String get projectEditorNovelsChapterWorkbenchValueUnset => 'unset';

  @override
  String get projectEditorNovelsActionSearchFiltersCleared => '已清空章节筛选条件。';

  @override
  String get projectEditorNovelsActionChapterCreateOk => '已新增章节。';

  @override
  String get projectEditorNovelsActionPreparseResultEmpty => '没有识别到可导入内容。';

  @override
  String projectEditorNovelsActionPreparseResultOk(int count) {
    return '已预解析 $count 条章节，先确认标题和顺序再导入。';
  }

  @override
  String get projectEditorNovelsActionImportPreviewAppendChapter =>
      '已追加 1 条补充章节，请补全标题和正文后导入。';

  @override
  String projectEditorNovelsActionImportPreviewDeletedRow(int chapterIndex) {
    return '已删除第 $chapterIndex 条预解析章节。';
  }

  @override
  String projectEditorNovelsActionImportPreviewRowTitleUpdated(
    int chapterIndex,
  ) {
    return '已更新第 $chapterIndex 条预解析章节标题。';
  }

  @override
  String projectEditorNovelsActionImportPreviewRowBodyUpdated(
    int chapterIndex,
  ) {
    return '已更新第 $chapterIndex 条正文。';
  }

  @override
  String projectEditorNovelsActionImportPreviewAreaTitle(int count) {
    return '预解析修正区（$count 条）';
  }

  @override
  String get projectEditorNovelsActionImportPreviewFooterNote =>
      '导入时会自动重新编号；空正文章节会被拦下，需先在这里补全。';

  @override
  String get projectEditorNovelsActionImportPreviewLongListHint =>
      '当前预览较长，继续向下滚动可逐条修正全部章节。';

  @override
  String projectEditorNovelsActionImportPreviewSupplementChapterTitle(int n) {
    return '补充章节 $n';
  }

  @override
  String get projectEditorNovelsWorkbenchCardSummaryEmptyHelp =>
      '用显式表单完成章节新增、搜索、查看、更新、删除和事件生成，不再依赖首条/末条 probe 按钮。';

  @override
  String projectEditorNovelsWorkbenchCardSummaryDualBounds(
    String summaryLine,
    int firstId,
    String firstChapter,
    int lastId,
    String lastChapter,
  ) {
    return '$summaryLine；首条 #$firstId $firstChapter，末条 #$lastId $lastChapter。';
  }

  @override
  String get projectEditorNovelsWorkbenchCardOpenButton => '打开章节工作台';

  @override
  String get projectEditorNovelsWorkbenchCardRefreshChapters => '刷新章节';

  @override
  String get projectEditorNovelsWorkbenchCardRefreshChaptersBusy => '刷新章节…';

  @override
  String get projectEditorNovelsWorkbenchCardGenerateEventsForTopThree =>
      '为前 3 条生成事件';

  @override
  String get projectEditorNovelsWorkbenchSearchKeywordLabel => '搜索章节关键字';

  @override
  String get projectEditorNovelsWorkbenchSearchKeywordHelper =>
      '调用 GET /projects/:project_uuid/novels?search=';

  @override
  String get projectEditorNovelsWorkbenchSearchIntakeStatusLabel => '准入状态';

  @override
  String get projectEditorNovelsWorkbenchSearchIntakeStatusAll => '全部状态';

  @override
  String get projectEditorNovelsWorkbenchSearchIntakeSourceLabel => '接入来源';

  @override
  String get projectEditorNovelsWorkbenchSearchIntakeSourceAll => '全部来源';

  @override
  String get projectEditorNovelsWorkbenchSearchButton => '搜索';

  @override
  String get projectEditorNovelsWorkbenchSearchClearFilters => '清空筛选';

  @override
  String get projectEditorNovelsWorkbenchSearchRefreshList => '刷新列表';

  @override
  String get projectEditorNovelsWorkbenchCreateSectionTitle => '新增章节';

  @override
  String get projectEditorNovelsWorkbenchCreateChapterTitleLabel => '章节标题';

  @override
  String get projectEditorNovelsWorkbenchCreateChapterBodyLabel => '章节正文';

  @override
  String get projectEditorNovelsWorkbenchCreateSubmit => '新增章节';

  @override
  String get projectEditorNovelsWorkbenchEditSectionTitle => '读取 / 更新章节';

  @override
  String get projectEditorNovelsWorkbenchEditNumericIdLabel => '章节 numeric ID';

  @override
  String get projectEditorNovelsWorkbenchEditReadButton => '读取章节';

  @override
  String get projectEditorNovelsWorkbenchEditPatchChapterLabel => '更新后的章节标题';

  @override
  String get projectEditorNovelsWorkbenchEditPatchBodyLabel => '更新后的章节正文';

  @override
  String get projectEditorNovelsWorkbenchEditIntakeStatusLabel => '准入状态';

  @override
  String get projectEditorNovelsWorkbenchEditIntakeStatusHelper =>
      'draft / pending_review / admitted / rejected';

  @override
  String get projectEditorNovelsWorkbenchEditSourceUrlLabel => '来源 URL';

  @override
  String get projectEditorNovelsWorkbenchEditIntakeNoteLabel => '准入备注';

  @override
  String get projectEditorNovelsWorkbenchEditSaveButton => '保存章节';

  @override
  String get projectEditorNovelsWorkbenchDeleteSectionTitle => '删除 / 生成事件';

  @override
  String get projectEditorNovelsWorkbenchDeleteNumericIdLabel =>
      '待删除章节 numeric ID';

  @override
  String get projectEditorNovelsWorkbenchDeleteButton => '删除章节';

  @override
  String get projectEditorNovelsWorkbenchDeleteGenerateIdsLabel => '生成事件章节 IDs';

  @override
  String get projectEditorNovelsWorkbenchDeleteGenerateIdsHelper =>
      '用逗号分隔，如 1,2,3';

  @override
  String get projectEditorNovelsWorkbenchDeleteGenerateEventsButton => '生成章节事件';

  @override
  String get projectEditorNovelsWorkbenchSnapshotSectionTitle => '快照 / 批量动作';

  @override
  String get projectEditorNovelsWorkbenchSnapshotEventStateIdsLabel =>
      '查询章节 ID（numeric）';

  @override
  String get projectEditorNovelsWorkbenchSnapshotEventStateIdsHelper =>
      '用于 get-novel-event-state；用逗号分隔，如 1,2,3';

  @override
  String get projectEditorNovelsWorkbenchSnapshotReadNovelDataButton =>
      '读取 get-novel-data';

  @override
  String get projectEditorNovelsWorkbenchSnapshotReadNovelIndexButton =>
      '读取 get-novel-index';

  @override
  String get projectEditorNovelsWorkbenchSnapshotReadEventStateButton =>
      '读取 event-state';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsLabel =>
      '批量删除章节 IDs';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteIdsHelper =>
      '调用 workbench batch-delete；用逗号分隔，删除后会回刷工作台。';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchDeleteButton => '批量删除章节';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsLabel =>
      '批量准入章节 IDs';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionIdsHelper =>
      '用逗号分隔，如 1,2,3';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionStatusLabel =>
      '目标准入状态';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteLabel =>
      '批量准入备注';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionNoteHelper =>
      '留空表示不写备注；会覆盖所选章节的 intake_note。';

  @override
  String get projectEditorNovelsWorkbenchSnapshotBatchAdmissionButton =>
      '批量更新准入状态';

  @override
  String get projectEditorNovelsWorkbenchImportSectionTitle => '整本导入';

  @override
  String get projectEditorNovelsWorkbenchImportCrawlUrlLabel => '抓取 URL';

  @override
  String get projectEditorNovelsWorkbenchImportCrawlUrlHelper =>
      '以 client 抓取+修正+导入为主；server 用于托管预览。';

  @override
  String get projectEditorNovelsWorkbenchImportBatchUrlsLabel =>
      '批量托管 URL（每行一个）';

  @override
  String get projectEditorNovelsWorkbenchImportBatchUrlsHelper =>
      '仅用于托管导入（增值）批量触发；默认导入仍以预解析修正区为准。';

  @override
  String get projectEditorNovelsWorkbenchImportScheduleDelayLabel =>
      '托管计划延迟（分钟）';

  @override
  String get projectEditorNovelsWorkbenchImportScheduleDelayHelper =>
      '0 表示立即执行';

  @override
  String get projectEditorNovelsWorkbenchImportScheduleRepeatLabel =>
      '重复间隔（分钟）';

  @override
  String get projectEditorNovelsWorkbenchImportScheduleRepeatHelper =>
      '留空表示不重复';

  @override
  String get projectEditorNovelsWorkbenchImportCreateScheduleButton =>
      '创建托管抓取计划';

  @override
  String get projectEditorNovelsWorkbenchImportListSchedulesButton => '查看托管计划';

  @override
  String get projectEditorNovelsWorkbenchImportRefreshObservabilityButton =>
      '刷新托管统计';

  @override
  String get projectEditorNovelsWorkbenchImportCrawlPreparseButton => '抓取并预解析';

  @override
  String get projectEditorNovelsWorkbenchImportRawPasteLabel => '粘贴整本或多章节正文';

  @override
  String get projectEditorNovelsWorkbenchImportRawPasteHelper =>
      '支持按「第十二章 / 第3回 / 第五集」等标题自动切章。';

  @override
  String get projectEditorNovelsWorkbenchImportBatchSizeLabel => '每批导入条数';

  @override
  String get projectEditorNovelsWorkbenchImportPreparseButton => '预解析整本';

  @override
  String get projectEditorNovelsWorkbenchImportParsedChaptersButton =>
      '导入预解析章节';

  @override
  String get projectEditorNovelsWorkbenchImportServerImportButton => '托管导入（增值）';

  @override
  String get projectEditorNovelsWorkbenchImportServerBatchButton =>
      '批量托管导入（增值）';

  @override
  String get projectEditorNovelsWorkbenchImportExecutionSideLabel => '抓取执行端';

  @override
  String get projectEditorNovelsWorkbenchImportExecutionSideClient =>
      'client (当前可用)';

  @override
  String get projectEditorNovelsWorkbenchImportExecutionSideServer =>
      'server (托管预览)';

  @override
  String get projectEditorNovelsWorkbenchImportIntakeStatusAfterImportLabel =>
      '导入后准入状态';

  @override
  String get projectEditorNovelsWorkbenchImportIntakeNoteLabel => '导入备注';

  @override
  String get projectEditorNovelsWorkbenchImportIntakeNoteHelper =>
      '可写抓取来源、清洗说明、待审原因等';

  @override
  String get projectEditorNovelsWorkbenchImportPreviewAddChapterButton =>
      '补充章节';

  @override
  String get projectEditorNovelsWorkbenchImportPreviewDeleteChapterTooltip =>
      '删除该章节';

  @override
  String get projectEditorNovelsWorkbenchImportPreviewChapterTitleField =>
      '章节标题';

  @override
  String get projectEditorNovelsWorkbenchImportPreviewChapterBodyField =>
      '章节正文';

  @override
  String projectEditorScriptsWorkbenchBatchFollowUpLine(
    String actionSummary,
    String nextAction,
    String detail,
  ) {
    return '$actionSummary 下一步建议：$nextAction。$detail';
  }

  @override
  String get projectEditorScriptsWorkbenchRecommendSyncContext => '读取剧本上下文';

  @override
  String get projectEditorScriptsWorkbenchRecommendPollSelected => '轮询所选状态';

  @override
  String get projectEditorScriptsWorkbenchRecommendExtractSelected => '提取所选素材';

  @override
  String get projectEditorScriptsWorkbenchRecommendExportSelected => '导出所选剧本';

  @override
  String get projectEditorScriptsWorkbenchReloadEmpty => '刷新完成，当前没有剧本。';

  @override
  String projectEditorScriptsWorkbenchReloadCount(int count) {
    return '刷新完成，共 $count 条剧本。';
  }

  @override
  String get projectEditorScriptsWorkbenchReadContextEmpty =>
      '上下文读取完成，但没有匹配剧本。';

  @override
  String projectEditorScriptsWorkbenchReadContextCount(int count) {
    return '已读取 $count 条剧本上下文。';
  }

  @override
  String get projectEditorScriptsWorkbenchErrorNeedScriptIds => '请先填写至少一个剧本 id';

  @override
  String projectEditorScriptsWorkbenchExportSelectedSummary(
    int count,
    String zipSize,
  ) {
    return '已导出 $count 条剧本，ZIP $zipSize。';
  }

  @override
  String get projectEditorScriptsWorkbenchPollExtractIdleOrComplete =>
      '当前均为 idle 或已完成';

  @override
  String projectEditorScriptsWorkbenchPollSelectedSummary(
    int count,
    String sample,
  ) {
    return '已轮询 $count 条剧本提取状态：$sample';
  }

  @override
  String projectEditorScriptsWorkbenchExtractSubmittedSelected(
    int count,
    String status,
    String message,
  ) {
    return '已提交 $count 条剧本素材抽取：$status · $message';
  }

  @override
  String get projectEditorScriptsWorkbenchBatchCreateCountInvalid =>
      '数量必须是 1-20 的整数';

  @override
  String get projectEditorScriptsWorkbenchDefaultNewScriptName => '新剧本';

  @override
  String projectEditorScriptsWorkbenchBatchCreated(int inserted) {
    return '已批量创建 $inserted 条剧本。';
  }

  @override
  String projectEditorScriptsWorkbenchCreatedScriptFollowUp(int id) {
    return '已创建剧本 #$id。';
  }

  @override
  String projectEditorScriptsWorkbenchCreatedScriptSnackBar(int id) {
    return '已创建剧本 #$id';
  }

  @override
  String projectEditorScriptsWorkbenchExportAllFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String projectEditorScriptsWorkbenchPollAllFailed(String error) {
    return '轮询提取状态失败：$error';
  }

  @override
  String projectEditorScriptsWorkbenchExtractAllFailed(String error) {
    return '提交素材抽取失败：$error';
  }

  @override
  String projectEditorScriptsWorkbenchExportAllSummary(
    int count,
    String zipSize,
  ) {
    return '已导出 $count 条剧本，ZIP $zipSize。';
  }

  @override
  String projectEditorScriptsWorkbenchPollAllSummary(int count, String sample) {
    return '已轮询 $count 条剧本提取状态：$sample';
  }

  @override
  String projectEditorScriptsWorkbenchExtractAllSummary(
    int count,
    String status,
    String message,
  ) {
    return '已提交 $count 条剧本素材抽取：$status · $message';
  }

  @override
  String get projectEditorScriptsWorkbenchOverviewOpenWorkbenchReadContext =>
      '打开工作台读取上下文';

  @override
  String get projectEditorScriptsWorkbenchOverviewPollAllExtract => '轮询全部提取状态';

  @override
  String get projectEditorScriptsWorkbenchOverviewExtractAllAssets =>
      '提取全部剧本素材';

  @override
  String get projectEditorScriptsWorkbenchOverviewExportAllScripts => '导出全部剧本';

  @override
  String get projectEditorScriptsSessionInfoNoScripts => '当前项目还没有剧本。';

  @override
  String projectEditorScriptsSessionInfoLoadedCount(int count) {
    return '当前已载入 $count 条剧本，可筛选后批量执行。';
  }

  @override
  String get projectEditorScriptsSessionDefaultAddBody => '剧情梗概待补充。';

  @override
  String get projectEditorScriptsDiagnosisBatchEmptySummary => '还没有选择要处理的剧本。';

  @override
  String get projectEditorScriptsDiagnosisBatchEmptyDetail =>
      '先读取剧本上下文或填写目标剧本 id，再执行批量导出、轮询或素材抽取。';

  @override
  String projectEditorScriptsDiagnosisBatchRunningSummary(int count) {
    return '所选剧本里有 $count 条仍在提取中。';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchRunningDetail =>
      '建议先轮询所选状态，确认批量任务是否完成，再决定是否重试抽取。';

  @override
  String projectEditorScriptsDiagnosisBatchFailedSummary(int count) {
    return '所选剧本里有 $count 条最近提取失败。';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchFailedDetail =>
      '建议重新发起所选剧本素材抽取，优先收敛失败项。';

  @override
  String projectEditorScriptsDiagnosisBatchMissingContextSummary(int count) {
    return '所选 $count 条剧本还缺少上下文快照。';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchMissingContextDetail =>
      '建议先读取剧本上下文，确认哪些剧本已有素材，再决定导出 ZIP 还是补做素材抽取。';

  @override
  String projectEditorScriptsDiagnosisBatchAllAssetsSummary(int count) {
    return '所选 $count 条剧本都已有关联素材。';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchAllAssetsDetail =>
      '可以先导出所选剧本 ZIP 做集中审阅，或转入单剧本工作台继续处理图片流程。';

  @override
  String projectEditorScriptsDiagnosisBatchPendingExtractSummary(int count) {
    return '所选 $count 条剧本仍有待抽取素材的项。';
  }

  @override
  String get projectEditorScriptsDiagnosisBatchPendingExtractDetail =>
      '建议直接批量发起素材抽取，把当前选择转成后续图片和分镜流程可用的资产。';

  @override
  String get projectEditorScriptsDiagnosisSingleNoSnapshotSummary =>
      '还没有当前剧本的工作台快照。';

  @override
  String get projectEditorScriptsDiagnosisSingleNoSnapshotDetail =>
      '先同步工作台，读取 get-script-api 上下文和最近一次提取状态。';

  @override
  String get projectEditorScriptsDiagnosisSingleExtractFailedSummary =>
      '素材提取最近一次执行失败。';

  @override
  String get projectEditorScriptsDiagnosisSingleExtractFailedDetailNoReason =>
      '建议修正输入后重新发起当前剧本素材抽取。';

  @override
  String projectEditorScriptsDiagnosisSingleExtractFailedDetailWithReason(
    String reason,
  ) {
    return '失败原因：$reason，建议修正后重新发起当前剧本素材抽取。';
  }

  @override
  String get projectEditorScriptsDiagnosisSingleExtractRunningSummary =>
      '素材提取正在进行中。';

  @override
  String get projectEditorScriptsDiagnosisSingleExtractRunningDetail =>
      '建议先轮询提取状态，确认任务是否完成，再决定是否进入图片编辑流程。';

  @override
  String get projectEditorScriptsDiagnosisSingleNoAssetsSummary =>
      '当前剧本还没有关联素材。';

  @override
  String get projectEditorScriptsDiagnosisSingleNoAssetsDetail =>
      '可以直接发起素材抽取，把脚本上下文转成后续图片与分镜流程可用的资产。';

  @override
  String get projectEditorScriptsDiagnosisSingleHasAssetsSummary =>
      '当前剧本已有关联素材。';

  @override
  String projectEditorScriptsDiagnosisSingleHasAssetsDetail(int count) {
    return '已同步 $count 条关联素材，可继续进入编辑图片工作台，或先导出 ZIP 做本地审阅。';
  }

  @override
  String get projectEditorScriptsSingleWorkbenchRecommendSyncWorkbench =>
      '同步工作台';

  @override
  String get projectEditorScriptsSingleWorkbenchRecommendPollExtractState =>
      '轮询提取状态';

  @override
  String get projectEditorScriptsSingleWorkbenchRecommendStartExtractAssets =>
      '提取当前剧本素材';

  @override
  String
  get projectEditorScriptsSingleWorkbenchRecommendOpenEditImageWorkbench =>
      '进入编辑图片工作台';

  @override
  String get projectEditorScriptsSingleWorkbenchRecommendExportScriptZip =>
      '导出当前剧本 ZIP';

  @override
  String get projectEditorScriptsSingleWorkbenchContextNotInApi =>
      '当前剧本暂未出现在 get-script-api 结果里。';

  @override
  String projectEditorScriptsSingleWorkbenchContextLoaded(int assetCount) {
    return '已加载脚本上下文：素材 $assetCount 项';
  }

  @override
  String projectEditorScriptsSingleWorkbenchContextReadFailed(String error) {
    return '脚本上下文读取失败：$error';
  }

  @override
  String projectEditorScriptsSingleWorkbenchFollowUpExportDone(String zipSize) {
    return '导出完成：1 个剧本，ZIP $zipSize。';
  }

  @override
  String projectEditorScriptsSingleWorkbenchFollowUpPollState(
    String stateLine,
  ) {
    return '已轮询当前剧本提取状态：$stateLine';
  }

  @override
  String projectEditorScriptsSingleWorkbenchFollowUpExtractSubmitted(
    String status,
    String message,
  ) {
    return '素材抽取已提交：$status · $message';
  }

  @override
  String get projectEditorScriptsSingleWorkbenchEditClosedStillMissing =>
      '编辑图片工作台已关闭；当前剧本仍未出现在 get-script-api 结果里。';

  @override
  String get projectEditorScriptsSingleWorkbenchFollowUpEditClosedSynced =>
      '编辑图片工作台已关闭，已同步脚本上下文与提取状态。';

  @override
  String get projectEditorScriptsSingleWorkbenchSyncBusy => '同步中…';

  @override
  String get projectEditorScriptsExtractStateEmpty =>
      '当前脚本提取状态为空：通常表示 idle 或已完成。';

  @override
  String projectEditorScriptsExtractStateLine(int state, String errorSuffix) {
    return '提取状态：$state$errorSuffix';
  }

  @override
  String get scriptEditorRelatedAssetsNone => '未关联素材';

  @override
  String get scriptEditorRelatedAssetsNameSeparator => '、';

  @override
  String scriptEditorRelatedAssetsOverflow(
    String visibleNames,
    int totalCount,
  ) {
    return '$visibleNames 等 $totalCount 项';
  }

  @override
  String get scriptEditorWorkbenchPanelTitle => '脚本工作台';

  @override
  String get scriptEditorWorkbenchPanelIntro =>
      '自动同步 get-script-api 上下文与提取状态，并支持导出 ZIP、发起素材抽取与编辑图片流程。';

  @override
  String scriptEditorWorkbenchRelatedAssetsLine(String assets) {
    return '关联素材：$assets';
  }

  @override
  String scriptEditorDialogTitle(int numericId) {
    return '剧本 #$numericId';
  }

  @override
  String get scriptEditorFieldNameLabelClearIfEmpty => '名称（留空则清空）';

  @override
  String get scriptEditorFieldContentLabelClearIfEmpty => '内容（留空则清空）';

  @override
  String get scriptEditorFieldExtractStateLabelClearIfEmpty => '提取状态（留空则清空）';

  @override
  String get scriptEditorOpenStoryboards => '分镜列表…';

  @override
  String get scriptEditorDeleteScriptButton => '删除剧本';

  @override
  String get scriptEditorDeleteConfirmTitle => '删除剧本？';

  @override
  String scriptEditorDeleteConfirmBody(int numericId) {
    return '将删除 script #$numericId 及其分镜（数据库级联）。';
  }

  @override
  String get scriptEditorDeleteConfirmDelete => '删除';

  @override
  String get scriptEditorExtractStateMustBeInteger => 'extract_state 须为整数';

  @override
  String get scriptEditorSaveSaving => '保存中…';

  @override
  String get scriptEditorSaveChanges => '保存修改';

  @override
  String get scriptEditorDeletedSnackBar => '剧本已删除';

  @override
  String get scriptEditorStoryboardAddDialogTitle => '新增分镜';

  @override
  String get scriptEditorStoryboardAddPromptLabel => '分镜提示词';

  @override
  String get scriptEditorStoryboardAddPromptHelper => '填写本镜头的画面描述或动作提示。';

  @override
  String get scriptEditorStoryboardAddDurationOptionalLabel => '时长（可选）';

  @override
  String get scriptEditorStoryboardAddDurationOptionalHelper =>
      '整数秒；留空表示由后端默认。';

  @override
  String get scriptEditorStoryboardAddConfirmButton => '新增';

  @override
  String get scriptEditorStoryboardAddPromptRequiredSnackBar => '分镜提示词不能为空';

  @override
  String get scriptEditorStoryboardDurationMustBeIntegerSnackBar => '时长必须是整数';

  @override
  String get scriptEditorStoryboardDurationMustBePositiveSnackBar => '时长必须是正整数';

  @override
  String scriptEditorStoryboardAddFollowUpSummary(int storyboardId) {
    return '已新增分镜 #$storyboardId。';
  }

  @override
  String get scriptEditorStoryboardBatchAddDialogTitle => '批量新增分镜';

  @override
  String get scriptEditorStoryboardBatchAddPromptsLabel => '每行一条分镜提示词';

  @override
  String get scriptEditorStoryboardBatchAddPromptsHelper => '会忽略空行，并按输入顺序批量创建。';

  @override
  String get scriptEditorStoryboardBatchAddUnifiedDurationLabel => '统一时长（可选）';

  @override
  String get scriptEditorStoryboardBatchAddUnifiedDurationHelper =>
      '若填写，会作用于本次全部新增分镜。';

  @override
  String get scriptEditorStoryboardBatchAddConfirmButton => '批量新增';

  @override
  String get scriptEditorStoryboardBatchAddNeedOnePromptSnackBar =>
      '至少填写一条分镜提示词';

  @override
  String
  get scriptEditorStoryboardBatchAddUnifiedDurationMustBeIntegerSnackBar =>
      '统一时长必须是整数';

  @override
  String
  get scriptEditorStoryboardBatchAddUnifiedDurationMustBePositiveSnackBar =>
      '统一时长必须是正整数';

  @override
  String scriptEditorStoryboardBatchAddFollowUpSummary(int count) {
    return '已批量新增 $count 条分镜。';
  }

  @override
  String scriptEditorStoryboardsDialogTitle(int count) {
    return '分镜 ($count)';
  }

  @override
  String get scriptEditorStoryboardsIntroEmpty =>
      '当前剧本还没有分镜，可直接新增单条或按每行一个提示词批量导入。';

  @override
  String get scriptEditorStoryboardsIntroHasBoards =>
      '按剧本维护分镜顺序、提示词与状态；点击条目可进入单条编辑。';

  @override
  String get scriptEditorStoryboardsProductionSummaryPending => '制作视图摘要尚未加载';

  @override
  String scriptEditorStoryboardsRecommendedActionLine(String action) {
    return '推荐动作：$action';
  }

  @override
  String get scriptEditorStoryboardsBusy => '处理中…';

  @override
  String get scriptEditorStoryboardsRefreshList => '刷新列表';

  @override
  String get scriptEditorStoryboardsRefreshing => '刷新中…';

  @override
  String get scriptEditorStoryboardsOpenImageWorkbench => '分镜出图工作台';

  @override
  String get scriptEditorStoryboardsRefreshProductionView => '刷新制作视图';

  @override
  String get scriptEditorStoryboardsLoadingProductionView => '读取制作视图…';

  @override
  String get scriptEditorStoryboardsEmptyList => '暂无分镜';

  @override
  String scriptEditorStoryboardsRowOrder(int index) {
    return '序号 $index';
  }

  @override
  String scriptEditorStoryboardsRowState(String state) {
    return '状态 $state';
  }

  @override
  String scriptEditorStoryboardsRowDuration(String duration) {
    return '时长 $duration';
  }

  @override
  String get scriptEditorStoryboardsStateFallback => 'unknown';

  @override
  String get scriptEditorStoryboardsNarrationExplicit => '已具备显式旁白文案';

  @override
  String get scriptEditorStoryboardsNarrationPromptFallback => '将回退到分镜提示词';

  @override
  String get scriptEditorStoryboardsNarrationPlaceholder => '仍是占位文本';

  @override
  String get scriptEditorStoryboardsVideoRecommendSyncProductionData =>
      '同步当前分镜数据';

  @override
  String get scriptEditorStoryboardsVideoRecommendReadCurrentPreview =>
      '读取当前预览';

  @override
  String get scriptEditorStoryboardsVideoRecommendPrepareVideoTrack => '准备视频轨道';

  @override
  String get scriptEditorStoryboardsVideoRecommendGenerateDefaultVideoPrompt =>
      '生成默认视频提示词';

  @override
  String get scriptEditorStoryboardsVideoRecommendRefreshVideoData => '刷新视频数据';

  @override
  String get scriptEditorStoryboardsVideoRecommendSubmitVideoGeneration =>
      '一键生成视频';

  @override
  String get scriptEditorStoryboardsVideoGenerating => '生成中…';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNeedProductionSummary =>
      '当前分镜还没有同步到制作视图。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNeedProductionDetail =>
      '建议先同步当前分镜数据，补齐 production 侧的图片、轨道和提示词快照，再继续处理视频流程。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoFrameSummary =>
      '当前分镜还没有可用画面。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoFrameDetail =>
      '先读取当前预览或手动保存图片 URL，让视频工作台有明确的输入源。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoTracksSummary =>
      '当前分镜还没有可用视频轨道。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoTracksDetail =>
      '建议先准备视频轨道，再提交视频生成任务。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisNoTrackSelectedSummary =>
      '当前分镜还没有选定视频轨道。';

  @override
  String scriptEditorStoryboardsVideoDiagnosisPickTrackDetail(String trackIds) {
    return '已发现轨道 $trackIds，建议先回填一个轨道 ID 再继续生成视频。';
  }

  @override
  String
  get scriptEditorStoryboardsVideoDiagnosisIncompleteVideoParamsSummary =>
      '视频参数还没有准备完整。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisIncompleteVideoParamsDetail =>
      '建议先生成默认视频提示词并确认时长；准备完成后可直接一键生成视频。';

  @override
  String scriptEditorStoryboardsVideoDiagnosisJobsRunningSummary(int count) {
    return '当前剧本还有 $count 条视频任务在运行。';
  }

  @override
  String scriptEditorStoryboardsVideoDiagnosisJobsRunningDetailNoVideos(
    String suffix,
  ) {
    return '建议先刷新视频数据，确认当前分镜是否已有新结果，再决定是否继续提交。$suffix';
  }

  @override
  String scriptEditorStoryboardsVideoDiagnosisJobsRunningDetailHasVideos(
    String suffix,
  ) {
    return '建议先刷新视频数据并检查当前分镜已有候选视频，再决定是否继续提交。$suffix';
  }

  @override
  String scriptEditorStoryboardsVideoDiagnosisJobsPendingSuffix(int pending) {
    return ' 其中约 $pending 条分镜仍仅有进行中任务，尚未检测到片媒体回库。';
  }

  @override
  String scriptEditorStoryboardsVideoDiagnosisHasVideoCandidatesSummary(
    int count,
  ) {
    return '当前分镜已有 $count 条视频候选。';
  }

  @override
  String get scriptEditorStoryboardsVideoDiagnosisHasVideoCandidatesDetail =>
      '可以先检查已有视频结果并设为当前视频；若仍不满意，再按当前参数继续提交新任务。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisAllReadySummary =>
      '图片、轨道和视频参数都已就绪。';

  @override
  String get scriptEditorStoryboardsVideoDiagnosisAllReadyDetail =>
      '可以直接一键生成视频，系统会自动补齐生成前提示词刷新、建议裁剪和结果回刷。';

  @override
  String get scriptEditorStoryboardsVideoErrorNoExtraDetail => '未提供额外错误信息。';

  @override
  String scriptEditorStoryboardsVideoFailureReasonDetail(
    String reason,
    String fallback,
  ) {
    return '失败原因：$reason。$fallback';
  }

  @override
  String get scriptEditorStoryboardsVoiceoverCompleted => '已生成配音';

  @override
  String get scriptEditorStoryboardsVoiceoverQueued => '配音排队中';

  @override
  String get scriptEditorStoryboardsVoiceoverFailed => '配音失败';

  @override
  String scriptEditorStoryboardsVoiceoverFailedWithError(String error) {
    return '配音失败：$error';
  }

  @override
  String get scriptEditorStoryboardsCurrentFrame => '当前画面';

  @override
  String get scriptEditorStoryboardsNoSelectedFrame => '暂无画面';

  @override
  String scriptEditorStoryboardsPreviewLoadFailed(String url) {
    return '预览加载失败：$url';
  }

  @override
  String scriptEditorStoryboardsSubtitleNarration(String text) {
    return '字幕 / 旁白：$text';
  }

  @override
  String scriptEditorStoryboardsAudioDelivery(String line) {
    return '音频：$line';
  }

  @override
  String get scriptEditorStoryboardsReadinessBasicSlot => '时间线槽位';

  @override
  String get scriptEditorStoryboardsReadinessPromptContext => '脚本 / 提示词';

  @override
  String get scriptEditorStoryboardsReadinessReferenceVisual => '参考图';

  @override
  String get scriptEditorStoryboardsReadinessCandidateCleared => '候选已清空';

  @override
  String get scriptEditorStoryboardsReadinessNoBlockingJob => '无阻塞任务';

  @override
  String get scriptEditorStoryboardsReadinessTitle => '短视频就绪度';

  @override
  String get scriptEditorStoryboardsReadinessReady => '就绪';

  @override
  String get scriptEditorStoryboardsReadinessIncomplete => '未就绪';

  @override
  String get scriptEditorStoryboardsReadinessSummaryReady =>
      '短视频就绪：本条分镜检查已通过，可继续生成。';

  @override
  String get scriptEditorStoryboardsReadinessSummaryPending => '短视频就绪：有待核对项。';

  @override
  String scriptEditorStoryboardsReadinessSummaryBlocked(String items) {
    return '短视频就绪：待补齐 $items';
  }

  @override
  String get scriptEditorStoryboardsReadinessBlockingMissingBasicSlot =>
      '时间线槽位';

  @override
  String get scriptEditorStoryboardsReadinessBlockingMissingPromptContext =>
      '脚本 / 提示词';

  @override
  String get scriptEditorStoryboardsReadinessBlockingMissingReferenceVisual =>
      '参考图';

  @override
  String
  get scriptEditorStoryboardsReadinessBlockingMissingLiveActionReferenceShot =>
      '真人参考镜头';

  @override
  String
  get scriptEditorStoryboardsReadinessBlockingMissingLiveActionPerformanceNotes =>
      '表演 / 口播约束';

  @override
  String get scriptEditorStoryboardsReadinessBlockingCandidatePending => '候选确认';

  @override
  String get scriptEditorStoryboardsReadinessBlockingBlockingJob => '生成任务进行中';

  @override
  String get scriptEditorEditImageWorkbenchTitle => '编辑图片工作台';

  @override
  String get scriptEditorEditImageWorkbenchIntro =>
      '直接在脚本工作台内管理 edit-image flow、上传源图并发起生成，不再只停留在 production probe。';

  @override
  String get scriptEditorEditImageWorkbenchSyncing => '同步中…';

  @override
  String get scriptEditorEditImageWorkbenchResyncFlow => '重新同步 Flow';

  @override
  String scriptEditorEditImageWorkbenchDefaultModelLine(
    String model,
    String resolution,
  ) {
    return '默认模型 $model · $resolution';
  }

  @override
  String get scriptEditorEditImageWorkbenchUploadLabel =>
      '源图 base64 / data URI';

  @override
  String get scriptEditorEditImageWorkbenchUploadHelper =>
      '粘贴 data:image/png;base64,... 或原始 base64；用于 upload-image。';

  @override
  String get scriptEditorEditImageWorkbenchBusy => '处理中…';

  @override
  String get scriptEditorEditImageWorkbenchUploadSource => '上传源图';

  @override
  String get scriptEditorEditImageWorkbenchFlowIdLabel => 'Flow ID';

  @override
  String get scriptEditorEditImageWorkbenchModelOptionalLabel => '生成模型（可选）';

  @override
  String get scriptEditorEditImageWorkbenchPromptLabel => '生成提示词';

  @override
  String get scriptEditorEditImageWorkbenchGenerate => '发起流程出图';

  @override
  String get scriptEditorEditImageWorkbenchSaveFlow => '保存当前 Flow';

  @override
  String get scriptEditorEditImageWorkbenchStepsHeading => '步骤状态';

  @override
  String get scriptEditorEditImageWorkbenchStepsEmpty => '暂无步骤，先点击「重新同步 Flow」。';

  @override
  String scriptEditorEditImageWorkbenchStepLine(String stepId, String status) {
    return '$stepId · $status';
  }

  @override
  String get scriptEditorEditImageWorkbenchStepIdLabel => 'Step ID';

  @override
  String get scriptEditorEditImageWorkbenchNewStatusLabel => '新状态';

  @override
  String get scriptEditorEditImageWorkbenchNewStatusHelper =>
      '例如 pending / completed / failed';

  @override
  String get scriptEditorEditImageWorkbenchUpdateStep => '更新单个步骤状态';

  @override
  String scriptEditorEditImageWorkbenchFlowLoaded(
    String flowId,
    int stepCount,
    String model,
  ) {
    return '已加载 flow $flowId，步骤 $stepCount，默认模型 $model';
  }

  @override
  String scriptEditorEditImageWorkbenchLoadFailed(String error) {
    return '读取编辑图片工作台失败：$error';
  }

  @override
  String get scriptEditorEditImageWorkbenchErrPasteSource =>
      '请先粘贴源图 base64 或 data URI';

  @override
  String get scriptEditorEditImageWorkbenchErrFlowAndPromptEmpty =>
      'Flow ID 和生成提示词都不能为空';

  @override
  String get scriptEditorEditImageWorkbenchSourceUploaded =>
      '源图已上传，URL 已返回，可继续生成流程图片';

  @override
  String scriptEditorEditImageWorkbenchJobEnqueued(
    String jobId,
    String status,
  ) {
    return '生成任务已入队：$jobId · $status';
  }

  @override
  String get scriptEditorEditImageWorkbenchErrFlowIdEmpty => 'Flow ID 不能为空';

  @override
  String scriptEditorEditImageWorkbenchFlowSaved(String flowId) {
    return 'Flow $flowId 已保存';
  }

  @override
  String get scriptEditorEditImageWorkbenchErrFlowStepStatusEmpty =>
      'Flow ID、Step ID 和新状态都不能为空';

  @override
  String scriptEditorEditImageWorkbenchStepUpdated(String stepId) {
    return '步骤 $stepId 已更新';
  }

  @override
  String get skillsHarnessTitle => 'Harness / 技能';

  @override
  String get skillsHarnessPrefsTooltip => '本机客户端偏好（调试壳，与各主面板标题旁 ⋯ 相同）';

  @override
  String skillsHarnessToolsLabel(String line) {
    return 'tools: $line';
  }

  @override
  String skillsHarnessUserWasmValidateLabel(String line) {
    return 'user-wasm validate: $line';
  }

  @override
  String skillsHarnessUserWasmPersistLabel(String line) {
    return 'user-wasm persist: $line';
  }

  @override
  String skillsHarnessUserWasmListLabel(String line) {
    return 'user-wasm list: $line';
  }

  @override
  String skillsHarnessUserWasmRevokeLabel(String line) {
    return 'user-wasm revoke: $line';
  }

  @override
  String skillsHarnessSummaryLabel(String line) {
    return 'summary: $line';
  }

  @override
  String get skillsHarnessPathLabel => '技能相对路径';

  @override
  String get skillsHarnessPathHelper => 'POST 需要一个在 data/skills 下尚不存在的路径';

  @override
  String get skillsHarnessBodyLabel => 'PUT / POST 请求体';

  @override
  String get skillsHarnessRollingBack => '回滚中…';

  @override
  String get skillsHarnessVersions => '版本历史 / 回滚';

  @override
  String get skillsHarnessWsRecent => 'WS 最近消息：';

  @override
  String skillsHarnessPreviewTruncated(String preview) {
    return '$preview\n\n（预览内容已在 12,000 字符处截断）';
  }

  @override
  String get skillsHarnessPreviewClose => '关闭';

  @override
  String skillsHarnessVersionDialogTitle(String path) {
    return '版本历史 · $path';
  }

  @override
  String get skillsHarnessVersionEmpty => '该路径暂无版本记录';

  @override
  String skillsHarnessVersionCountHint(int count) {
    return '共 $count 个版本';
  }

  @override
  String skillsHarnessVersionHash(String hash) {
    return '哈希 $hash';
  }

  @override
  String skillsHarnessVersionTitle(int index) {
    return '版本 $index';
  }

  @override
  String skillsHarnessRollbackVersionTitle(int index) {
    return '回滚快照 $index';
  }

  @override
  String get skillsHarnessDiffTitle => '差异（当前 vs 所选）';

  @override
  String get skillsHarnessConfirmRollbackTitle => '确认回滚';

  @override
  String skillsHarnessConfirmRollbackBody(String time, String hash) {
    return '回滚到 $time 的快照（哈希 $hash）？';
  }

  @override
  String get skillsHarnessCancel => '取消';

  @override
  String get skillsHarnessConfirmRollback => '回滚';

  @override
  String get skillsHarnessRollbackToVersion => '回滚到此版本';

  @override
  String skillsHarnessPutResult(String path, int length) {
    return 'PUT 成功：$path（已写入 $length 字符）';
  }

  @override
  String skillsHarnessPostResult(String path, int length) {
    return 'POST 成功：$path（已写入 $length 字符）';
  }

  @override
  String skillsHarnessDeleteResult(String path) {
    return 'DELETE 成功：$path';
  }

  @override
  String get skillsHarnessRollbackSummary => '通过 Harness 界面回滚';

  @override
  String skillsHarnessRollbackResult(String path, String hash) {
    return '已回滚 $path · 哈希 $hash';
  }

  @override
  String get skillsHarnessRollbackDone => '回滚完成';

  @override
  String skillsHarnessValidateResult(String validated, int sizeBytes) {
    return 'validated=$validated, size_bytes=$sizeBytes（内嵌探针）';
  }

  @override
  String skillsHarnessPersistResult(
    String id,
    String sha,
    int sizeBytes,
    String createdAt,
  ) {
    return '已存储 id=$id, sha256=$sha, size=$sizeBytes, 时间=$createdAt';
  }

  @override
  String get skillsHarnessStoredModulesEmpty => '0 个已存储模块';

  @override
  String skillsHarnessStoredModulesSummary(
    int count,
    String preview,
    String suffix,
  ) {
    return '$count 个已存储模块 — $preview$suffix';
  }

  @override
  String skillsHarnessRevokeResult(String id, String revokedAt) {
    return '已吊销 id=$id, revoked_at=$revokedAt';
  }

  @override
  String skillsHarnessAggregateResult(
    String scope,
    int markdownCount,
    int totalBytes,
  ) {
    return 'scope=$scope · $markdownCount 个 Markdown 文件，共 $totalBytes 字节';
  }

  @override
  String skillsHarnessListSummary(int count, String sample) {
    return '$count 个文件；示例：$sample';
  }

  @override
  String get skillsHarnessListSampleEmpty => '—';

  @override
  String get storyboardWorkbenchErrNoExportJobSubmitted => '当前还没有已提交的导出任务';

  @override
  String get storyboardWorkbenchExportCompletedSyncedProduction =>
      '导出任务已完成，已自动同步当前分镜制作数据。';

  @override
  String get storyboardWorkbenchSyncProductionLoadingSummary => '正在同步当前分镜制作数据。';

  @override
  String get storyboardWorkbenchSyncProductionLoadingDetail =>
      '同步完成后会自动回填当前画面、轨道和可用视频参数。';

  @override
  String get storyboardWorkbenchSyncProductionFailedSummary => '同步当前分镜制作数据失败。';

  @override
  String get storyboardWorkbenchSyncProductionFailedFallbackDetail =>
      '可先检查当前分镜是否已在 production 侧生成，再重新同步。';

  @override
  String get storyboardWorkbenchRefreshVideoLoadingSummary => '正在刷新当前分镜的视频数据。';

  @override
  String get storyboardWorkbenchRefreshVideoLoadingDetail =>
      '刷新完成后会同步模型信息、已生成视频和进行中的任务。';

  @override
  String get storyboardWorkbenchRefreshVideoFailedSummary => '刷新当前分镜的视频数据失败。';

  @override
  String get storyboardWorkbenchRefreshVideoFailedFallbackDetail =>
      '可稍后重试，或先继续维护图片和轨道信息。';

  @override
  String get storyboardWorkbenchProductionMetaNotLoaded => '制作视图尚未加载';

  @override
  String storyboardWorkbenchProductionMetaSbIndex(int sbIndex) {
    return '序号 $sbIndex';
  }

  @override
  String storyboardWorkbenchProductionMetaState(String state) {
    return '状态 $state';
  }

  @override
  String storyboardWorkbenchProductionMetaDuration(String duration) {
    return '时长 $duration';
  }

  @override
  String storyboardWorkbenchProductionMetaTrack(int trackId) {
    return '轨道 $trackId';
  }

  @override
  String get storyboardWorkbenchProductionMetaLoadedEmpty => '制作视图已加载';

  @override
  String get shortVideoReadinessNoPayloadHeadline => '还没有读取到分镜就绪数据。';

  @override
  String get shortVideoReadinessEmptyProjectHeadline =>
      '当前项目还没有分镜行，可先在脚本侧拆镜后再看聚合。';

  @override
  String shortVideoReadinessRollupHeadline(int ready, int total, int blocked) {
    return '就绪 $ready/$total 条分镜；阻塞 $blocked 条。';
  }

  @override
  String shortVideoReadinessReasonRollupLine(String reasonLabel, int count) {
    return '$reasonLabel（$count 条分镜）';
  }

  @override
  String shortVideoReadinessStoryboardDetailPrefix(int storyboardNumericId) {
    return '分镜 #$storyboardNumericId';
  }

  @override
  String shortVideoReadinessScriptSuffix(int scriptId) {
    return ' · 脚本 #$scriptId';
  }

  @override
  String shortVideoReadinessSlotSuffix(int sbIndex) {
    return ' · 镜位 $sbIndex';
  }

  @override
  String shortVideoReadinessBlockedShotDetail(String lead, String reasons) {
    return '$lead：$reasons';
  }

  @override
  String get shortVideoCandidateCompareReadinessNoData => 'readiness 暂无数据';

  @override
  String get shortVideoCandidateCompareReadinessReady => '已就绪，可继续生成/导出';

  @override
  String shortVideoCandidateCompareReadinessBlocked(String items) {
    return '待补 $items';
  }

  @override
  String get scriptEditorStoryboardsProductionEmptyData => '制作视图当前没有分镜数据';

  @override
  String scriptEditorStoryboardsProductionSummaryLine(
    int count,
    String preview,
    String ellipsis,
  ) {
    return '制作视图 $count 条 · $preview$ellipsis';
  }

  @override
  String scriptEditorStoryboardsProductionReadFailed(String error) {
    return '制作视图读取失败：$error';
  }

  @override
  String get scriptEditorStoryboardsDiagnosisEmptySummary => '当前剧本还没有分镜。';

  @override
  String get scriptEditorStoryboardsDiagnosisEmptyDetail =>
      '先新增单条或批量导入分镜，再继续同步制作视图或发起出图。';

  @override
  String scriptEditorStoryboardsDiagnosisProductionNotSyncedSummary(int count) {
    return '已维护 $count 条分镜，但制作视图还未同步。';
  }

  @override
  String get scriptEditorStoryboardsDiagnosisProductionNotSyncedDetail =>
      '建议先刷新制作视图，确认 production 侧是否已生成对应记录，再决定是否继续批量出图。';

  @override
  String scriptEditorStoryboardsDiagnosisNoPromptsSummary(int count) {
    return '已存在 $count 条分镜，但都还缺少可用提示词。';
  }

  @override
  String get scriptEditorStoryboardsDiagnosisNoPromptsDetail =>
      '先打开单条分镜补全提示词，再进入出图工作台会更稳妥。';

  @override
  String scriptEditorStoryboardsDiagnosisReadyBatchSummary(
    int ready,
    int total,
  ) {
    return '已有 $ready/$total 条分镜可直接进入出图流程。';
  }

  @override
  String get scriptEditorStoryboardsDiagnosisReadyBatchDetail =>
      '可以进入分镜出图工作台批量读取制作视图、生成预览并导出所选图片。';

  @override
  String get scriptEditorStoryboardsRecommendAddStoryboard => '继续新增分镜';

  @override
  String get scriptEditorStoryboardsRecommendRefreshProduction => '刷新制作视图';

  @override
  String get scriptEditorStoryboardsRecommendOpenBatchWorkbench => '进入分镜出图工作台';

  @override
  String get scriptEditorStoryboardsRecommendEditPrompts => '补充分镜提示词';

  @override
  String scriptEditorStoryboardsFollowUpLine(
    String actionSummary,
    String nextAction,
    String detail,
  ) {
    return '$actionSummary 下一步建议：$nextAction。$detail';
  }

  @override
  String scriptEditorStoryboardBatchFollowUpLine(
    String actionSummary,
    String nextAction,
    String detail,
  ) {
    return '$actionSummary 下一步建议：$nextAction。$detail';
  }

  @override
  String get scriptEditorStoryboardBatchRecommendSyncProduction => '同步制作视图';

  @override
  String get scriptEditorStoryboardBatchRecommendSelectReady => '全选可出图分镜';

  @override
  String get scriptEditorStoryboardBatchRecommendGenerateSelected => '一键批量出图';

  @override
  String get scriptEditorStoryboardBatchRecommendPreviewSelected => '读取当前预览';

  @override
  String get scriptEditorStoryboardBatchReadDownloadLink => '读取下载链接';

  @override
  String get scriptEditorStoryboardBatchRecommendExportSelected => '导出所选 ZIP';

  @override
  String get scriptEditorStoryboardBatchDiagnosisNoSelectionSummary =>
      '当前还没有选择要处理的分镜。';

  @override
  String scriptEditorStoryboardBatchDiagnosisNoSelectionWithReadyDetail(
    int readyCount,
  ) {
    return '已有 $readyCount 条分镜具备可用提示词，可直接一键批量出图；系统会自动挑出准备好的分镜入队。';
  }

  @override
  String get scriptEditorStoryboardBatchDiagnosisNoSelectionSyncFirstDetail =>
      '建议先同步制作视图，确认 production 侧分镜记录和提示词是否齐全，再决定后续动作。';

  @override
  String scriptEditorStoryboardBatchDiagnosisPartialProductionSummary(
    int count,
  ) {
    return '所选 $count 条分镜还没有全部同步到制作视图。';
  }

  @override
  String get scriptEditorStoryboardBatchDiagnosisPartialProductionDetail =>
      '建议先刷新制作视图，补齐 production 侧分镜快照后再读预览、下载链接或导出。';

  @override
  String get scriptEditorStoryboardBatchDiagnosisNoPromptsSummary =>
      '所选分镜都还缺少可直接出图的提示词。';

  @override
  String get scriptEditorStoryboardBatchDiagnosisNoPromptsDetail =>
      '先回到分镜编辑区补全提示词，或同步制作视图确认 production 侧是否已有可复用提示词。';

  @override
  String get scriptEditorStoryboardBatchDiagnosisSingleHasImageSummary =>
      '当前所选分镜已经有现成画面。';

  @override
  String get scriptEditorStoryboardBatchDiagnosisSingleHasImageDetail =>
      '建议先读取当前预览确认画面是否可直接复用，再决定是否重新发起出图。';

  @override
  String scriptEditorStoryboardBatchDiagnosisAllHaveImagesSummary(int count) {
    return '所选 $count 条分镜都已有现成画面。';
  }

  @override
  String get scriptEditorStoryboardBatchDiagnosisAllHaveImagesDetail =>
      '可以直接导出所选 ZIP 做集中审阅，必要时再回到单条分镜重跑出图。';

  @override
  String scriptEditorStoryboardBatchDiagnosisMixedReadySummary(
    int selected,
    int ready,
  ) {
    return '所选 $selected 条分镜里有 $ready 条可直接发起出图。';
  }

  @override
  String get scriptEditorStoryboardBatchDiagnosisMixedReadyDetail =>
      '建议先批量提交出图任务，再回到当前工作台读取预览或下载链接确认结果。';

  @override
  String get scriptEditorStoryboardBatchDialogTitle => '分镜出图工作台';

  @override
  String get scriptEditorStoryboardBatchDialogIntro =>
      '把批量出图、当前预览、下载链接与导出 ZIP 收口到剧本分镜区，不再只依赖 production probe。';

  @override
  String get scriptEditorStoryboardBatchHasImage => '已有画面';

  @override
  String get scriptEditorStoryboardBatchMetaIncomplete => '待补充分镜信息';

  @override
  String get scriptEditorStoryboardBatchSyncProductionEmpty =>
      '制作视图尚无分镜记录，仍可按脚本分镜提示词发起出图。';

  @override
  String scriptEditorStoryboardBatchSyncProductionCount(int count) {
    return '已同步 $count 条制作分镜。';
  }

  @override
  String scriptEditorStoryboardBatchLoadProductionFailed(String error) {
    return '加载制作视图失败：$error';
  }

  @override
  String scriptEditorStoryboardBatchGenerateAutoSelected(
    int readyCount,
    int total,
    int enqueued,
  ) {
    return '已自动选中 $readyCount 条可出图分镜，并为 $total 条分镜创建出图任务，队列 $enqueued 条。';
  }

  @override
  String scriptEditorStoryboardBatchGenerateSubmitted(int total, int enqueued) {
    return '已为 $total 条分镜创建出图任务，队列 $enqueued 条。';
  }

  @override
  String get scriptEditorStoryboardBatchSelectAllReady => '已选择全部可直接出图的分镜。';

  @override
  String get scriptEditorStoryboardBatchClearSelection => '已清空选择。';

  @override
  String get scriptEditorStoryboardBatchNoPreview => '当前分镜还没有预览图。';

  @override
  String scriptEditorStoryboardBatchPreviewLoaded(int storyboardId) {
    return '已读取分镜 #$storyboardId 的当前预览。';
  }

  @override
  String scriptEditorStoryboardBatchDownloadReady(int storyboardId) {
    return '已生成分镜 #$storyboardId 的下载链接。';
  }

  @override
  String scriptEditorStoryboardBatchExportDone(
    int count,
    String filename,
    String durationLabel,
  ) {
    return '已导出 $count 条分镜，文件 $filename，总时长 $durationLabel。';
  }

  @override
  String get scriptEditorStoryboardBatchNoPromptsError =>
      '所选分镜没有可用提示词，无法发起批量出图';

  @override
  String get scriptEditorStoryboardBatchSyncing => '同步中…';

  @override
  String get scriptEditorStoryboardBatchClearSelectionButton => '清空选择';

  @override
  String get scriptEditorStoryboardBatchPromptSuffixLabel => '追加提示词（可选）';

  @override
  String get scriptEditorStoryboardBatchPromptSuffixHelper => '会拼接到每条分镜原提示词末尾。';

  @override
  String get scriptEditorStoryboardBatchNegativePromptLabel => '负面提示词（可选）';

  @override
  String get scriptEditorStoryboardBatchModelLabel => '模型（可选）';

  @override
  String get scriptEditorStoryboardBatchResolutionLabel => '分辨率（可选）';

  @override
  String get scriptEditorStoryboardBatchQuickGenerateHint =>
      '未手动选择分镜时，一键批量出图会自动挑出已具备可用提示词的分镜直接入队；只有预览和导出这类精确动作仍需要你明确选择。';

  @override
  String get scriptEditorStoryboardBatchNoResolvablePrompt => '无可用提示词';

  @override
  String get scriptEditorStoryboardBatchPreviewExportHeading => '预览与导出信息';

  @override
  String get scriptEditorStoryboardBatchSelectOneForPreview =>
      '选中 1 条分镜后可读取当前预览与下载链接。';

  @override
  String scriptEditorStoryboardBatchViewingShot(int id) {
    return '当前查看分镜 #$id';
  }

  @override
  String get scriptEditorStoryboardBatchExportEstimateHeading => '待导出包预估';

  @override
  String scriptEditorStoryboardBatchExportEstimateContent(
    int shotCount,
    String sidecar,
  ) {
    return '内容：$shotCount 张分镜图 + $sidecar';
  }

  @override
  String scriptEditorStoryboardBatchExportEstimateEntries(
    int entryCount,
    String durationLabel,
  ) {
    return '预计条目：$entryCount 个 · 总时长 $durationLabel';
  }

  @override
  String scriptEditorStoryboardBatchDownloadLinkLine(String url) {
    return '下载链接：$url';
  }

  @override
  String get scriptEditorStoryboardBatchLastExportHeading => '最近导出包';

  @override
  String scriptEditorStoryboardBatchExportFileLine(String filename) {
    return '文件：$filename';
  }

  @override
  String scriptEditorStoryboardBatchExportContentLine(
    int shotCount,
    String sidecar,
  ) {
    return '内容：$shotCount 张分镜图 + $sidecar';
  }

  @override
  String scriptEditorStoryboardBatchExportDetailWithSize(
    int entryCount,
    String durationLabel,
    String size,
  ) {
    return '预计条目：$entryCount 个 · 总时长 $durationLabel · 大小 $size';
  }

  @override
  String scriptEditorStoryboardBatchExportShotIds(String ids) {
    return '分镜 ID：$ids';
  }

  @override
  String get scriptEditorStoryboardBatchPreviewPlaceholder => '这里会显示当前分镜预览图。';

  @override
  String projectEditorScriptsSingleWorkbenchRecentExtractError(String reason) {
    return '最近提取错误：$reason';
  }

  @override
  String get projectEditorScriptsWorkbenchDialogTitle => '剧本批量工作台';

  @override
  String get projectEditorScriptsWorkbenchDialogNameFilterLabel => '剧本名称筛选';

  @override
  String get projectEditorScriptsWorkbenchDialogNameFilterHelper =>
      '读取 POST …/projects/<project id>/scripts/get-script-api 时按名称过滤，可留空读取全量上下文。';

  @override
  String get projectEditorScriptsWorkbenchDialogReadScriptContext => '读取剧本上下文';

  @override
  String get projectEditorScriptsWorkbenchDialogUseCurrentPreview => '使用当前预览';

  @override
  String get projectEditorScriptsWorkbenchDialogUseAllScripts => '使用全部剧本';

  @override
  String get projectEditorScriptsWorkbenchDialogReloadProjectScripts =>
      '刷新项目剧本';

  @override
  String get projectEditorScriptsWorkbenchDialogTargetScriptIdsLabel =>
      '目标剧本 numeric ID';

  @override
  String get projectEditorScriptsWorkbenchDialogTargetScriptIdsHelper =>
      '支持逗号、空格或换行分隔；批量导出、轮询和素材抽取都使用这里的列表。';

  @override
  String get projectEditorScriptsWorkbenchDialogExtractGroupSizeLabel =>
      '素材抽取 group size';

  @override
  String get projectEditorScriptsWorkbenchDialogExtractGroupSizeHelper =>
      '留空则沿用后端默认分组；设置后用于 extract-assets。';

  @override
  String get projectEditorScriptsWorkbenchDialogContextPreviewHeading =>
      '上下文预览';

  @override
  String get projectEditorScriptsWorkbenchDialogContextPreviewEmpty =>
      '暂无可预览剧本。';

  @override
  String projectEditorScriptsWorkbenchDialogPreviewRowBrief(
    int numericId,
    String name,
    int extractState,
  ) {
    return '#$numericId $name · 提取状态 $extractState';
  }

  @override
  String projectEditorScriptsWorkbenchDialogPreviewRowWithAssets(
    int numericId,
    String name,
    int extractState,
    String assets,
  ) {
    return '#$numericId $name · 提取状态 $extractState · 素材 $assets';
  }

  @override
  String get projectEditorScriptsWorkbenchDialogBatchCreate => '批量创建';

  @override
  String get projectEditorScriptsWorkbenchDialogClose => '关闭';

  @override
  String get projectEditorAssetSummaryProductionEmpty => 'production 资产数据为空';

  @override
  String projectEditorAssetSummaryProductionLine(
    int total,
    String typesLine,
    String sampleLine,
  ) {
    return 'production 资产 $total 条 · $typesLine · 示例：$sampleLine';
  }

  @override
  String projectEditorAssetSummaryTypeCount(String type, int count) {
    return '$type $count 条';
  }

  @override
  String get projectEditorAssetSummaryPollingEmpty => '未返回选中资产的图片状态';

  @override
  String projectEditorAssetSummaryPollingLine(
    int count,
    String stateLine,
    String sampleLine,
  ) {
    return '已轮询 $count 条资产 · $stateLine · 示例：$sampleLine';
  }

  @override
  String projectEditorAssetSummaryStateCount(String state, int count) {
    return '$state $count 条';
  }

  @override
  String projectEditorAssetSummaryImageCount(int assetId, int count) {
    return '#$assetId: $count 张';
  }

  @override
  String projectEditorAssetSummaryMaterialContext(
    int imageCount,
    int videoCount,
  ) {
    return '素材上下文 $imageCount 条图片素材 · $videoCount 条视频素材';
  }

  @override
  String get projectEditorAssetSummaryBatchEmpty => '批量候选为空';

  @override
  String projectEditorAssetSummaryBatchLine(
    int count,
    int total,
    String sampleLine,
  ) {
    return '批量候选 $count/$total 条 · 示例：$sampleLine';
  }

  @override
  String get projectEditorAssetSummaryPromptEmpty => '未返回 prompt 状态';

  @override
  String projectEditorAssetSummaryPromptLine(int count, String stateLine) {
    return 'prompt 轮询 $count 条 · $stateLine';
  }

  @override
  String get projectEditorAssetSummarySelectionNone => '当前未选择资产';

  @override
  String projectEditorAssetSummarySelectionSingle(int id, String name) {
    return '当前选择 #$id $name';
  }

  @override
  String projectEditorAssetSummarySelectionMultiple(int count, String sample) {
    return '当前选择 $count 条资产：$sample';
  }

  @override
  String get authSupabaseNotConfigured =>
      '未配置：运行示例\nflutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...';

  @override
  String get authSignIn => '登录';

  @override
  String get authSignUp => '注册';

  @override
  String get authSignOut => '退出';

  @override
  String authSignedInUser(String userId) {
    return '已登录 user: $userId';
  }

  @override
  String get authRequestInProgress => '请求中…';

  @override
  String get authGetMeBearer => 'GET /api/v1/me (Bearer)';

  @override
  String authMeResponse(String response) {
    return '/me: $response';
  }

  @override
  String get authDevSwitchProbe =>
      'GET+PUT /api/v1/settings/dev/switch-ai-tool';

  @override
  String authDevSwitchResponse(String response) {
    return 'dev switch: $response';
  }

  @override
  String get authMemoryConfigProbe =>
      'memory-config GET+POST + clear-agent-memories';

  @override
  String authMemoryConfigResponse(String response) {
    return 'memory-config: $response';
  }

  @override
  String get authAboutProbe =>
      'POST …/settings/about/check-update + download-app';

  @override
  String authAboutResponse(String response) {
    return 'about: $response';
  }

  @override
  String get authUsageSummary => 'GET /api/v1/usage/summary';

  @override
  String authUsageResponse(String response) {
    return 'usage: $response';
  }

  @override
  String get authPromptsProbe => 'GET /api/v1/prompts + GET/1 + PATCH/1';

  @override
  String authPromptsResponse(String response) {
    return 'prompts: $response';
  }

  @override
  String get authVisualManualProbe => 'GET+POST /api/v1/visual-manual';

  @override
  String authVisualManualResponse(String response) {
    return 'visual-manual: $response';
  }

  @override
  String get authDirectorManualProbe => 'POST …/project/query-director-manual';

  @override
  String authDirectorManualResponse(String response) {
    return 'director-manual: $response';
  }

  @override
  String get authSkillsBinaryProbe => 'GET /api/v1/skills/binary (_smoke PNG)';

  @override
  String authSkillsBinaryResponse(String response) {
    return 'skills/binary: $response';
  }

  @override
  String get authModelsCatalogProbe =>
      'models + vendors + vendor-add + danger + production + agent-deploy + model-test + script-agent + assets-gen';

  @override
  String get authTextModelDefaultProbe =>
      'GET+PATCH /api/v1/models/text-default';

  @override
  String get authModelDetailProbe =>
      'GET /api/v1/models/detail (1:gpt-4o-mini)';

  @override
  String authModelsResponse(String response) {
    return 'models: $response';
  }

  @override
  String authTextDefaultResponse(String response) {
    return 'text-default: $response';
  }

  @override
  String authModelDetailResponse(String response) {
    return 'model detail: $response';
  }

  @override
  String get shortVideoSpaceDialogExportProgressTitle => '导出进度';

  @override
  String get shortVideoSpaceDialogExportProgressStatusQueued => '排队中';

  @override
  String get shortVideoSpaceDialogExportProgressStatusProcessing => '处理中';

  @override
  String get shortVideoSpaceDialogExportProgressStatusCompleted => '已完成';

  @override
  String get shortVideoSpaceDialogExportProgressStatusFailed => '失败';

  @override
  String get shortVideoSpaceDialogExportProgressStatusCancelled => '已取消';

  @override
  String get shortVideoSpaceDialogExportProgressStageInitializing => '初始化';

  @override
  String get shortVideoSpaceDialogExportProgressStageLoadingAssets => '加载素材';

  @override
  String get shortVideoSpaceDialogExportProgressStageEncoding => '编码视频';

  @override
  String get shortVideoSpaceDialogExportProgressStageUploading => '上传文件';

  @override
  String get shortVideoSpaceDialogExportProgressStageFinalizing => '完成处理';

  @override
  String get shortVideoSpaceDialogExportProgressLoadingStatus => '正在获取导出状态...';

  @override
  String shortVideoSpaceDialogExportProgressFetchError(String error) {
    return '获取进度失败: $error';
  }

  @override
  String get shortVideoSpaceDialogExportProgressSessionExpired => '会话已失效，请重新登录';

  @override
  String shortVideoSpaceDialogExportProgressCancelFailed(String error) {
    return '取消失败: $error';
  }

  @override
  String shortVideoSpaceDialogExportProgressTaskId(String taskId) {
    return '任务 ID: $taskId';
  }

  @override
  String get shortVideoSpaceDialogExportProgressCancelButton => '取消导出';

  @override
  String get shortVideoSpaceDialogExportProgressCloseButton => '关闭';

  @override
  String get shortVideoSpaceDialogExportProgressMessageQueued =>
      '导出任务已加入队列，等待处理...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageInitializing =>
      '正在初始化导出任务...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageLoadingAssets =>
      '正在加载视频素材和音频文件...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageEncoding =>
      '正在编码视频，这可能需要几分钟...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageUploading =>
      '正在上传导出的视频文件...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageFinalizing =>
      '正在完成最后的处理步骤...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageProcessing =>
      '正在处理导出任务...';

  @override
  String get shortVideoSpaceDialogExportProgressMessageCompleted =>
      '导出成功完成！视频已准备好下载。';

  @override
  String get shortVideoSpaceDialogExportProgressMessageFailed =>
      '导出失败，请重试或联系支持。';

  @override
  String get shortVideoSpaceDialogExportProgressMessageCancelled => '导出已被取消。';

  @override
  String get shortVideoSpaceDialogConfirmDeleteVersionTitle => '确认删除';

  @override
  String shortVideoSpaceDialogConfirmDeleteVersionMessage(String versionName) {
    return '确定要删除版本 \"$versionName\" 吗？\n\n此操作无法撤销。';
  }

  @override
  String get shortVideoSpaceDialogConfirmDeleteVersionDontShow => '不再提示';

  @override
  String get shortVideoSpaceDialogConfirmDeleteVersionCancel => '取消';

  @override
  String get shortVideoSpaceDialogConfirmDeleteVersionConfirm => '删除';

  @override
  String get shortVideoSpaceDialogConfirmBatchDisableTitle => '确认批量禁用';

  @override
  String shortVideoSpaceDialogConfirmBatchDisableMessage(int shotCount) {
    return '确定要禁用选中的 $shotCount 个镜头吗？\n\n禁用后的镜头将不会出现在最终视频中。';
  }

  @override
  String get shortVideoSpaceDialogConfirmBatchDisableConfirm => '确认禁用';

  @override
  String get shortVideoSpaceDialogConfirmRestoreDraftTitle => '确认恢复草稿';

  @override
  String shortVideoSpaceDialogConfirmRestoreDraftMessage(String draftName) {
    return '确定要恢复草稿 \"$draftName\" 吗？\n\n当前未保存的编辑状态将会丢失。';
  }

  @override
  String get shortVideoSpaceDialogConfirmRestoreDraftConfirm => '恢复';

  @override
  String get shortVideoSpaceDialogConfirmCancelExportTitle => '取消导出';

  @override
  String get shortVideoSpaceDialogConfirmCancelExportMessage =>
      '确定要取消导出吗？已处理的内容将会丢失。';

  @override
  String get shortVideoSpaceDialogConfirmCancelExportContinue => '继续导出';

  @override
  String get shortVideoSpaceDialogConfirmCancelExportConfirm => '确认取消';

  @override
  String get shortVideoSpaceDialogConfirmBatchArchiveTitle => '批量归档确认';

  @override
  String shortVideoSpaceDialogConfirmBatchArchiveMessage(int draftCount) {
    return '确定要归档 $draftCount 张发布草稿吗？归档后将从待发布队列中移除（视后端策略可能可恢复）。';
  }

  @override
  String get shortVideoSpaceDialogConfirmBatchArchiveConfirm => '确认归档';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsTitle => '配音参数设置';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsProviderLabel => 'TTS 供应商';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsProviderOpenAI =>
      'OpenAI TTS';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsProviderAzure => 'Azure TTS';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsProviderGoogle =>
      'Google TTS';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceLabel => '声线';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceAlloy => 'Alloy (中性)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceEcho => 'Echo (男性)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceFable => 'Fable (英式)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceOnyx => 'Onyx (深沉)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceNova => 'Nova (女性)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsVoiceShimmer =>
      'Shimmer (柔和)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionLabel => '情绪';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionNeutral =>
      '中性 (Neutral)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionHappy => '愉悦 (Happy)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionSad => '悲伤 (Sad)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsEmotionAngry => '愤怒 (Angry)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsSpeedLabel => '语速';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsSpeedRange =>
      '调整范围：0.5x (慢速) - 2.0x (快速)';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsInfoMessage =>
      '保存后将应用到新生成的配音。已生成的配音需要重新生成才能应用新参数。';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsCancel => '取消';

  @override
  String get shortVideoSpaceDialogVoiceoverSettingsSave => '保存';

  @override
  String get shortVideoSpacePublishQualityStageUnlabeled => '未标注阶段';

  @override
  String get shortVideoSpacePublishQualityStageStorySkeleton => '故事骨架';

  @override
  String get shortVideoSpacePublishQualityStageAdaptationStrategy => '改编策略';

  @override
  String get shortVideoSpacePublishQualityStageDirectorPlanning => '导演规划';

  @override
  String get shortVideoSpacePublishQualityStageStoryboardTable => '分镜表';

  @override
  String get shortVideoSpacePublishQualityStageStoryboardPanel => '分镜面板';

  @override
  String get shortVideoSpacePublishQualityStageVideoPrompt => '视频提示 / 成片';

  @override
  String get shortVideoSpacePublishExportIssueCandidatePending => '候选待确认';

  @override
  String get shortVideoSpacePublishExportIssueMissingSelectedMedia => '未选成片媒体';

  @override
  String get shortVideoSpacePublishExportIssueSelectedMediaNotVideo =>
      '所选媒体非视频';

  @override
  String get shortVideoSpacePublishExportIssueSubtitlePlaceholder =>
      '字幕 / 口播文案缺失';

  @override
  String get shortVideoSpacePublishExportIssueSubtitleEmpty => '字幕为空';

  @override
  String get shortVideoSpacePublishExportIssueVoiceoverFailed => '旁白生成失败';

  @override
  String get shortVideoSpacePublishExportIssueVoiceoverAudioMissing =>
      '旁白音频未就绪';

  @override
  String get shortVideoSpacePublishExportIssueVoiceoverNotReady => '配音未就绪';

  @override
  String get shortVideoSpacePublishExportIssueDurationNotExplicit =>
      '时长未标明（导出默认）';

  @override
  String get shortVideoSpacePublishExportIssueDurationNotSet => '时长未设定';

  @override
  String get shortVideoSpacePublishExportIssueDurationUnparsable => '时长格式异常';

  @override
  String get shortVideoSpacePublishExportIssueCompletionUncertain =>
      '成片状态未标「已完成」';

  @override
  String get shortVideoSpacePublishAssemblyLoadingHeadline => '正在读取成片装配快照…';

  @override
  String get shortVideoSpacePublishAssemblyLoadingDetail =>
      '数据来自 GET …/short-video-assembly（按剧本顺序汇总分镜与成片要素）。';

  @override
  String get shortVideoSpacePublishAssemblyUnavailableHeadline => '成片装配快照暂不可用。';

  @override
  String get shortVideoSpacePublishAssemblyUnavailableDetail =>
      '可稍后刷新，或在制作工作区确认分镜与时间线后再试。';

  @override
  String get shortVideoSpacePublishAssemblyNoScriptsHeadline =>
      '当前尚无剧本 / 分镜装配数据。';

  @override
  String shortVideoSpacePublishAssemblyHeadlineScripts(
    int count,
    int shots,
    int seconds,
    String formatted,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个剧本',
      one: '1 个剧本',
    );
    return '$_temp0 · $shots 条分镜（导出路径快照）\n成片总时长：$seconds秒 ($formatted)';
  }

  @override
  String get shortVideoSpacePublishAssemblyVoiceProfileNotSet => '配音档案：未写';

  @override
  String shortVideoSpacePublishAssemblyVoiceProfile(String profile) {
    return '配音档案：$profile';
  }

  @override
  String get shortVideoSpacePublishAssemblySubtitleDefault => '字幕：默认';

  @override
  String shortVideoSpacePublishAssemblySubtitle(String style) {
    return '字幕：$style';
  }

  @override
  String get shortVideoSpacePublishAssemblyBgmNotSpecified => 'BGM：未指定';

  @override
  String shortVideoSpacePublishAssemblyBgm(String strategy) {
    return 'BGM：$strategy';
  }

  @override
  String shortVideoSpacePublishAssemblyEffectiveTts(String voice) {
    return '生效 TTS（入队/worker）：$voice';
  }

  @override
  String shortVideoSpacePublishAssemblyScriptTitle(int id) {
    return '剧本 #$id';
  }

  @override
  String shortVideoSpacePublishAssemblyScriptTitleNamed(int id, String name) {
    return '剧本 #$id · $name';
  }

  @override
  String shortVideoSpacePublishAssemblyScriptSummary(
    String title,
    int shots,
    int withMedia,
    int voReady,
  ) {
    return '$title · $shots 镜 · 已选成片 $withMedia · 旁白就绪 $voReady';
  }

  @override
  String get shortVideoSpacePublishAssemblyShotPreviewYes => '预览✓';

  @override
  String get shortVideoSpacePublishAssemblyShotPreviewNo => '预览×';

  @override
  String get shortVideoSpacePublishAssemblyShotDurationUnknown => '时长?';

  @override
  String get shortVideoSpacePublishAssemblyShotSubtitleYes => '字幕✓';

  @override
  String get shortVideoSpacePublishAssemblyShotSubtitleNo => '字幕×';

  @override
  String get shortVideoSpacePublishAssemblyShotVoiceoverYes => '旁白✓';

  @override
  String get shortVideoSpacePublishAssemblyShotVoiceoverNo => '旁白×';

  @override
  String get shortVideoSpacePublishAssemblyShotBgmDefault => '默认';

  @override
  String shortVideoSpacePublishAssemblyShotDetail(
    String order,
    String preview,
    String duration,
    String subtitle,
    String voiceover,
    String bgm,
  ) {
    return '镜头[$order] · $preview · $duration · $subtitle · $voiceover · BGM $bgm';
  }

  @override
  String shortVideoSpacePublishAssemblyMoreShots(int count) {
    return '…其余 $count 镜请在制作工作区时间线查看';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityProjectBadCase(int count) {
    return '项目级待验收坏例：$count（与生产概览同源）';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityAssemblyReviews(
    int total,
    int badCase,
    int shots,
  ) {
    return '当前装配分镜上的评审：$total 条 · 坏例 $badCase · 涉及分镜 $shots';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityLateStageBadCase(int count) {
    return '贴近成片阶段坏例（分镜面板/视频提示）：$count';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityByStage(String stages) {
    return '按阶段：$stages';
  }

  @override
  String shortVideoSpacePublishAssemblyQualityStageBadCase(
    String stage,
    int count,
  ) {
    return '$stage · 坏例 $count';
  }

  @override
  String get shortVideoSpacePublishAssemblyQualityTaskCenterHint =>
      '在任务中心侧可按项目筛选质量评审列表，分镜级 target 与装配一致。';

  @override
  String shortVideoSpacePublishAssemblyMultiTrackEstimate(
    int subtitle,
    int voiceover,
    int bgm,
    int total,
  ) {
    return '轨道占用估算：视频 1 + 字幕 $subtitle + 旁白 $voiceover + BGM $bgm = $total 轨。';
  }

  @override
  String shortVideoSpacePublishAssemblyMaterialReady(
    int video,
    int subtitle,
    int voiceover,
    int totalShots,
  ) {
    return '素材就绪：视频镜头 $video/$totalShots，字幕镜头 $subtitle/$totalShots，旁白镜头 $voiceover/$totalShots。';
  }

  @override
  String shortVideoSpacePublishAssemblyDurationEstimate(
    int known,
    int total,
    String minutes,
  ) {
    return '时长估算：已识别 $known/$total 镜，总时长约 $minutes 分钟。';
  }

  @override
  String get shortVideoSpacePublishAssemblyExportDecisionProfessional =>
      '导出决策：当前超出受限多轨边界（>4 轨或时长复杂），建议转专业台（需求 8.2）处理。';

  @override
  String get shortVideoSpacePublishAssemblyExportDecisionLimited =>
      '导出决策：维持受限多轨（<=4 轨）路径，可继续在当前链路导出。';

  @override
  String get shortVideoSpacePublishAssemblyBoundaryNote =>
      '边界说明：Space 仅覆盖\"视频 + 单字幕轨 + 旁白 + BGM\"受限混排，不替代专业 NLE。';

  @override
  String get shortVideoSpacePublishAssemblyDetail =>
      '只读剪辑台：展示镜头顺序、时长、字幕、旁白、BGM 与预览就绪摘要；导出阻塞结论见下方「导出前检查」。';

  @override
  String get shortVideoSpacePublishExportCheckLoadingHeadline => '正在读取导出前检查…';

  @override
  String get shortVideoSpacePublishExportCheckLoadingDetail =>
      '聚合分镜阻塞与提醒；质量门禁观测字段仅占位展示。';

  @override
  String get shortVideoSpacePublishExportCheckUnavailableHeadline =>
      '导出前检查暂不可用。';

  @override
  String get shortVideoSpacePublishExportCheckUnavailableDetail =>
      '可稍后刷新页面，或在制作工作区确认分镜后再试。';

  @override
  String get shortVideoSpacePublishExportCheckReadyHeadline =>
      '服务端未发现阻塞级问题（仍需在制作侧确认成片）。';

  @override
  String get shortVideoSpacePublishExportCheckBlockingHeadline =>
      '存在阻塞项：建议先在制作工作区补齐后再导出 / 成片。';

  @override
  String get shortVideoSpacePublishExportCheckMetricStoryboards => '分镜';

  @override
  String get shortVideoSpacePublishExportCheckMetricBlocking => '阻塞';

  @override
  String get shortVideoSpacePublishExportCheckMetricWarning => '提醒';

  @override
  String get shortVideoSpacePublishExportCheckMetricExportable => '可导出';

  @override
  String get shortVideoSpacePublishExportCheckMetricYes => '是';

  @override
  String get shortVideoSpacePublishExportCheckMetricNo => '否';

  @override
  String get shortVideoSpacePublishExportCheckQualityGateOff =>
      '质量门禁：已关闭（不检查质量问题）。';

  @override
  String get shortVideoSpacePublishExportCheckQualityGateWarnNoBadCase =>
      '质量门禁：警告模式 - 暂无待复核坏例（允许导出）。';

  @override
  String shortVideoSpacePublishExportCheckQualityGateWarnWithBadCase(
    int count,
  ) {
    return '质量门禁：警告模式 - 待复核坏例 $count 条（允许导出但建议修复）。';
  }

  @override
  String shortVideoSpacePublishExportCheckQualityGateBlockEnforcedWithBadCase(
    int count,
  ) {
    return '质量门禁：阻断模式 - 待复核坏例 $count 条（阻止导出，需先修复）。';
  }

  @override
  String
  shortVideoSpacePublishExportCheckQualityGateBlockNotEnforcedWithBadCase(
    int count,
  ) {
    return '质量门禁：阻断模式 - 待复核坏例 $count 条（暂未强制执行）。';
  }

  @override
  String get shortVideoSpacePublishExportCheckQualityGateBlockNoBadCase =>
      '质量门禁：阻断模式 - 暂无待复核坏例（允许导出）。';

  @override
  String shortVideoSpacePublishExportCheckQualityGateUnknown(String strategy) {
    return '质量门禁：未知策略 \"$strategy\"。';
  }

  @override
  String shortVideoSpacePublishExportCheckBlockingIssue(
    int scriptId,
    int sbId,
    String sbIndex,
    String label,
    String detail,
  ) {
    return '剧本 #$scriptId · 分镜 #$sbId$sbIndex · $label · $detail';
  }

  @override
  String get shortVideoSpacePublishExportCheckDetailReady =>
      '阻塞计数为 0 时表示服务端聚合路径上暂无硬阻塞（仍以实际导出管线为准）。';

  @override
  String get shortVideoSpacePublishExportCheckDetailBlocking =>
      '下方列出部分阻塞项；完整列表请在制作工作区逐镜核对。';

  @override
  String get shortVideoSpacePublishCandidateLoadingHeadline => '正在读取项目资产…';

  @override
  String get shortVideoSpacePublishCandidateLoadingDetail =>
      '用于统计候选 workflow：pending / linked / ignored（与 PATCH 资产一致）。';

  @override
  String get shortVideoSpacePublishCandidateUnavailableHeadline =>
      '候选资产摘要暂不可用。';

  @override
  String get shortVideoSpacePublishCandidateUnavailableDetail =>
      '可稍后刷新页面，或直接去项目区查看并编辑资产。';

  @override
  String get shortVideoSpacePublishCandidateNoTrackedHeadline =>
      '尚未标记 pending / linked / ignored；可在项目区对镜头候选等资产 PATCH candidate_status。';

  @override
  String get shortVideoSpacePublishCandidateTrackedHeadline =>
      '候选状态已按项目全量聚合（下方计数含未标记）：';

  @override
  String shortVideoSpacePublishCandidateDetail(int total) {
    return '项目资产共 $total 条；计数由服务端一次性聚合（不分页）。在项目区可通过 PATCH candidate_status 更新。';
  }

  @override
  String get shortVideoSpacePublishPanelLoadingHeadline => '正在读取导出检查与发布域…';

  @override
  String get shortVideoSpacePublishPanelLoadingDetail =>
      '后端路径：`/api/v1/projects/:id/publish/*`（profiles / drafts / jobs）。';

  @override
  String get shortVideoSpacePublishPanelUnavailableHeadline =>
      '发布域接口暂不可用（可能尚未执行数据库迁移）。';

  @override
  String get shortVideoSpacePublishPanelUnavailableExportGateMissing =>
      '导出检查数据缺失，发布面板仅提示占位。';

  @override
  String get shortVideoSpacePublishPanelUnavailableExportGateNoBlocking =>
      '导出检查：当前无阻塞项。';

  @override
  String shortVideoSpacePublishPanelUnavailableExportGateBlocking(int count) {
    return '导出检查：仍有 $count 条阻塞项。';
  }

  @override
  String get shortVideoSpacePublishPanelUnavailableDetail =>
      '确认 Supabase 已应用 `app_publish_*` 迁移后再试；Rust worker 会在后台消化发布作业队列。';

  @override
  String get shortVideoSpacePublishPanelExportGateUnavailable =>
      '导出检查数据暂不可用；仍可试着创建发布草稿并校验。';

  @override
  String get shortVideoSpacePublishPanelExportGateReady =>
      '导出检查：无阻塞项（**E13**：可从成片链路进入发布准备）。';

  @override
  String shortVideoSpacePublishPanelExportGateBlocking(int count) {
    return '导出检查：仍有 $count 条阻塞项；可先补齐字段再投递作业。';
  }

  @override
  String shortVideoSpacePublishPanelHeadline(int drafts, int jobs) {
    return '已连接发布 API：$drafts 张草稿 · $jobs 条作业。';
  }

  @override
  String shortVideoSpacePublishPanelCurrentDraft(String title) {
    return '当前草稿：$title';
  }

  @override
  String get shortVideoSpacePublishPanelCurrentDraftUntitled => '当前草稿：（无标题）';

  @override
  String get shortVideoSpacePublishPanelSelectDraftWarning =>
      '⚠️ 请明确选择草稿（不再自动使用第一条）';

  @override
  String get shortVideoSpacePublishPanelPrepareCheckOk =>
      '校验：✓ 当前草稿满足占位规则（仍需真实成片引用才能实际上线）。';

  @override
  String get shortVideoSpacePublishPanelPrepareCheckMultipleDrafts =>
      '多张草稿时请先在「当前操作草稿」中选择一张，再显示 prepare-check。';

  @override
  String get shortVideoSpacePublishPanelPrepareCheckSelectFirst =>
      '选择草稿后将显示 prepare-check 校验结果。';

  @override
  String get shortVideoSpacePublishPanelPrepareCheckNoDraft =>
      '尚无草稿或未完成 prepare-check。';

  @override
  String get shortVideoSpacePublishPanelDraftNoTitle => '（无标题）';

  @override
  String get shortVideoSpacePublishPanelDraftMissingVideo => ' · 缺 video 引用';

  @override
  String shortVideoSpacePublishPanelDraftScheduled(String time) {
    return ' · 定时 $time';
  }

  @override
  String shortVideoSpacePublishPanelJobShortId(String id) {
    return '$id…';
  }

  @override
  String shortVideoSpacePublishPanelJobError(String error) {
    return ' · $error';
  }

  @override
  String shortVideoSpacePublishPanelOverviewSucceeded(int count) {
    return '成功作业：$count';
  }

  @override
  String shortVideoSpacePublishPanelOverviewFailed(int count) {
    return '失败/部分失败：$count';
  }

  @override
  String shortVideoSpacePublishPanelOverviewAwaiting(int count) {
    return '待确认：$count';
  }

  @override
  String shortVideoSpacePublishPanelOverviewScheduled(
    int scheduled,
    int total,
  ) {
    return '已定时草稿：$scheduled/$total';
  }

  @override
  String shortVideoSpacePublishPanelOverviewDeliveryModes(String modes) {
    return '投递模式：$modes';
  }

  @override
  String shortVideoSpacePublishPanelOverviewPerformanceAlerts(int count) {
    return '低表现预警：$count 条（建议进入任务中心排障并改写文案）';
  }

  @override
  String shortVideoSpacePublishPanelOverviewPerformanceAlert(
    String platform,
    int views,
    String rate,
  ) {
    return '$platform · 播放 $views · 完播 $rate%';
  }

  @override
  String shortVideoSpacePublishPanelOverviewAudit(
    String platform,
    String status,
    String mode,
  ) {
    return '审计：$platform · $status · mode=$mode';
  }

  @override
  String shortVideoSpacePublishPanelOverviewTargetAutomation(String modes) {
    return '目标自动化：$modes';
  }

  @override
  String get shortVideoSpacePublishPanelDetail =>
      '半自动作业在 `awaiting_confirmation` 时需点「确认」；worker 骨架会写入 `publish_attempts` 占位成功记录。';

  @override
  String get shortVideoSpaceProductionAssemblyExportCompleted =>
      'Export completed.';

  @override
  String get shortVideoSpaceProductionAssemblyExportNotCompleted =>
      'Export not completed or cancelled.';

  @override
  String shortVideoSpaceProductionAssemblyExportStartFailed(String error) {
    return 'Export start failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyReplaceVideoTitle =>
      'Replace current video version';

  @override
  String get shortVideoSpaceProductionAssemblyVideoUrlLabel => 'Video URL';

  @override
  String get shortVideoSpaceProductionAssemblyVideoUrlHint => 'https://...';

  @override
  String get shortVideoSpaceProductionAssemblyCancel => 'Cancel';

  @override
  String get shortVideoSpaceProductionAssemblyWriteBackVersion =>
      'Write back current version';

  @override
  String shortVideoSpaceProductionAssemblyShotDisabled(int storyboardId) {
    return 'Shot #$storyboardId paused (cleared current video).';
  }

  @override
  String shortVideoSpaceProductionAssemblyDisableFailed(String error) {
    return 'Pause failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyNoVideoUrl =>
      'No available video URL, please enter replacement address first.';

  @override
  String shortVideoSpaceProductionAssemblyShotWriteBack(int storyboardId) {
    return 'Shot #$storyboardId wrote back current video version.';
  }

  @override
  String shortVideoSpaceProductionAssemblyWriteBackFailed(String error) {
    return 'Write back failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyReorderPersisted =>
      'Persisted shot reorder (wrote back timeline and shot numbers by script).';

  @override
  String shortVideoSpaceProductionAssemblyReorderFailed(String error) {
    return 'Reorder persistence failed: $error';
  }

  @override
  String shortVideoSpaceProductionAssemblyShotAligned(
    int storyboardId,
    int duration,
  ) {
    return 'Shot #$storyboardId aligned to ${duration}s.';
  }

  @override
  String shortVideoSpaceProductionAssemblyAlignFailed(String error) {
    return 'Duration alignment failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblySubtitleExistsDurationMissing =>
      'Subtitle exists, but duration not explicit (suggest aligning duration first).';

  @override
  String get shortVideoSpaceProductionAssemblyDurationSetSubtitleEmpty =>
      'Duration is set, but subtitle is empty (possible subtitle track gap).';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleExistsDurationAbnormal =>
      'Subtitle exists, but duration is abnormal (<=0).';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleDurationNoMismatch =>
      'No obvious subtitle-duration mismatch.';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsTitle =>
      'Basic shot operations';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsDescription =>
      'Supports basic reordering (this panel view), enable/disable, and replace current video version.';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsNote =>
      'Enable/disable/replace writes back directly to J media slot; reorder is for this troubleshooting view only.';

  @override
  String shortVideoSpaceProductionAssemblyTotalDuration(
    int seconds,
    String formatted,
  ) {
    return 'Total finished duration: ${seconds}s ($formatted)';
  }

  @override
  String get shortVideoSpaceProductionAssemblySaveReorder => 'Save reorder';

  @override
  String get shortVideoSpaceProductionAssemblyUndoToOpen => 'Undo to open time';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverTasks =>
      'Voiceover tasks';

  @override
  String get shortVideoSpaceProductionAssemblyClose => 'Close';

  @override
  String get shortVideoSpaceProductionAssemblyNoShotsFiltered =>
      'No shots under current filter conditions, try clearing search or relaxing criteria.';

  @override
  String shortVideoSpaceProductionAssemblyScriptShotOrder(
    int scriptId,
    int storyboardId,
    int order,
  ) {
    return 'Script #$scriptId · Shot #$storyboardId · Order $order';
  }

  @override
  String get shortVideoSpaceProductionAssemblyStatusPaused => 'Status: Paused';

  @override
  String shortVideoSpaceProductionAssemblyStatusEnabled(String kind) {
    return 'Status: Enabled ($kind)';
  }

  @override
  String get shortVideoSpaceProductionAssemblyDurationLabel => 'Duration:';

  @override
  String get shortVideoSpaceProductionAssemblyDurationNotSet => 'Not set';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleLabel => 'Subtitle:';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleEmpty => 'Empty';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverScriptReady =>
      'Voiceover script: ✓ Ready';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverScriptNotReady =>
      'Voiceover script: ✗ Not ready';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAssetReady =>
      'Voiceover asset: ✓ Ready';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAssetNotReady =>
      'Voiceover asset: ✗ Not ready';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverStatusLabel =>
      'Voiceover status:';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAudioLabel =>
      'Voiceover audio:';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverErrorLabel =>
      'Voiceover error:';

  @override
  String get shortVideoSpaceProductionAssemblyMismatchCheckLabel =>
      'Mismatch check:';

  @override
  String get shortVideoSpaceProductionAssemblyMoveUp => 'Move up';

  @override
  String get shortVideoSpaceProductionAssemblyMoveDown => 'Move down';

  @override
  String get shortVideoSpaceProductionAssemblyEnable => 'Enable';

  @override
  String get shortVideoSpaceProductionAssemblyPause => 'Pause';

  @override
  String get shortVideoSpaceProductionAssemblyAlignDuration => 'Align duration';

  @override
  String get shortVideoSpaceProductionAssemblyReplaceVersion =>
      'Replace current version';

  @override
  String get shortVideoSpaceProductionAssemblyGenerateVoiceover =>
      'Generate voiceover';

  @override
  String get shortVideoSpaceProductionAssemblyPreviewVoiceover =>
      'Preview voiceover';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationTitle =>
      'Single shot duration alignment';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationLabel =>
      'Duration (seconds)';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationHint =>
      'Enter 1~300';

  @override
  String get shortVideoSpaceProductionAssemblyAlignAndWriteBack =>
      'Align and write back';

  @override
  String get shortVideoSpaceProductionAssemblyAssemblyStyleTitle =>
      'Assembly-level style adjustment';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleStyleLabel =>
      'Subtitle style subtitle_style';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleStyleHint =>
      'e.g. cinematic_cn_v2 (leave empty to fall back to default)';

  @override
  String get shortVideoSpaceProductionAssemblyBgmStrategyLabel =>
      'BGM strategy bgm_strategy';

  @override
  String get shortVideoSpaceProductionAssemblyBgmStrategyHint =>
      'e.g. pulse_light (leave empty to fall back to default)';

  @override
  String get shortVideoSpaceProductionAssemblyStyleNote =>
      'After saving, will write back D7 default configuration and refresh effective values in assembly snapshot.';

  @override
  String get shortVideoSpaceProductionAssemblySaveAndRefresh =>
      'Save and refresh';

  @override
  String shortVideoSpaceProductionAssemblyStyleUpdated(
    String subtitle,
    String bgm,
  ) {
    return 'Updated assembly-level defaults: subtitle $subtitle · BGM $bgm';
  }

  @override
  String get shortVideoSpaceProductionAssemblyStyleDefault => 'default';

  @override
  String shortVideoSpaceProductionAssemblyStyleWriteBackFailed(String error) {
    return 'Assembly style write back failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverTaskCenterTitle =>
      'Voiceover task center';

  @override
  String get shortVideoSpaceProductionAssemblyAllStatus => 'All status';

  @override
  String get shortVideoSpaceProductionAssemblyRefresh => 'Refresh';

  @override
  String get shortVideoSpaceProductionAssemblyGroupByShot => 'Group by shot';

  @override
  String shortVideoSpaceProductionAssemblyBatchRetryFailed(int count) {
    return 'Batch retry failed ($count)';
  }

  @override
  String get shortVideoSpaceProductionAssemblyFilterTaskIdScriptShot =>
      'Filter: Task ID / Script # / Shot #';

  @override
  String shortVideoSpaceProductionAssemblyTaskSummary(
    int total,
    int queued,
    int running,
    int succeeded,
    int failed,
    int cancelled,
    int filtered,
    int visible,
  ) {
    return 'Total $total · queued $queued · running $running · succeeded $succeeded · failed $failed · cancelled $cancelled · Showing $filtered/$visible';
  }

  @override
  String get shortVideoSpaceProductionAssemblyNoVoiceoverTasks =>
      'No voiceover tasks yet';

  @override
  String shortVideoSpaceProductionAssemblyTaskEntry(
    String prefix,
    String taskId,
    String status,
  ) {
    return '$prefix $taskId · Status $status';
  }

  @override
  String get shortVideoSpaceProductionAssemblyLatestTask => 'Latest task';

  @override
  String get shortVideoSpaceProductionAssemblyTask => 'Task';

  @override
  String shortVideoSpaceProductionAssemblyTaskSubtitle(
    String scriptId,
    String shotId,
    String audio,
    String error,
  ) {
    return 'Script #$scriptId · Shot #$shotId$audio$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyTaskSubtitleAudioReady =>
      ' · Audio ready';

  @override
  String shortVideoSpaceProductionAssemblyTaskSubtitleError(String error) {
    return ' · Error: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyPreviewAudio => 'Preview audio';

  @override
  String get shortVideoSpaceProductionAssemblyCopyAudioLink =>
      'Copy audio link';

  @override
  String get shortVideoSpaceProductionAssemblyAudioLinkCopied =>
      'Audio link copied';

  @override
  String get shortVideoSpaceProductionAssemblyCancelTask => 'Cancel';

  @override
  String shortVideoSpaceProductionAssemblyTaskCancelled(String taskId) {
    return 'Cancelled voiceover task $taskId';
  }

  @override
  String shortVideoSpaceProductionAssemblyCancelFailed(String error) {
    return 'Cancel failed: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyRetryTask => 'Retry';

  @override
  String shortVideoSpaceProductionAssemblyTaskRetried(String taskId) {
    return 'Retried, task $taskId queued';
  }

  @override
  String shortVideoSpaceProductionAssemblyRetryFailed(String error) {
    return 'Retry failed: $error';
  }

  @override
  String shortVideoSpaceProductionAssemblyBatchRetryCompleted(
    int succeeded,
    int failed,
  ) {
    return 'Batch retry completed: succeeded $succeeded, failed $failed';
  }

  @override
  String shortVideoSpaceProductionAssemblyLoadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String get accountSectionTitle => '账户与隐私';

  @override
  String get accountRiskyPrefsTooltip => '本机客户端偏好（删号、导出等「不再提示」与恢复确认）';

  @override
  String get accountSectionSubtitle =>
      '统一管理账户数据导出、下载留档和不可逆删号。导出任务会走平台 job 队列，可反复生成新版快照。';

  @override
  String get accountExportTitle => '数据导出';

  @override
  String get accountExportCreate => '创建导出包';

  @override
  String get accountExportIncludeAuditLogs => '包含审计日志';

  @override
  String get accountExportIncludeNotifications => '包含通知记录';

  @override
  String get accountExportActiveCount => '包含通知记录';

  @override
  String get accountExportCopyLastSavedPath => '复制最近保存路径';

  @override
  String get accountExportEmpty => '还没有账户导出记录。';

  @override
  String get accountExportDefaultFileName => '账户导出 #...';

  @override
  String get accountExportTaskLine => '任务 #... · ...';

  @override
  String get accountExportSizeLine => '大小 ...';

  @override
  String get accountExportSavedSnack => '已保存导出包：\$path';

  @override
  String get accountExportDownload => '下载到本机';

  @override
  String get accountExportCopyFileName => '复制文件名';

  @override
  String get accountDeleteTitle => '删除账号';

  @override
  String get accountDeleteDescription =>
      '删号会删除当前用户、其 owner workspace、个人项目、任务、通知和本地导出/媒体目录。共享 workspace 中的成员关系也会移除。';

  @override
  String get accountDeleteConfirmLabel => '输入 DELETE MY ACCOUNT 以确认';

  @override
  String get accountDeleteIrreversibleAck =>
      '我确认这是不可逆操作，并接受相关 workspace / project 级联删除。';

  @override
  String get accountDeleteLastResponse => 'job ...';

  @override
  String get accountDeleteButton => '永久删除当前账号';

  @override
  String get accountExportStatusQueued => '生成中';

  @override
  String get accountExportStatusRunning => '可下载';

  @override
  String get accountExportStatusSucceeded => '可下载';

  @override
  String get accountExportStatusFailed => '可下载';

  @override
  String get adminConsoleMembershipItem => '...';

  @override
  String get adminConsoleRecentJobItem => '... · ... · project ...';

  @override
  String get adminConsoleAuditListItem => '... · ... · ...';

  @override
  String get adminConsoleDailyQuotaLabel => 'dailyJobQuota';

  @override
  String get adminConsoleChipMember => 'archived';

  @override
  String get adminConsoleArchivedLabel => 'archived';

  @override
  String get adminConsoleMemberListItem => '... · ... · joined ...';

  @override
  String get adminConsoleRecentProjectItem => '#... ...';

  @override
  String get adminConsoleChipScript => 'active job ...';

  @override
  String get adminConsoleChipAsset => 'active job ...';

  @override
  String get adminConsoleChipJob => 'active job ...';

  @override
  String get adminConsoleAclMemberItem =>
      '... · workspace ... · project ... · ...';

  @override
  String get adminConsoleWorkspaceCandidateItem => '... · ... · explicit ...';

  @override
  String get adminConsoleProjectRecentJobItem => '... · ... · ... · ...';

  @override
  String get adminConsoleAuditUserSummary => 'status=\$nextStatus · quota=...';

  @override
  String get adminConsoleAuditWorkspaceMembership =>
      'action=\$action · user=...';

  @override
  String get adminConsoleAuditOwnerTransfer => 'owner=...';

  @override
  String get adminConsoleAuditArchiveNote =>
      'archivedAt=\$nextArchived · opsNote=...';

  @override
  String get adminConsoleAuditProjectOwnerTransfer => 'owner=...';

  @override
  String get adminConsoleFieldUserId =>
      'archivedAt=\$nextArchived · opsNote=...';

  @override
  String get adminConsoleFieldCreatedAt => 'admin console field created at';

  @override
  String get adminConsoleFieldUpdatedAt => 'admin console field updated at';

  @override
  String get adminConsoleFieldOperationalStatus =>
      'admin console field operational status';

  @override
  String get adminConsoleFieldBillingProvider =>
      'admin console field billing provider';

  @override
  String get adminConsoleFieldSubscription =>
      'admin console field subscription';

  @override
  String get adminConsoleFieldCurrentWorkspace =>
      'admin console field current workspace';

  @override
  String get adminConsoleFieldWorkspaceId => 'admin console field workspace id';

  @override
  String get adminConsoleFieldOwner => 'admin console field owner';

  @override
  String get adminConsoleFieldArchivedAt => 'admin console field archived at';

  @override
  String get adminConsoleFieldOpsNote => 'admin console field ops note';

  @override
  String get adminConsoleFieldProjectId => 'admin console field project id';

  @override
  String get adminConsoleFieldWorkspace => 'admin console field workspace';

  @override
  String get adminConsoleFieldProjectArchivedAt =>
      'admin console field project archived at';

  @override
  String get adminConsoleFieldAclMode => 'admin console field acl mode';

  @override
  String get adminConsoleFieldEditorCount => 'admin console field editor count';

  @override
  String get adminConsoleFieldViewerCount => 'admin console field viewer count';

  @override
  String get agentWorkspaceProductionPromptLabel => '用于制作通道 harness.agent.run';

  @override
  String get agentWorkspaceProductionPromptHelper => '用于制作通道 harness.agent.run';

  @override
  String get agentWorkspaceProductionRunWorkflow => '运行制作工作流';

  @override
  String get agentWorkspaceProductionDomainToolLabel => '制作域工具';

  @override
  String get agentWorkspaceProductionFlowKeyLabel =>
      '作为 get_flowData key 和写回 key';

  @override
  String get agentWorkspaceProductionFlowKeyHelper =>
      '作为 get_flowData key 和写回 key';

  @override
  String get agentWorkspaceProductionArgsLabel =>
      '非 get_flowData 时使用，例如 ids:[1,2]（JSON）';

  @override
  String get agentWorkspaceProductionArgsHelper =>
      '非 get_flowData 时使用，例如 ids:[1,2]（JSON）';

  @override
  String get agentWorkspaceProductionReadTool => '读取制作工具';

  @override
  String get agentWorkspaceProductionSubAgentToolLabel => '制作子代理工具';

  @override
  String get agentWorkspaceProductionSubAgentArgsLabel =>
      '例如 storyboardIds:[1,2]，assetIds:[7,12]（JSON）';

  @override
  String get agentWorkspaceProductionSubAgentArgsHelper =>
      '例如 storyboardIds:[1,2]，assetIds:[7,12]（JSON）';

  @override
  String get agentWorkspaceProductionRunSubAgent => '运行子代理';

  @override
  String get agentWorkspaceProductionWritebackToolResult => '写回工具结果';

  @override
  String get agentWorkspaceProductionArgumentTemplates => '参数模板';

  @override
  String get agentWorkspaceProductionCurrentCandidateArgs => '当前结果候选参数';

  @override
  String get agentWorkspaceProductionCandidateIds => '候选 ... 项：......';

  @override
  String get agentWorkspaceProductionPromptPreviewTitle => '执行提示';

  @override
  String get agentWorkspaceProductionStagesTitle => '执行阶段';

  @override
  String get agentWorkspaceProductionFlowChip => 'flow=...';

  @override
  String get agentWorkspaceProductionApplyStage => '应用阶段';

  @override
  String get agentWorkspaceProductionDiagnosisTitle => '下一步建议';

  @override
  String get agentWorkspaceProductionToolChip => 'tool=...';

  @override
  String get agentWorkspaceProductionAgentChip => 'agent=...';

  @override
  String get agentWorkspaceProductionApplySuggestion => '应用建议';

  @override
  String get agentWorkspaceProductionStepPullAssetsFlow => '1) 拉取资产 flow';

  @override
  String get agentWorkspaceProductionStepRunAssetsSubAgent => '2) 运行资产子代理';

  @override
  String get agentWorkspaceProductionStepPullStoryboardFlow => '3) 拉取分镜 flow';

  @override
  String get agentWorkspaceProductionStepWritebackFlow => '4) 写回 flow';

  @override
  String get agentWorkspaceProductionStepRunStoryboardSubAgent => '5) 运行分镜子代理';

  @override
  String get agentWorkspaceProductionStepRunDirectorPlanSubAgent =>
      '6) 运行导演计划子代理';

  @override
  String get agentWorkspaceProductionPromptFlowDown =>
      '执行顺序：先核对导演计划点名资产，再补分镜表和镜头结果。';

  @override
  String get agentWorkspaceProductionPromptRewriteFocus =>
      '执行顺序：先核对导演计划点名资产，再补分镜表和镜头结果。';

  @override
  String get agentWorkspaceProductionPromptVisualPacing =>
      '执行顺序：先核对导演计划点名资产，再补分镜表和镜头结果。';

  @override
  String get agentWorkspaceProductionPromptExtraConstraint =>
      '执行顺序：先核对导演计划点名资产，再补分镜表和镜头结果。';

  @override
  String get agentWorkspaceProductionPromptAssetFocus =>
      '执行顺序：先核对导演计划点名资产，再补分镜表和镜头结果。';

  @override
  String get agentWorkspaceProductionPromptExecutionOrder =>
      '执行顺序：先核对导演计划点名资产，再补分镜表和镜头结果。';

  @override
  String get agentWorkspaceProductionStoryboardPriorityMissing =>
      '其余 \$hiddenCount 行已折叠';

  @override
  String get agentWorkspaceProductionCollapsedRows => '其余 \$hiddenCount 行已折叠';

  @override
  String get agentWorkspaceProductionReviewTarget => '聚焦资产: ...';

  @override
  String get agentWorkspaceProductionReviewGrade => '聚焦资产: ...';

  @override
  String get agentWorkspaceProductionReviewIssues => '聚焦资产: ...';

  @override
  String get agentWorkspaceProductionReviewNextStep => '聚焦资产: ...';

  @override
  String get agentWorkspaceProductionReviewAssetIds => '聚焦资产范围: ...';

  @override
  String get agentWorkspaceProductionReviewAssetScope => '聚焦资产范围: ...';

  @override
  String get agentWorkspaceProductionReviewStoryboardIds => '结论: ...';

  @override
  String get agentWorkspaceProductionReviewSummary => '结论: ...';

  @override
  String get agentWorkspaceProductionShotLabel => '时长: \$duration';

  @override
  String get agentWorkspaceProductionSceneLabel => '时长: \$duration';

  @override
  String get agentWorkspaceProductionDurationLabel => '资产: ...';

  @override
  String get agentWorkspaceProductionAssetsLabel => '资产: ...';

  @override
  String get agentWorkspaceProductionStateLabel => '模式: 纯文本';

  @override
  String get agentWorkspaceProductionModeTextOnly => '结果: 已有画面';

  @override
  String get agentWorkspaceProductionResultHasImage => '结果: 缺帧待补图';

  @override
  String get agentWorkspaceProductionResultMissingImage => '资产: ...';

  @override
  String get agentWorkspaceProductionContextFromTool => '来自 \$toolName';

  @override
  String get agentWorkspaceProductionContextDerivedRewrite =>
      '由 scriptPlan 派生的 production 执行提示';

  @override
  String get agentWorkspaceProductionContextDerivedRewriteSubtitle =>
      '由 scriptPlan 派生的 production 执行提示';

  @override
  String get agentWorkspaceProductionContextReturnList => '来自 \$toolName';

  @override
  String get agentWorkspaceProductionContextToolText => '工具返回文本';

  @override
  String get agentWorkspaceProductionContextReviewSummary => '来自 \$toolName';

  @override
  String get agentWorkspaceProductionContextSnapshotTitle => '上下文快照';

  @override
  String get agentWorkspaceSummaryReturnedList => '返回列表 ... 项';

  @override
  String get agentWorkspaceSummaryReturnedText => '返回文本 ... 字';

  @override
  String get agentWorkspaceProductionSummaryItems => '返回 items ... 项';

  @override
  String get agentWorkspaceProductionSummaryReviewHeadline => '聚焦资产 ... 项';

  @override
  String get agentWorkspaceProductionSummaryIssueBreakdown => '聚焦资产 ... 项';

  @override
  String get agentWorkspaceProductionSummaryFocusedAssets =>
      'agent workspace production summary focused assets';

  @override
  String get agentWorkspaceProductionSummaryFocusedAssetScope => '聚焦资产范围 ...';

  @override
  String get agentWorkspaceProductionSummaryFocusedShots => '聚焦镜头 ... 项';

  @override
  String get agentWorkspaceSummaryReturnedObjectKeys => '返回对象 keys=...';

  @override
  String get agentWorkspaceProductionSummaryFlowEmpty => '当前 flow 为空';

  @override
  String get agentWorkspaceProductionSummaryFlowEmptyString => '当前 flow 为空字符串';

  @override
  String get agentWorkspaceProductionSummaryTextChars => '已承接改写约束';

  @override
  String get agentWorkspaceProductionSummaryLineCount => '已承接改写约束';

  @override
  String get agentWorkspaceProductionSummaryPlanSections => '已承接改写约束';

  @override
  String get agentWorkspaceProductionSummaryRewriteInherited => '已承接改写约束';

  @override
  String get agentWorkspaceProductionSummaryStoryboardRows =>
      '关联资产 \$assetCount 项';

  @override
  String get agentWorkspaceProductionSummaryLinkedAssets =>
      '关联资产 \$assetCount 项';

  @override
  String get agentWorkspaceProductionSummaryListCount => '含媒体地址 \$withUrl 项';

  @override
  String get agentWorkspaceProductionSummaryPrompts => '含媒体地址 \$withUrl 项';

  @override
  String get agentWorkspaceProductionSummaryMediaUrls => '含媒体地址 \$withUrl 项';

  @override
  String get agentWorkspaceProductionSummaryNeedImages =>
      '纯文本 \$skippedCount 项';

  @override
  String get agentWorkspaceProductionSummaryMissingFrames =>
      '纯文本 \$skippedCount 项';

  @override
  String get agentWorkspaceProductionSummaryTextOnlyCount =>
      'agent workspace production summary text only count';

  @override
  String get agentWorkspaceProductionSummaryStateTypes => '状态种类 \$states 个';

  @override
  String get agentWorkspaceProductionSummaryObjectKeyCount => '对象 keys=... 个';

  @override
  String get agentWorkspaceProductionSummaryObjectListEntry => '...: ... 项';

  @override
  String get agentWorkspaceProductionSummaryObjectTextEntry => '...: ... 字';

  @override
  String get agentWorkspaceProductionSummaryReturnedType => '返回 ...';

  @override
  String get agentWorkspaceProductionIdleHint => '等待执行：可直接用引导任务或表单按钮。';

  @override
  String get agentWorkspaceProductionLatestToolResult =>
      '最新工具结果：\$workspaceLastToolResultLine';

  @override
  String get agentWorkspaceProductionResultSummary => '结果摘要';

  @override
  String get agentWorkspaceProductionSuggestedFlowKey =>
      '建议写回 key：\$suggestedFlowKeyLine';

  @override
  String get agentWorkspaceProductionUseSuggestedFlowKey => '使用该 key';

  @override
  String get agentWorkspaceProductionWritebackStrategy =>
      '核心 key 回写策略：get_flowData 直接写回；资产/分镜/导演计划相关工具会先刷新对应 flow key 再写回。';

  @override
  String get agentWorkspaceScriptStepFetchPlanData => '1) 拉取 planData';

  @override
  String get agentWorkspaceScriptStepFetchContent => '2) 拉取剧本正文';

  @override
  String get agentWorkspaceScriptStepGenerateDraft => '3) 生成剧本草稿';

  @override
  String get agentWorkspaceScriptStepWriteback => '4) 写回剧本';

  @override
  String get agentWorkspaceScriptPromptLabel => '用于剧本通道 harness.agent.run';

  @override
  String get agentWorkspaceScriptPromptHelper => '用于剧本通道 harness.agent.run';

  @override
  String get agentWorkspaceScriptRunWorkflow => '运行剧本工作流';

  @override
  String get agentWorkspaceScriptDomainToolLabel => '剧本域工具';

  @override
  String get agentWorkspaceScriptReadContext => '读取剧本上下文';

  @override
  String get agentWorkspaceScriptArgsLabel => '优先沿用最近章节结果填充 novelId；拿不准时先别写死。';

  @override
  String get agentWorkspaceScriptArgsHelper => '优先沿用最近章节结果填充 novelId；拿不准时先别写死。';

  @override
  String get agentWorkspaceScriptSubAgentToolLabel => '剧本子代理工具';

  @override
  String get agentWorkspaceScriptRunSubAgent => '运行子代理';

  @override
  String get agentWorkspaceScriptWritebackPlanData => '写回计划数据';

  @override
  String get agentWorkspaceScriptWritebackUpdateData => 'update-data 写回';

  @override
  String get agentWorkspaceScriptStagesTitle => '执行阶段';

  @override
  String get agentWorkspaceScriptApplyStage => '应用阶段';

  @override
  String get agentWorkspaceScriptAdvanceStage => '推进阶段';

  @override
  String get agentWorkspaceScriptDiagnosisTitle => '下一步建议';

  @override
  String get agentWorkspaceScriptToolChip => 'tool=...';

  @override
  String get agentWorkspaceScriptAgentChip => 'agent=...';

  @override
  String get agentWorkspaceScriptApplySuggestion => '应用建议';

  @override
  String get agentWorkspaceScriptContextSkeletonFocus => '骨架重点：\$skeletonHint';

  @override
  String get agentWorkspaceScriptContextAdaptationFocus =>
      '改编口径：\$strategyHint';

  @override
  String get agentWorkspaceScriptContextExecutionOrder =>
      '对白约束：避免解释剧情，优先口语化冲突表达和情绪推进。';

  @override
  String get agentWorkspaceScriptContextDialogueConstraint =>
      '对白约束：避免解释剧情，优先口语化冲突表达和情绪推进。';

  @override
  String get agentWorkspaceScriptContextStorySkeleton => '来自 get_planData';

  @override
  String get agentWorkspaceScriptContextFromPlanData => '来自 get_planData';

  @override
  String get agentWorkspaceScriptContextAdaptationStrategy => '来自 get_planData';

  @override
  String get agentWorkspaceScriptContextRewriteConstraints =>
      '由 get_planData 派生的下游消费提示';

  @override
  String get agentWorkspaceScriptContextRewriteConstraintsSubtitle =>
      '由 get_planData 派生的下游消费提示';

  @override
  String get agentWorkspaceScriptContextUntitledScript => '未命名剧本';

  @override
  String get agentWorkspaceScriptContextNoBody => '无正文';

  @override
  String get agentWorkspaceScriptContextPlanDrafts => '最多展示前 4 条 script rows';

  @override
  String get agentWorkspaceScriptContextPlanDraftsSubtitle =>
      '最多展示前 4 条 script rows';

  @override
  String get agentWorkspaceScriptContextCurrentScriptBody =>
      '来自 get_script_content';

  @override
  String get agentWorkspaceScriptContextFromScriptContent =>
      '来自 get_script_content';

  @override
  String get agentWorkspaceScriptContextUntitledChapter => 'chapter';

  @override
  String get agentWorkspaceScriptContextChapterPrefix => '第 ... 章 · \$chapter';

  @override
  String get agentWorkspaceScriptContextNovelChapters =>
      '来自 get_novel_text，最多展示前 4 条';

  @override
  String get agentWorkspaceScriptContextNovelChaptersSubtitle =>
      '来自 get_novel_text，最多展示前 4 条';

  @override
  String get agentWorkspaceScriptContextUntitledEvent => '未命名事件';

  @override
  String get agentWorkspaceScriptContextNovelEvents =>
      '来自 get_novel_events，最多展示前 6 条';

  @override
  String get agentWorkspaceScriptContextNovelEventsSubtitle =>
      '来自 get_novel_events，最多展示前 6 条';

  @override
  String get agentWorkspaceScriptContextSnapshotTitle => '上下文快照';

  @override
  String get agentWorkspaceScriptLatestAssistantResult => '最新助手结果';

  @override
  String get agentWorkspaceScriptWritebackSource =>
      '写回来源：\$scriptWritebackSourceLine';

  @override
  String get agentWorkspaceScriptSummaryReviewReturned => '审核结果已返回';

  @override
  String get agentWorkspaceScriptSummaryReviewLine =>
      '审核 ...：... 级，问题 \$issueCount 项\$summary';

  @override
  String get agentWorkspaceScriptSummaryPlanDataMissing => 'planData 缺少 data';

  @override
  String get agentWorkspaceScriptSummaryStorySkeletonReady => '故事骨架已就绪';

  @override
  String get agentWorkspaceScriptSummaryAdaptationReady => '改编策略已就绪';

  @override
  String get agentWorkspaceScriptSummaryPlanScripts => '计划剧本 ... 条';

  @override
  String get agentWorkspaceScriptSummaryRewriteReady => '改写约束已可下游消费';

  @override
  String get agentWorkspaceScriptSummaryPlanDataReturned => 'planData 已返回';

  @override
  String get agentWorkspaceScriptSummaryScriptEmpty => '剧本正文 ... 字';

  @override
  String get agentWorkspaceScriptSummaryScriptChars => '剧本正文 ... 字';

  @override
  String get agentWorkspaceScriptSummaryNovelTextEmpty => '章节材料 ... 条';

  @override
  String get agentWorkspaceScriptSummaryNovelTextCount => '章节材料 ... 条';

  @override
  String get agentWorkspaceScriptSummaryNovelEventsEmpty => '小说事件 ... 条';

  @override
  String get agentWorkspaceScriptSummaryNovelEventsCount => '小说事件 ... 条';

  @override
  String get agentWorkspaceScopeProjectIdLabel => '项目 ID（numeric）';

  @override
  String get agentWorkspaceScopeScriptIdLabel => '剧本 ID（numeric）';

  @override
  String get agentWorkspaceScopeProjectUuidLabel =>
      '项目 UUID（可选，与 WS projectUuid 对齐）';

  @override
  String get agentWorkspaceScopeScriptUuidLabel => '剧本 UUID（可选，制作 attach）';

  @override
  String get agentWorkspaceScopeWorkspaceUuidLabel =>
      '工作区 UUID（可选，WS workspaceUuid）';

  @override
  String get agentWorkspacePaneScript => '执行动态';

  @override
  String get agentWorkspacePaneProduction => '执行动态';

  @override
  String get agentWorkspacePaneActivity => '执行动态';

  @override
  String get agentWorkspaceActivityTitle => '执行动态';

  @override
  String get agentWorkspaceActivityLatest => 'latest: \$eventType';

  @override
  String get agentWorkspaceActivityLatestToolResult =>
      '最新工具结果：\$workspaceLastToolResultLine';

  @override
  String get agentWorkspaceActivityLatestAssistantText => '最新助手文本';

  @override
  String get agentWorkspaceActivityNoWsEvents => '暂无 WS 事件。';

  @override
  String get agentWorkspaceProductionCardTitle => '制作工作区';

  @override
  String get agentWorkspaceGuidedTasksTitle => '引导任务';

  @override
  String get agentWorkspaceScriptWritebackSourceAssistant => 'assistant stream';

  @override
  String get agentWorkspaceScriptPlanHint =>
      'PlanData source ready:\$planHint story/adaptation + script rows=\$scriptCount';

  @override
  String get agentWorkspaceScriptPlanWritebackReady =>
      'PlanData source ready:\$planHint story/adaptation + script rows=\$scriptCount';

  @override
  String get agentWorkspaceScriptRunningWorkflow => '执行中：写回计划数据';

  @override
  String get agentWorkspaceScriptRunningReadContext => '执行中：写回计划数据';

  @override
  String get agentWorkspaceScriptRunningSubAgent => '执行中：写回计划数据';

  @override
  String get agentWorkspaceScriptRunningWriteback =>
      'agent workspace script running writeback';

  @override
  String get agentWorkspaceScriptRunningWritebackPlan =>
      'agent workspace script running writeback plan';

  @override
  String get agentWorkspaceScriptCardTitle => '剧本工作区';

  @override
  String get agentWorkspaceSectionTitle => 'Agent 工作区';

  @override
  String get agentWorkspaceSectionDescription =>
      '将 script 与 production 工作流拆分为独立面板，并把执行日志归并到单独执行动态面板。';

  @override
  String get contentComplianceTargetProject =>
      'content compliance target project';

  @override
  String get contentComplianceTargetScript =>
      'content compliance target script';

  @override
  String get contentComplianceTargetStoryboard =>
      'content compliance target storyboard';

  @override
  String get contentComplianceTargetAsset => 'content compliance target asset';

  @override
  String get contentComplianceTargetNovel => 'content compliance target novel';

  @override
  String get contentComplianceTargetUser => 'content compliance target user';

  @override
  String get contentComplianceOptionAll => 'content compliance option all';

  @override
  String get contentComplianceCategoryCopyright =>
      'content compliance category copyright';

  @override
  String get contentComplianceCategorySafety =>
      'content compliance category safety';

  @override
  String get contentComplianceCategoryHarassment =>
      'content compliance category harassment';

  @override
  String get contentComplianceCategoryAdult =>
      'content compliance category adult';

  @override
  String get contentComplianceCategoryViolence =>
      'content compliance category violence';

  @override
  String get contentComplianceCategorySpam =>
      'content compliance category spam';

  @override
  String get contentComplianceCategoryOther =>
      'content compliance category other';

  @override
  String get contentComplianceSeverityLow => 'content compliance severity low';

  @override
  String get contentComplianceSeverityMedium =>
      'content compliance severity medium';

  @override
  String get contentComplianceSeverityHigh =>
      'content compliance severity high';

  @override
  String get contentComplianceSeverityCritical =>
      'content compliance severity critical';

  @override
  String get contentComplianceStatusPending =>
      'content compliance status pending';

  @override
  String get contentComplianceStatusClaimed =>
      'content compliance status claimed';

  @override
  String get contentComplianceStatusResolved =>
      'content compliance status resolved';

  @override
  String get contentComplianceStatusDismissed =>
      'content compliance status dismissed';

  @override
  String get contentComplianceSlaOpenOver24h =>
      'content compliance sla open over24h';

  @override
  String get contentComplianceSlaOpenOver72h =>
      'content compliance sla open over72h';

  @override
  String get contentComplianceSlaClaimedOver24h => 'claimed>24h ...';

  @override
  String get contentComplianceFieldTargetType => 'storyboard';

  @override
  String get contentComplianceFieldCategory => 'violence';

  @override
  String get contentComplianceFieldSeverity => 'critical';

  @override
  String get contentComplianceFieldTargetUuid => 'target UUID';

  @override
  String get contentComplianceFieldStatus => 'resolved';

  @override
  String get contentComplianceSlaChip => 'SLA: ...';

  @override
  String get contentComplianceMetricPending => 'high ...';

  @override
  String get contentComplianceMetricClaimed => 'high ...';

  @override
  String get contentComplianceMetricResolved =>
      'content compliance metric resolved';

  @override
  String get contentComplianceMetricDismissed =>
      'content compliance metric dismissed';

  @override
  String get contentComplianceMetricCritical =>
      'content compliance metric critical';

  @override
  String get contentComplianceMetricHigh => 'content compliance metric high';

  @override
  String get contentComplianceOldestHours => 'oldest ...h';

  @override
  String get contentComplianceCapacityPerReviewer => 'capacity .../reviewer';

  @override
  String get contentComplianceOwnerCounts => 'pending ... · claimed ...';

  @override
  String get contentComplianceOwnerDetail => '...';

  @override
  String get contentComplianceWorkspaceCounts =>
      'open ... · pending ... · claimed ...';

  @override
  String get contentComplianceWorkspaceDetail =>
      'critical ... · high ... · SLA ... · oldest ...h';

  @override
  String get contentComplianceReportInfo => 'reporter ...';

  @override
  String get contentComplianceResolutionLine => 'resolution: ...';

  @override
  String get contentComplianceActionClaim => 'content compliance action claim';

  @override
  String get contentComplianceActionResolve => 'resolve';

  @override
  String get contentComplianceActionDismiss => 'dismiss';

  @override
  String get contentComplianceFieldDisposition => 'disposition';

  @override
  String get contentComplianceDispositionNone => 'disposition';

  @override
  String get contentComplianceDispositionArchiveProject => 'archive_project';

  @override
  String get contentComplianceDispositionSuspendUser => 'suspend_user';

  @override
  String get contentComplianceFieldResolutionNote => 'resolution note';

  @override
  String get jobsEmptyValue => 'jobs empty value';

  @override
  String get jobsKindCountEntry => 'jobs kind count entry';

  @override
  String get jobsStatusCountEntry => 'jobs status count entry';

  @override
  String get jobsIdempotencyMismatch => 'jobs idempotency mismatch';

  @override
  String get jobsUpdatedAt => 'jobs updated at';

  @override
  String get jobsClaimedBy => 'jobs claimed by';

  @override
  String get jobsFailedReason => 'jobs failed reason';

  @override
  String get jobsTitle => '任务作业';

  @override
  String get jobsPrefsTooltip => '本机客户端偏好';

  @override
  String get jobsSubtitle => '查看作业列表、状态汇总，并按 ID 打开单条执行记录。';

  @override
  String get jobsLoadList => '加载作业列表';

  @override
  String get jobsLoadFailed => '查看失败作业';

  @override
  String get jobsLoadKinds => '加载作业类型';

  @override
  String get jobsLoadKindSummary => '查看类型汇总';

  @override
  String get jobsLoadStatusSummary => '查看状态汇总';

  @override
  String get jobsCompatTitle => '保留 flutter.probe 相关回归入口，默认折叠';

  @override
  String get jobsCompatSubtitle => '保留 flutter.probe 相关回归入口，默认折叠';

  @override
  String get jobsCompatHttpProbeFilters => 'HTTP probe filters';

  @override
  String get jobsFilterFlutterProbe => '按 flutter.probe 查看';

  @override
  String get jobsFilterFlutterProbeQueued => '查看 flutter.probe 排队中';

  @override
  String get jobsCreateProbeJob => '创建 probe 作业';

  @override
  String get jobsJobIdLabel => '作业 ID（点下方列表可自动填入）';

  @override
  String get jobsFetchDetail => '查看作业详情';

  @override
  String get jobsDetailLabel => '作业详情：...';

  @override
  String get jobsKindsLabel => '作业类型：...';

  @override
  String get jobsKindSummaryLabel => '类型汇总：...';

  @override
  String get jobsStatusSummaryLabel => '状态汇总：...';

  @override
  String get jobsCountLabel => '... 条作业';

  @override
  String get jobsRetry => 'jobs retry';

  @override
  String get jobsCancel => 'jobs cancel';

  @override
  String get notificationsRealtimeDisconnected =>
      'notifications realtime disconnected';

  @override
  String get notificationsPlatformStatusRecovered =>
      'notifications platform status recovered';

  @override
  String get notificationsPlatformStatusDegraded =>
      'notifications platform status degraded';

  @override
  String get notificationsPlatformStatusRecoveredMessage =>
      'notifications platform status recovered message';

  @override
  String get notificationsPlatformStatusDegradedMessage =>
      'notifications platform status degraded message';

  @override
  String get notificationsPlatformStatusAffectedEndpoints =>
      'notifications platform status affected endpoints';

  @override
  String get notificationsComplianceAlertTitle =>
      'notifications compliance alert title';

  @override
  String get notificationsDownloadUnsupported =>
      'notifications download unsupported';

  @override
  String get notificationsComplianceSharedAsyncExportCompleted =>
      'notifications compliance shared async export completed';

  @override
  String get notificationsComplianceSharedAsyncExportCancelled =>
      'notifications compliance shared async export cancelled';

  @override
  String get notificationsComplianceSharedAsyncExportFailed =>
      'notifications compliance shared async export failed';

  @override
  String get notificationsComplianceSharedAsyncExportFailedWithDetail =>
      'notifications compliance shared async export failed with detail';

  @override
  String get notificationsComplianceSharedAsyncExportTimedOut =>
      'notifications compliance shared async export timed out';

  @override
  String get notificationsImportJsonObjectRequired =>
      'notifications import json object required';

  @override
  String get notificationsImportJsonParseFailed =>
      'notifications import json parse failed';

  @override
  String get notificationsUnknownTemplate => 'notifications unknown template';

  @override
  String get platformStatusChipLabel => '\$title: \$value';

  @override
  String get opsWhActivityEntryTitle => '... · ...';

  @override
  String get opsWhFieldId => 'updatedAt: ...';

  @override
  String get opsWhFieldCreatedAt => 'updatedAt: ...';

  @override
  String get opsWhFieldUpdatedAt => 'updatedAt: ...';

  @override
  String get opsWhApiEventTypes => 'API: ...';

  @override
  String get billingAuditEventTypeLabel => 'event_type';

  @override
  String get billingAuditProviderEventIdLabel => 'provider_event_id';

  @override
  String get billingAuditRawEventIdLabel => 'raw_event_id';

  @override
  String get billingAuditProviderEventIdPrefixLabel =>
      'provider_event_id_prefix';

  @override
  String get billingAuditRawEventIdPrefixLabel => 'raw_event_id_prefix';

  @override
  String get billingAuditEventCreatedFromLabel => 'event_created_from';

  @override
  String get billingAuditEventCreatedToLabel => 'event_created_to';

  @override
  String get billingAuditCreatedFromLabel => 'created_from';

  @override
  String get billingAuditCreatedToLabel => 'created_to';
}
