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
  String get localizedFormattingFileSizeZero => '0 B';

  @override
  String get localizedFormattingByteSuffix => 'B';

  @override
  String get localizedFormattingKilobyteSuffix => 'KB';

  @override
  String get localizedFormattingMegabyteSuffix => 'MB';

  @override
  String get localizedFormattingGigabyteSuffix => 'GB';

  @override
  String get localizedFormattingTerabyteSuffix => 'TB';

  @override
  String localizedFormattingDurationHours(int count) {
    return '$count小时';
  }

  @override
  String localizedFormattingDurationMinutes(int count) {
    return '$count分钟';
  }

  @override
  String localizedFormattingDurationSeconds(int count) {
    return '$count秒';
  }

  @override
  String get localizedFormattingDurationZero => '0秒';

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
  String get shortVideoSpaceUndoRedoOperationDefault => '操作';

  @override
  String shortVideoSpaceUndoSucceeded(String description) {
    return '已撤销：$description';
  }

  @override
  String shortVideoSpaceUndoFailed(String error) {
    return '撤销失败：$error';
  }

  @override
  String shortVideoSpaceRedoSucceeded(String description) {
    return '已重做：$description';
  }

  @override
  String shortVideoSpaceRedoFailed(String error) {
    return '重做失败：$error';
  }

  @override
  String get shortVideoSpacePreviewVideoLoadFailed => '视频加载失败';

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
  String get notificationsComplianceExportFormatJson => 'JSON';

  @override
  String get notificationsComplianceExportFormatCsv => 'CSV';

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
  String get productPipelineStripTitle => '短剧生产平台链';

  @override
  String get productPipelineStripSubtitle =>
      '从项目配置到脚本、制作、任务与质量评审的统一入口；短视频 Space 用于编排与成片相关能力。';

  @override
  String get productPipelineStripProjects => '项目';

  @override
  String get productPipelineStripScripts => '脚本';

  @override
  String get productPipelineStripProduction => '制作';

  @override
  String get productPipelineStripTasks => '任务';

  @override
  String get productPipelineStripJobs => '作业';

  @override
  String get productPipelineStripQuality => '质量';

  @override
  String get productPipelineStripShortVideo => '短视频';

  @override
  String workspaceDebugOverviewApiBase(String baseUrl) {
    return 'API: $baseUrl';
  }

  @override
  String get workspaceDebugOverviewProbeBusy => '请求中…';

  @override
  String get workspaceDebugOverviewButtonHealthV1 => 'GET /api/v1/health';

  @override
  String get workspaceDebugOverviewButtonHealthRoot => 'GET /health';

  @override
  String get workspaceDebugOverviewButtonPing => 'GET /api/v1/ping';

  @override
  String get workspaceDebugOverviewButtonVersion => 'GET /api/v1/version';

  @override
  String get workspaceDebugOverviewButtonReady => 'GET /api/v1/ready';

  @override
  String workspaceDebugOverviewHealthV1Line(String body) {
    return 'health (v1): $body';
  }

  @override
  String workspaceDebugOverviewHealthRootLine(String body) {
    return 'health (root): $body';
  }

  @override
  String workspaceDebugOverviewPingLine(String body) {
    return 'ping: $body';
  }

  @override
  String workspaceDebugOverviewVersionLine(String body) {
    return 'version: $body';
  }

  @override
  String workspaceDebugOverviewReadyLine(String body) {
    return 'ready: $body';
  }

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
  String get billingAuditProviderStripe => 'Stripe';

  @override
  String get billingAuditProviderAlipay => '支付宝';

  @override
  String get billingAuditProviderPaddle => 'Paddle';

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
  String projectsSummaryLine(String body) {
    return '项目摘要：$body';
  }

  @override
  String projectsArtStylesLine(String body) {
    return '美术风格：$body';
  }

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
  String globalSearchNovelEventNavigated(String eventId) {
    return '已定位到项目。请在项目详情中打开「小说与事件」查看大纲事件（事件 #$eventId）。';
  }

  @override
  String globalSearchNovelChapterNavigated(String chapterIndex) {
    return '已定位到项目。请在项目详情中打开「小说与事件」查看章节（章索引 $chapterIndex）。';
  }

  @override
  String get globalSearchNovelOrEventNavigatedHint =>
      '请从首页主导航打开「项目列表」，在目标项目内使用小说工作台查看章节与事件。';

  @override
  String accountDeletedSummary(
    int workspaceCount,
    int projectCount,
    int jobCount,
  ) {
    return '账号已删除：workspace $workspaceCount · project $projectCount · job $jobCount';
  }

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
  String shortVideoSpaceErrorContextWrap(String context) {
    return '（$context）';
  }

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
  String get shortVideoSpaceDialogExportHistoryDurationDash => '—';

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
    String framerateDisplay,
  ) {
    return '设置: $bitrate · $framerateDisplay';
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
  String get projectMembersTitle => '项目成员 ACL';

  @override
  String get projectMembersAclEnabledIntro =>
      '本项目已启用显式 ACL：普通成员仅按下方只读/编辑行获得访问；工作区拥有者/管理员仍保留完整权限。';

  @override
  String get projectMembersAclInheritedIntro =>
      '本项目处于工作区继承模式：普通成员沿用原项目访问权限。添加第一条显式 ACL 行后，将切换为受限模式。';

  @override
  String get projectMembersChipMode => '模式';

  @override
  String get projectMembersChipExplicitMembers => '显式成员';

  @override
  String get projectMembersChipCandidates => '候选工作区成员';

  @override
  String get projectMembersForbiddenTitle => '当前账号无法管理项目 ACL';

  @override
  String get projectMembersForbiddenBody =>
      '仅工作区拥有者/管理员或项目拥有者可查看与修改显式项目成员。若你只需继续编辑其他内容，当前项目仍将按既有工作区/项目权限正常可用。';

  @override
  String get projectMembersAddSectionTitle => '添加显式成员';

  @override
  String get projectMembersAddSectionIntro =>
      '建议优先从当前工作区成员中选择；若暂时无法拉取工作区成员列表，也可直接输入用户 UUID 进行受控补录。';

  @override
  String get projectMembersFieldGrantRole => '授予角色';

  @override
  String get projectMembersRoleViewer => '只读（viewer）';

  @override
  String get projectMembersRoleEditor => '编辑（editor）';

  @override
  String get projectMembersLoadingWorkspaceMembers => '正在加载工作区成员…';

  @override
  String get projectMembersForbiddenWorkspaceMembers =>
      '当前账号无权读取工作区成员列表；仍可手动输入用户 UUID 管理显式 ACL。';

  @override
  String get projectMembersNoWorkspaceContext =>
      '本项目暂时无可用工作区上下文，已保留手动 UUID 录入。';

  @override
  String get projectMembersNoCandidates =>
      '当前没有可直接添加的普通工作区成员。owner/admin 已具备自然项目访问权限；已建立显式行的成员请见下方列表。';

  @override
  String get projectMembersFieldSelectFromWorkspace => '从工作区成员添加';

  @override
  String get projectMembersButtonAdd => '添加';

  @override
  String get projectMembersFieldManualUserId => '手动输入用户 UUID';

  @override
  String get projectMembersFieldManualUserIdHint =>
      '00000000-0000-0000-0000-000000000000';

  @override
  String get projectMembersButtonAddByUuid => '按 UUID 添加';

  @override
  String get projectMembersExplicitSectionTitle => '显式 ACL 行';

  @override
  String get projectMembersExplicitEmptyIntro => '当前尚无显式项目成员。项目仍处于工作区继承模式。';

  @override
  String get projectMembersExplicitNonEmptyIntro =>
      '以下为当前项目实际启用的只读/编辑规则。删除最后一行后，项目将恢复为继承模式。';

  @override
  String get projectMembersExplicitEmptyState => '暂无显式 ACL 行';

  @override
  String get projectMembersTooltipCopyUserId => '复制用户 UUID';

  @override
  String get projectMembersTagExplicitRole => '显式角色';

  @override
  String get projectMembersTagWorkspaceRole => '工作区角色';

  @override
  String get projectMembersTagUpdatedAt => '更新时间';

  @override
  String get projectMembersFieldUpdateRole => '更新角色';

  @override
  String get projectMembersTooltipSaveRole => '保存角色';

  @override
  String get projectMembersTooltipRemoveAcl => '移除显式 ACL';

  @override
  String get projectMembersButtonRefresh => '刷新';

  @override
  String get projectMembersSnackInvalidUuid => '请输入有效的用户 UUID';

  @override
  String get projectMembersSnackNoCandidates => '当前没有可直接添加的工作区成员';

  @override
  String get projectMembersSnackMemberAdded => '已添加项目成员';

  @override
  String get projectMembersSnackRoleUpdated => '角色已更新';

  @override
  String get projectMembersSnackAclRemoved => '已移除显式 ACL';

  @override
  String get projectMembersSnackUserIdCopied => '用户 UUID 已复制';

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
  String agentMemoryScopeStoryboardIds(String ids) {
    return '分镜 $ids';
  }

  @override
  String agentMemoryScopeSampleCount(String count) {
    return '样本 $count';
  }

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
    return '已使用 $count 次';
  }

  @override
  String globalSearchSavedViewWorkspaceLine(String name) {
    return '工作区：$name';
  }

  @override
  String globalSearchSavedViewTypesLine(String types) {
    return '类型：$types';
  }

  @override
  String globalSearchSavedViewLastUsedLine(String when) {
    return '最近：$when';
  }

  @override
  String get globalSearchTemplateRecent7d => '近 7 天';

  @override
  String get globalSearchTemplateProjects30d => '项目近 30 天';

  @override
  String get globalSearchTemplateScripts30d => '剧本近 30 天';

  @override
  String get globalSearchTemplateAssets30d => '资产近 30 天';

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
  String qualityReviewsDashboardStatsScopePrefix(String scope) {
    return 'scope=$scope · ';
  }

  @override
  String qualityReviewsDashboardTargetStatRow(
    String targetType,
    int totalReviews,
    String passPct,
    String avgScore,
  ) {
    return '$targetType：共 $totalReviews 条，通过率 $passPct%，均分 $avgScore';
  }

  @override
  String qualityReviewsDashboardStagePassRateRow(
    String date,
    String targetType,
    String passPct,
    int totalReviews,
  ) {
    return '$date $targetType：通过率 $passPct%，共 $totalReviews 条';
  }

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
  String get qualityReviewsAbbrevNotAvailable => '暂无';

  @override
  String get qualityReviewsStatDeliveryNa => '投放侧无数据';

  @override
  String get qualityReviewsStatNonNa => '非投放侧无数据';

  @override
  String qualityReviewsStatDeliveryPassRate(String rate) {
    return '投放 $rate%';
  }

  @override
  String qualityReviewsStatNonPassRate(String rate) {
    return '非投放 $rate%';
  }

  @override
  String qualityReviewsWorkbenchStagePassRateRow(
    String date,
    String targetType,
    String passPct,
    String deliveryPart,
    String nonDeliveryPart,
  ) {
    return '$date $targetType：通过率 $passPct%（$deliveryPart，$nonDeliveryPart）';
  }

  @override
  String qualityReviewsWorkbenchQualityStatRow(
    String targetType,
    int totalReviews,
    String passPct,
    String deliveryPart,
    String nonDeliveryPart,
  ) {
    return '$targetType：共 $totalReviews 条，通过率 $passPct%（$deliveryPart，$nonDeliveryPart）';
  }

  @override
  String qualityReviewsScopeInsightSlimChars(int chars, int rows, String unit) {
    return '压缩 $chars 字符/$rows$unit';
  }

  @override
  String qualityReviewsSummaryScopeLine(String value) {
    return '范围：$value';
  }

  @override
  String qualityReviewsSummaryTokenLine(String value) {
    return 'Token：$value';
  }

  @override
  String qualityReviewsWorkbenchDashboardTokenRow(
    String targetType,
    String prompt,
    String memory,
    String delivery,
    String action,
  ) {
    return '$targetType：提示词 $prompt 字符，记忆 $memory 字符，投放记忆 $delivery 字符 · 动作 $action';
  }

  @override
  String qualityReviewsTokenEfficiencyStatLine(
    String targetType,
    String prompt,
    String base,
    String memory,
    String memoryShare,
    String delivery,
    String deliveryShare,
    String hitRate,
  ) {
    return '$targetType：提示词 $prompt，基础 $base，记忆 $memory（占比 $memoryShare%，投放 $delivery/$deliveryShare%，命中 $hitRate%）';
  }

  @override
  String qualityReviewsTokenEfficiencySampleLine(
    String date,
    String targetType,
    String prompt,
    String base,
    String memory,
    String memoryShare,
    String deliveryFlag,
  ) {
    return '$date $targetType：提示词 $prompt，基础 $base，记忆 $memory（占比 $memoryShare%，$deliveryFlag）';
  }

  @override
  String qualityReviewsWorkbenchStageGradeRow(
    String stage,
    int a,
    int b,
    int c,
    int d,
    String passPct,
  ) {
    return '$stage：A$a/B$b/C$c/D$d · 通过率 $passPct%';
  }

  @override
  String qualityReviewsPreviewListTitle(
    String targetType,
    String source,
    String score,
  ) {
    return '$targetType · $source · 分数=$score';
  }

  @override
  String qualityReviewsPreviewDetailTarget(String targetId) {
    return '目标=$targetId';
  }

  @override
  String qualityReviewsPreviewDetailPassed(String passed) {
    return '通过=$passed';
  }

  @override
  String get qualityReviewsPreviewDetailBadCase => '坏例';

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
  String get adminConsoleDailyQuotaInputExample => '例如 100';

  @override
  String get adminConsoleDailyQuotaInputDisabledHint => '无限制';

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
  String projectEditorScriptsSectionCountLine(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条剧本',
      one: '1 条剧本',
      zero: '0 条剧本',
    );
    return '$_temp0';
  }

  @override
  String get projectEditorScriptsSectionIntroBody => '在项目下管理剧本，并进入剧本详情维护内容与分镜。';

  @override
  String get projectEditorScriptsSectionBatchWorkbenchTitle => '剧本批量工作台';

  @override
  String get projectEditorScriptsSectionBatchWorkbenchDescription =>
      '把项目级剧本上下文读取、批量导出、提取状态轮询、素材抽取和批量创建收口到同一工作台，不再只靠全量快捷按钮。';

  @override
  String get projectEditorScriptsSectionOpenBatchWorkbench => '打开剧本批量工作台';

  @override
  String get projectEditorScriptsSectionOpenPlanWorkbench => '打开骨架工作台';

  @override
  String get projectEditorScriptsSectionSuggestionsTitle => '当前批量建议';

  @override
  String get projectEditorScriptsSectionBatchAdd => '批量新增剧本';

  @override
  String get projectEditorScriptsSectionExportAll => '导出全部剧本';

  @override
  String get projectEditorScriptsSectionPollAllExtract => '轮询全部提取状态';

  @override
  String get projectEditorScriptsSectionExtractAllMaterials => '提取全部剧本素材';

  @override
  String get projectEditorScriptsSectionCreateEmpty => '新建空剧本';

  @override
  String get projectEditorScriptsSectionCompatibilityTile => '兼容性检查';

  @override
  String get projectEditorScriptsSectionCompatibilitySubtitle =>
      '保留旧剧本接口与导出/提取回归入口，默认折叠';

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
  String get projectEditorProbeGeneralBusyLabel => 'general…';

  @override
  String get projectEditorProbeGeneralButtonGetSingleProject =>
      'compat getSingleProject';

  @override
  String get projectEditorProbeGeneralButtonUpdateProject =>
      'compat updateProject';

  @override
  String get projectEditorProbeGeneralButtonPatchProjectNameNoop =>
      'PATCH …/projects（name noop）';

  @override
  String get projectEditorProbeGeneralGetSingleZeroRows => '0 行';

  @override
  String projectEditorProbeGeneralGetSingleSnack(String line) {
    return 'compat getSingleProject（GET projects 过滤 numeric_id）：$line';
  }

  @override
  String get projectEditorProbeGeneralUpdateProjectSnack =>
      'compat updateProject（PATCH projects）：intro 探针 + 还原已完成。';

  @override
  String projectEditorProbeGeneralPatchNameNoopSnack(String name) {
    return 'PATCH …/projects name noop → $name';
  }

  @override
  String get projectEditorProbeProjectBusyLabel => 'project…';

  @override
  String get projectEditorProbeProjectButtonGetProject =>
      'POST project get-project';

  @override
  String projectEditorProbeProjectEditNoopResult(int numericId) {
    return 'POST …/project/edit-project noop #$numericId 已完成。';
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
  String get projectEditorNovelsSummaryNoChapters => '当前没有小说章节';

  @override
  String projectEditorNovelsSummaryChaptersLine(
    int count,
    String visible,
    String suffix,
  ) {
    return '共 $count 条 · $visible$suffix';
  }

  @override
  String get projectEditorNovelsSummaryIntakeEmptyBaseline =>
      '准入 admitted 0 / pending 0 / rejected 0 · source manual 0 / import 0 / crawler_client 0 / crawler_server 0';

  @override
  String projectEditorNovelsSummaryIntakeCounts(
    int admitted,
    int pending,
    int rejected,
    int manual,
    int bookImport,
    int crawlerClient,
    int crawlerServer,
  ) {
    return '准入 admitted $admitted / pending $pending / rejected $rejected · source manual $manual / import $bookImport / crawler_client $crawlerClient / crawler_server $crawlerServer';
  }

  @override
  String get projectEditorNovelsSummaryNoEvents => '当前没有小说事件';

  @override
  String projectEditorNovelsSummaryEventsLine(
    int count,
    String visible,
    String suffix,
  ) {
    return '事件 $count 条 · $visible$suffix';
  }

  @override
  String get projectEditorNovelEventsRegressionProbeCaption => '小说事件回归检查';

  @override
  String get projectEditorAssetsWorkbenchNoAssetsYet => '当前项目还没有资产，可直接在这里创建。';

  @override
  String get projectEditorAssetsSectionListNotLoaded => '资产列表尚未加载';

  @override
  String projectEditorNovelsWorkbenchDefaultNewChapterTitle(int stamp) {
    return '章节_$stamp';
  }

  @override
  String get projectEditorNovelsWorkbenchDefaultNewChapterBody => '在这里填写章节正文。';

  @override
  String get projectEditorStylePackTagArt => '画风';

  @override
  String get projectEditorStylePackTagStory => '故事';

  @override
  String get projectEditorStylePackNoDescriptionFallback => '暂无简介';

  @override
  String get projectEditorNovelImportCrawlerBodyFallbackTitle => '抓取正文';

  @override
  String projectEditorNovelImportFallbackChapterTitle(int index) {
    return '导入章节 $index';
  }

  @override
  String get projectEditorNovelImportQualityNoChaptersBlocker => '没有可导入的正文章节';

  @override
  String projectEditorNovelImportQualityTotalCharsTooLowBlocker(
    int totalChars,
  ) {
    return '正文总字数过少（$totalChars），疑似抽取失败';
  }

  @override
  String projectEditorNovelImportQualityAvgCharsTooLowBlocker(int avgChars) {
    return '平均章节字数过少（$avgChars），请先检查切章结果';
  }

  @override
  String projectEditorNovelImportQualityDuplicateHighBlocker(
    int duplicateRatioPercent,
  ) {
    return '章节正文重复比例过高（$duplicateRatioPercent%）';
  }

  @override
  String projectEditorNovelImportQualityDuplicatePartialWarning(
    int duplicateRatioPercent,
  ) {
    return '检测到部分重复正文（$duplicateRatioPercent%）';
  }

  @override
  String get projectEditorNovelImportQualitySingleChapterWarning =>
      '仅识别到 1 章，可能是整本未正确切章';

  @override
  String projectEditorNovelImportQualityManyChaptersWarning(int count) {
    return '章节数较多（$count），建议抽样检查切章准确性';
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
  String projectEditorNovelsActionBatchDeleteOk(int count) {
    return '已批量删除 $count 条章节。';
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
  String get projectEditorNovelsIntakeStatusValueDraft => '草稿';

  @override
  String get projectEditorNovelsIntakeStatusValuePendingReview => '待审核';

  @override
  String get projectEditorNovelsIntakeStatusValueAdmitted => '已通过';

  @override
  String get projectEditorNovelsIntakeStatusValueRejected => '已拒绝';

  @override
  String get projectEditorNovelsIntakeSourceValueManual => '手动';

  @override
  String get projectEditorNovelsIntakeSourceValueWholeBookImport => '整本导入';

  @override
  String get projectEditorNovelsIntakeSourceValueCrawlerClient => '爬虫（客户端）';

  @override
  String get projectEditorNovelsIntakeSourceValueCrawlerServer => '爬虫（服务端）';

  @override
  String get projectEditorNovelsProbeMutationGenerateEventsButton =>
      'POST generate-events（前 3 条）';

  @override
  String get projectEditorNovelsProbeMutationAddNovelEmptyButton =>
      'POST add-novel []';

  @override
  String get projectEditorNovelsProbeMutationBatchDeleteEmptyButton =>
      'POST batch-delete []';

  @override
  String get projectEditorNovelsProbeMutationDeleteNovelZeroButton =>
      'POST delete-novel id=0';

  @override
  String get projectEditorNovelsProbeMutationUpdateNovelNoopButton =>
      'POST update-novel（空改）';

  @override
  String projectEditorNovelsProbeMutationGenerateEventsSnackbar(String detail) {
    return 'POST …/novel-events/generate-events：$detail';
  }

  @override
  String get projectEditorNovelsProbeMutationAddNovelEmptySnackbar =>
      'POST …/novels/add-novel 空 data：无操作。';

  @override
  String get projectEditorNovelsProbeMutationBatchDeleteUnexpected200Snackbar =>
      'POST …/novels/batch-delete：unexpected 200';

  @override
  String get projectEditorNovelsProbeMutationBatchDeleteExpected400Snackbar =>
      'POST …/novels/batch-delete [] → 400（预期）';

  @override
  String get projectEditorNovelsProbeMutationDeleteNovelUnexpected200Snackbar =>
      'POST …/novels/delete-novel：unexpected 200';

  @override
  String get projectEditorNovelsProbeMutationDeleteNovelExpected400Snackbar =>
      'POST …/novels/delete-novel id=0 → 400（预期）';

  @override
  String projectEditorNovelsProbeMutationUpdateNovelNoopSnackbar(int id) {
    return 'POST …/novels/update-novel 空改 #$id 已完成。';
  }

  @override
  String get projectEditorNovelsCompatibilitySectionTitle => '兼容性检查';

  @override
  String get projectEditorNovelsCompatibilitySectionSubtitle =>
      '保留旧 Electron 形接口与事件回归入口，默认折叠';

  @override
  String get projectEditorNovelsCompatibilitySectionProbeHint => '小说 HTTP 探测';

  @override
  String get projectEditorNovelsProbeReadGetNovelButton => 'POST get-novel';

  @override
  String projectEditorNovelsProbeReadGetNovelSnackbarWithFirst(
    int total,
    int id,
    String chapter,
  ) {
    return 'POST …/novels/get-novel：total=$total · 首行 #$id $chapter';
  }

  @override
  String projectEditorNovelsProbeReadGetNovelSnackbarTotalOnly(int total) {
    return 'POST …/novels/get-novel：total=$total';
  }

  @override
  String get projectEditorNovelsProbeReadGetNovelDataButton =>
      'POST get-novel-data';

  @override
  String projectEditorNovelsProbeReadGetNovelDataSnackbar(int count) {
    return 'POST …/novels/get-novel-data：$count 条';
  }

  @override
  String get projectEditorNovelsProbeReadGetNovelIndexButton =>
      'POST get-novel-index';

  @override
  String projectEditorNovelsProbeReadGetNovelIndexSnackbar(int count) {
    return 'POST …/novels/get-novel-index：$count 条';
  }

  @override
  String get projectEditorNovelsProbeReadGetNovelEventStateButton =>
      'POST get-novel-event-state';

  @override
  String projectEditorNovelsProbeReadGetNovelEventStateSnackbar(int count) {
    return 'POST …/novels/get-novel-event-state：$count 条非 0 状态';
  }

  @override
  String get projectEditorNovelsProbeEventsGetEventsButton =>
      'POST events/get-events';

  @override
  String get projectEditorNovelsProbeEventsBatchDeleteEmptyButton =>
      'POST events/batch-delete []';

  @override
  String projectEditorNovelsProbeEventsGetEventsSnackbarWithFirst(
    int total,
    int id,
    String eventName,
  ) {
    return 'POST …/novels/events/get-events：total=$total · 首条 #$id $eventName';
  }

  @override
  String projectEditorNovelsProbeEventsGetEventsSnackbarTotalOnly(int total) {
    return 'POST …/novels/events/get-events：total=$total';
  }

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
  String storyboardEditorDialogTitle(int numericId) {
    return '分镜编辑器 #$numericId';
  }

  @override
  String get storyboardEditorPromptLabelClearEmpty => '分镜提示词（留空则清空）';

  @override
  String get storyboardEditorStateLabelClearEmpty => '状态（留空则清空）';

  @override
  String get storyboardEditorVideoDescLabelClearEmpty => '视频描述（留空则清空）';

  @override
  String get storyboardEditorSbIndexLabelClearEmpty => '分镜序号（留空则清空）';

  @override
  String get storyboardEditorShouldGenerateImageLabelClearEmpty =>
      '是否需要出图（留空则清空）';

  @override
  String get storyboardEditorDeleteConfirmTitle => '删除分镜？';

  @override
  String storyboardEditorDeleteConfirmBody(int id) {
    return '确定要删除分镜 $id 吗？';
  }

  @override
  String get storyboardEditorDialogCancel => '取消';

  @override
  String get storyboardEditorDialogConfirmDelete => '删除';

  @override
  String get storyboardEditorDeletedSnack => '分镜已删除';

  @override
  String get storyboardEditorSbIndexMustBeInteger => '分镜序号必须是整数';

  @override
  String get storyboardEditorShouldGenerateImageMustBeInteger => '是否需要出图必须是整数';

  @override
  String get storyboardEditorDeleteStoryboard => '删除分镜';

  @override
  String get storyboardEditorSaving => '保存中…';

  @override
  String get storyboardEditorSaveChanges => '保存修改';

  @override
  String get storyboardVideoWorkbenchTitle => '视频工作台';

  @override
  String get storyboardVideoWorkbenchTrackIdLabel => '轨道 ID';

  @override
  String get storyboardVideoWorkbenchTrackIdHelperNoTracks => '当前还没有已知轨道，可先新建。';

  @override
  String storyboardVideoWorkbenchTrackIdHelperKnown(String ids) {
    return '已知轨道 ID：$ids';
  }

  @override
  String get storyboardVideoWorkbenchNewTrackNameLabel => '新轨道名称';

  @override
  String get storyboardVideoWorkbenchNewTrackNameHelper => '新增后会自动回填轨道 ID。';

  @override
  String get storyboardVideoWorkbenchAddTrack => '新增轨道';

  @override
  String get storyboardVideoWorkbenchDeleteTrack => '删除轨道';

  @override
  String get storyboardVideoWorkbenchGenerateDefaultPrompt => '手动生成默认提示词';

  @override
  String get storyboardVideoWorkbenchPatchRegeneration => '局部返工';

  @override
  String get storyboardVideoWorkbenchApplyPromptRepairs => '手动应用生成前建议';

  @override
  String get storyboardVideoWorkbenchRefreshing => '刷新中…';

  @override
  String get storyboardVideoWorkbenchRefreshVideoDataManual => '手动刷新视频数据';

  @override
  String get storyboardVideoWorkbenchPrimaryHint =>
      '默认建议直接点「一键生成视频」。系统会自动补提示词、裁剪低收益片段、压缩重复负向约束并刷新结果；上面这些按钮保留给需要手动干预的场景。';

  @override
  String get storyboardVideoWorkbenchPatchAttributionHint =>
      '局部返工只提交最小修复范围；若命中 attribution mode，会返回归因提示，避免把单点问题误当全量重跑。';

  @override
  String get storyboardVideoWorkbenchQualityReviewCheckboxTitle =>
      '生成时自动记录质量评审样本';

  @override
  String get storyboardVideoWorkbenchQualityReviewCheckboxSubtitle =>
      '用于统计「命中表演/语气记忆优先策略」的通过率与坏例趋势。';

  @override
  String get storyboardVideoWorkbenchSubtitleLabel => '字幕/旁白文案';

  @override
  String get storyboardVideoWorkbenchSubtitleHelper =>
      '导出 SRT、时间线字幕和默认视频提示词会优先使用这里的内容。';

  @override
  String get storyboardVideoWorkbenchSaveSubtitle => '保存字幕/旁白文案';

  @override
  String get storyboardVideoWorkbenchRegenerateVoiceover => '重新生成配音';

  @override
  String get storyboardVideoWorkbenchGenerateVoiceover => '生成配音';

  @override
  String get storyboardVideoWorkbenchLiveActionRefsLabel => '真人参考镜头 URL（每行一条）';

  @override
  String get storyboardVideoWorkbenchLiveActionRefsHelper =>
      '真人模式会把这组参考镜头纳入 readiness；动漫模式可留空。';

  @override
  String get storyboardVideoWorkbenchPerformanceNotesLabel => '表演 / 口播约束';

  @override
  String get storyboardVideoWorkbenchPerformanceNotesHelper =>
      '例如停顿、情绪强度、镜头真实感、口型同步重点。';

  @override
  String get storyboardVideoWorkbenchSaveLiveAction => '保存真人参考与表演约束';

  @override
  String get storyboardVideoWorkbenchVideoPromptLabel => '视频生成提示词';

  @override
  String storyboardVideoWorkbenchRepairSuggestionsPrefix(String items) {
    return '生成前建议：$items';
  }

  @override
  String get storyboardVideoWorkbenchNegativePromptLabel => '负向提示词';

  @override
  String get storyboardVideoWorkbenchNegativePromptHelper =>
      '会自动回填当前分镜的失败约束，可按需继续删减或补充。';

  @override
  String get storyboardVideoWorkbenchDurationSecondsLabel => '时长（秒）';

  @override
  String get storyboardVideoWorkbenchResolutionLabel => '分辨率';

  @override
  String get storyboardVideoWorkbenchResolution1080p => '1080p';

  @override
  String get storyboardVideoWorkbenchResolution720p => '720p';

  @override
  String get storyboardVideoWorkbenchModeLabel => '生成模式';

  @override
  String get storyboardVideoWorkbenchModeStandard => '标准';

  @override
  String get storyboardVideoWorkbenchModeFast => '快速';

  @override
  String get storyboardVideoWorkbenchModelLabel => '模型';

  @override
  String get storyboardVideoWorkbenchModelLoading => '等待加载模型信息';

  @override
  String get storyboardVideoWorkbenchIncludeAudioTitle => '生成视频时携带音频';

  @override
  String get storyboardVideoWorkbenchGenerating => '生成中…';

  @override
  String get storyboardVideoWorkbenchGenerateVideoOneClick => '一键生成视频';

  @override
  String get storyboardVideoWorkbenchExportCurrentVideoJob => '导出当前视频（job）';

  @override
  String get storyboardVideoWorkbenchRefreshingExportJob => '刷新导出任务中…';

  @override
  String get storyboardVideoWorkbenchRefreshExportJobStatus => '刷新导出任务状态';

  @override
  String get storyboardVideoWorkbenchSingleTrackHint =>
      '若当前只发现 1 条可用轨道，提交时会自动回填，减少重复填写；存在多条轨道时仍保持手动选择，避免误生成。';

  @override
  String storyboardVideoWorkbenchLatestExportJobLine(
    int taskId,
    String status,
    String updatedAt,
  ) {
    return '最近导出任务：#$taskId · $status · $updatedAt';
  }

  @override
  String get storyboardVideoWorkbenchExportLinkPrefix => '导出链接：';

  @override
  String get storyboardVideoWorkbenchExportErrorPrefix => '导出错误：';

  @override
  String get storyboardVideoWorkbenchSelectedVideoHeading => '当前已选视频';

  @override
  String get storyboardVideoWorkbenchSelectedVideoDetailSelected =>
      '这条是当前分镜真正会继续导出和复用的视频版本。';

  @override
  String get storyboardVideoWorkbenchSelectedVideoDetailEmpty =>
      '当前还没有已选视频；可先从候选里设为当前，再继续返工或导出。';

  @override
  String get storyboardVideoWorkbenchExportSelectedVideo => '导出当前视频';

  @override
  String get storyboardVideoWorkbenchContinuePatch => '继续局部返工';

  @override
  String get storyboardVideoWorkbenchDeleteSelectedVideo => '删除当前已选视频';

  @override
  String get storyboardVideoWorkbenchPickCandidateFirst =>
      '先从下面的视频候选里选一条更满意的版本，后续返工会更聚焦。';

  @override
  String get storyboardVideoWorkbenchCandidatesHeading => '当前分镜的视频候选';

  @override
  String get storyboardVideoWorkbenchCandidatesEmpty =>
      '还没有与当前 storyboard 关联的已生成视频。';

  @override
  String get storyboardVideoWorkbenchCandidatesDetail =>
      '优先展示当前 storyboard 的视频结果；可直接设为当前，或继续局部返工。';

  @override
  String get storyboardVideoWorkbenchVideoUrlMissing => '视频 URL 缺失';

  @override
  String get storyboardVideoWorkbenchCandidateMetaCurrent => '当前生效中';

  @override
  String storyboardVideoWorkbenchCandidateMetaState(String state) {
    return '状态 $state';
  }

  @override
  String storyboardVideoWorkbenchCandidateMetaTrack(int trackId) {
    return '轨道 $trackId';
  }

  @override
  String storyboardVideoWorkbenchCandidateMetaDuration(String duration) {
    return '时长 $duration';
  }

  @override
  String get storyboardVideoWorkbenchCurrentSelectedBadge => '当前已选';

  @override
  String get storyboardVideoWorkbenchSetAsCurrentVideo => '设为当前视频';

  @override
  String get storyboardVideoWorkbenchPatchShort => '局部返工';

  @override
  String get storyboardVideoWorkbenchPatchContinue => '继续局部返工';

  @override
  String get storyboardVideoWorkbenchInFlightJobsHeading => '进行中的视频任务';

  @override
  String storyboardVideoWorkbenchWritebackSummaryNoPending(
    int scriptCount,
    int persistedCount,
    int inFlightCount,
  ) {
    return '成片回写概要：本分镜脚本共 $scriptCount 镜；已检测到片媒体路径 $persistedCount；进行中任务关联 $inFlightCount 镜。';
  }

  @override
  String storyboardVideoWorkbenchWritebackSummaryWithPending(
    int scriptCount,
    int persistedCount,
    int inFlightCount,
    int pendingCount,
  ) {
    return '成片回写概要：本分镜脚本共 $scriptCount 镜；已检测到片媒体路径 $persistedCount；进行中任务关联 $inFlightCount 镜，其中尚未回库的约 $pendingCount 镜（待 worker 完结）。';
  }

  @override
  String storyboardVideoWorkbenchJobSubtitle(String status, String updatedAt) {
    return '状态 $status · $updatedAt';
  }

  @override
  String get storyboardActionFollowUpPreviewMissing => '当前分镜还没有可读取的预览图。';

  @override
  String get storyboardActionFollowUpPreviewRead => '已读取当前分镜预览。';

  @override
  String get storyboardActionErrImageUrlRequired => '图片 URL 不能为空';

  @override
  String get storyboardActionFollowUpImageUrlSaved => '已保存当前图片 URL。';

  @override
  String get storyboardActionFollowUpLiveActionCleared => '已清空真人参考镜头与表演约束。';

  @override
  String storyboardActionFollowUpLiveActionSaved(int count) {
    return '已保存 $count 条真人参考镜头，并同步表演/口播约束。';
  }

  @override
  String get storyboardActionFollowUpFrameCleared => '已清空当前分镜画面。';

  @override
  String get storyboardActionErrTrackNameRequired => '轨道名称不能为空';

  @override
  String storyboardActionFollowUpTrackAdded(int trackId) {
    return '已新增轨道 #$trackId。';
  }

  @override
  String get storyboardActionErrTrackIdInvalid => '请填写有效轨道 ID';

  @override
  String storyboardActionFollowUpTrackDeleted(int trackId) {
    return '已删除轨道 #$trackId。';
  }

  @override
  String get storyboardActionFollowUpVideoSelectedBase => '已将当前候选视频设为分镜视频。';

  @override
  String get storyboardActionFollowUpVideoDeletedBase => '已删除当前分镜已选视频。';

  @override
  String get storyboardActionFollowUpTrackReady => '当前轨道 ID 已可直接用于视频生成。';

  @override
  String storyboardActionFollowUpTrackBackfilled(int trackId) {
    return '已回填轨道 $trackId，可继续确认视频参数。';
  }

  @override
  String storyboardActionFollowUpTrackNamePrefilled(int storyId) {
    return '分镜 $storyId 视频轨';
  }

  @override
  String get storyboardActionFollowUpTrackNameHint => '已预填新轨道名称，下一步可直接新增轨道。';

  @override
  String get storyboardActionFollowUpSyncProduction => '已同步当前分镜制作数据。';

  @override
  String get storyboardActionFollowUpRefreshVideo => '已刷新当前分镜的视频数据。';

  @override
  String get storyboardMemorySelectedPerfDistilled => '已提炼当前分镜的私有表演记忆。';

  @override
  String storyboardMemorySelectedPrivateParts(String parts) {
    return '已提炼私有记忆：$parts。';
  }

  @override
  String get storyboardMemoryPrivateScopeFooter =>
      '仅作用于当前用户、项目、剧本，后续会优先复用而不串别的短剧。';

  @override
  String get storyboardMemoryRejectedHeadEmpty => '已回写当前分镜的私有坏例约束。';

  @override
  String storyboardMemoryRejectedHeadAvoid(String avoid) {
    return '已回写私有坏例约束：$avoid。';
  }

  @override
  String storyboardMemoryRejectedFailures(int count) {
    return '累计失败 $count 次';
  }

  @override
  String storyboardMemoryRejectedRisks(String tags) {
    return '重点风险 $tags';
  }

  @override
  String get storyboardMemoryRejectedNegativeFooter =>
      '后续生成会优先复用当前用户、项目、剧本下的负向记忆。';

  @override
  String get storyboardAutoNegativeSourceReview => '自动负向来自最近评审坏例';

  @override
  String get storyboardAutoNegativeSourceRejectedMemory => '自动负向来自私有坏例记忆';

  @override
  String get storyboardAutoNegativeSourceBoth => '自动负向同时用了评审坏例和私有记忆';

  @override
  String get storyboardAutoNegativeSourcePendingObservation =>
      '自动负向来自最近一次 reject 观察兜底';

  @override
  String get storyboardAutoNegativeSourcePendingNoteOnly =>
      '当前还没正式负向词，只回带待观察失败提示';

  @override
  String get storyboardAutoNegativeSourceNone => '当前没有额外自动负向来源。';

  @override
  String storyboardMemoryScopeProject(int count) {
    return '项目 $count';
  }

  @override
  String storyboardMemoryScopeScript(int count) {
    return '剧本 $count';
  }

  @override
  String storyboardMemoryScopeRole(int count) {
    return '角色 $count';
  }

  @override
  String get storyboardPromptGenDefaultFilledDuration => '已生成默认视频提示词并回填时长';

  @override
  String storyboardPromptGenHitMemory(String scope) {
    return '命中$scope记忆';
  }

  @override
  String storyboardPromptGenNegativeTrimmed(int fragCount, int chars) {
    return '自动精简 $fragCount 条负向约束 / $chars chars';
  }

  @override
  String storyboardPromptSourceMemorySlim(
    int rows,
    int low,
    int dup,
    int visual,
  ) {
    return '自动瘦身 $rows 条（低信号 $low / 重复 $dup / 纯视觉 $visual）';
  }

  @override
  String storyboardPromptSourceNegativeSlim(int fragCount, int chars) {
    return '负向精简 $fragCount 条 / $chars chars';
  }

  @override
  String storyboardPromptSourceReviewFrags(int count) {
    return '评审 $count 条';
  }

  @override
  String storyboardPromptSourceMemoryFrags(int count) {
    return '记忆 $count 条';
  }

  @override
  String storyboardPromptAnchorRole(int count) {
    return '角色锚点 $count';
  }

  @override
  String storyboardPromptAnchorScene(int count) {
    return '场景锚点 $count';
  }

  @override
  String storyboardPromptAnchorTool(int count) {
    return '道具锚点 $count';
  }

  @override
  String storyboardPromptAnchorStyle(int count) {
    return '风格锚点 $count';
  }

  @override
  String storyboardPromptAnchorPrivateMemory(int count) {
    return '私有记忆 $count';
  }

  @override
  String storyboardPromptAnchorContinuity(int count) {
    return '连续性记忆 $count';
  }

  @override
  String get storyboardPromptAnchorReferenceFrame => '已引用当前画面';

  @override
  String get storyboardPromptAnchorEmpty => '当前提示词未命中额外锚点或记忆。';

  @override
  String storyboardDiagPromptChars(int chars) {
    return '提示词 $chars 字符';
  }

  @override
  String storyboardDiagNegativeLine(int chars, String tier) {
    return '负向 $chars（$tier）';
  }

  @override
  String storyboardDiagObservation(int chars) {
    return '观察 $chars';
  }

  @override
  String storyboardDiagMemoryStyle(int chars) {
    return '记忆 $chars';
  }

  @override
  String storyboardDiagNegativeSlimSaved(int chars) {
    return '负向精简 -$chars';
  }

  @override
  String storyboardDiagMemorySlimRemoved(int chars) {
    return '记忆精简 -$chars';
  }

  @override
  String get storyboardDiagDeliveryPriority => '优先交付 ✅';

  @override
  String storyboardDiagMemoryTier(String tier) {
    return '记忆档位 $tier';
  }

  @override
  String get storyboardBudgetHintNoReferenceFrame =>
      '当前提示词未绑定当前画面，先补参考帧再继续压缩，更稳。';

  @override
  String get storyboardBudgetHintOptimizationKeptDelivery =>
      '本次生成前已自动清掉重复/纯视觉私有记忆，优先保住了表演和语气锚点；继续补词时先别把这些省下来的预算又填回泛风格句。';

  @override
  String get storyboardBudgetHintProjectMemoryHeavy =>
      '这次主要命中项目级记忆，先把通用风格句收短一点，预算优先留给人物表演和当前镜头连续性。';

  @override
  String get storyboardBudgetHintRoleVsProject =>
      '角色级记忆已经命中，继续压缩时先动项目级泛化描述，别把角色表演和情绪锚点一起删掉。';

  @override
  String get storyboardBudgetHintDeliveryExpanded =>
      '已命中表演/语气优先记忆，先别删这段；优先压缩重复的场景/风格与连续性泛句，避免又回到“读稿腔”。';

  @override
  String storyboardBudgetHintSuppressedBucket(String bucket) {
    return '当前私有记忆里已压掉较多$bucket类重复片段，继续先收这类泛句，别先删角色表演记忆。';
  }

  @override
  String get storyboardBudgetHintPromptLong =>
      '当前提示词偏长，优先删重复场景/风格描述，先别动角色和关键道具锚点。';

  @override
  String get storyboardBudgetHintPrivateMemoryHeavy =>
      '当前提示词里的私有记忆占比已经不低，优先合并泛化风格句，别先删角色表演记忆。';

  @override
  String get storyboardBudgetHintRiskyShotExpanded =>
      '当前镜头被判定为高风险，先保留角色表演和连续性记忆，再压其他泛化描述。';

  @override
  String get storyboardBudgetHintNearLongPrompt =>
      '当前提示词已接近长 prompt，继续补充前先检查风格锚点和连续性记忆是否重复。';

  @override
  String get storyboardBudgetHintContinuityLong =>
      '连续性记忆已经偏长，先把重复的衔接描述压成更短的动作或表演锚点。';

  @override
  String get storyboardBudgetHintNegativeExpanded =>
      '当前镜头的防穿帮约束已切到 expanded，先保留人物一致性和镜头连续性，再压泛化负面词。';

  @override
  String get storyboardBudgetHintNegativeLeanLong =>
      '当前负向约束已经偏长，优先合并重复的情绪/光影警告，别先删身份一致性约束。';

  @override
  String get storyboardBudgetHintAutoNegativeDup =>
      '当前负向词已经自动带入评审和私有坏例，手动补词前先检查是否只是重复表达。';

  @override
  String get storyboardBudgetHintPendingObservation =>
      '这次已经自动继承最近失败观察，先看重试结果，别急着再补一串同义负面词。';

  @override
  String get storyboardBudgetHintNoAnchors => '当前提示词主要依赖分镜文案，缺少角色/场景锚点，画面更容易漂。';

  @override
  String get storyboardBudgetHintHealthy => '当前提示词预算仍可控，可继续优先保留人物表演、关键道具和情绪信息。';

  @override
  String get storyboardRepairSuggestReferenceFrame =>
      '先补当前参考帧，再压词；人物脸、服化道和站位会更稳。';

  @override
  String get storyboardRepairSuggestContinuity =>
      '连续性约束改成 1-2 条硬规则，只留机位、服化道和角色位置。';

  @override
  String get storyboardRepairSuggestDelivery => '保留表演/语气记忆，把情绪写成可演动作，别退回成读稿腔。';

  @override
  String get storyboardRepairSuggestTrimGeneric =>
      '优先删动作/光影泛句，把预算让给口型、微表情和人物一致性。';

  @override
  String get storyboardRepairSuggestNegativeReuse =>
      '沿用自动坏例负向约束，手动补词前先去重，避免同义词重复烧 token。';

  @override
  String get storyboardRepairSuggestMemoryReuse =>
      '这次已经命中项目/剧本私有坏例记忆，先复用它，别再堆一层共享长记忆。';

  @override
  String get storyboardRepairSuggestProjectMemoryTrim =>
      '这轮主要靠项目级通用记忆在撑，继续压词时优先缩短泛风格句。';

  @override
  String get storyboardRepairSuggestRoleMemoryKeep =>
      '已经命中角色级私有记忆，优先保住角色情绪和口型，别被项目级描述盖掉。';

  @override
  String get storyboardRepairSuggestAnchors => '补角色、场景或关键道具锚点，不然画面更容易漂和穿帮。';

  @override
  String get storyboardRepairSuggestHealthy => '当前预算可控，继续保留人物表演、关键道具和情绪细节。';

  @override
  String get storyboardActionRepairAppliedSummary => '已应用当前生成前建议。';

  @override
  String get storyboardActionRepairNoChangeSummary => '当前建议已经基本落实，无需再裁剪。';

  @override
  String storyboardActionRepairDetailTrimmed(
    int promptRemoved,
    int negRemoved,
  ) {
    return '本次精简了 $promptRemoved 条低收益提示词片段，并去掉 $negRemoved 条重复负向约束。';
  }

  @override
  String get storyboardActionRepairDetailLean =>
      '当前分镜的 prompt/negative prompt 已经比较精简，可直接继续生成。';

  @override
  String get storyboardActionOperationFailedSummary => '当前分镜操作失败。';

  @override
  String get storyboardActionOperationFailedDetail => '建议先完成当前推荐步骤后再重试。';

  @override
  String get storyboardActionErrNeedSourceImageOrPreview =>
      '生成视频前需要先提供图片 URL 或当前预览图';

  @override
  String get storyboardActionErrTrackIdRequired => '生成视频前请填写有效轨道 ID';

  @override
  String get storyboardActionErrDurationPositiveInteger => '视频时长必须是正整数';

  @override
  String get storyboardActionErrVideoPromptEmpty => '视频提示词不能为空';

  @override
  String storyboardActionVideoJobsSubmittedTotalOnly(int total) {
    return '已提交 $total 条视频任务。';
  }

  @override
  String storyboardActionVideoJobsSubmittedRepairOnly(
    int total,
    int pRm,
    int nRm,
  ) {
    return '已提交 $total 条视频任务，并在提交前自动精简 $pRm 条低收益 prompt 片段与 $nRm 条重复负向约束。';
  }

  @override
  String storyboardActionVideoJobsSubmittedDedupeOnly(int total, int deduped) {
    return '已提交 $total 条视频任务，并自动剔除 $deduped 条重复负向约束。';
  }

  @override
  String storyboardActionVideoJobsSubmittedRepairFinal(
    int total,
    int pRm,
    int nRm,
  ) {
    return '已提交 $total 条视频任务，提交前自动精简了 $pRm 条低收益 prompt 片段、$nRm 条重复负向约束，并回填最终负向提示词。';
  }

  @override
  String storyboardActionVideoJobsSubmittedDedupeFinal(int total, int deduped) {
    return '已提交 $total 条视频任务，自动剔除 $deduped 条重复负向约束，并回填最终负向提示词。';
  }

  @override
  String storyboardActionVideoJobsSubmittedFinalOnly(int total) {
    return '已提交 $total 条视频任务，并回填最终负向提示词。';
  }

  @override
  String storyboardActionVoiceoverJobsSubmitted(int total) {
    return '已提交 $total 条配音任务，可稍后刷新制作数据查看状态。';
  }

  @override
  String storyboardActionVoiceoverJobsSubmittedWithJob(
    int total,
    String jobId,
  ) {
    return '已提交 $total 条配音任务（job=$jobId），可稍后刷新制作数据查看状态。';
  }

  @override
  String get storyboardActionVideoDescCleared => '已清空字幕/旁白文案，导出时会回退到分镜提示词。';

  @override
  String get storyboardActionVideoDescSaved =>
      '已保存字幕/旁白文案，后续默认视频提示词和导出字幕会优先使用它。';

  @override
  String get storyboardActionErrNoExportableVideoUrl =>
      '当前分镜还没有可导出的已选视频或候选视频 URL';

  @override
  String storyboardActionExportJobEnqueued(String jobId) {
    return '已提交视频导出任务（job=$jobId）。完成后会写回当前分镜视频 URL，可稍后刷新制作数据查看。';
  }

  @override
  String get storyboardPatchDialogTitle => '局部返工面板';

  @override
  String get storyboardPatchScopeLabel => 'scope';

  @override
  String get storyboardPatchScopeHelper =>
      'episode / scene / storyboard_item / video_prompt / derive_asset';

  @override
  String get storyboardPatchModelTierLabel => 'model tier';

  @override
  String get storyboardPatchModelTierHelper => 'low 用于格式修复，high 用于内容质量修复';

  @override
  String get storyboardPatchTargetIdsLabel => 'target ids';

  @override
  String get storyboardPatchTargetIdsHelper =>
      '逗号分隔。默认带当前 storyboard numeric ID。';

  @override
  String get storyboardPatchReasonLabel => '返工原因';

  @override
  String get storyboardPatchReasonHelper => '建议明确写出人物、情绪、镜头、连续性、台词或视觉穿帮问题。';

  @override
  String get storyboardPatchScopeHint =>
      '提示：优先选择最小 scope；如果只是当前分镜的表演、镜头或提示词问题，先用 storyboard_item / video_prompt，不要直接放大到整集。';

  @override
  String get storyboardPatchAttributionLabel => 'attribution mode:';

  @override
  String get storyboardPatchRepairPriorityHeading => '返工优先级：';

  @override
  String get storyboardPatchSnackNeedTargetId => '请至少填写一个合法 target id';

  @override
  String get storyboardPatchSnackNeedReason => '请填写返工原因';

  @override
  String storyboardPatchSubmitLine(
    String patchId,
    String scope,
    String ids,
    String modelTier,
    String status,
    int failures,
    int tokens,
    String memorySuffix,
  ) {
    return '已提交 patch #$patchId · scope=$scope · ids=$ids · model=$modelTier · status=$status · 连续失败 $failures 次 · 预计节省 $tokens token$memorySuffix';
  }

  @override
  String get storyboardPatchMemoryWrittenSuffix => ' · 已写入归因记忆';

  @override
  String get storyboardPatchAttributionUpstreamHint =>
      '当前请求已进入问题归因模式，请先处理上游原因。';

  @override
  String get storyboardPatchFollowUpAttribution =>
      '局部返工已提交，并进入 attribution mode。优先按面板里的 P1/P2 顺序处理，不要直接整段重跑。';

  @override
  String get storyboardPatchFollowUpQueued => '局部返工已提交，当前按最小范围排队处理。';

  @override
  String get storyboardPatchSubmitting => '提交中…';

  @override
  String get storyboardPatchSubmit => '提交返工';

  @override
  String get storyboardPatchDefaultReason => '请修复当前分镜的内容质量、连续性或情绪表达问题';

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
  String get shortVideoMetricStoryboardReadiness => '分镜就绪';

  @override
  String get shortVideoShotReadinessSelectProjectHint =>
      '选择短剧项目后，会显示服务端分镜阻塞汇总。';

  @override
  String get shortVideoTaskUnnamed => '未命名任务';

  @override
  String get shortVideoBadCaseUncategorized => '未分类';

  @override
  String get shortVideoQualityNoSignalAnimated =>
      '质量评审还没有收敛出明显信号，后续会在这里提醒画风一致性、角色连续性和镜头节奏风险。';

  @override
  String get shortVideoQualityNoSignalLive =>
      '质量评审还没有收敛出明显信号，后续会在这里提醒表演自然度、真实感和口播节奏风险。';

  @override
  String shortVideoQualityInsightAnimated(String passRate, int badCount) {
    return '当前项目自动/人工评审通过率约 $passRate%，已记录 $badCount 条坏例；继续重点盯角色一致性、画面连续性和镜头节奏。';
  }

  @override
  String shortVideoQualityInsightLive(String passRate, int badCount) {
    return '当前项目自动/人工评审通过率约 $passRate%，已记录 $badCount 条坏例；继续重点盯表演自然度、场景真实感和口播镜头质感。';
  }

  @override
  String get shortVideoReadinessGapAllReadyAnimated =>
      '动漫短剧的基础准备项已经齐了，可以直接推进脚本、制作和质检闭环。';

  @override
  String get shortVideoReadinessGapAllReadyLive =>
      '真人短剧的基础准备项已经齐了，可以继续推进镜头生成、口播和成片复核。';

  @override
  String shortVideoReadinessGapAndMore(int count) {
    return ' 等 $count 项';
  }

  @override
  String shortVideoReadinessGapMissing(String labels, String more) {
    return '当前还缺 $labels$more，建议先回项目区把这些准备项补齐。';
  }

  @override
  String get shortVideoReadinessLabelScriptBase => '剧本基础';

  @override
  String shortVideoReadinessDetailScriptsHas(int count) {
    return '已有 $count 份剧本';
  }

  @override
  String get shortVideoReadinessDetailScriptsMissing => '还没有第一版剧本';

  @override
  String get shortVideoReadinessAnimLabelRoleAssets => '角色资产';

  @override
  String shortVideoReadinessDetailRolesHas(int count) {
    return '已有 $count 个角色资产';
  }

  @override
  String get shortVideoReadinessDetailRolesMissingAnim => '还缺角色资产';

  @override
  String get shortVideoReadinessLiveLabelRoleSetup => '角色设定';

  @override
  String get shortVideoReadinessDetailRolesMissingLive => '还缺角色设定 / 角色资产';

  @override
  String get shortVideoReadinessLabelSceneAssets => '场景资产';

  @override
  String shortVideoReadinessDetailScenesHas(int count) {
    return '已有 $count 个场景资产';
  }

  @override
  String get shortVideoReadinessDetailScenesMissingAnim => '还缺场景资产';

  @override
  String get shortVideoReadinessDetailScenesMissingLive => '还缺真人场景参考';

  @override
  String get shortVideoReadinessAnimLabelVisualStyle => '画风信号';

  @override
  String shortVideoReadinessDetailVisualConfigured(String name) {
    return '已配置 $name';
  }

  @override
  String get shortVideoReadinessDetailVisualMissingAnim => '还没收口画风 / 视觉风格';

  @override
  String get shortVideoReadinessLiveLabelVisualManual => '视觉手册';

  @override
  String get shortVideoReadinessDetailVisualMissingLive => '还没收口真人视觉风格';

  @override
  String get shortVideoReadinessFallbackStylePack => '画风或风格包';

  @override
  String get shortVideoReadinessFallbackDirectorPack => '导演手册或故事风格包';

  @override
  String get shortVideoReadinessFallbackLiveVisualPack => '视觉风格或风格包';

  @override
  String get shortVideoReadinessAnimLabelDirectorManual => '导演手册';

  @override
  String get shortVideoReadinessLiveLabelPerformanceManual => '表演 / 口播手册';

  @override
  String shortVideoReadinessDetailDirectorConfigured(String name) {
    return '已配置 $name';
  }

  @override
  String get shortVideoReadinessDetailDirectorMissingAnim => '还没收口导演手册';

  @override
  String get shortVideoReadinessDetailPerformanceMissingLive =>
      '还没收口口播语气 / 导演手册';

  @override
  String get shortVideoReadinessAnimLabelStoryboardBase => '分镜基础';

  @override
  String shortVideoReadinessDetailStoryboardsHas(int count) {
    return '已有 $count 条分镜';
  }

  @override
  String get shortVideoReadinessDetailStoryboardsMissing => '还没有分镜结构';

  @override
  String get shortVideoReadinessLiveLabelClipRefs => '镜头素材';

  @override
  String shortVideoReadinessDetailClipsHas(int count) {
    return '已有 $count 份 clip 参考';
  }

  @override
  String get shortVideoReadinessDetailClipsMissing => '还缺真人镜头 / clip 参考';

  @override
  String get shortVideoAssetTypeRole => '角色';

  @override
  String get shortVideoAssetTypeScene => '场景';

  @override
  String get shortVideoAssetTypeTool => '道具';

  @override
  String get shortVideoAssetTypeClip => '镜头';

  @override
  String get shortVideoAssetTypeOther => '其他';

  @override
  String get shortVideoAssetsOverviewLoadingHeadline => '正在读取资产总览…';

  @override
  String get shortVideoAssetsOverviewLoadingDetail =>
      '按资产类型汇总数量，并聚合关联剧本号（app_script_asset）。';

  @override
  String get shortVideoAssetsOverviewUnavailableHeadline => '资产总览暂不可用。';

  @override
  String get shortVideoAssetsOverviewUnavailableDetail =>
      '可稍后刷新，或在项目区维护资产与剧本挂载关系。';

  @override
  String get shortVideoAssetsOverviewNoLinkedScripts => '暂无关联剧本';

  @override
  String get shortVideoAssetsOverviewScriptsPrefix => '剧本 ';

  @override
  String get shortVideoAssetsOverviewScriptsEllipsis => '…';

  @override
  String shortVideoAssetsOverviewTypeLine(
    String type,
    int count,
    String scriptPart,
  ) {
    return '$type · $count 条 · $scriptPart';
  }

  @override
  String shortVideoAssetsOverviewHeadline(int total) {
    return '共 $total 条资产，按类型分组（实验剧本挂载关系见每行「剧本」摘要）。';
  }

  @override
  String get shortVideoAssetsOverviewFooter =>
      '数据来自只读聚合接口；候选状态维护仍在项目区 PATCH 资产。';

  @override
  String get shortVideoCandidateCompareLoadingHeadline => '正在整理分镜候选与当前版本…';

  @override
  String get shortVideoCandidateCompareLoadingDetail =>
      '会按分镜聚合参考图、当前视频、readiness 与质量评审摘要。';

  @override
  String get shortVideoCandidateCompareUnavailableHeadline => '当前还没有可对比的分镜候选。';

  @override
  String get shortVideoCandidateCompareUnavailableDetail =>
      '先在制作工作区生成镜头或补参考图，再回到 Space 查看对比。';

  @override
  String get shortVideoCandidateQualityNoReviewsLive =>
      '暂无质检记录，先盯表演自然度、真实感和口播镜头质感。';

  @override
  String get shortVideoCandidateQualityNoReviewsAnimated =>
      '暂无质检记录，先盯角色一致性、画面连续性和镜头节奏。';

  @override
  String shortVideoCandidateQualitySummary(int total, int passed, int bad) {
    return '评审 $total 条 · 通过 $passed 条 · 坏例 $bad 条';
  }

  @override
  String shortVideoCandidateCompareHeadline(int count) {
    return '优先对比 $count 条分镜的当前版本、参考图与质检状态。';
  }

  @override
  String get shortVideoCandidateCompareDetailLive =>
      '真人模式会额外展示参考镜头与表演/口播约束命中情况，方便先锁住真实感与演员感。';

  @override
  String get shortVideoCandidateCompareDetailAnimated =>
      '先看哪几条分镜缺参考、缺当前视频或命中过多坏例，再决定去制作台局部返工。';

  @override
  String get shortVideoSpaceModeTitleAnimated => '动漫短剧';

  @override
  String get shortVideoSpaceModeTitleLive => '真人短剧';

  @override
  String get shortVideoSpaceModeSummaryAnimated =>
      '当前主链路更贴近动漫短剧，所以会优先强调画风、角色一致性、分镜出图和连续性。';

  @override
  String get shortVideoSpaceModeSummaryLive =>
      '真人短剧也应该成为同一个 Space 里的标准模式，后续重点会转向演员感、场景真实度、镜头参考和口播质感。';

  @override
  String get shortVideoSpaceModeAdviceAnimated =>
      '建议先准备画风、视觉手册和角色资产，再进入脚本与制作流程。';

  @override
  String get shortVideoSpaceModeAdviceLive =>
      '建议先准备真人参考图、角色设定、镜头语气和视觉手册，再进入脚本与制作流程。';

  @override
  String get shortVideoProjectOptionUnnamed => '未命名项目';

  @override
  String get shortVideoMetricScript => '剧本';

  @override
  String get shortVideoMetricStoryboard => '分镜';

  @override
  String get shortVideoMetricRole => '角色';

  @override
  String get shortVideoMetricNovel => '小说';

  @override
  String get shortVideoMetricVideo => '视频';

  @override
  String get shortVideoMetricRecentTasks => '最近任务';

  @override
  String get shortVideoMetricGenerationJobs => '生成任务';

  @override
  String get shortVideoMetricInProgress => '进行中';

  @override
  String get shortVideoMetricFailed => '失败';

  @override
  String get shortVideoMetricBadCases => '坏例';

  @override
  String get shortVideoMetricPassRate => '通过率';

  @override
  String get shortVideoMetricScenes => '场景';

  @override
  String get shortVideoMetricClips => 'clip';

  @override
  String get shortVideoReadinessIntroAnimated => '动漫短剧更看重画风、角色和分镜连续性。';

  @override
  String get shortVideoReadinessIntroLive => '真人短剧更看重角色设定、场景参考、clip 镜头素材和口播手册。';

  @override
  String get shortVideoStageCard1Title => '1. 立项';

  @override
  String get shortVideoStageCard1Status => '现在可用';

  @override
  String get shortVideoStageCard1DetailAnimated => '从项目开始收口题材、画风、创作手册和角色资产。';

  @override
  String get shortVideoStageCard1DetailLive => '从项目开始收口题材、真人参考、创作手册和角色设定。';

  @override
  String get shortVideoStageCard2Title => '2. 生成脚本';

  @override
  String get shortVideoStageCard2Status => '现在可用';

  @override
  String get shortVideoStageCard2DetailAnimated =>
      '复用脚本工作区的上下文探测、子 Agent 和正文回写。';

  @override
  String get shortVideoStageCard2DetailLive => '复用脚本工作区生成更贴近口播、表演和场景调度的脚本版本。';

  @override
  String get shortVideoStageCard3Title => '3. 组织素材';

  @override
  String get shortVideoStageCard3Status => '适合下一步补齐';

  @override
  String get shortVideoStageCard3DetailAnimated =>
      '把素材检索、资产出图、镜头候选和旁白草稿收成同一段流程。';

  @override
  String get shortVideoStageCard3DetailLive => '把真人参考图、镜头候选、旁白草稿和素材筛选收成同一段流程。';

  @override
  String get shortVideoStageCard4Title => '4. 出片与复核';

  @override
  String get shortVideoStageCard4Status => '基础已在';

  @override
  String get shortVideoStageCard4DetailAnimated =>
      '挂接制作工作区、任务中心和质量评审，形成可追踪的成片闭环。';

  @override
  String get shortVideoStageCard4DetailLive =>
      '挂接制作工作区、任务中心和质量评审，重点补演员一致性与真实感复核。';

  @override
  String get shortVideoMigrationSummaryAnimated =>
      '先做单入口，再补链路。第一波只编排现有项目、脚本、制作、任务、质检能力；第二波再补自动旁白、字幕样式和一键成片。';

  @override
  String get shortVideoMigrationSummaryLive =>
      '真人模式也先走同一入口。第一波先把用户选择显式化，后面再补真人参考素材、口播语气、镜头真实度和成片验收规则。';

  @override
  String get shortVideoFilterPanelSearchHint => '搜索字幕或旁白内容... (Ctrl+F / Cmd+F)';

  @override
  String get shortVideoFilterPanelClearButton => '清除';

  @override
  String get shortVideoFilterPanelSavePresetButton => '保存预设';

  @override
  String get shortVideoFilterPanelApplyPresetTooltip => '应用预设';

  @override
  String get shortVideoFilterPanelDeletePresetTooltip => '删除预设';

  @override
  String get shortVideoFilterPanelSearchScopeLabel => '搜索范围：';

  @override
  String get shortVideoFilterPanelSearchChipSubtitle => '字幕';

  @override
  String get shortVideoFilterPanelSearchChipVoiceover => '旁白';

  @override
  String get shortVideoFilterPanelStatusLabel => '状态过滤';

  @override
  String get shortVideoFilterPanelQualityLabel => '质量过滤';

  @override
  String get shortVideoFilterPanelDropdownAll => '全部';

  @override
  String shortVideoFilterPanelDropdownSelectedCount(int count) {
    return '已选 $count 项';
  }

  @override
  String shortVideoFilterActiveTagSearch(String keyword) {
    return '搜索: $keyword';
  }

  @override
  String shortVideoFilterPresetPartSearch(String keyword) {
    return '搜索: $keyword';
  }

  @override
  String shortVideoFilterPresetPartStatusCount(int count) {
    return '$count个状态';
  }

  @override
  String shortVideoFilterPresetPartQualityCount(int count) {
    return '$count个质量';
  }

  @override
  String get shortVideoFilterPresetSummaryEmpty => '无过滤条件';

  @override
  String get shortVideoFilterSnackbarNoActiveFilters => '当前没有活动的过滤条件';

  @override
  String shortVideoFilterSnackbarPresetSaved(String name) {
    return '预设 \"$name\" 已保存';
  }

  @override
  String shortVideoFilterSnackbarPresetApplied(String name) {
    return '已应用预设 \"$name\"';
  }

  @override
  String shortVideoFilterSnackbarPresetDeleted(String name) {
    return '预设 \"$name\" 已删除';
  }

  @override
  String get shortVideoFilterSaveDialogTitle => '保存过滤预设';

  @override
  String get shortVideoFilterSaveDialogNameLabel => '预设名称';

  @override
  String get shortVideoFilterSaveDialogNameHint => '例如：已启用且有视频';

  @override
  String get shortVideoFilterStatusEnabled => '已启用';

  @override
  String get shortVideoFilterStatusDisabled => '已禁用';

  @override
  String get shortVideoFilterStatusHasVideo => '有视频';

  @override
  String get shortVideoFilterStatusNoVideo => '无视频';

  @override
  String get shortVideoFilterStatusHasDuration => '有时长';

  @override
  String get shortVideoFilterStatusNoDuration => '无时长';

  @override
  String get shortVideoFilterStatusHasSubtitle => '有字幕';

  @override
  String get shortVideoFilterStatusNoSubtitle => '无字幕';

  @override
  String get shortVideoFilterStatusHasVoiceover => '有配音';

  @override
  String get shortVideoFilterStatusNoVoiceover => '无配音';

  @override
  String get shortVideoFilterStatusVoiceoverFailed => '配音失败';

  @override
  String get shortVideoFilterQualityHasBadExample => '有坏例';

  @override
  String get shortVideoFilterQualityNoBadExample => '无坏例';

  @override
  String get shortVideoFilterQualityGenerationStage => '生成阶段';

  @override
  String get shortVideoFilterQualityPostProductionStage => '后期阶段';

  @override
  String get shortVideoFilterQualityHasDegradation => '有退化';

  @override
  String get shortVideoFilterQualityNoDegradation => '无退化';

  @override
  String get shortVideoSpacePageTitle => '短视频 Space';

  @override
  String get shortVideoSpacePageSubtitle =>
      '参考 MoneyPrinterTurbo 的长处，先把“主题到成片”的链路聚成一个入口，再逐步把脚本、素材、旁白、字幕和质检串成标准流程。';

  @override
  String get shortVideoSpaceSectionCreativeMode => '创作模式';

  @override
  String get shortVideoSpaceSectionModeReadiness => '模式准备度';

  @override
  String get shortVideoSpaceReadinessReadyChip => '已就绪';

  @override
  String get shortVideoSpaceSectionShotReadinessServer => '分镜生成就绪（服务端）';

  @override
  String get shortVideoSpaceShotReadinessLoading => '正在读取分镜就绪聚合…';

  @override
  String get shortVideoSpaceShotReadinessUnavailableHint =>
      '分镜就绪摘要暂不可用，其余概览仍有效。';

  @override
  String get shortVideoSpaceShotReadinessPriorityShots => '优先处理的分镜';

  @override
  String get shortVideoSpaceOpenProductionBoardButton => '打开制作工作区分镜';

  @override
  String get shortVideoSpaceSectionSuggestedNext => '建议下一步';

  @override
  String get shortVideoSpaceSectionMigrationOrder => '建议迁移顺序';

  @override
  String get shortVideoSpaceNavProjects => '项目';

  @override
  String get shortVideoSpaceNavScriptWorkspace => '脚本工作区';

  @override
  String get shortVideoSpaceNavProductionWorkspace => '制作工作区';

  @override
  String get shortVideoSpaceNavTaskCenter => '任务中心';

  @override
  String get shortVideoSpaceNavQualityReviews => '质量评审';

  @override
  String shortVideoCandidateCompareStoryboardOnly(int id) {
    return '分镜 #$id';
  }

  @override
  String shortVideoCandidateCompareStoryboardWithScript(
    int storyboardId,
    int scriptId,
  ) {
    return '分镜 #$storyboardId · 脚本 #$scriptId';
  }

  @override
  String get shortVideoCandidateReferenceImageNotPreviewable => '参考图不可预览';

  @override
  String shortVideoCandidateLiveRefShotCount(int count) {
    return '真人参考镜头 $count 条';
  }

  @override
  String get shortVideoCandidateCurrentVideo => '当前视频';

  @override
  String get shortVideoCandidateSetCurrent => '设为当前';

  @override
  String get shortVideoCandidatePartialRework => '局部返工';

  @override
  String get shortVideoDeliveryModeLive => '真实 ✓';

  @override
  String get shortVideoDeliveryModeSandbox => '沙盒 ⚠️';

  @override
  String get shortVideoDeliveryModeManualBridge => '人工 👤';

  @override
  String get shortVideoDeliveryModeUnknown => '未知';

  @override
  String get shortVideoPublishPlatformDouyin => '抖音';

  @override
  String get shortVideoPublishPlatformBilibili => '哔哩哔哩';

  @override
  String get shortVideoPublishPlatformXiaohongshu => '小红书';

  @override
  String get shortVideoPublishPlatformWeixinChannels => '视频号';

  @override
  String get shortVideoPublishPlatformKuaishou => '快手';

  @override
  String get shortVideoPublishPlatformTiktok => 'TikTok';

  @override
  String get shortVideoPublishPlatformYoutubeShorts => 'YouTube Shorts';

  @override
  String get shortVideoPublishPlatformInstagramReels => 'Instagram Reels';

  @override
  String get shortVideoPublishPlatformFacebookReels => 'Facebook Reels';

  @override
  String get shortVideoSpaceAspectRatioPortrait916 => '竖屏 9:16';

  @override
  String get shortVideoSpaceAspectRatioLandscape169 => '横屏 16:9';

  @override
  String get shortVideoSpaceAspectRatioSquare11 => '方屏 1:1';

  @override
  String get shortVideoSpacePublishMarketPlatformTitle => '默认发布市场 / 平台';

  @override
  String get shortVideoSpaceTargetMarketLabel => '目标市场';

  @override
  String get shortVideoSpaceTargetMarketDomestic => '国内';

  @override
  String get shortVideoSpaceTargetMarketOverseas => '海外';

  @override
  String get shortVideoSpaceTargetMarketBoth => '双端';

  @override
  String get shortVideoSpaceTargetPlatformsHint => '目标平台（至少选一个；写回项目供分发与校验共用）';

  @override
  String get shortVideoSpaceDurationStrategyTitle => '时长策略';

  @override
  String get shortVideoSpaceDurationShort => '短';

  @override
  String get shortVideoSpaceDurationMedium => '中';

  @override
  String get shortVideoSpaceDurationLong => '长';

  @override
  String get shortVideoSpaceVoiceSubtitleBgmTitle => '旁白 / 字幕 / BGM（项目级默认）';

  @override
  String get shortVideoSpaceVoiceProfileLabel => '声线标识 voice_profile';

  @override
  String get shortVideoSpaceVoiceProfileHint => '如 default_narrator（可留空）';

  @override
  String get shortVideoSpaceSubtitleStyleLabel => '字幕样式 subtitle_style';

  @override
  String get shortVideoSpaceBgmStrategyLabel => 'BGM 策略 bgm_strategy';

  @override
  String get shortVideoSpaceCreatingProject => '新建中';

  @override
  String get shortVideoSpaceCreateProjectDirect => '直接新建短剧项目';

  @override
  String get shortVideoSpaceSavingProjectConfig => '保存中';

  @override
  String get shortVideoSpaceSaveProjectConfigWriteback => '写回项目配置';

  @override
  String get shortVideoSpaceOpenProjectsRefine => '打开项目区继续细化';

  @override
  String get shortVideoSpaceLoadingProjectReadiness => '正在读取当前项目准备度…';

  @override
  String get shortVideoSpaceMetricChipVisual => '视觉';

  @override
  String get shortVideoSpaceMetricChipManual => '手册';

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
  String get storyboardExportBundleSidecarList =>
      'manifest.json / storyboard.csv / timeline.json / subtitles.srt / voiceover_script.txt / voiceover_segments.json / assembly_plan.json';

  @override
  String storyboardExportBundleSubtitleCoverage(
    int explicitCount,
    int promptFallbackCount,
    int placeholderCount,
  ) {
    return '字幕来源：$explicitCount 条旁白文案 / $promptFallbackCount 条提示词回退 / $placeholderCount 条占位文本';
  }

  @override
  String storyboardExportBundleVoiceoverCoverage(
    int scriptedCount,
    int placeholderCount,
  ) {
    return '旁白脚本：$scriptedCount 条可用文案 / $placeholderCount 条占位文案';
  }

  @override
  String storyboardExportBundleAudioDelivery(
    int readyCount,
    int placeholderCount,
  ) {
    return '音频交付：$readyCount 条可直接配音 / $placeholderCount 条仍是占位文本';
  }

  @override
  String storyboardExportBundleVoiceoverJson(
    int readyCount,
    int placeholderCount,
  ) {
    return '配音 JSON：$readyCount 条可直接投喂 / $placeholderCount 条仍需补文案';
  }

  @override
  String storyboardExportBundleAssemblyPlan(
    int readyCount,
    int placeholderCount,
  ) {
    return '成片计划：$readyCount 条镜头带可用音频 / $placeholderCount 条镜头仍待补音频';
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
  String get projectScriptPlanCoverageNoChaptersNoEvents =>
      '当前还没有章节与事件，可先从内容接入区导入并生成事件。';

  @override
  String projectScriptPlanCoverageChaptersNoEventsYet(int chapterCount) {
    return '当前有 $chapterCount 条章节，但还没有事件；建议先生成事件后再整理骨架。';
  }

  @override
  String get projectScriptPlanCoverageChaptersNotLoaded => '暂未加载章节';

  @override
  String projectScriptPlanCoverageChaptersProgress(int covered, int total) {
    return '覆盖 $covered/$total 条章节';
  }

  @override
  String projectScriptPlanCoverageEventsSummary(
    int eventCount,
    String coverage,
    String sampleSuffix,
  ) {
    return '当前 $eventCount 条事件，$coverage$sampleSuffix';
  }

  @override
  String get projectScriptPlanDraftsSummaryEmpty => '当前还没有可生成的剧本初稿，先补章节或事件。';

  @override
  String projectScriptPlanDraftsSummary(
    int draftCount,
    int chapterCount,
    String sampleSuffix,
  ) {
    return '已生成 $draftCount 份剧本初稿，覆盖 $chapterCount 条章节$sampleSuffix';
  }

  @override
  String get projectScriptPlanGuidanceSummaryEmpty =>
      '当前还没有结构化改写 guidance，先生成剧本初稿或补齐章节事件。';

  @override
  String projectScriptPlanGuidanceSummary(
    int guidanceCount,
    String sampleSuffix,
  ) {
    return '已生成 $guidanceCount 份结构化改写 guidance$sampleSuffix';
  }

  @override
  String get projectScriptPlanSkeletonOpeningHookLabel => '开场钩子：';

  @override
  String get projectScriptPlanSkeletonOpeningHookZeroChapters =>
      '用一句话交代主角所处困局，并在前 30 秒抛出反常动作或危险信号。';

  @override
  String projectScriptPlanSkeletonOpeningHookWithChapters(int chapterSpan) {
    return '围绕前 $chapterSpan 条章节快速建立人物处境，并在首屏给出强钩子。';
  }

  @override
  String get projectScriptPlanSkeletonCorePushLabel => '核心推进：';

  @override
  String get projectScriptPlanSkeletonCoreEmptyLine1 =>
      '- 先从章节中提炼 3-5 个关键事件节点，按“冲突升级 -> 误判 -> 反转”排序。';

  @override
  String get projectScriptPlanSkeletonCoreEmptyLine2 =>
      '- 每个节点只保留推动人物关系或局势变化的动作，不要复述原文。';

  @override
  String projectScriptPlanSkeletonEventLine(
    String name,
    String chapterIndexes,
    String detail,
  ) {
    return '- $name（章节 $chapterIndexes）：$detail';
  }

  @override
  String get projectScriptPlanSkeletonEventDetailFallback =>
      '补充该事件如何改变人物处境与下一步目标。';

  @override
  String get projectScriptPlanSkeletonClosingLabel => '结尾翻点：';

  @override
  String get projectScriptPlanSkeletonClosingBullet =>
      '- 让最后一个节点留下未兑现的情绪账或更大的外部压力，形成下一集追更动机。';

  @override
  String get projectScriptPlanAdaptPeopleLabel => '人物策略：';

  @override
  String get projectScriptPlanAdaptPeopleLine1 =>
      '- 主角情绪变化要有台阶，不要从头到尾同一强度；每次反应都对应具体刺激。';

  @override
  String get projectScriptPlanAdaptPeopleLine2 =>
      '- 配角只保留能放大主角选择压力的人物，避免信息型路人。';

  @override
  String get projectScriptPlanAdaptPacingLabel => '节奏策略：';

  @override
  String get projectScriptPlanAdaptPacingNoEvents =>
      '- 先按章节切出 3-5 个强动作节点，再压缩成短剧节奏。';

  @override
  String projectScriptPlanAdaptPacingWithEvents(int eventCount) {
    return '- 当前已有 $eventCount 条事件，优先保留冲突强、身份变化大、情绪反差明显的节点。';
  }

  @override
  String get projectScriptPlanAdaptPacingNoChapters =>
      '- 保持单集只解决一个核心问题，并把更大的危机留到尾部。';

  @override
  String projectScriptPlanAdaptPacingWithChapters(int chapterCount) {
    return '- 当前 $chapterCount 条章节不做平铺直叙，按“前快中压后翻”重排信息释放。';
  }

  @override
  String get projectScriptPlanAdaptVoiceLabel => '表达策略：';

  @override
  String get projectScriptPlanAdaptVoiceLine1 => '- 对话要口语化、有目的，避免解释剧情式复述。';

  @override
  String get projectScriptPlanAdaptVoiceLine2 =>
      '- 画面与动作优先服务人物状态和情绪变化，不做空镜头堆砌。';

  @override
  String projectScriptPlanDraftEpisodeNumbered(int episodeNumber) {
    return '第$episodeNumber集';
  }

  @override
  String get projectScriptPlanDraftChapterPendingSummary => '待补章节依据';

  @override
  String projectScriptPlanDraftChapterSummaryPlainIndex(int index) {
    return '章节 $index';
  }

  @override
  String projectScriptPlanDraftChapterSummaryTitled(int index, String title) {
    return '章节 $index《$title》';
  }

  @override
  String get projectScriptPlanDraftSkeletonFallback =>
      '前段快速抛钩子，中段连续加压，尾段留下更大的情绪账。';

  @override
  String get projectScriptPlanDraftStrategyFallback => '对白口语化、动作带情绪、信息通过冲突释放。';

  @override
  String projectScriptPlanDraftBeatFromChapterPlain(int index) {
    return '- 从 章节 $index 提炼一个能推动关系或处境变化的动作节点。';
  }

  @override
  String projectScriptPlanDraftBeatFromChapterTitled(String title) {
    return '- 从 《$title》 提炼一个能推动关系或处境变化的动作节点。';
  }

  @override
  String get projectScriptPlanDraftEventNameFallback => '关键事件';

  @override
  String get projectScriptPlanDraftEventDetailFallback =>
      '补充该事件带来的情绪变化、行动选择和局势变化。';

  @override
  String projectScriptPlanDraftEventBeat(String name, String detail) {
    return '- $name：$detail';
  }

  @override
  String get projectScriptPlanDraftEndingNoEvents =>
      '在最后一个动作后补一个未说透的发现、误会或反击前奏。';

  @override
  String projectScriptPlanDraftEndingAfterEvent(String eventName) {
    return '把“$eventName”后的余波留到结尾，让人物以为稳住了，实际更危险。';
  }

  @override
  String get projectScriptPlanDraftHdrPositioning => '【剧本定位】';

  @override
  String projectScriptPlanDraftPositioningBody(
    String packetName,
    String chapterSummary,
  ) {
    return '$packetName：围绕 $chapterSummary 压缩成一集短剧，首屏先给冲突，结尾必须留钩子。';
  }

  @override
  String get projectScriptPlanDraftHdrSkeleton => '【骨架约束】';

  @override
  String get projectScriptPlanDraftHdrAdaptation => '【改编口径】';

  @override
  String get projectScriptPlanDraftHdrBeats => '【剧情节拍】';

  @override
  String get projectScriptPlanDraftHdrScenes => '【场次草稿】';

  @override
  String get projectScriptPlanDraftHdrDialogue => '【对白要求】';

  @override
  String get projectScriptPlanDraftDialogueLine1 =>
      '- 每段对白都带目的，不解释观众已经能从动作看懂的信息。';

  @override
  String get projectScriptPlanDraftDialogueLine2 =>
      '- 人物情绪要有起伏，先忍、再顶、再露底牌，避免全程一个腔调。';

  @override
  String get projectScriptPlanDraftHdrEnding => '【结尾钩子】';

  @override
  String get projectScriptPlanDraftSceneDefault1 =>
      '- 场1：用一个反常动作或外部威胁开场，把主角直接推入选择。';

  @override
  String get projectScriptPlanDraftSceneDefault2 => '- 场2：让关键关系失衡，冲突不要靠旁白解释。';

  @override
  String get projectScriptPlanDraftSceneDefault3 =>
      '- 场3：用情绪反转收尾，并留下下一集必须追的悬念。';

  @override
  String projectScriptPlanDraftSceneChapterOnly(
    int sceneNumber,
    int chapterIndex,
  ) {
    return '- 场$sceneNumber：章节 $chapterIndex。';
  }

  @override
  String projectScriptPlanDraftSceneTitleNoExcerpt(
    int sceneNumber,
    String title,
  ) {
    return '- 场$sceneNumber：《$title》。';
  }

  @override
  String projectScriptPlanDraftSceneTitleWithExcerpt(
    int sceneNumber,
    String title,
    String excerpt,
  ) {
    return '- 场$sceneNumber：《$title》，抓住“$excerpt”里的动作和情绪做可拍场面。';
  }

  @override
  String get projectScriptPlanRewriteSkeletonFallback =>
      '先把主角困局和最大冲突抛到最前面，别平推背景说明。';

  @override
  String get projectScriptPlanRewriteStrategyFallback =>
      '对白口语化、动作外化情绪、信息跟着冲突走。';

  @override
  String get projectScriptPlanRewriteChapterWhenNoIndexes =>
      '- 优先围绕最强冲突改写，不够戏剧性的原文说明直接压缩。';

  @override
  String projectScriptPlanRewriteChapterPlainEmptyExcerpt(int index) {
    return '- 章节 $index：只保留能推动冲突或人物关系变化的动作。';
  }

  @override
  String projectScriptPlanRewriteChapterPlainWithExcerpt(
    int index,
    String excerpt,
  ) {
    return '- 章节 $index：围绕“$excerpt”改成可拍的动作和情绪交锋。';
  }

  @override
  String projectScriptPlanRewriteChapterTitledEmptyExcerpt(
    int index,
    String title,
  ) {
    return '- 章节 $index《$title》：只保留能推动冲突或人物关系变化的动作。';
  }

  @override
  String projectScriptPlanRewriteChapterTitledWithExcerpt(
    int index,
    String title,
    String excerpt,
  ) {
    return '- 章节 $index《$title》：围绕“$excerpt”改成可拍的动作和情绪交锋。';
  }

  @override
  String get projectScriptPlanRewriteEventDefault =>
      '- 先补出 3 个节点：抛钩子、压迫升级、尾部反转或悬念。';

  @override
  String projectScriptPlanRewriteEventNamed(String name) {
    return '- 事件“$name”必须带来情绪或局势变化，不能只做信息通报。';
  }

  @override
  String get projectScriptPlanRewriteHdrGoal => '【改写目标】';

  @override
  String get projectScriptPlanRewriteHdrStrategy => '【改写策略】';

  @override
  String get projectScriptPlanRewriteHdrChapters => '【章节压缩指令】';

  @override
  String get projectScriptPlanRewriteHdrEvents => '【事件改写指令】';

  @override
  String get projectScriptPlanRewriteHdrPeople => '【人物情绪】';

  @override
  String get projectScriptPlanRewritePeopleLine1 =>
      '- 主角每场都要有明确刺激、反应和下一步动作，情绪不能整集一个平面。';

  @override
  String get projectScriptPlanRewritePeopleLine2 => '- 配角发言要推动主角选择，不留解释剧情的空对白。';

  @override
  String get projectScriptPlanRewriteHdrDeAi => '【去 AI 味约束】';

  @override
  String get projectScriptPlanRewriteDeAiLine1 =>
      '- 少写总结句、价值判断句和书面连接词，改成口语化冲突表达。';

  @override
  String get projectScriptPlanRewriteDeAiLine2 =>
      '- 画面先写动作、视线、停顿、压迫感来源，再补必要对白。';

  @override
  String get projectScriptPlanRewriteDeAiLine3 =>
      '- 同一场里不要连续三句都在解释背景，让信息藏进试探、误会和逼问。';

  @override
  String get projectScriptPlanWorkbenchTitle => '故事骨架与改编策略';

  @override
  String projectScriptPlanWorkbenchPlanMountedLine(
    String planId,
    int count,
    String namesSuffix,
  ) {
    return 'planId $planId · 已挂载 $count 条剧本$namesSuffix';
  }

  @override
  String get projectScriptPlanWorkbenchFillSkeletonFromEvents => '用事件填充骨架草稿';

  @override
  String get projectScriptPlanWorkbenchFillStrategyFromEvents => '用事件填充策略草稿';

  @override
  String get projectScriptPlanWorkbenchGenerateDraftPackets => '生成剧本草稿包';

  @override
  String get projectScriptPlanWorkbenchGenerateStructuredGuidance =>
      '生成结构化改写指引';

  @override
  String get projectScriptPlanWorkbenchWriteScriptDrafts => '写入剧本草稿';

  @override
  String get projectScriptPlanWorkbenchStorySkeletonLabel => '故事骨架';

  @override
  String get projectScriptPlanWorkbenchStorySkeletonHelper =>
      '聚焦故事主线、主要冲突、转折点与收束路径';

  @override
  String get projectScriptPlanWorkbenchAdaptationStrategyLabel => '改编策略';

  @override
  String get projectScriptPlanWorkbenchAdaptationStrategyHelper =>
      '记录改编取舍、人物弧光、节奏与风格约束';

  @override
  String get projectScriptPlanWorkbenchScriptDraftPreviewTitle => '剧本草稿预览';

  @override
  String get projectScriptPlanWorkbenchNoDraftPacketsHint =>
      '尚无草稿包。请先完善骨架/策略，再生成。';

  @override
  String get projectScriptPlanWorkbenchStructuredGuidanceTitle => '结构化改写指引';

  @override
  String get projectScriptPlanWorkbenchNoGuidanceHint =>
      '尚无结构化指引。在改写前后运行以约束修订。';

  @override
  String get projectScriptPlanWorkbenchChaptersPrefix => '章节';

  @override
  String get projectScriptPlanWorkbenchTbd => '待定';

  @override
  String get projectScriptPlanWorkbenchReloadPlan => '重新加载方案';

  @override
  String get projectScriptPlanWorkbenchSavePlan => '保存方案';

  @override
  String get projectScriptPlanWorkbenchRefreshing => '刷新中…';

  @override
  String get projectScriptPlanWorkbenchSaving => '保存中…';

  @override
  String get projectScriptPlanWorkbenchLoadingInitial => '正在加载方案…';

  @override
  String get projectScriptPlanWorkbenchRefreshingPlan => '正在刷新方案…';

  @override
  String projectScriptPlanWorkbenchLoadedPlan(String planId, int scriptCount) {
    return '已加载方案 $planId · $scriptCount 条剧本行';
  }

  @override
  String projectScriptPlanWorkbenchLoadFailed(String error) {
    return '加载方案失败：$error';
  }

  @override
  String get projectScriptPlanWorkbenchSkeletonDraftGenerated =>
      '已从事件填充故事骨架草稿。';

  @override
  String get projectScriptPlanWorkbenchStrategyDraftGenerated =>
      '已从事件填充改编策略草稿。';

  @override
  String get projectScriptPlanWorkbenchNoDraftsNoEvents =>
      '暂无草稿包（请补充事件/小说或完善骨架/策略）。';

  @override
  String projectScriptPlanWorkbenchDraftsGenerated(int count) {
    return '已生成 $count 个剧本草稿包。';
  }

  @override
  String get projectScriptPlanWorkbenchNoGuidanceNoEvents =>
      '暂无结构化指引（请补充事件/小说或完善骨架/策略）。';

  @override
  String projectScriptPlanWorkbenchGuidanceGenerated(int count) {
    return '已生成 $count 条结构化指引。';
  }

  @override
  String get projectScriptPlanWorkbenchSavingPlan => '正在保存方案…';

  @override
  String projectScriptPlanWorkbenchSaveFailedHttp(int status) {
    return '保存失败（HTTP $status）';
  }

  @override
  String get projectScriptPlanWorkbenchPlanSaved => '方案已保存。';

  @override
  String projectScriptPlanWorkbenchSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get projectScriptPlanWorkbenchNeedDraftsFirst => '请先生成草稿包。';

  @override
  String get projectScriptPlanWorkbenchWritingDrafts => '正在写入剧本草稿…';

  @override
  String projectScriptPlanWorkbenchWriteFailedHttp(int status) {
    return '写入失败（HTTP $status）';
  }

  @override
  String projectScriptPlanWorkbenchDraftsWritten(int count) {
    return '草稿已写入；已刷新，仍有 $count 个草稿包待处理。';
  }

  @override
  String projectScriptPlanWorkbenchWriteDraftsFailed(String error) {
    return '写入草稿失败：$error';
  }

  @override
  String shortVideoUndoEnableShot(int storyboardId) {
    return '启用镜头 #$storyboardId';
  }

  @override
  String shortVideoUndoDisableShot(int storyboardId) {
    return '停用镜头 #$storyboardId';
  }

  @override
  String shortVideoUndoSetShotDuration(int storyboardId, int seconds) {
    return '将镜头 #$storyboardId 时长设为 $seconds 秒';
  }

  @override
  String shortVideoUndoReplaceShotVideo(int storyboardId) {
    return '替换镜头 #$storyboardId 视频';
  }

  @override
  String shortVideoUndoBatchEnable(int count) {
    return '批量启用 $count 个镜头';
  }

  @override
  String shortVideoUndoBatchDisable(int count) {
    return '批量停用 $count 个镜头';
  }

  @override
  String shortVideoUndoBatchAlignDuration(int count) {
    return '批量对齐 $count 个镜头时长';
  }

  @override
  String shortVideoUndoBatchReplaceVideo(int count) {
    return '批量替换 $count 个镜头视频';
  }

  @override
  String shortVideoUndoTooltipWithDescription(String description) {
    return '撤销：$description（Ctrl+Z / Cmd+Z）';
  }

  @override
  String get shortVideoUndoTooltipEmpty => '没有可撤销的操作';

  @override
  String shortVideoRedoTooltipWithDescription(String description) {
    return '重做：$description（Ctrl+Shift+Z / Cmd+Shift+Z）';
  }

  @override
  String get shortVideoRedoTooltipEmpty => '没有可重做的操作';

  @override
  String get shortVideoOperationHistoryToolbarTooltip => '查看操作历史';

  @override
  String get shortVideoOperationHistoryTitle => '操作历史';

  @override
  String get shortVideoOperationHistorySummaryHeading => '摘要';

  @override
  String shortVideoOperationHistoryUndoStack(int count) {
    return '撤销栈：$count';
  }

  @override
  String shortVideoOperationHistoryRedoStack(int count) {
    return '重做栈：$count';
  }

  @override
  String shortVideoOperationHistoryLimitLine(int max) {
    return '历史上限：$max 条';
  }

  @override
  String get shortVideoOperationHistoryEmpty => '暂无操作记录';

  @override
  String get shortVideoOperationHistoryOperationsHeading => '操作（最新在前）';

  @override
  String get shortVideoOperationHistoryLatestChip => '最新';

  @override
  String get shortVideoOperationHistoryClear => '清空历史';

  @override
  String get shortVideoOperationHistoryClearedSnackbar => '已清空操作历史';

  @override
  String shortVideoOperationHistoryRelativeSecondsAgo(int count) {
    return '$count 秒前';
  }

  @override
  String shortVideoOperationHistoryRelativeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String shortVideoOperationHistoryRelativeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String get shortVideoPreviewPlaylistComplete => '已播放完全部镜头';

  @override
  String get shortVideoPreviewPlayerVideoUrlEmpty => '视频 URL 为空';

  @override
  String shortVideoPreviewPlayerLoadFailed(String error) {
    return '视频加载失败：$error';
  }

  @override
  String shortVideoPreviewPlayerShotLabel(int number) {
    return '镜头 #$number';
  }

  @override
  String shortVideoPreviewPlayerPlaylistPosition(int current, int total) {
    return '（$current/$total）';
  }

  @override
  String get shortVideoPreviewPlayerOverallProgress => '总进度';

  @override
  String get shortVideoPreviewPlayerPreviousShot => '上一个镜头';

  @override
  String get shortVideoPreviewPlayerNextShot => '下一个镜头';

  @override
  String get shortVideoPreviewPlayerStop => '停止';

  @override
  String get shortVideoPreviewPlayerPlay => '播放';

  @override
  String get shortVideoPreviewPlayerPause => '暂停';

  @override
  String get shortVideoProductionBatchNoStoryboards => '还没有分镜，无法批量生成候选成片。';

  @override
  String get shortVideoProductionBatchNoScripts => '项目下没有剧本行，请先在项目区创建剧本后再试。';

  @override
  String shortVideoProductionBatchQueued(
    int total,
    int trackId,
    String resolution,
    int durationSeconds,
    int skipped,
  ) {
    return '已排队 $total 条候选视频任务（轨道 #$trackId，$resolution，${durationSeconds}s）；跳过 $skipped 镜。';
  }

  @override
  String shortVideoProductionBatchFailed(String error) {
    return '批量候选成片失败：$error';
  }

  @override
  String shortVideoProductionSetCurrentConfirming(int id) {
    return '正在确认分镜 #$id 的当前视频版本…';
  }

  @override
  String shortVideoProductionSetCurrentDone(int id) {
    return '已确认分镜 #$id 的当前视频版本。';
  }

  @override
  String shortVideoProductionSetCurrentFailed(String error) {
    return '设当前失败：$error';
  }

  @override
  String get shortVideoProjectNotLoggedWriteback => '当前未登录，暂时无法把短视频模式写回项目。';

  @override
  String get shortVideoProjectEmptyList => '还没有项目，可先去项目区创建一个短剧项目。';

  @override
  String shortVideoProjectLoadFailed(String error) {
    return '读取项目失败：$error';
  }

  @override
  String get shortVideoProjectCreateNeedLogin => '请先登录后再创建短剧项目。';

  @override
  String get shortVideoProjectDefaultNameAnimated => '动漫短剧项目';

  @override
  String get shortVideoProjectDefaultNameLive => '真人短剧项目';

  @override
  String shortVideoProjectCreated(
    int numericId,
    String modeLabel,
    String ratioLabel,
  ) {
    return '已新建项目 #$numericId，并写入 $modeLabel · $ratioLabel。';
  }

  @override
  String shortVideoProjectCreateFailed(String error) {
    return '新建项目失败：$error';
  }

  @override
  String get shortVideoProjectSaveNeedSelection => '请先登录并选择项目。';

  @override
  String shortVideoProjectSaved(
    int numericId,
    String modeLabel,
    String ratioLabel,
    String market,
    int platformCount,
    String duration,
  ) {
    return '已写回项目 #$numericId：$modeLabel · $ratioLabel · 市场 $market · 平台 $platformCount 个 · 时长 $duration';
  }

  @override
  String shortVideoProjectSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get shortVideoBatchThrottleMessage => '操作过于频繁，请稍后再试。';

  @override
  String get shortVideoBatchSelectAll => '全选';

  @override
  String get shortVideoBatchDeselectAll => '取消全选';

  @override
  String shortVideoBatchSelectedCount(int selected, int total) {
    return '已选择：$selected / $total';
  }

  @override
  String get shortVideoBatchOpEnable => '批量启用';

  @override
  String get shortVideoBatchOpDisable => '批量禁用';

  @override
  String get shortVideoBatchOpDurationAlign => '时长对齐';

  @override
  String get shortVideoBatchOpReplace => '批量替换 URL';

  @override
  String get shortVideoBatchOpVoiceover => '批量配音';

  @override
  String shortVideoBatchProgressCompletedTotal(int completed, int total) {
    return '进度：$completed / $total';
  }

  @override
  String shortVideoBatchProgressSucceededLabel(int count) {
    return '成功：$count';
  }

  @override
  String shortVideoBatchProgressFailedLabel(int count) {
    return '失败：$count';
  }

  @override
  String get shortVideoBatchProgressFailedHeading => '失败项：';

  @override
  String shortVideoBatchProgressStoryboardLine(int id) {
    return '分镜 #$id';
  }

  @override
  String get shortVideoBatchProgressCancel => '取消';

  @override
  String get shortVideoBatchProgressRetryFailed => '重试失败项';

  @override
  String get shortVideoBatchProgressClose => '关闭';

  @override
  String shortVideoBatchErrorCode(String code) {
    return '错误码：$code';
  }

  @override
  String shortVideoBatchOperationRetryTitle(String title) {
    return '$title（重试）';
  }

  @override
  String get shortVideoBatchSelectShotsToEnableFirst => '请先选择要启用的镜头。';

  @override
  String get shortVideoBatchNoShotsWithVideoUrl => '所选镜头均无可用的视频 URL。';

  @override
  String get shortVideoBatchEnableTitle => '批量启用镜头';

  @override
  String shortVideoBatchEnableFinished(int successful, int failed) {
    return '批量启用完成：成功 $successful，失败 $failed';
  }

  @override
  String shortVideoBatchEnableFailedStatus(String code) {
    return '批量启用失败：$code';
  }

  @override
  String shortVideoBatchEnableFailedError(String error) {
    return '批量启用失败：$error';
  }

  @override
  String get shortVideoBatchSelectShotsToDisableFirst => '请先选择要停用的镜头。';

  @override
  String get shortVideoBatchDisableTitle => '批量停用镜头';

  @override
  String shortVideoBatchDisableFinished(int successful, int failed) {
    return '批量停用完成：成功 $successful，失败 $failed';
  }

  @override
  String shortVideoBatchDisableFailedStatus(String code) {
    return '批量停用失败：$code';
  }

  @override
  String shortVideoBatchDisableFailedError(String error) {
    return '批量停用失败：$error';
  }

  @override
  String get shortVideoBatchSelectShotsDurationFirst => '请先选择要对齐时长的镜头。';

  @override
  String get shortVideoBatchDurationDialogTitle => '批量时长对齐';

  @override
  String get shortVideoBatchDurationLabel => '时长（秒）';

  @override
  String get shortVideoBatchDurationHint => '请输入 1–300';

  @override
  String get shortVideoBatchAlignAndSave => '对齐并保存';

  @override
  String get shortVideoBatchDurationProgressTitle => '批量时长对齐';

  @override
  String shortVideoBatchDurationFinished(int successful, int failed) {
    return '批量时长对齐完成：成功 $successful，失败 $failed';
  }

  @override
  String get shortVideoBatchSelectShotsReplaceFirst => '请先选择要替换的镜头。';

  @override
  String get shortVideoBatchReplaceDialogTitle => '批量替换视频 URL';

  @override
  String get shortVideoBatchReplaceFindPatternLabel => '查找模式（支持正则）';

  @override
  String get shortVideoBatchReplaceFindPatternHint => '例如 /v1/';

  @override
  String get shortVideoBatchReplaceWithLabel => '替换为';

  @override
  String get shortVideoBatchReplaceWithHint => '例如 /v2/';

  @override
  String get shortVideoBatchReplaceUrlDescription => '对每个选中镜头的视频 URL 执行查找替换。';

  @override
  String get shortVideoBatchApplyReplacement => '应用替换';

  @override
  String get shortVideoBatchReplaceNoMatch => '没有可替换的镜头（模式未匹配）。';

  @override
  String shortVideoBatchReplaceFinished(int successful, int failed) {
    return '批量替换完成：成功 $successful，失败 $failed';
  }

  @override
  String shortVideoBatchReplaceFailedStatus(String code) {
    return '批量替换失败：$code';
  }

  @override
  String shortVideoBatchReplaceFailedError(String error) {
    return '批量替换失败：$error';
  }

  @override
  String get shortVideoBatchCannotLoadProject => '无法加载项目。';

  @override
  String get shortVideoBatchSelectShotsVoiceoverFirst => '请先选择要生成配音的镜头。';

  @override
  String get shortVideoBatchNoVoiceoverTextSelected => '所选镜头没有可用的配音文案。';

  @override
  String get shortVideoBatchGenerateVoiceoverTitle => '批量生成配音';

  @override
  String shortVideoBatchVoiceoverQueueProgress(
    int done,
    int total,
    String percent,
  ) {
    return '进度：$done / $total（$percent%）';
  }

  @override
  String shortVideoBatchVoiceoverQueueStats(int succeeded, int failed) {
    return '成功：$succeeded · 失败：$failed';
  }

  @override
  String get shortVideoBatchVoiceoverQueueFailedHeading => '失败项：';

  @override
  String shortVideoBatchVoiceoverQueueFailedLine(int id, String message) {
    return '镜头 #$id：$message';
  }

  @override
  String get shortVideoBatchVoiceoverQueueDone => '完成';

  @override
  String shortVideoBatchVoiceoverGenFailedStatus(String code) {
    return '批量配音生成失败：$code';
  }

  @override
  String shortVideoBatchVoiceoverGenFailedError(String error) {
    return '批量配音生成失败：$error';
  }

  @override
  String shortVideoBatchVoiceoverDoneJobs(int count) {
    return '批量配音完成：已为 $count 个镜头入队任务。';
  }

  @override
  String shortVideoBatchVoiceoverDonePartial(int succeeded, int failed) {
    return '批量配音完成：成功 $succeeded，失败 $failed';
  }

  @override
  String get shortVideoBatchShotNoVoiceoverText => '该镜头没有可用的配音文案。';

  @override
  String get shortVideoBatchGeneratingVoiceover => '正在生成配音…';

  @override
  String shortVideoBatchVoiceoverJobEnqueued(int id) {
    return '镜头 #$id 的配音任务已入队。';
  }

  @override
  String get shortVideoBatchVoiceoverCouldNotCreateTask => '配音生成失败：无法创建任务。';

  @override
  String shortVideoBatchVoiceoverSingleFailedStatus(
    String code,
    String message,
  ) {
    return '配音生成失败：$code — $message';
  }

  @override
  String shortVideoBatchVoiceoverSingleFailedError(String error) {
    return '配音生成失败：$error';
  }

  @override
  String get shortVideoRustApiUnknownError => '未知错误';

  @override
  String get shortVideoCandidateAssetConfirmationTitle => '候选素材确认';

  @override
  String get shortVideoCandidateMetricPending => '待处理';

  @override
  String get shortVideoCandidateMetricLinked => '已关联';

  @override
  String get shortVideoCandidateMetricIgnored => '已忽略';

  @override
  String get shortVideoCandidateMetricUnset => '未设置';

  @override
  String get shortVideoCandidateBatchGenerateSubmitting => '正在提交候选片段批量任务…';

  @override
  String get shortVideoCandidateBatchGenerateLabel => '批量生成候选片段（项目默认）';

  @override
  String get shortVideoCandidateOpenProjectsForAssets => '打开项目管理素材';

  @override
  String get shortVideoCandidateCompareSectionTitle => '候选对比';

  @override
  String get projectEditorAssetFilterDialogTitle => '高级素材筛选';

  @override
  String get projectEditorAssetFilterByScript => '按剧本筛选';

  @override
  String get projectEditorAssetFilterAllScripts => '（全部剧本）';

  @override
  String get projectEditorAssetFilterAssetTypeOptional => '素材类型（可选）';

  @override
  String get projectEditorAssetFilterAssetTypeHint => 'role / clip / props';

  @override
  String get projectEditorAssetFilterNameContainsOptional => '名称包含（可选）';

  @override
  String get projectEditorAssetFilterPage => '页码';

  @override
  String get projectEditorAssetFilterLimit => '每页条数';

  @override
  String get projectEditorAssetFilterApply => '应用筛选';

  @override
  String get projectEditorAssetFilterSnackbarPageLimitPositive =>
      'page 与 limit 须为正整数';

  @override
  String projectEditorAssetFilterSnackbarApplied(int shown, int total) {
    return '已应用筛选：$shown/$total 行';
  }

  @override
  String get projectEditorAssetCrudCreateTitle => '新建资产';

  @override
  String get projectEditorAssetCrudEditTitle => '编辑资产';

  @override
  String get projectEditorAssetCrudFieldNameLabel => '资产名称';

  @override
  String get projectEditorAssetCrudFieldTypeLabel => '资产类型';

  @override
  String get projectEditorAssetCrudFieldTypeHelperCreate =>
      '示例：role / clip / props';

  @override
  String get projectEditorAssetCrudFieldDescriptionLabel => '描述（可选）';

  @override
  String get projectEditorAssetCrudEditTargetLabel => '目标资产';

  @override
  String get projectEditorAssetCrudCancel => '取消';

  @override
  String get projectEditorAssetCrudCreate => '创建';

  @override
  String get projectEditorAssetCrudSave => '保存';

  @override
  String get projectEditorAssetCrudCreateNameTypeRequiredSnack => '资产名称和类型不能为空';

  @override
  String get projectEditorAssetCrudCreateSuccessSnack => '已创建资产';

  @override
  String get projectEditorAssetCrudEditNoneSnack => '当前没有可编辑资产';

  @override
  String get projectEditorAssetCrudEditEmptyPatchSnack => '请至少填写一项修改内容';

  @override
  String projectEditorAssetCrudEditSuccessSnack(int id) {
    return '已更新资产 #$id';
  }

  @override
  String get projectEditorBasicsStylePackPickerNone => '未选择';

  @override
  String projectEditorBasicsStylePackPickerCurrentConfigRow(String path) {
    return '$path · 当前配置';
  }

  @override
  String projectEditorBasicsStylePackOptionDisplay(String name, String tag) {
    return '$name · $tag';
  }

  @override
  String get projectEditorBasicsStylePackFootnoteNone => '未选择';

  @override
  String get projectEditorBasicsStylePackFootnoteLegacy => '当前项目已配置旧路径或未收录风格包。';

  @override
  String get projectEditorBasicsHomeSectionTitle => '项目首页';

  @override
  String projectEditorBasicsHomeReadinessLine(int score, String summary) {
    return '就绪度 $score/100 · $summary';
  }

  @override
  String projectEditorBasicsHomeNextStep(String step) {
    return '下一步：$step';
  }

  @override
  String projectEditorBasicsHomeChecklistItemDone(String label) {
    return '✓ $label';
  }

  @override
  String projectEditorBasicsHomeChecklistItemTodo(String label) {
    return '○ $label';
  }

  @override
  String get projectEditorBasicsFieldNameClearLabel => '名称（留空则清空）';

  @override
  String get projectEditorBasicsFieldIntroClearLabel => '简介（留空则清空）';

  @override
  String get projectEditorBasicsFieldPremise => '故事前提';

  @override
  String get projectEditorBasicsFieldTargetAudience => '目标受众';

  @override
  String get projectEditorBasicsFieldEmotionalTone => '情绪基调';

  @override
  String get projectEditorBasicsFieldCoreHook => '核心钩子';

  @override
  String get projectEditorBasicsFieldVisualDirection => '视觉方向';

  @override
  String get projectEditorBasicsFieldBrandName => '品牌名称';

  @override
  String get projectEditorBasicsFieldBrandPromise => '品牌承诺';

  @override
  String get projectEditorBasicsFieldVisualMotifsOnePerLine => '视觉母题（每行一个）';

  @override
  String get projectEditorBasicsFieldForbiddenOnePerLine => '禁忌元素（每行一个）';

  @override
  String get projectEditorBasicsFieldContinuityRulesOnePerLine => '连续性规则（每行一个）';

  @override
  String get projectEditorBasicsPitchSectionTitle => '项目立项';

  @override
  String get projectEditorBasicsBrandSectionTitle => '品牌圣经';

  @override
  String get projectEditorBasicsLabelArtStylePack => '画风技能包';

  @override
  String get projectEditorBasicsLabelStoryStylePack => '故事风格包';

  @override
  String get projectEditorBasicsCompatTitle => '兼容性检查';

  @override
  String get projectEditorBasicsCompatSubtitle =>
      '旧 general / project / tasks 接口回归入口，默认折叠';

  @override
  String projectEditorBasicsStatsLine(
    int scriptCount,
    int storyboardCount,
    int novelCount,
    int roleCount,
    int videoCount,
  ) {
    return 'GET …/stats：剧本 $scriptCount · 分镜 $storyboardCount · 小说 $novelCount · 角色/成片视频 $roleCount/$videoCount';
  }

  @override
  String get projectEditorBasicsStatsNotLoaded => 'GET …/stats 未加载';

  @override
  String get projectEditorAuditTitle => '项目活动记录';

  @override
  String get projectEditorAuditSubtitle => '聚焦项目配置与 ACL 变更，方便回答「谁改了这个项目」。';

  @override
  String get projectEditorAuditActionFilterLabel => '动作过滤';

  @override
  String get projectEditorAuditActionAll => '全部';

  @override
  String get projectEditorAuditActionProjectUpdated => '项目修改';

  @override
  String get projectEditorAuditActionMemberAdded => '添加 ACL';

  @override
  String get projectEditorAuditActionMemberRoleChanged => '角色调整';

  @override
  String get projectEditorAuditActionMemberRemoved => '移除 ACL';

  @override
  String get projectEditorAuditActionProjectCreated => '项目创建';

  @override
  String get projectEditorAuditActionProjectDeleted => '项目删除';

  @override
  String get projectEditorAuditSearchLabel => '搜索 actor / target / 字段 / 项目名';

  @override
  String get projectEditorAuditEmpty => '当前没有可显示的项目活动记录。';

  @override
  String get projectEditorAuditLoadMore => '加载更多';

  @override
  String get projectEditorAuditRefresh => '刷新';

  @override
  String get projectEditorShortDramaTargetsSectionTitle => '短视频编排';

  @override
  String get projectEditorShortDramaTargetsSectionBody =>
      '与短视频 Space 相同的项目级写回（PATCH …/projects），在此可从项目对话框直接调整。\n首页「短剧生产平台链」可一键跳到脚本 / 制作 / 任务 / 作业 / 质量 / 短视频。';

  @override
  String get projectEditorShortDramaTargetsFlavorLabel => '短剧形态';

  @override
  String get projectEditorShortDramaTargetsFlavorAnimated => '动漫短剧';

  @override
  String get projectEditorShortDramaTargetsFlavorLiveAction => '真人短剧';

  @override
  String get projectEditorShortDramaTargetsAspectLabel => '画幅';

  @override
  String get projectEditorShortDramaTargetsRatioPortrait916 => '竖屏 9:16';

  @override
  String get projectEditorShortDramaTargetsRatioLandscape169 => '横屏 16:9';

  @override
  String get projectEditorShortDramaTargetsRatioSquare11 => '方形 1:1';

  @override
  String get projectEditorShortDramaTargetsSaveBusy => '写回中…';

  @override
  String get projectEditorShortDramaTargetsSaveButton => '写回短剧参数';

  @override
  String projectEditorShortDramaTargetsSaveSuccess(
    String flavor,
    String ratio,
  ) {
    return '已写回短剧参数：$flavor · $ratio';
  }

  @override
  String projectEditorShortDramaTargetsSaveFailedHttp(String code) {
    return '保存失败：$code';
  }

  @override
  String projectEditorShortDramaTargetsSaveFailed(String error) {
    return '保存失败：$error';
  }

  @override
  String get projectEditorAssetEditImageNeedScriptSnack => '请先创建剧本再上传编辑图片。';

  @override
  String get projectEditorAssetEditImageDialogTitle => '上传编辑图片';

  @override
  String get projectEditorAssetEditImageTargetScriptLabel => '目标剧本';

  @override
  String get projectEditorAssetEditImageDataUriLabel => '图片 data URI';

  @override
  String get projectEditorAssetEditImageDataUriHelper =>
      '支持 jpeg/jpg/png 的 base64 data URI。';

  @override
  String get projectEditorAssetEditImageUploadButton => '上传';

  @override
  String get projectEditorAssetEditImageEmptyDataUriSnack =>
      'base64 data URI 不能为空。';

  @override
  String projectEditorAssetEditImageUploadSuccess(String url) {
    return '上传成功：$url';
  }

  @override
  String get projectEditorAssetLinkNeedScriptAndAssetSnack =>
      '请先准备至少一个剧本和一个资产。';

  @override
  String get projectEditorAssetLinkDialogTitleLink => '关联剧本与资产';

  @override
  String get projectEditorAssetLinkDialogTitleUnlink => '取消剧本-资产关联';

  @override
  String get projectEditorAssetLinkScriptLabel => '剧本';

  @override
  String get projectEditorAssetLinkAssetLabel => '资产';

  @override
  String get projectEditorAssetLinkConfirmLink => '确认关联';

  @override
  String get projectEditorAssetLinkConfirmUnlink => '取消关联';

  @override
  String projectEditorAssetLinkSuccessLinked(int scriptId, int assetId) {
    return '已关联 script#$scriptId · asset#$assetId';
  }

  @override
  String projectEditorAssetLinkSuccessUnlinked(int scriptId, int assetId) {
    return '已取消关联 script#$scriptId · asset#$assetId';
  }

  @override
  String get projectEditorAssetGenWorkbenchNeedAssetsSnack =>
      '请先加载资产列表再打开出图工作台。';

  @override
  String get projectEditorAssetGenWorkbenchNeedScriptSnack => '请先创建剧本再发起资产出图。';

  @override
  String get projectEditorAssetGenWorkbenchSyncSummaryBusy => '同步中…';

  @override
  String get projectEditorAssetGenWorkbenchSyncSummary => '同步当前工作台摘要';

  @override
  String get projectEditorAssetGenWorkbenchLoadMaterialContext => '读取素材上下文';

  @override
  String get projectEditorAssetGenWorkbenchLoadBatchCandidates => '读取批量候选';

  @override
  String get projectEditorAssetGenWorkbenchSelectAllVisible => '全选当前可见资产';

  @override
  String get projectEditorAssetGenWorkbenchRebuildSelectionByType => '按类型重建选择';

  @override
  String get projectEditorAssetGenWorkbenchClearSelection => '清空选择';

  @override
  String get projectEditorAssetGenWorkbenchMutationBusy => '处理中…';

  @override
  String get projectEditorAssetGenWorkbenchBatchGenerate => '批量发起资产出图';

  @override
  String get projectEditorAssetGenWorkbenchPollImageStatuses => '轮询图片状态';

  @override
  String get projectEditorAssetGenWorkbenchPollPromptStatuses => '轮询 prompt 状态';

  @override
  String get projectEditorAssetGenWorkbenchDeleteDerivatives => '清理衍生图';

  @override
  String get projectEditorAssetGenWorkbenchUpdateCoverUrl => '更新封面 URL';

  @override
  String get projectEditorAssetGenWorkbenchScriptLabel => '生成使用的剧本';

  @override
  String get projectEditorAssetGenWorkbenchScriptHelper =>
      '批量出图会把所选资产投给这个剧本上下文';

  @override
  String get projectEditorAssetGenWorkbenchAssetTypeLabel => '资产类型筛选';

  @override
  String get projectEditorAssetGenWorkbenchAssetTypeHelper =>
      '同时影响 production 摘要读取和可见选择集';

  @override
  String get projectEditorAssetGenWorkbenchAssetTypeAll => '（全部类型）';

  @override
  String get projectEditorAssetGenWorkbenchModelOptionalLabel => '模型（可选）';

  @override
  String get projectEditorAssetGenWorkbenchResolutionOptionalLabel => '分辨率（可选）';

  @override
  String get projectEditorAssetGenWorkbenchBatchNameFilterOptionalLabel =>
      '批量候选名称过滤（可选）';

  @override
  String get projectEditorAssetGenWorkbenchBatchLimitLabel => '候选 limit';

  @override
  String get projectEditorAssetGenWorkbenchCoverUrlLabel => '更新封面 URL（单选时可用）';

  @override
  String get projectEditorAssetGenWorkbenchCoverUrlHelper =>
      '用于 production/assets/update-assets-url';

  @override
  String get projectEditorAssetGenWorkbenchSelectionScopeGlobal =>
      '当前按项目全量资产操作；可在主视图先切换「按剧本筛选」再进入工作台。';

  @override
  String projectEditorAssetGenWorkbenchSelectionScopeFiltered(int scriptId) {
    return '当前主视图已按剧本 #$scriptId 过滤资产，工作台默认沿用这批可见资产。';
  }

  @override
  String get projectEditorAssetGenWorkbenchAssetNoDescription => '无描述';

  @override
  String get projectEditorAssetDeleteDialogNoAssetsSnack => '当前没有可删除资产';

  @override
  String get projectEditorAssetDeleteDialogTitle => '删除资产';

  @override
  String get projectEditorAssetDeleteDialogTargetLabel => '目标资产';

  @override
  String get projectEditorAssetDeleteDialogCancel => '取消';

  @override
  String get projectEditorAssetDeleteDialogConfirm => '删除';

  @override
  String projectEditorAssetDeleteSuccessSnack(int id) {
    return '已删除资产 #$id';
  }

  @override
  String get projectEditorAssetClipUploadDialogTitle => '上传 Clip 资产';

  @override
  String get projectEditorAssetClipUploadNameLabel => '资产名称';

  @override
  String get projectEditorAssetClipUploadNameHelper => '建议使用可追踪的业务名称';

  @override
  String get projectEditorAssetClipUploadTypeLabel => '资产类型';

  @override
  String get projectEditorAssetClipUploadTypeHelper => '默认 clip；当前后端仅接受 clip';

  @override
  String get projectEditorAssetClipUploadImageDataLabel =>
      '图片 data URI / base64';

  @override
  String get projectEditorAssetClipUploadImageDataHelper =>
      '支持 data URI 或原始 base64（由后端校验）';

  @override
  String get projectEditorAssetClipUploadCancel => '取消';

  @override
  String get projectEditorAssetClipUploadUpload => '上传';

  @override
  String get projectEditorAssetClipUploadFieldsRequiredSnack =>
      '名称、类型和图片数据不能为空';

  @override
  String projectEditorAssetClipUploadSuccessSnack(String message) {
    return '上传成功：$message';
  }

  @override
  String get projectEditorAssetsProbeCreateTestAssetButton => '新增测试资产';

  @override
  String get projectEditorAssetsProbeCreateTestAssetSnack => '已新增测试资产';

  @override
  String get projectEditorAssetsProbeFetchFirstAssetButton => '查看首条资产';

  @override
  String projectEditorAssetsProbeFetchFirstAssetSnack(
    int id,
    String name,
    String assetType,
  ) {
    return '已读取资产 #$id：$name（$assetType）';
  }

  @override
  String get projectEditorAssetsProbePatchFirstNameButton => '更新首条资产';

  @override
  String get projectEditorAssetsProbePatchFirstNameSnack => '已 PATCH 首条资产名称';

  @override
  String get projectEditorAssetsProbeDeleteLastAssetButton => '删除末条资产';

  @override
  String get projectEditorAssetsProbeLinkFirstPairButton => '关联首剧本与首资产';

  @override
  String get projectEditorAssetsProbeUnlinkFirstPairButton => '取消首条关联';

  @override
  String get projectEditorAssetsCompatibilityPanelTitle => '资产探针';

  @override
  String get projectEditorAssetsCompatibilityPanelSubtitle =>
      '用于资产轮询、历史图片与 workbench 形检查，默认折叠';

  @override
  String get projectEditorAssetsCompatibilityImagesSectionLabel =>
      '资产图片 / workbench 轮询检查';

  @override
  String get projectEditorAssetsProbeImagesCornerScapeButton =>
      'POST corner-scape';

  @override
  String get projectEditorAssetsProbeImagesCornerScapeSnackZero =>
      'POST …/assets/corner-scape：0 条';

  @override
  String projectEditorAssetsProbeImagesCornerScapeSnack(
    int count,
    int history,
    String previewSuffix,
  ) {
    return 'POST …/assets/corner-scape：$count 条，首条 history_images=$history$previewSuffix';
  }

  @override
  String get projectEditorAssetsProbeImagesCornerScapePreviewSuffix => '（预览）';

  @override
  String get projectEditorAssetsProbeImagesPostFirstButton => 'POST 首条资产图片';

  @override
  String projectEditorAssetsProbeImagesPostFirstSnack(
    int assetId,
    String imageIdPrefix,
  ) {
    return 'POST …/assets/$assetId/images：$imageIdPrefix…';
  }

  @override
  String get projectEditorAssetsProbeImagesGetOneButton => 'GET 资产图片(单条)';

  @override
  String get projectEditorAssetsProbeImagesGetEmptySnack =>
      'GET …/images：0 条，可先点「POST 首条资产图片」';

  @override
  String projectEditorAssetsProbeImagesGetOneSnack(
    String idShort,
    int sortIndex,
    String state,
    String filePart,
  ) {
    return 'GET …/images/$idShort：sort=$sortIndex state=$state$filePart';
  }

  @override
  String get projectEditorAssetsProbeImagesPatchDelButton => 'POST→PATCH→DEL 图';

  @override
  String projectEditorAssetsProbeImagesPatchDelSnack(
    int sortBefore,
    int sortAfter,
    String state,
  ) {
    return 'POST→PATCH→DEL 资产图片：sort $sortBefore→$sortAfter state=$state 已删';
  }

  @override
  String get projectEditorAssetsCornerScapeLoadingAll =>
      '正在加载 corner-scape 资产（全部类型）…';

  @override
  String projectEditorAssetsCornerScapeLoadingTypes(String types) {
    return '正在加载 corner-scape 资产（类型：$types）…';
  }

  @override
  String projectEditorAssetsCornerScapeLoadFailed(String error) {
    return '加载 corner-scape 资产失败：$error';
  }

  @override
  String projectEditorAssetsWorkbenchFocusAssetSummary(
    int id,
    String name,
    String type,
  ) {
    return '当前焦点资产：#$id $name · $type';
  }

  @override
  String get projectEditorAssetsWorkbenchFocusAssetEmptyOption => '（当前无资产）';

  @override
  String get projectEditorAssetsWorkbenchFocusAssetLabel => '当前焦点资产';

  @override
  String get projectEditorAssetsWorkbenchFocusAssetHelper =>
      '用于快速查看当前工作焦点；具体编辑在下方动作中完成。';

  @override
  String get projectEditorAssetsWorkbenchFocusScriptEmptyOption => '（当前无剧本）';

  @override
  String get projectEditorAssetsWorkbenchFocusScriptLabel => '当前焦点剧本';

  @override
  String get projectEditorAssetsWorkbenchFocusScriptHelper => '用于剧本-资产关联相关动作。';

  @override
  String get projectEditorAssetsProbeWbGetImageButton => 'POST get-image';

  @override
  String get projectEditorAssetsProbeWbUploadClipButton => 'POST upload-clip';

  @override
  String get projectEditorAssetsProbeWbMaterialDataButton =>
      'POST get-material-data';

  @override
  String get projectEditorAssetsProbeWbBatchGenDataButton =>
      'POST batch-generation-data';

  @override
  String get projectEditorAssetsProbeWbGetAssetsApiButton =>
      'POST get-assets-api';

  @override
  String get projectEditorAssetsProbeWbPollingImageButton =>
      'POST polling-image-assets';

  @override
  String get projectEditorAssetsProbeWbPollingPromptButton =>
      'POST polling-prompt-assets';

  @override
  String projectEditorAssetsProbeWbGetImageSnack(
    int tempAssets,
    String imageId,
  ) {
    return 'POST …/workbench/image-bundle：tempAssets=$tempAssets imageId=$imageId';
  }

  @override
  String projectEditorAssetsProbeWbUploadClipSnack(String message) {
    return 'POST …/workbench/upload-clip：$message';
  }

  @override
  String projectEditorAssetsProbeWbMaterialDataSnack(
    int clips,
    int videos,
    String suffix,
  ) {
    return 'POST …/workbench/material-data：clips=$clips videos=$videos$suffix';
  }

  @override
  String projectEditorAssetsProbeWbMaterialDataFirstClipSuffix(String name) {
    return ' 首条=$name';
  }

  @override
  String projectEditorAssetsProbeWbBatchGenSnack(
    int rows,
    int total,
    String suffix,
  ) {
    return 'POST …/workbench/batch-generation-data：rows=$rows/$total$suffix';
  }

  @override
  String projectEditorAssetsProbeWbBatchGenFirstSuffix(
    String name,
    String assetType,
  ) {
    return ' 首条=$name（$assetType）';
  }

  @override
  String projectEditorAssetsProbeWbNestedSnack(
    int parents,
    int total,
    String suffix,
  ) {
    return 'POST …/workbench/nested：parents=$parents/$total$suffix';
  }

  @override
  String projectEditorAssetsProbeWbNestedFirstSuffix(int count) {
    return ' firstChildren=$count';
  }

  @override
  String get projectEditorAssetsProbeWbPollingImageZeroSnack =>
      'POST …/workbench/polling-image-assets：0 条';

  @override
  String projectEditorAssetsProbeWbPollingImageRowSnack(
    String state,
    String filePath,
  ) {
    return 'POST …/workbench/polling-image-assets：state=$state filePath=$filePath';
  }

  @override
  String get projectEditorAssetsProbeWbPollingPromptZeroSnack =>
      'POST …/workbench/polling-prompt-assets：0 条';

  @override
  String projectEditorAssetsProbeWbPollingPromptRowSnack(
    String promptState,
    String assetType,
  ) {
    return 'POST …/workbench/polling-prompt-assets：promptState=$promptState type=$assetType';
  }

  @override
  String get projectEditorAssetsProbeQueryPageButton => 'GET 分页 page=1&limit=2';

  @override
  String get projectEditorAssetsProbeQueryFilterButton => 'GET 筛选 type+name';

  @override
  String get projectEditorAssetsProbeQueryScriptScopedButton => 'GET 当前剧本+分页';

  @override
  String projectEditorAssetsProbeQueryPageSnack(
    int total,
    int pageCount,
    String idPart,
  ) {
    return 'GET …/assets?page=1&limit=2：total=$total，本页 $pageCount 条$idPart';
  }

  @override
  String projectEditorAssetsProbeQueryFilterSnack(
    int total,
    int returned,
    String idPart,
  ) {
    return 'GET …/assets?asset_type=role&name=probe：total=$total，返回 $returned 条$idPart';
  }

  @override
  String projectEditorAssetsProbeQueryScriptSnack(
    int scriptId,
    int total,
    int pageCount,
    String idPart,
  ) {
    return 'GET …/assets?script_numeric_id=$scriptId&page=1&limit=2：total=$total，本页 $pageCount 条$idPart';
  }

  @override
  String get projectEditorDeleteProjectTitle => '删除项目？';

  @override
  String projectEditorDeleteProjectBody(int id) {
    return '将删除项目 #$id、相关剧本/分镜（数据库级联），并清除该项目的智能体记忆。';
  }

  @override
  String get projectEditorDeleteProjectSnackbar => '项目已删除';

  @override
  String get projectEditorDeleteProjectButton => '删除';

  @override
  String get projectEditorSavePatch => '保存（PATCH）';

  @override
  String get projectEditorSavingEllipsis => '保存中…';

  @override
  String get projectEditorPublishSectionTitle => '发布';

  @override
  String get projectEditorPublishSectionBody => '草稿、排期、任务与审计位于 短视频空间 → 发布。';

  @override
  String get projectEditorPublishOpenWorkspace => '打开发布工作区';

  @override
  String projectEditorPublishOverviewSnackbar(int drafts, int jobs) {
    return '发布概览：草稿=$drafts 任务=$jobs';
  }

  @override
  String get projectEditorPublishViewOverview => '查看发布概览';

  @override
  String projectEditorPublishOverviewFailed(String error) {
    return '加载发布概览失败：$error';
  }

  @override
  String get projectEditorStoryboardImageWorkbenchTitle => '图片工作台';

  @override
  String get projectEditorStoryboardImageUrlLabel => '当前图片 URL / data URI';

  @override
  String get projectEditorStoryboardImageUrlHelper =>
      'HTTP URL 或 data:image/...;base64。';

  @override
  String get projectEditorStoryboardImageLoadPreview => '加载当前预览';

  @override
  String get projectEditorStoryboardImageWorking => '处理中…';

  @override
  String get projectEditorStoryboardImageSaveUrl => '保存图片 URL';

  @override
  String get projectEditorStoryboardImageClearFrame => '清空画格';

  @override
  String get projectEditorStoryboardImageRefreshProduction => '刷新制作数据';

  @override
  String get projectEditorStoryboardImageRefreshing => '刷新中…';

  @override
  String get projectEditorNovelsEventsWorkbenchEmptyDetail =>
      '通过显式表单管理事件（搜索/创建/更新/删除/批量），勿依赖 HTTP 探测按钮。';

  @override
  String projectEditorNovelsEventsWorkbenchSummaryFirst(
    String summaryLine,
    int id,
    String name,
  ) {
    return '$summaryLine；首条 #$id $name。';
  }

  @override
  String get projectEditorNovelsEventsOpenWorkbench => '打开事件工作台';

  @override
  String get projectEditorNovelsEventsRefresh => '刷新事件';

  @override
  String get projectEditorNovelsEventsRefreshing => '正在刷新事件…';

  @override
  String get projectEditorAssetsMainWorkbenchTitle => '资产主工作台';

  @override
  String get projectEditorAssetsOverviewCardIntro =>
      '把资产 CRUD、剧本关联、筛选与上传动作收口到一个正式入口，主区不再堆叠一排零散按钮。';

  @override
  String get projectEditorAssetsMainWorkbenchDialogIntro =>
      '把资产 CRUD、剧本关联、筛选和上传入口收口到一个正式工作台，主区不再堆一排控制台式按钮。';

  @override
  String get projectEditorAssetsOverviewFilteringByScript => '正在按剧本筛选资产…';

  @override
  String get projectEditorAssetsOverviewScriptAssetsNotLoaded => '当前剧本资产尚未加载';

  @override
  String get projectEditorAssetsOverviewFilterHint => '按剧本筛选资产列表';

  @override
  String get projectEditorAssetsOverviewFilterOptionAll => '（全部，不按剧本筛选）';

  @override
  String get projectEditorAssetsOverviewRefreshBusy => '刷新资产…';

  @override
  String get projectEditorAssetsOverviewRefresh => '刷新资产';

  @override
  String get projectEditorAssetsOverviewOpenMainWorkbench => '打开资产主工作台';

  @override
  String get projectEditorAssetsSpecializedWorkbenchesTitle => '专项工作台';

  @override
  String get projectEditorAssetsSpecializedWorkbenchesSubtitle =>
      '把图片管理、出图链路和历史图查询也统一挂到这里，资产主区只保留一个正式入口。';

  @override
  String get projectEditorAssetsMainWorkbenchRefreshBusy => '处理中…';

  @override
  String get projectEditorAssetsMainWorkbenchRefresh => '刷新工作台';

  @override
  String get projectEditorAssetsMainWorkbenchClose => '关闭';

  @override
  String get projectEditorAssetsWorkbenchNewAsset => '新建素材';

  @override
  String get projectEditorAssetsWorkbenchEditAsset => '编辑素材';

  @override
  String get projectEditorAssetsWorkbenchDeleteAsset => '删除素材';

  @override
  String get projectEditorAssetsWorkbenchFilterAssets => '筛选素材';

  @override
  String get projectEditorAssetsWorkbenchLinkScript => '关联剧本与素材';

  @override
  String get projectEditorAssetsWorkbenchUnlink => '解除关联';

  @override
  String get projectEditorAssetsWorkbenchUploadEditImage => '上传修图';

  @override
  String get projectEditorAssetsWorkbenchUploadClipAsset => '上传片段素材';

  @override
  String get projectEditorAssetImagesWorkbenchDialogTitle => '资产图片工作台';

  @override
  String get projectEditorAssetImagesFieldTargetAsset => '目标素材';

  @override
  String get projectEditorAssetImagesNewFilePathOptional => '新建 file_path（可选）';

  @override
  String get projectEditorAssetImagesNewStateOptional => '新建 state（可选）';

  @override
  String get projectEditorAssetImagesNewSortOptional => '新建 sort_index（可选）';

  @override
  String get projectEditorAssetImagesAddImage => '新增图片';

  @override
  String get projectEditorAssetImagesEditFilePathMayClear =>
      '编辑 file_path（可清空）';

  @override
  String get projectEditorAssetImagesEditStateMayClear => '编辑 state（可清空）';

  @override
  String get projectEditorAssetImagesEditSortOptional => '编辑 sort_index（可选）';

  @override
  String get projectEditorAssetImagesSaveCurrentImage => '保存当前图片';

  @override
  String get projectEditorAssetImagesDeleteCurrentImage => '删除当前图片';

  @override
  String get projectEditorAssetImagesLoadImageList => '加载图片列表';

  @override
  String get projectEditorAssetImagesLoadingEllipsis => '加载中…';

  @override
  String get projectEditorAssetImagesPreviewImage => '预览图片';

  @override
  String get projectEditorAssetImagesLoadingPreview => '正在加载预览…';

  @override
  String get projectEditorAssetImagesFieldImages => '图片';

  @override
  String projectEditorAssetGenUseMaterialContext(int count) {
    return '使用素材上下文（$count 行）';
  }

  @override
  String projectEditorAssetGenUseBatchCandidates(int count) {
    return '使用批量候选（$count 行）';
  }

  @override
  String get projectEditorAssetGenBatchCandidatesNeedAssetType =>
      '批量候选读取需要有效资产类型。';

  @override
  String get projectEditorAssetGenBatchCandidatesLimitPositive =>
      '候选 limit 必须大于 0。';

  @override
  String projectEditorAssetGenLeadBatchGenerate(int total, int enqueuedCount) {
    return '已为 $total 条资产创建出图任务，队列 $enqueuedCount 条。';
  }

  @override
  String projectEditorAssetGenLeadDeleteDerivatives(
    int deleted,
    String assetIds,
  ) {
    return '已删除 $deleted 个衍生图记录，资产 $assetIds。';
  }

  @override
  String projectEditorAssetGenLeadUpdateImageUrl(int assetId, String message) {
    return '已更新资产 #$assetId 封面 URL：$message';
  }

  @override
  String projectEditorAssetGenSyncSnapshotFailed(String error) {
    return '同步工作台摘要失败：$error';
  }

  @override
  String get projectEditorAssetGenSelectionLabelSelectAllVisible => '已全选当前可见资产';

  @override
  String get projectEditorAssetGenSelectionLabelRebuildAllTypes => '已按全部类型重建选择';

  @override
  String projectEditorAssetGenSelectionLabelRebuildForType(String assetType) {
    return '已按 $assetType 重建选择';
  }

  @override
  String get projectEditorAssetGenSelectionLabelClear => '已清空选择';

  @override
  String projectEditorAssetGenSelectionLabelRebuildImageState(String state) {
    return '已按图片状态 $state 重建选择';
  }

  @override
  String get projectEditorAssetGenSelectionLabelRebuildMaterialContext =>
      '已按素材上下文重建选择';

  @override
  String get projectEditorAssetGenSelectionLabelRebuildBatchCandidates =>
      '已按批量候选重建选择';

  @override
  String projectEditorAssetGenSelectionLabelRebuildPromptState(String state) {
    return '已按 prompt 状态 $state 重建选择';
  }

  @override
  String projectEditorAssetGenWorkbenchSelectionLineEmpty(String label) {
    return '$label：没有可选资产';
  }

  @override
  String projectEditorAssetGenWorkbenchSelectionLineCount(
    String label,
    int count,
  ) {
    return '$label：已选择 $count 条资产';
  }

  @override
  String projectEditorAssetGenWorkbenchScopedSelectionLineEmpty(String label) {
    return '$label：当前可见资产中没有匹配项';
  }

  @override
  String get projectEditorAssetGenSwitchingTypeAll => '正在切换到全部类型并同步工作台摘要…';

  @override
  String projectEditorAssetGenSwitchingTypeNamed(String assetType) {
    return '正在切换到 $assetType 并同步工作台摘要…';
  }

  @override
  String projectEditorAssetGenSnapshotLoadingWithLead(String lead) {
    return '$lead，正在同步工作台摘要…';
  }

  @override
  String projectEditorAssetGenBatchCandidatesStatusWithType(
    String summary,
    String assetType,
  ) {
    return '$summary · type=$assetType';
  }

  @override
  String get projectEditorAssetSummaryWorkbenchPartsSeparator => '；';

  @override
  String get projectEditorAssetImagesCreateAssetFirst => '请先创建素材再管理图片';

  @override
  String get projectEditorAssetImagesDiagnosisNotLoadedSummary =>
      '尚未加载该资产的图片列表。';

  @override
  String get projectEditorAssetImagesDiagnosisNotLoadedDetail =>
      '先同步图片列表以确认是否存在历史图片，再预览或新增。';

  @override
  String get projectEditorAssetImagesDiagnosisNoImagesSummary => '该资产尚无图片。';

  @override
  String get projectEditorAssetImagesDiagnosisNoImagesDetail =>
      '新增图片以创建该资产的首条可编辑历史记录。';

  @override
  String projectEditorAssetImagesDiagnosisPreviewPendingSummary(int count) {
    return '已加载 $count 张图片；尚未加载预览。';
  }

  @override
  String get projectEditorAssetImagesDiagnosisPreviewPendingDetail =>
      '加载当前图片预览，并在编辑或删除前核对 file_path 与 state。';

  @override
  String get projectEditorAssetImagesDiagnosisReadySummary => '当前图片已就绪，可继续编辑。';

  @override
  String projectEditorAssetImagesDiagnosisReadyDetail(int sortIndex) {
    return '当前聚焦 sort=$sortIndex；可更新 file_path、state 或 sort_index，必要时删除。';
  }

  @override
  String get projectEditorAssetImagesUnknownState => '未知状态';

  @override
  String get projectEditorAssetImagesSelectionNoImages => '该资产没有图片。';

  @override
  String get projectEditorAssetImagesSelectionCoverNone => '无封面图';

  @override
  String projectEditorAssetImagesSelectionCoverNumeric(int id) {
    return '封面数字图片 #$id';
  }

  @override
  String projectEditorAssetImagesSelectionFocusLine(int sort, String state) {
    return '聚焦 sort=$sort · $state';
  }

  @override
  String projectEditorAssetImagesSelectionSummary(
    int count,
    String coverLine,
    String focusLine,
  ) {
    return '已加载 $count 张图片；$coverLine；$focusLine。';
  }

  @override
  String projectEditorAssetImagesFollowUp(
    String actionSummary,
    String nextAction,
    String detail,
  ) {
    return '$actionSummary 下一步：$nextAction。$detail';
  }

  @override
  String projectEditorAssetImagesFailureNotice(
    String actionSummary,
    String nextAction,
    String reason,
    String fallbackDetail,
  ) {
    return '$actionSummary 下一步：$nextAction。原因：$reason。$fallbackDetail';
  }

  @override
  String get projectEditorAssetImagesNoErrorDetail => '无更多错误详情。';

  @override
  String get projectEditorAssetImagesRecommendedLoadList => '加载图片列表';

  @override
  String get projectEditorAssetImagesRecommendedAddImage => '新增图片';

  @override
  String get projectEditorAssetImagesRecommendedLoadPreview => '加载当前预览';

  @override
  String get projectEditorAssetImagesRecommendedSaveImage => '保存当前图片';

  @override
  String get projectEditorAssetImagesMutationCreateSuccess => '已新增资产图片。';

  @override
  String get projectEditorAssetImagesMutationCreateFailure => '新增资产图片失败。';

  @override
  String get projectEditorAssetImagesMutationCreateFallback =>
      '请检查 file_path、state 或 sort_index 后重试。';

  @override
  String get projectEditorAssetImagesMutationPatchSuccess => '已更新当前图片。';

  @override
  String get projectEditorAssetImagesMutationPatchFailure => '更新当前图片失败。';

  @override
  String get projectEditorAssetImagesMutationPatchFallback =>
      '请先重新读取预览，确认当前图片后再修改。';

  @override
  String get projectEditorAssetImagesMutationDeleteSuccess => '已删除当前图片。';

  @override
  String get projectEditorAssetImagesMutationDeleteFailure => '删除当前图片失败。';

  @override
  String get projectEditorAssetImagesMutationDeleteFallback =>
      '请先刷新图片列表，确认当前选择后再删除。';

  @override
  String get projectEditorAssetImagesPreviewLoadFailed => '读取当前图片预览失败。';

  @override
  String get projectEditorAssetImagesPreviewLoadFailedFallback =>
      '建议先确认 file_path 或切换到其他图片后重试。';

  @override
  String get projectEditorAssetImagesListLoadFailed => '读取当前资产图片列表失败。';

  @override
  String get projectEditorAssetImagesListLoadFailedFallback =>
      '建议稍后重新同步图片列表，确认资产下是否已有图片。';

  @override
  String get projectEditorAssetImagesNoPreviewCleared => '当前没有可预览的图片，已清空预览内容。';

  @override
  String get projectEditorAssetImagesPreviewLoaded => '已读取当前图片预览。';

  @override
  String get projectEditorAssetImagesListSynced => '已同步当前资产的图片列表。';

  @override
  String get projectEditorAssetImagesCreateSortMustBePositive =>
      '新增时 sort_index 须为正整数。';

  @override
  String get projectEditorAssetImagesPatchSortMustBePositive =>
      '编辑时 sort_index 须为正整数。';

  @override
  String get projectEditorAssetImagesSelectImageToEdit => '请先选择要编辑的图片。';

  @override
  String get projectEditorAssetImagesSelectImageToDelete => '请先选择要删除的图片。';

  @override
  String projectEditorAssetImagesSwitchingAsset(int id) {
    return '正在切换到资产 #$id 并加载图片列表…';
  }

  @override
  String get projectEditorAssetImagesSwitchingImagePreview => '正在切换图片并刷新预览…';

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
  String get authSupabaseAuthTitle => 'Supabase 登录';

  @override
  String get authEmailFieldLabel => '邮箱';

  @override
  String get authPasswordFieldLabel => '密码';

  @override
  String get agentWorkspaceScriptArgFillFirstChapter => '填充首章';

  @override
  String get agentWorkspaceScriptArgFillFirstThreeChapters => '填充前 3 章';

  @override
  String get agentWorkspaceScriptArgCarryChapterToEvents => '沿用章节到事件';

  @override
  String get agentWorkspaceRunProjectUuidInvalid => 'projectUuid 格式无效';

  @override
  String get agentWorkspaceRunProjectScopeRequired =>
      '请填写 projectUuid 或正整数 project_id';

  @override
  String get agentWorkspaceRunWorkspaceUuidInvalid => 'workspaceUuid 格式无效';

  @override
  String get agentWorkspaceRunScriptUuidInvalid => 'scriptUuid 格式无效';

  @override
  String get agentWorkspaceRunScriptScopeRequired =>
      '请填写 scriptUuid 或正整数 script_id';

  @override
  String get agentWorkspaceRunPromptRequired => 'prompt 必须有效';

  @override
  String get agentWorkspaceRunToolNameRequired => 'tool 名称必须有效';

  @override
  String get agentWorkspaceRunGetScriptContentNeedsScriptId =>
      'get_script_content 需要有效 script_id';

  @override
  String get agentWorkspaceRunScriptArgsMustBeObject =>
      'script tool arguments 必须是 JSON object';

  @override
  String get agentWorkspaceRunScriptArgsJsonInvalid =>
      'script tool arguments JSON 解析失败';

  @override
  String get agentWorkspaceRunPromptAndToolRequired => 'prompt/tool 必须有效';

  @override
  String get agentWorkspaceRunProductionArgsMustBeObject =>
      'production tool arguments 必须是 JSON object';

  @override
  String get agentWorkspaceRunProductionArgsJsonInvalid =>
      'production tool arguments JSON 解析失败';

  @override
  String get agentWorkspaceRunGetFlowDataNeedsKey => 'get_flowData 需要有效 key';

  @override
  String get agentWorkspaceRunProductionSubAgentArgsMustBeObject =>
      'production sub-agent arguments 必须是 JSON object';

  @override
  String get agentWorkspaceRunProductionSubAgentArgsJsonInvalid =>
      'production sub-agent arguments JSON 解析失败';

  @override
  String get agentWorkspaceHarnessRunCancelledHint => '当前运行已取消，可检查日志后决定是否写回。';

  @override
  String get agentWorkspaceScriptWritebackSourceToolGetScriptContent =>
      'tool:get_script_content';

  @override
  String get agentWorkspaceWritebackScriptInputsInvalid =>
      'project_id/script_id 与可回写结果必须有效';

  @override
  String get agentWorkspaceWritebackProjectNotFound => '未找到项目';

  @override
  String agentWorkspaceWritebackScriptSuccess(
    int numericId,
    String source,
    int length,
  ) {
    return '写回成功：script $numericId 已更新，source=$source，content 长度 $length。';
  }

  @override
  String get agentWorkspaceWritebackPlanInputsInvalid =>
      'project_id 与 planData 回写源必须有效';

  @override
  String get agentWorkspaceWritebackPlanDataMissingData =>
      'planData 结果缺少 data 字段';

  @override
  String agentWorkspaceWritebackPlanDataSetSuccess(
    int projectId,
    int rowCount,
  ) {
    return '写回成功：script-agent planData 已更新（project=$projectId，script_rows=$rowCount）。';
  }

  @override
  String get agentWorkspaceWritebackNeedPlanRowAndPlanData =>
      '需要 planId 与 planData：请先拉取 get_planData（含 plan 行 id）';

  @override
  String agentWorkspaceWritebackPlanDataUpdateSuccess(
    int planRowId,
    int rowCount,
  ) {
    return '写回成功：script-agent update-data（plan_row_id=$planRowId，script_rows=$rowCount）。';
  }

  @override
  String get agentWorkspaceWritebackNeedToolResultFirst => '需先执行工具并拿到结果后再回写';

  @override
  String get agentWorkspaceWritebackMissingToolSource => '缺少工具来源，无法安全回写';

  @override
  String agentWorkspaceWritebackCoreFlowOverwriteBlocked(String flowKey) {
    return '该工具结果不能直接覆盖核心 flow[$flowKey]，请改用扩展 key（如 workspaceResult）或先 get_flowData';
  }

  @override
  String get agentWorkspaceWritebackPayloadEmptyRefreshFlowKey =>
      '回写数据为空，请先刷新对应 flow key 后重试';

  @override
  String agentWorkspaceWritebackFlowSaved(
    String flowKey,
    int projectId,
    int scriptId,
    String source,
  ) {
    return '回写成功：flow[$flowKey] 已保存到 project $projectId / script $scriptId（source=$source）。';
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
  String shortVideoPublishExportCheckQualityGateBlockingLine(
    String reasonLabel,
    String message,
    String routeSuffix,
  ) {
    return '$reasonLabel：$message$routeSuffix';
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
      '半自动发布在「待确认」状态时会暂停，需你点击「确认」后继续；投递结果会写入发布稽核记录，便于追溯。';

  @override
  String get shortVideoSpaceProductionAssemblyExportCompleted => '导出已完成。';

  @override
  String get shortVideoSpaceProductionAssemblyExportNotCompleted =>
      '导出未完成或已取消。';

  @override
  String shortVideoSpaceProductionAssemblyExportStartFailed(String error) {
    return '导出启动失败：$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyReplaceVideoTitle => '替换当前视频版本';

  @override
  String get shortVideoSpaceProductionAssemblyVideoUrlLabel => '视频 URL';

  @override
  String get shortVideoSpaceProductionAssemblyVideoUrlHint => 'https://...';

  @override
  String get shortVideoSpaceProductionAssemblyCancel => '取消';

  @override
  String get shortVideoSpaceProductionAssemblyWriteBackVersion => '写回当前版本';

  @override
  String shortVideoSpaceProductionAssemblyShotDisabled(int storyboardId) {
    return '分镜 #$storyboardId 已暂停（清空当前视频）。';
  }

  @override
  String shortVideoSpaceProductionAssemblyDisableFailed(String error) {
    return '暂停失败：$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyNoVideoUrl =>
      '没有可用视频 URL，请先输入替换地址。';

  @override
  String shortVideoSpaceProductionAssemblyShotWriteBack(int storyboardId) {
    return '分镜 #$storyboardId 已写回当前视频版本。';
  }

  @override
  String shortVideoSpaceProductionAssemblyWriteBackFailed(String error) {
    return '写回失败：$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyReorderPersisted =>
      '已持久化镜头重排顺序（按剧本写回时间线与分镜序号）。';

  @override
  String shortVideoSpaceProductionAssemblyReorderFailed(String error) {
    return '重排持久化失败：$error';
  }

  @override
  String shortVideoSpaceProductionAssemblyShotAligned(
    int storyboardId,
    int duration,
  ) {
    return '分镜 #$storyboardId 已对齐为 ${duration}s。';
  }

  @override
  String shortVideoSpaceProductionAssemblyAlignFailed(String error) {
    return '时长对齐失败：$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblySubtitleExistsDurationMissing =>
      '字幕存在，但时长未显式（建议先对齐时长）。';

  @override
  String get shortVideoSpaceProductionAssemblyDurationSetSubtitleEmpty =>
      '时长已设定，但字幕为空（可能有字幕轨缺口）。';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleExistsDurationAbnormal =>
      '字幕存在，但时长异常（<=0）。';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleDurationNoMismatch =>
      '字幕与时长未见明显错位。';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsTitle => '镜头基础操作';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsDescription =>
      '支持基础重排（本次面板视图）、启停和替换当前视频版本。';

  @override
  String get shortVideoSpaceProductionAssemblyBasicOpsNote =>
      '启停 / 替换会直接写回 J 媒体槽位；重排仅用于本次排障视图。';

  @override
  String shortVideoSpaceProductionAssemblyTotalDuration(
    int seconds,
    String formatted,
  ) {
    return '成片总时长：$seconds秒 ($formatted)';
  }

  @override
  String get shortVideoSpaceProductionAssemblySaveReorder => '保存重排顺序';

  @override
  String get shortVideoSpaceProductionAssemblyUndoToOpen => '撤销到打开时';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverTasks => '配音任务';

  @override
  String get shortVideoSpaceProductionAssemblyClose => '关闭';

  @override
  String get shortVideoSpaceProductionAssemblyNoShotsFiltered =>
      '当前过滤条件下没有镜头，试试清空搜索或放宽条件。';

  @override
  String shortVideoSpaceProductionAssemblyScriptShotOrder(
    int scriptId,
    int storyboardId,
    int order,
  ) {
    return '剧本 #$scriptId · 分镜 #$storyboardId · 顺序 $order';
  }

  @override
  String get shortVideoSpaceProductionAssemblyStatusPaused => '状态：暂停';

  @override
  String shortVideoSpaceProductionAssemblyStatusEnabled(String kind) {
    return '状态：启用（$kind）';
  }

  @override
  String get shortVideoSpaceProductionAssemblyDurationLabel => '时长：';

  @override
  String get shortVideoSpaceProductionAssemblyDurationNotSet => '未设定';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleLabel => ' · 字幕：';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleEmpty => '空';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverScriptReady =>
      '配音文本：✓ 就绪';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverScriptNotReady =>
      '配音文本：✗ 未就绪';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAssetReady =>
      '配音资产：✓ 就绪';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAssetNotReady =>
      '配音资产：✗ 未就绪';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverStatusLabel => '配音状态：';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverAudioLabel => '配音音频：';

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverErrorLabel => '配音错误：';

  @override
  String get shortVideoSpaceProductionAssemblyMismatchCheckLabel => '错位检查：';

  @override
  String get shortVideoSpaceProductionAssemblyMoveUp => '上移';

  @override
  String get shortVideoSpaceProductionAssemblyMoveDown => '下移';

  @override
  String get shortVideoSpaceProductionAssemblyEnable => '启用';

  @override
  String get shortVideoSpaceProductionAssemblyPause => '暂停';

  @override
  String get shortVideoSpaceProductionAssemblyAlignDuration => '时长对齐';

  @override
  String get shortVideoSpaceProductionAssemblyReplaceVersion => '替换当前版本';

  @override
  String get shortVideoSpaceProductionAssemblyGenerateVoiceover => '生成配音';

  @override
  String get shortVideoSpaceProductionAssemblyPreviewVoiceover => '预览配音';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationTitle =>
      '单镜头时长对齐';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationLabel =>
      '时长（秒）';

  @override
  String get shortVideoSpaceProductionAssemblySingleShotDurationHint =>
      '输入 1~300';

  @override
  String get shortVideoSpaceProductionAssemblyAlignAndWriteBack => '对齐并写回';

  @override
  String get shortVideoSpaceProductionAssemblyAssemblyStyleTitle => '成片级样式调整';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleStyleLabel =>
      '字幕样式 subtitle_style';

  @override
  String get shortVideoSpaceProductionAssemblySubtitleStyleHint =>
      '例如 cinematic_cn_v2（留空则回退默认）';

  @override
  String get shortVideoSpaceProductionAssemblyBgmStrategyLabel =>
      'BGM 策略 bgm_strategy';

  @override
  String get shortVideoSpaceProductionAssemblyBgmStrategyHint =>
      '例如 pulse_light（留空则回退默认）';

  @override
  String get shortVideoSpaceProductionAssemblyStyleNote =>
      '保存后会写回 D7 默认配置，并刷新成片装配快照中的生效值。';

  @override
  String get shortVideoSpaceProductionAssemblySaveAndRefresh => '保存并刷新';

  @override
  String shortVideoSpaceProductionAssemblyStyleUpdated(
    String subtitle,
    String bgm,
  ) {
    return '已更新成片级默认：字幕 $subtitle · BGM $bgm';
  }

  @override
  String get shortVideoSpaceProductionAssemblyStyleDefault => '默认';

  @override
  String shortVideoSpaceProductionAssemblyStyleWriteBackFailed(String error) {
    return '成片样式写回失败：$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyVoiceoverTaskCenterTitle =>
      '配音任务中心';

  @override
  String get shortVideoSpaceProductionAssemblyAllStatus => '全部状态';

  @override
  String get shortVideoSpaceProductionAssemblyRefresh => '刷新';

  @override
  String get shortVideoSpaceProductionAssemblyGroupByShot => '按分镜聚合';

  @override
  String shortVideoSpaceProductionAssemblyBatchRetryFailed(int count) {
    return '批量重试（$count）';
  }

  @override
  String get shortVideoSpaceProductionAssemblyFilterTaskIdScriptShot =>
      '筛选：任务ID / 剧本号 / 分镜号';

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
    return '共 $total 条 · 排队 $queued · 执行中 $running · 成功 $succeeded · 失败 $failed · 已取消 $cancelled · 展示 $filtered/$visible';
  }

  @override
  String get shortVideoSpaceProductionAssemblyNoVoiceoverTasks => '暂无配音任务';

  @override
  String shortVideoSpaceProductionAssemblyTaskEntry(
    String prefix,
    String taskId,
    String status,
  ) {
    return '$prefix $taskId · 状态 $status';
  }

  @override
  String get shortVideoSpaceProductionAssemblyLatestTask => '最近任务';

  @override
  String get shortVideoSpaceProductionAssemblyTask => '任务';

  @override
  String shortVideoSpaceProductionAssemblyTaskSubtitle(
    String scriptId,
    String shotId,
    String audio,
    String error,
  ) {
    return '剧本 #$scriptId · 分镜 #$shotId$audio$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyTaskSubtitleAudioReady =>
      ' · 音频就绪';

  @override
  String shortVideoSpaceProductionAssemblyTaskSubtitleError(String error) {
    return ' · 错误: $error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyPreviewAudio => '预览音频';

  @override
  String get shortVideoSpaceProductionAssemblyCopyAudioLink => '复制音频链接';

  @override
  String get shortVideoSpaceProductionAssemblyAudioLinkCopied => '已复制音频链接';

  @override
  String get shortVideoSpaceProductionAssemblyCancelTask => '取消';

  @override
  String shortVideoSpaceProductionAssemblyTaskCancelled(String taskId) {
    return '已取消配音任务 $taskId';
  }

  @override
  String shortVideoSpaceProductionAssemblyCancelFailed(String error) {
    return '取消失败：$error';
  }

  @override
  String get shortVideoSpaceProductionAssemblyRetryTask => '重试';

  @override
  String shortVideoSpaceProductionAssemblyTaskRetried(String taskId) {
    return '已重试，任务 $taskId 已入队';
  }

  @override
  String shortVideoSpaceProductionAssemblyRetryFailed(String error) {
    return '重试失败：$error';
  }

  @override
  String shortVideoSpaceProductionAssemblyBatchRetryCompleted(
    int succeeded,
    int failed,
  ) {
    return '批量重试完成：成功 $succeeded，失败 $failed';
  }

  @override
  String shortVideoSpaceProductionAssemblyLoadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String shortVideoAssemblyDraftLoadFailed(String error) {
    return '加载草稿和版本失败：$error';
  }

  @override
  String get shortVideoAssemblyDraftNoShotsToApply => '没有可应用的镜头数据';

  @override
  String get shortVideoAssemblyDraftNoShotsToSave => '没有可保存的镜头数据';

  @override
  String shortVideoAssemblyDraftLimitReached(int max) {
    return '草稿数量已达上限（最多 $max 个）';
  }

  @override
  String get shortVideoAssemblyDraftNotFound => '草稿不存在';

  @override
  String get shortVideoAssemblyDraftNoDataToDelete => '没有可删除的草稿数据';

  @override
  String shortVideoAssemblyDraftSaved(String name) {
    return '草稿「$name」保存成功';
  }

  @override
  String shortVideoAssemblyDraftSaveFailed(String error) {
    return '保存草稿失败：$error';
  }

  @override
  String shortVideoAssemblyDraftRestored(String name) {
    return '草稿「$name」已恢复';
  }

  @override
  String shortVideoAssemblyDraftRestoreFailed(String error) {
    return '恢复草稿失败：$error';
  }

  @override
  String get shortVideoAssemblyDraftDeleted => '草稿已删除';

  @override
  String shortVideoAssemblyDraftDeleteFailed(String error) {
    return '删除草稿失败：$error';
  }

  @override
  String get shortVideoAssemblyVersionNameEmpty => '版本名称不能为空';

  @override
  String get shortVideoAssemblyVersionNoAssembly => '没有可用的装配数据';

  @override
  String shortVideoAssemblyVersionLimitReached(int max) {
    return '成片版本已达上限（最多 $max 个）';
  }

  @override
  String shortVideoAssemblyVersionCreated(String name) {
    return '已创建成片版本「$name」';
  }

  @override
  String shortVideoAssemblyVersionCreateFailed(String error) {
    return '创建版本失败：$error';
  }

  @override
  String get shortVideoAssemblyVersionNotFound => '版本不存在';

  @override
  String shortVideoAssemblyVersionSwitched(String name) {
    return '已切换到版本「$name」';
  }

  @override
  String shortVideoAssemblyVersionSwitchFailed(String error) {
    return '切换版本失败：$error';
  }

  @override
  String get shortVideoAssemblyVersionKeepAtLeastOne => '至少保留 1 个成片版本快照';

  @override
  String get shortVideoAssemblyVersionDeleted => '版本已删除';

  @override
  String shortVideoAssemblyVersionDeleteFailed(String error) {
    return '删除版本失败：$error';
  }

  @override
  String get shortVideoVersionManagerDefaultVersion => '默认版本';

  @override
  String get shortVideoVersionManagerTitle => '版本管理';

  @override
  String get shortVideoVersionManagerCompareVersions => '对比版本';

  @override
  String get shortVideoVersionManagerCreateNewVersion => '创建新版本';

  @override
  String get shortVideoVersionManagerSaveDraft => '保存草稿';

  @override
  String shortVideoVersionManagerCurrentVersion(String name) {
    return '当前版本：$name';
  }

  @override
  String shortVideoVersionManagerCurrentVersionMeta(
    int shotCount,
    String dateTime,
  ) {
    return '镜头数：$shotCount · 创建时间：$dateTime';
  }

  @override
  String shortVideoVersionManagerAllVersions(int count) {
    return '所有版本 ($count)';
  }

  @override
  String get shortVideoVersionManagerNoVersionsHint => '暂无版本，点击上方按钮创建第一个版本';

  @override
  String shortVideoVersionManagerVersionRowSubtitle(
    int shotCount,
    String dateTime,
  ) {
    return '镜头数：$shotCount · 创建时间：$dateTime';
  }

  @override
  String get shortVideoVersionManagerTooltipSwitchVersion => '切换到此版本';

  @override
  String get shortVideoVersionManagerTooltipDeleteVersion => '删除版本';

  @override
  String shortVideoVersionManagerDraftsHeader(int count, int max) {
    return '草稿 ($count/$max)';
  }

  @override
  String get shortVideoVersionManagerViewAllDrafts => '查看全部';

  @override
  String get shortVideoVersionManagerNoDraftsHint =>
      '暂无草稿，点击上方「保存草稿」按钮保存当前编辑状态';

  @override
  String shortVideoVersionManagerDraftRowSubtitle(
    int shotCount,
    String dateTime,
  ) {
    return '镜头数：$shotCount · 保存时间：$dateTime';
  }

  @override
  String shortVideoVersionManagerDraftListRowSubtitle(
    int shotCount,
    String dateTime,
  ) {
    return '镜头数：$shotCount\n保存时间：$dateTime';
  }

  @override
  String get shortVideoVersionManagerTooltipRestoreDraft => '恢复草稿';

  @override
  String get shortVideoVersionManagerTooltipDeleteDraft => '删除草稿';

  @override
  String get shortVideoVersionManagerCreateVersionDialogTitle => '创建新版本';

  @override
  String get shortVideoVersionManagerCreateVersionDialogBody => '新版本将复制当前镜头配置。';

  @override
  String get shortVideoVersionManagerVersionNameLabel => '版本名称';

  @override
  String get shortVideoVersionManagerVersionNameHint => '例如：优化版 v2';

  @override
  String get shortVideoVersionManagerCreateAction => '创建';

  @override
  String get shortVideoVersionManagerDraftLimitTitle => '草稿数量已达上限';

  @override
  String get shortVideoVersionManagerDraftLimitBody =>
      '最多只能保存 10 个草稿。\n\n请先删除一些旧草稿，然后再保存新草稿。';

  @override
  String get shortVideoVersionManagerGotIt => '知道了';

  @override
  String get shortVideoVersionManagerViewDraftsList => '查看草稿';

  @override
  String get shortVideoVersionManagerSaveDraftDialogTitle => '保存草稿';

  @override
  String get shortVideoVersionManagerSaveDraftDialogBody =>
      '草稿将保存当前编辑状态，方便稍后继续编辑。';

  @override
  String get shortVideoVersionManagerDraftNameLabel => '草稿名称';

  @override
  String get shortVideoVersionManagerDraftNameHint => '例如：实验性剪辑 v1';

  @override
  String get shortVideoVersionManagerDraftListTitle => '草稿列表';

  @override
  String get shortVideoVersionManagerNoDraftsInList => '暂无草稿';

  @override
  String shortVideoVersionManagerSnackbarVersionCreated(String name) {
    return '版本「$name」创建成功';
  }

  @override
  String shortVideoVersionManagerErrorVersionCreate(String error) {
    return '创建版本失败：$error';
  }

  @override
  String shortVideoVersionManagerSnackbarVersionSwitched(String name) {
    return '已切换到版本「$name」';
  }

  @override
  String shortVideoVersionManagerErrorVersionSwitch(String error) {
    return '切换版本失败：$error';
  }

  @override
  String shortVideoVersionManagerSnackbarVersionDeleted(String name) {
    return '版本「$name」已删除';
  }

  @override
  String shortVideoVersionManagerErrorVersionDelete(String error) {
    return '删除版本失败：$error';
  }

  @override
  String shortVideoVersionManagerSnackbarDraftSaved(String name) {
    return '草稿「$name」保存成功';
  }

  @override
  String shortVideoVersionManagerErrorDraftSave(String error) {
    return '保存草稿失败：$error';
  }

  @override
  String shortVideoVersionManagerSnackbarDraftRestored(String name) {
    return '草稿「$name」已恢复';
  }

  @override
  String shortVideoVersionManagerErrorDraftRestore(String error) {
    return '恢复草稿失败：$error';
  }

  @override
  String get shortVideoVersionManagerConfirmDeleteDraftTitle => '确认删除';

  @override
  String shortVideoVersionManagerConfirmDeleteDraftBody(String name) {
    return '确定要删除草稿「$name」吗？\n\n此操作无法撤销。';
  }

  @override
  String shortVideoVersionManagerSnackbarDraftDeleted(String name) {
    return '草稿「$name」已删除';
  }

  @override
  String shortVideoVersionManagerErrorDraftDelete(String error) {
    return '删除草稿失败：$error';
  }

  @override
  String get shortVideoVersionManagerCompareDialogTitle => '选择要对比的版本';

  @override
  String get shortVideoVersionManagerCompareBaseLabel => '选择基准版本（旧版本）：';

  @override
  String get shortVideoVersionManagerCompareBaseHint => '选择基准版本';

  @override
  String get shortVideoVersionManagerCompareTargetLabel => '选择对比版本（新版本）：';

  @override
  String get shortVideoVersionManagerCompareTargetHint => '选择对比版本';

  @override
  String shortVideoVersionManagerCompareVersionWithShots(
    String versionName,
    int shotCount,
  ) {
    return '$versionName（$shotCount 镜头）';
  }

  @override
  String get shortVideoVersionManagerStartCompare => '开始对比';

  @override
  String get shortVideoVersionComparisonDiffAdded => '新增镜头';

  @override
  String get shortVideoVersionComparisonDiffRemoved => '删除镜头';

  @override
  String shortVideoVersionComparisonDiffModifiedField(String fieldName) {
    return '修改 $fieldName';
  }

  @override
  String get shortVideoVersionComparisonDiffModifiedGeneric => '修改';

  @override
  String get shortVideoVersionComparisonDiffUnchanged => '未变化';

  @override
  String get shortVideoVersionComparisonReportSeparator => '---';

  @override
  String get shortVideoVersionComparisonReportTitle => '# 版本对比报告';

  @override
  String get shortVideoVersionComparisonReportVersionInfo => '## 版本信息';

  @override
  String shortVideoVersionComparisonReportBaseVersionLine(String name) {
    return '**基准版本（旧）：** $name';
  }

  @override
  String shortVideoVersionComparisonReportCreatedAt(String dateTime) {
    return '- 创建时间：$dateTime';
  }

  @override
  String shortVideoVersionComparisonReportShotCount(int count) {
    return '- 镜头数：$count';
  }

  @override
  String shortVideoVersionComparisonReportCompareVersionLine(String name) {
    return '**对比版本（新）：** $name';
  }

  @override
  String get shortVideoVersionComparisonReportStatistics => '## 差异统计';

  @override
  String shortVideoVersionComparisonReportTotalShots(int count) {
    return '- 总镜头数：$count';
  }

  @override
  String shortVideoVersionComparisonReportAdded(int count) {
    return '- 新增镜头：$count';
  }

  @override
  String shortVideoVersionComparisonReportRemoved(int count) {
    return '- 删除镜头：$count';
  }

  @override
  String shortVideoVersionComparisonReportModified(int count) {
    return '- 修改镜头：$count';
  }

  @override
  String shortVideoVersionComparisonReportUnchanged(int count) {
    return '- 未变化镜头：$count';
  }

  @override
  String shortVideoVersionComparisonReportChangeRate(String percent) {
    return '- 变化率：$percent';
  }

  @override
  String get shortVideoVersionComparisonReportDetails => '## 详细差异';

  @override
  String shortVideoVersionComparisonReportSectionAdded(int count) {
    return '### 新增镜头（$count）';
  }

  @override
  String shortVideoVersionComparisonReportSectionRemoved(int count) {
    return '### 删除镜头（$count）';
  }

  @override
  String get shortVideoVersionComparisonReportSectionModified => '### 修改镜头';

  @override
  String shortVideoVersionComparisonReportShotItem(String shotId) {
    return '- 镜头 $shotId';
  }

  @override
  String shortVideoVersionComparisonReportShotHeading(String shotId) {
    return '#### 镜头 $shotId';
  }

  @override
  String shortVideoVersionComparisonReportFieldLine(String fieldName) {
    return '- **$fieldName**';
  }

  @override
  String shortVideoVersionComparisonReportOldValue(String value) {
    return '  - 旧值：$value';
  }

  @override
  String shortVideoVersionComparisonReportNewValue(String value) {
    return '  - 新值：$value';
  }

  @override
  String shortVideoVersionComparisonReportGeneratedFooter(String dateTime) {
    return '*报告生成时间：$dateTime*';
  }

  @override
  String get shortVideoVersionComparisonValueEmpty => '(空)';

  @override
  String get shortVideoVersionComparisonValueYes => '是';

  @override
  String get shortVideoVersionComparisonValueNo => '否';

  @override
  String shortVideoVersionComparisonValueList(int count) {
    return '列表（$count 项）';
  }

  @override
  String shortVideoVersionComparisonValueObject(int count) {
    return '对象（$count 个字段）';
  }

  @override
  String get shortVideoVersionComparisonReportCopied => '对比报告已复制到剪贴板';

  @override
  String get shortVideoVersionComparisonSnackbarView => '查看';

  @override
  String shortVideoVersionComparisonExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String get shortVideoVersionComparisonReportDialogTitle => '对比报告';

  @override
  String get shortVideoVersionComparisonCopy => '复制';

  @override
  String get shortVideoVersionComparisonClipboardCopied => '已复制到剪贴板';

  @override
  String get shortVideoVersionComparisonTitle => '版本对比';

  @override
  String get shortVideoVersionComparisonStatAdded => '新增';

  @override
  String get shortVideoVersionComparisonStatRemoved => '删除';

  @override
  String get shortVideoVersionComparisonStatModified => '修改';

  @override
  String get shortVideoVersionComparisonStatUnchanged => '未变化';

  @override
  String get shortVideoVersionComparisonStatChangeRate => '变化率';

  @override
  String get shortVideoVersionComparisonSearchHint => '搜索镜头 ID 或字段名…';

  @override
  String get shortVideoVersionComparisonShowChangesOnly => '仅显示变化';

  @override
  String get shortVideoVersionComparisonExportReport => '导出报告';

  @override
  String get shortVideoVersionComparisonEmptyNoMatch => '没有找到匹配的差异';

  @override
  String get shortVideoVersionComparisonEmptyIdentical => '两个版本完全相同';

  @override
  String shortVideoVersionComparisonShotTitle(String shotId) {
    return '镜头 $shotId';
  }

  @override
  String get shortVideoVersionComparisonBadgeOld => '旧';

  @override
  String get shortVideoVersionComparisonBadgeNew => '新';

  @override
  String get shortVideoPublishPanelTitle => '发布准备';

  @override
  String get shortVideoPublishPanelResetDontShowAgain => '重置「不再提示」';

  @override
  String get shortVideoPublishPanelMatrixDomesticLabel => '国内平台矩阵（占位约束）';

  @override
  String get shortVideoPublishPanelMatrixOverseasLabel => '海外平台矩阵（占位约束）';

  @override
  String get shortVideoPublishPanelPrepareChecks => '发布准备校验';

  @override
  String get shortVideoPublishPanelDraftListHeading => '发布单（草稿）';

  @override
  String get shortVideoPublishPanelMultiSelectExit => '退出多选';

  @override
  String get shortVideoPublishPanelMultiSelectMode => '多选模式';

  @override
  String shortVideoPublishPanelSelectedDraftCount(int count) {
    return '已选择 $count 张草稿';
  }

  @override
  String get shortVideoPublishPanelSelectAll => '全选';

  @override
  String get shortVideoPublishPanelClearSelection => '清空';

  @override
  String get shortVideoPublishPanelBatchSchedule => '批量定时';

  @override
  String get shortVideoPublishPanelBatchPublish => '批量发布';

  @override
  String get shortVideoPublishPanelBatchArchive => '批量归档';

  @override
  String get shortVideoPublishPanelCompareDrafts => '对比草稿';

  @override
  String get shortVideoPublishPanelBatchValidationTitle => '批量验证结果';

  @override
  String shortVideoPublishPanelBatchValidationSummary(int ready, int blocked) {
    return '就绪：$ready 张 · 阻塞：$blocked 张';
  }

  @override
  String get shortVideoPublishPanelCurrentDraftLabel => '当前操作草稿';

  @override
  String get shortVideoPublishPanelSelectDraftHint => '请选择要操作的草稿';

  @override
  String get shortVideoPublishPanelUntitledDraft => '（无标题）';

  @override
  String shortVideoPublishDraftDropdownLabel(String title, String status) {
    return '$title｜$status';
  }

  @override
  String shortVideoMetricChipLine(String label, String value) {
    return '$label $value';
  }

  @override
  String get shortVideoPublishPanelConfirmSemiAuto => '确认半自动发布（服务端闸门）';

  @override
  String get shortVideoPublishPanelAutomationByPlatform => '自动化模式（按平台）';

  @override
  String get shortVideoPublishPanelRefreshPublish => '刷新发布数据';

  @override
  String get shortVideoPublishPanelBootstrapDraft => '创建发布草稿并写入平台目标';

  @override
  String get shortVideoPublishPanelEnqueueJob => '投递发布作业';

  @override
  String get shortVideoPublishPanelEnqueueJobBlocked => '投递发布作业（存在阻塞项）';

  @override
  String get shortVideoPublishPanelEnqueueAllDrafts => '批量投递全部草稿';

  @override
  String get shortVideoPublishPanelEnqueueAllDraftsBlocked => '批量投递全部草稿（存在阻塞项）';

  @override
  String get shortVideoPublishPanelRetryFailedJobs => '批量重试失败作业';

  @override
  String get shortVideoPublishPanelSuggestCopy => '生成差异化文案';

  @override
  String get shortVideoPublishPanelClearSchedule => '清除定时（允许入队）';

  @override
  String get shortVideoPublishPanelScheduleCurrentDraft => '定时当前草稿…';

  @override
  String get shortVideoPublishPanelScheduleAllDrafts => '批量定时全部草稿…';

  @override
  String get shortVideoPublishPanelOpenTroubleshooting => '打开发布排障入口';

  @override
  String get shortVideoPublishPanelBatchResultSummary => '批量结果摘要';

  @override
  String get shortVideoPublishBatchSelectDraftsToSchedule => '请先选择要定时的草稿。';

  @override
  String get shortVideoPublishBatchScheduleValidateTitle => '批量定时验证';

  @override
  String shortVideoPublishBatchReadyDraftsCount(int count) {
    return '就绪：$count 张草稿';
  }

  @override
  String shortVideoPublishBatchBlockedDraftsCount(int count) {
    return '阻塞：$count 张草稿';
  }

  @override
  String get shortVideoPublishBatchBlockedReasonsLabel => '阻塞原因：';

  @override
  String get shortVideoPublishBatchContinueScheduleReady => '继续定时就绪草稿';

  @override
  String shortVideoPublishBatchScheduledCount(int count, String iso) {
    return '已批量定时 $count 张草稿：$iso（UTC）';
  }

  @override
  String shortVideoPublishBatchScheduleFailedStatus(int statusCode) {
    return '批量定时失败：$statusCode';
  }

  @override
  String shortVideoPublishBatchScheduleFailed(String error) {
    return '批量定时失败：$error';
  }

  @override
  String get shortVideoPublishBatchSelectDraftsToPublish => '请先选择要发布的草稿。';

  @override
  String get shortVideoPublishBatchPublishValidateTitle => '批量发布验证';

  @override
  String get shortVideoPublishBatchContinuePublishReady => '继续发布就绪草稿';

  @override
  String shortVideoPublishBatchPublishDone(int succeeded, int failed) {
    return '批量发布完成：成功 $succeeded，失败 $failed';
  }

  @override
  String shortVideoPublishBatchPublishFailedStatus(int statusCode) {
    return '批量发布失败：$statusCode';
  }

  @override
  String shortVideoPublishBatchPublishFailed(String error) {
    return '批量发布失败：$error';
  }

  @override
  String get shortVideoPublishBatchSelectDraftsToArchive => '请先选择要归档的草稿。';

  @override
  String shortVideoPublishBatchArchivedCount(int count) {
    return '已归档 $count 张草稿';
  }

  @override
  String shortVideoPublishBatchArchiveFailedStatus(int statusCode) {
    return '批量归档失败：$statusCode';
  }

  @override
  String shortVideoPublishBatchArchiveFailed(String error) {
    return '批量归档失败：$error';
  }

  @override
  String get shortVideoPublishBatchCompareSelectCount => '请选择 2-4 张草稿进行对比。';

  @override
  String get shortVideoPublishBatchCompareStaleSelection =>
      '部分选中草稿已不存在，请刷新发布区后重试。';

  @override
  String shortVideoPublishDraftCompareTitle(int count) {
    return '发布草稿对比（$count）';
  }

  @override
  String get shortVideoPublishDraftCompareIntro =>
      '按当前多选顺序展示。可核对标题、定时、资产键与分平台文案差异。';

  @override
  String get shortVideoPublishDraftComparePerPlatformHeading =>
      '分平台文案（title / description / tags）';

  @override
  String shortVideoPublishDraftCompareIdLine(String shortId) {
    return 'ID：$shortId';
  }

  @override
  String get shortVideoPublishDraftCompareFieldStatus => '状态';

  @override
  String get shortVideoPublishDraftCompareFieldScheduled => '定时';

  @override
  String get shortVideoPublishDraftCompareFieldScript => '剧本';

  @override
  String get shortVideoPublishDraftCompareFieldVideoAsset => '视频资产';

  @override
  String get shortVideoPublishDraftCompareFieldCover => '封面';

  @override
  String get shortVideoPublishDraftCompareFieldSummary => '简介';

  @override
  String get shortVideoPublishDraftCompareFieldTags => '标签';

  @override
  String shortVideoPublishDraftComparePlatformTitle(String platformId) {
    return '平台 $platformId';
  }

  @override
  String shortVideoPublishDraftCompareCopyLineTitle(String value) {
    return 'title: $value';
  }

  @override
  String shortVideoPublishDraftCompareCopyLineDescription(String value) {
    return 'description: $value';
  }

  @override
  String shortVideoPublishDraftCompareCopyLineTags(String value) {
    return 'tags: $value';
  }

  @override
  String get shortVideoPublishCopyCreateDraftFirst => '请先创建发布草稿。';

  @override
  String get shortVideoPublishCopySelectDraftToSuggest => '请先明确选择要生成文案的草稿。';

  @override
  String shortVideoPublishCopySuggestApplied(String source) {
    return '差异化文案已写入（来源：$source）。';
  }

  @override
  String shortVideoPublishCopySuggestFailedStatus(int statusCode) {
    return '文案建议失败：$statusCode';
  }

  @override
  String shortVideoPublishCopySuggestFailed(String error) {
    return '文案建议失败：$error';
  }

  @override
  String get shortVideoPublishCopySelectDraftToEdit => '请先明确选择要编辑文案的草稿。';

  @override
  String get shortVideoPublishCopySaved => '已保存差异化文案。';

  @override
  String shortVideoPublishCopySaveFailedStatus(int statusCode) {
    return '保存文案失败：$statusCode';
  }

  @override
  String shortVideoPublishCopySaveFailed(String error) {
    return '保存文案失败：$error';
  }

  @override
  String get shortVideoPublishOpsDefaultDraftTitle => '发布草稿';

  @override
  String get shortVideoPublishOpsDraftCreated => '已创建发布草稿并写入平台目标。';

  @override
  String shortVideoPublishOpsCreateDraftFailedStatus(int statusCode) {
    return '发布草稿失败：$statusCode';
  }

  @override
  String shortVideoPublishOpsCreateDraftFailed(String error) {
    return '发布草稿失败：$error';
  }

  @override
  String shortVideoPublishOpsSelectActiveDraftWhenMany(String draftLabel) {
    return '有多张发布草稿时，请先在「$draftLabel」中选择一张。';
  }

  @override
  String get shortVideoPublishOpsJobSubmitted => '已投递发布作业（服务端 worker 将处理队列）。';

  @override
  String shortVideoPublishOpsEnqueueFailedStatus(int statusCode) {
    return '投递失败：$statusCode';
  }

  @override
  String shortVideoPublishOpsEnqueueFailed(String error) {
    return '投递失败：$error';
  }

  @override
  String shortVideoPublishOpsBatchEnqueueResult(int ok, int total) {
    return '批量投递完成：$ok/$total 成功。';
  }

  @override
  String shortVideoPublishOpsBatchLineOk(String ref) {
    return 'OK · $ref';
  }

  @override
  String shortVideoPublishOpsBatchLineFail(String id, String detail) {
    return 'FAIL · $id · $detail';
  }

  @override
  String shortVideoPublishOpsBatchLineRetryOk(String jobId) {
    return 'OK · 重试作业 $jobId';
  }

  @override
  String shortVideoPublishOpsBatchRetryResult(int ok, int total) {
    return '批量重试完成：$ok/$total 成功。';
  }

  @override
  String get shortVideoPublishOpsSemiAutoConfirmed => '已确认半自动闸门，worker 将继续投递。';

  @override
  String shortVideoPublishOpsConfirmFailedStatus(int statusCode) {
    return '确认失败：$statusCode';
  }

  @override
  String shortVideoPublishOpsConfirmFailed(String error) {
    return '确认失败：$error';
  }

  @override
  String get shortVideoPublishScheduleSelectDraftFirst => '请先明确选择要定时的草稿。';

  @override
  String shortVideoPublishScheduleSingleSet(String iso) {
    return '已设为定时：$iso（UTC）';
  }

  @override
  String shortVideoPublishScheduleSingleFailedStatus(int statusCode) {
    return '定时失败：$statusCode';
  }

  @override
  String shortVideoPublishScheduleSingleFailed(String error) {
    return '定时失败：$error';
  }

  @override
  String shortVideoPublishScheduleCalendarTitle(String day) {
    return '批量定时 · $day';
  }

  @override
  String get shortVideoPublishScheduleCalendarIncludeScheduled =>
      '包含已定时草稿并重写为该时刻';

  @override
  String get shortVideoPublishScheduleCalendarHintOverrideAll =>
      '将对当前列表中的全部草稿写入同一发布时间。';

  @override
  String get shortVideoPublishScheduleCalendarHintNewOnly =>
      '仅对尚未填写定时的草稿写入发布时间。';

  @override
  String get shortVideoPublishScheduleCalendarChooseTime => '选择时间';

  @override
  String get shortVideoPublishScheduleCalendarNoDrafts =>
      '没有符合条件的草稿（试勾选「包含已定时」）。';

  @override
  String shortVideoPublishScheduleCalendarUpdated(int count, String iso) {
    return '已更新 $count 张草稿定时：$iso（UTC）';
  }

  @override
  String shortVideoPublishScheduleCalendarFailedStatus(int statusCode) {
    return '日历批量定时失败：$statusCode';
  }

  @override
  String shortVideoPublishScheduleCalendarFailed(String error) {
    return '日历批量定时失败：$error';
  }

  @override
  String shortVideoPublishScheduleClearUpdated(int count) {
    return '已更新 $count 张草稿的定时字段（可为 worker 放行）。';
  }

  @override
  String shortVideoPublishScheduleClearFailedStatus(int statusCode) {
    return '清除定时失败：$statusCode';
  }

  @override
  String shortVideoPublishScheduleClearFailed(String error) {
    return '清除定时失败：$error';
  }

  @override
  String get shortVideoExportSettingsTitle => '导出设置';

  @override
  String get shortVideoExportSettingsFormatLabel => '导出格式';

  @override
  String get shortVideoExportSettingsResolutionLabel => '分辨率';

  @override
  String get shortVideoExportSettingsBitrateLabel => '码率';

  @override
  String get shortVideoExportSettingsFramerateLabel => '帧率';

  @override
  String shortVideoExportSettingsFramerateOption(int framerate) {
    return '$framerate FPS';
  }

  @override
  String get shortVideoExportSettingsEstimatedSize => '预估文件大小';

  @override
  String shortVideoExportSettingsBasedOnDuration(int seconds) {
    return '基于 $seconds 秒视频时长';
  }

  @override
  String get shortVideoExportSettingsExportTimeHint =>
      '导出时间取决于视频长度和质量设置。高质量设置将需要更长的处理时间。';

  @override
  String get shortVideoExportSettingsStartExport => '开始导出';

  @override
  String get shortVideoExportFormatMp4 => 'MP4 (推荐)';

  @override
  String get shortVideoExportFormatMov => 'MOV (高质量)';

  @override
  String get shortVideoExportFormatWebm => 'WebM (网络优化)';

  @override
  String get shortVideoExportResolution1080p => '1080p (1920×1080)';

  @override
  String get shortVideoExportResolution720p => '720p (1280×720)';

  @override
  String get shortVideoExportResolution480p => '480p (854×480)';

  @override
  String get shortVideoExportResolution360p => '360p (640×360)';

  @override
  String get shortVideoExportBitrateHigh => '高 (8 Mbps)';

  @override
  String get shortVideoExportBitrateMedium => '中 (4 Mbps)';

  @override
  String get shortVideoExportBitrateLow => '低 (2 Mbps)';

  @override
  String get shortVideoAudioPreviewTitle => '配音预览';

  @override
  String get shortVideoAudioPreviewCloseTooltip => '关闭';

  @override
  String get shortVideoAudioPreviewLoading => '正在加载音频…';

  @override
  String get shortVideoAudioPreviewTooltipStop => '停止';

  @override
  String get shortVideoAudioPreviewTooltipPlay => '播放';

  @override
  String get shortVideoAudioPreviewTooltipPause => '暂停';

  @override
  String shortVideoAudioPreviewLoadFailed(String error) {
    return '加载音频失败：$error';
  }

  @override
  String shortVideoAudioPreviewPlaybackFailed(String error) {
    return '播放控制失败：$error';
  }

  @override
  String shortVideoAudioPreviewStopFailed(String error) {
    return '停止播放失败：$error';
  }

  @override
  String shortVideoAudioPreviewSeekFailed(String error) {
    return '跳转失败：$error';
  }

  @override
  String shortVideoAudioPreviewVolumeFailed(String error) {
    return '音量调节失败：$error';
  }

  @override
  String get shortVideoOpHistoryEnableShot => '启用镜头';

  @override
  String get shortVideoOpHistoryDisableShot => '禁用镜头';

  @override
  String get shortVideoOpHistoryReorderShots => '重排镜头顺序';

  @override
  String get shortVideoOpHistoryAdjustDuration => '调整镜头时长';

  @override
  String get shortVideoOpHistoryReplaceVideo => '替换视频';

  @override
  String get shortVideoOpHistoryBatchEnable => '批量启用镜头';

  @override
  String get shortVideoOpHistoryBatchDisable => '批量禁用镜头';

  @override
  String get shortVideoOpHistoryBatchDuration => '批量时长对齐';

  @override
  String get shortVideoOpHistoryBatchReplace => '批量替换视频';

  @override
  String get shortVideoOpHistoryEditOperation => '编辑操作';

  @override
  String shortVideoProjectVisualStylePack(String pack) {
    return '风格包 $pack';
  }

  @override
  String shortVideoProjectVisualArtStyle(String style) {
    return '画风 $style';
  }

  @override
  String shortVideoProjectDirectionStoryPack(String pack) {
    return '故事包 $pack';
  }

  @override
  String shortVideoProjectDirectionManual(String manual) {
    return '手册 $manual';
  }

  @override
  String get shortVideoProjectReadinessAwaitingStats =>
      '读取项目统计后，会在这里提示你更适合先去脚本还是制作。';

  @override
  String get shortVideoProjectReadinessNoScript => '当前项目还没有剧本，建议先去脚本工作区生成第一版。';

  @override
  String get shortVideoProjectReadinessNoStoryboard =>
      '已有剧本但还缺分镜，建议先继续脚本/分镜规划，再进入制作。';

  @override
  String get shortVideoProjectReadinessNoRoles =>
      '已有脚本和分镜，但角色资产还少，建议先补角色与参考素材。';

  @override
  String get shortVideoProjectReadinessProductionReady =>
      '脚本、分镜和角色资产都已有基础，可以直接进入制作工作区继续出图和出片。';

  @override
  String get shortVideoSpaceOverviewAggregating => '正在汇总当前项目的脚本、任务和质检状态…';

  @override
  String get shortVideoSpaceOverviewSelectProjectFirst =>
      '先选一个项目，Space 才能把当前模式、任务和质检线索收成同一张概览。';

  @override
  String get shortVideoSpaceOverviewProjectSelectedNoStats =>
      '项目已选中，但概览还没读到。可以先刷新项目或直接进入脚本工作区。';

  @override
  String shortVideoSpaceOverviewRecentFailedTasks(int count) {
    return '这个项目最近有 $count 个失败任务，建议先去任务中心定位失败点，再继续出图或出片。';
  }

  @override
  String shortVideoSpaceOverviewRunningTasks(int count) {
    return '当前还有 $count 个任务在处理中，适合先去任务中心盯进度，同时准备下一轮脚本或素材。';
  }

  @override
  String shortVideoSpaceOverviewBadCaseRecords(int count) {
    return '这个项目已有 $count 条坏例记录，建议先看质量评审再决定是改脚本还是重做分镜。';
  }

  @override
  String shortVideoSpaceOverviewRecentTaskRecords(int count) {
    return '当前项目最近已有 $count 条任务记录，基础链路已经跑起来了，可以继续推进脚本、制作或质检复核。';
  }

  @override
  String get shortVideoNextStepCtaGoProjectsFirst => '先去项目区';

  @override
  String get shortVideoNextStepCtaOpenTasks => '打开任务中心';

  @override
  String get shortVideoNextStepCtaOpenQuality => '打开质量评审';

  @override
  String get shortVideoNextStepCtaOpenProjectsPrep => '打开项目区补准备项';

  @override
  String get shortVideoNextStepCtaOpenScriptWorkspace => '打开脚本工作区';

  @override
  String get shortVideoNextStepCtaOpenProductionWorkspace => '打开制作工作区';

  @override
  String get shortVideoNextStepPickProjectTitle => '先选一个短剧项目';

  @override
  String get shortVideoNextStepPickProjectDetail =>
      '选中项目后，Space 才能把模式、任务、质检和工作区上下文收成同一条主链路。';

  @override
  String get shortVideoNextStepFailedTasksTitle => '先处理失败任务';

  @override
  String get shortVideoNextStepFailedTasksDetail =>
      '最近已有失败任务，先去任务中心确认是脚本、素材、出图还是出片环节卡住。';

  @override
  String get shortVideoNextStepQualityTitle => '先看坏例和质检反馈';

  @override
  String get shortVideoNextStepQualityDetailAnimated =>
      '当前更适合先看角色一致性、画面连续性和镜头节奏的坏例，再决定返工脚本还是分镜。';

  @override
  String get shortVideoNextStepQualityDetailLive =>
      '当前更适合先看表演自然度、场景真实感和口播镜头质感的坏例，再决定返工脚本还是镜头。';

  @override
  String get shortVideoNextStepAnimVisualStyleTitle => '先收口画风与视觉风格';

  @override
  String get shortVideoNextStepAnimVisualStyleDetail =>
      '动漫模式先把画风、视觉手册或风格包收口，后面的角色一致性和出图连续性会更稳。';

  @override
  String get shortVideoNextStepLiveSceneRefsTitle => '先补真人场景参考';

  @override
  String get shortVideoNextStepLiveSceneRefsDetail =>
      '真人模式先补场景参考，后面的人物走位、真实空间感和镜头衔接会更稳。';

  @override
  String get shortVideoNextStepLiveClipRefsTitle => '先补真人镜头参考';

  @override
  String get shortVideoNextStepLiveClipRefsDetail =>
      '真人模式更依赖 clip / 镜头参考。先补镜头素材，后面的人物表演、景别和口播质感会更稳。';

  @override
  String get shortVideoNextStepLivePerformManualTitle => '先收口表演与口播手册';

  @override
  String get shortVideoNextStepLivePerformManualDetail =>
      '真人模式最好先把口播语气、表演节奏和导演手册收口，后面的配音和镜头演绎会更稳。';

  @override
  String get shortVideoNextStepFirstScriptTitle => '先生成第一版剧本';

  @override
  String get shortVideoNextStepFirstScriptDetailAnimated =>
      '先在脚本工作区把动漫短剧的情绪节奏、角色关系和章节改编跑起来。';

  @override
  String get shortVideoNextStepFirstScriptDetailLive =>
      '先在脚本工作区把真人短剧的对白自然度、口播感和场景调度跑起来。';

  @override
  String get shortVideoNextStepStoryboardTitle => '先补分镜和镜头结构';

  @override
  String get shortVideoNextStepStoryboardDetail =>
      '剧本已经有了，但还没拆到分镜层；下一步适合继续脚本/分镜规划，再进制作。';

  @override
  String get shortVideoNextStepRolesAnimTitle => '先补角色与画风资产';

  @override
  String get shortVideoNextStepRolesLiveTitle => '先补真人参考与角色设定';

  @override
  String get shortVideoNextStepRolesAnimDetail =>
      '分镜已经起步，但角色资产偏少，先补角色、画风和参考图会更稳。';

  @override
  String get shortVideoNextStepRolesLiveDetail =>
      '分镜已经起步，但真人参考、角色设定和镜头参考还不够，先补这些会更稳。';

  @override
  String get shortVideoNextStepProductionReadyTitle => '可以直接推进制作与出片';

  @override
  String get shortVideoNextStepProductionReadyDetailAnimated =>
      '当前项目已经具备脚本、分镜和角色基础，可以继续进制作工作区出图、出片和复核。';

  @override
  String get shortVideoNextStepProductionReadyDetailLive =>
      '当前项目已经具备脚本、分镜和角色基础，可以继续进制作工作区推进真人镜头、视频生成和复核。';

  @override
  String shortVideoPublishExportCheckReworkRouteSuffix(String route) {
    return ' [返工: $route]';
  }

  @override
  String shortVideoPublishExportCheckStoryboardIndexPart(int sb) {
    return ' · 序 $sb';
  }

  @override
  String shortVideoPublishMatrixPlatformRow(
    String labelZh,
    String platformId,
    String automationMode,
    int titleMaxChars,
    int tagsMax,
    int descriptionMaxChars,
  ) {
    return '$labelZh · $platformId · $automationMode · 标题≤$titleMaxChars · 标签≤$tagsMax · 简介≤$descriptionMaxChars';
  }

  @override
  String get shortVideoPublishMatrixRequiresCoverSuffix => ' · 需封面';

  @override
  String get shortVideoPublishAuditOverviewTitle => '发布概览';

  @override
  String get shortVideoPublishAuditDeliveryModeTitle => '作业投递模式分布';

  @override
  String shortVideoPublishAuditJobCount(int count) {
    return '$count 条';
  }

  @override
  String get shortVideoPublishCalendarPrevMonth => '上一月';

  @override
  String get shortVideoPublishCalendarNextMonth => '下一月';

  @override
  String get shortVideoPublishCalendarDraftCountEmpty => '—';

  @override
  String get shortVideoPublishCalendarDraftCountOverflow => '9+';

  @override
  String get rustApiClientRetryAfterTryLater => '请稍后重试';

  @override
  String rustApiClientRetryAfterSeconds(int seconds) {
    return '$seconds 秒后重试';
  }

  @override
  String rustApiClientRetryAfterMinutes(int minutes) {
    return '$minutes 分钟后重试';
  }

  @override
  String rustApiClientRetryAfterMinutesSeconds(int minutes, int seconds) {
    return '$minutes 分 $seconds 秒后重试';
  }

  @override
  String rustApiClientRetryAfterHours(int hours) {
    return '$hours 小时后重试';
  }

  @override
  String rustApiClientRetryAfterHoursMinutes(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟后重试';
  }

  @override
  String get rustApiClientConcurrentLimitExceeded =>
      '同时进行的工作区审计导出已达上限，请等待已有任务完成或结束后再试。';

  @override
  String rustApiClientQuotaOrRateWithWait(String wait) {
    return '配额或频率已用尽，$wait。';
  }

  @override
  String rustApiClientTooFrequentWithWait(String wait) {
    return '请求过于频繁，$wait。';
  }

  @override
  String get rustApiClientRecordNotFound => '未找到对应记录。';

  @override
  String get rustApiClientRequestCancelled => '请求已取消。';

  @override
  String rustApiClientUnknownError(String detail) {
    return '出现问题：$detail';
  }

  @override
  String get rustApiClientSearchQueryTooShort => '搜索关键词不能为空且至少需要 2 个字符。';

  @override
  String get rustApiClientSearchQueryTooLong => '搜索关键词过长，请限制在 200 字符以内。';

  @override
  String get rustApiOutboundWebhookJobCompleted => '作业完成';

  @override
  String get rustApiOutboundWebhookJobFailed => '作业失败';

  @override
  String get rustApiOutboundWebhookProjectCreated => '项目创建';

  @override
  String get rustApiOutboundWebhookWorkspaceMemberAdded => '工作区成员加入';

  @override
  String get shortVideoPublishCopyEditorSectionTitle => '差异化文案（按平台）';

  @override
  String get shortVideoPublishCopyFieldTitle => '标题';

  @override
  String get shortVideoPublishCopyFieldDescription => '简介';

  @override
  String get shortVideoPublishCopyFieldTagsCommaHint => '标签（英文逗号分隔）';

  @override
  String get shortVideoPublishCopySaveToCurrentDraft => '保存到当前草稿';

  @override
  String get shortVideoPublishDraftStatusEditing => '编辑中';

  @override
  String get shortVideoPublishDraftStatusReady => '就绪';

  @override
  String get shortVideoPublishDraftStatusArchived => '已归档';

  @override
  String get shortVideoPublishDraftStatusDraft => '草稿';

  @override
  String get shortVideoPublishDraftStatusUnknown => '未知状态';

  @override
  String shortVideoPublishDraftStatusRaw(String status) {
    return '$status';
  }

  @override
  String get shortVideoPublishAutomationFullAuto => '全自动';

  @override
  String get shortVideoPublishAutomationSemiAuto => '半自动';

  @override
  String get shortVideoPublishAutomationManualAssisted => '人工辅助';

  @override
  String get shortVideoPublishAutomationModeUnknown => '未知模式';

  @override
  String shortVideoPublishAutomationModeRaw(String mode) {
    return '$mode';
  }

  @override
  String get shortVideoPublishJobStatusQueued => '排队中';

  @override
  String get shortVideoPublishJobStatusRetrying => '重试中';

  @override
  String get shortVideoPublishJobStatusRunning => '执行中';

  @override
  String get shortVideoPublishJobStatusValidating => '校验中';

  @override
  String get shortVideoPublishJobStatusUploading => '上传中';

  @override
  String get shortVideoPublishJobStatusAwaitingConfirmation => '待人工确认';

  @override
  String get shortVideoPublishJobStatusSucceeded => '成功';

  @override
  String get shortVideoPublishJobStatusFailed => '失败';

  @override
  String get shortVideoPublishJobStatusCancelled => '已取消';

  @override
  String get shortVideoPublishJobStatusPartialFailed => '部分失败';

  @override
  String get shortVideoPublishJobStatusPlatformProcessing => '平台处理中';

  @override
  String get shortVideoPublishJobStatusIdle => '空闲';

  @override
  String get shortVideoPublishJobStatusUnknown => '未知状态';

  @override
  String shortVideoPublishJobStatusRaw(String status) {
    return '$status';
  }

  @override
  String get shortVideoPublishPrepareSeverityBlocking => '阻断';

  @override
  String get shortVideoPublishPrepareSeverityWarning => '警告';

  @override
  String get shortVideoPublishPrepareSeverityUnknown => '未知严重度';

  @override
  String shortVideoPublishPrepareSeverityRaw(String severity) {
    return '$severity';
  }

  @override
  String get shortVideoPanelVersionDataInconsistencyTitle => '检测到数据不一致';

  @override
  String shortVideoPanelVersionStaleSummary(int staleCount) {
    return '部分面板可能展示较早的数据，约 $staleCount 个视图版本落后。';
  }

  @override
  String get shortVideoPanelVersionRefresh => '刷新';

  @override
  String shortVideoPanelVersionStaleRow(String panelName, String relativeAge) {
    return '• $panelName：$relativeAge';
  }

  @override
  String get shortVideoPanelVersionPanelProduction => '制作';

  @override
  String get shortVideoPanelVersionPanelAssets => '资产';

  @override
  String get shortVideoPanelVersionPanelAssembly => '成片装配';

  @override
  String get shortVideoPanelVersionPanelExport => '导出检查';

  @override
  String shortVideoPanelVersionAgeSeconds(int seconds) {
    return '$seconds 秒前';
  }

  @override
  String shortVideoPanelVersionAgeMinutes(int minutes) {
    return '$minutes 分钟前';
  }

  @override
  String shortVideoPanelVersionAgeHours(int hours) {
    return '$hours 小时前';
  }

  @override
  String get shortVideoPanelVersionStaleDialogBody => '部分面板数据可能已过期，是否先刷新再继续？';

  @override
  String get shortVideoPanelVersionRefreshAndContinue => '刷新并继续';

  @override
  String get shortVideoPanelVersionExamplePublish => '发布';

  @override
  String get shortVideoPanelVersionRefreshPanelTooltip => '刷新此面板';

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
  String accountExportActiveCount(int count) {
    return '进行中 $count';
  }

  @override
  String get accountExportCopyLastSavedPath => '复制最近保存路径';

  @override
  String get accountExportEmpty => '还没有账户导出记录。';

  @override
  String accountExportDefaultFileName(int numericTaskId) {
    return '账户导出 #$numericTaskId';
  }

  @override
  String accountExportTaskLine(int numericTaskId, String createdAt) {
    return '任务 #$numericTaskId · $createdAt';
  }

  @override
  String accountExportSizeLine(String size) {
    return '大小 $size';
  }

  @override
  String accountExportSavedSnack(String path) {
    return '已保存到 $path';
  }

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
  String accountDeleteLastResponse(
    int workspaceCount,
    int projectCount,
    int jobCount,
  ) {
    return '已删除账户：$workspaceCount 个工作区，$projectCount 个项目，$jobCount 个作业';
  }

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
  String adminConsoleMembershipItem(
    String workspaceName,
    String workspaceType,
    String role,
    String archivedSuffix,
  ) {
    return '$workspaceName · $workspaceType · $role$archivedSuffix';
  }

  @override
  String adminConsoleRecentJobItem(
    String kind,
    String status,
    String projectId,
    String ownerEmail,
  ) {
    return '$kind · $status · 项目 $projectId · $ownerEmail';
  }

  @override
  String adminConsoleAuditListItem(
    String createdAt,
    String actorLabel,
    String summary,
  ) {
    return '$createdAt · $actorLabel · $summary';
  }

  @override
  String get adminConsoleDailyQuotaLabel => '每日配额';

  @override
  String adminConsoleChipMember(int count) {
    return '成员 $count';
  }

  @override
  String get adminConsoleArchivedLabel => 'archived';

  @override
  String adminConsoleMemberListItem(
    String email,
    String role,
    String joinedAt,
  ) {
    return '$email · $role · 加入 $joinedAt';
  }

  @override
  String adminConsoleRecentProjectItem(
    int numericId,
    String name,
    String detail,
  ) {
    return '#$numericId $name · $detail';
  }

  @override
  String adminConsoleChipScript(int count) {
    return '剧本 $count';
  }

  @override
  String adminConsoleChipAsset(int count) {
    return '资产 $count';
  }

  @override
  String adminConsoleChipJob(int count) {
    return '作业 $count';
  }

  @override
  String adminConsoleAclMemberItem(
    String email,
    String workspaceRole,
    String projectRole,
    String detail,
  ) {
    return '$email · 工作区 $workspaceRole · 项目 $projectRole · $detail';
  }

  @override
  String adminConsoleWorkspaceCandidateItem(
    String email,
    String workspaceRole,
    String explicitProjectRole,
  ) {
    return '$email · $workspaceRole · 显式项目角色 $explicitProjectRole';
  }

  @override
  String adminConsoleProjectRecentJobItem(
    String kind,
    String status,
    String ownerEmail,
    String createdAt,
  ) {
    return '$kind · $status · $ownerEmail · $createdAt';
  }

  @override
  String adminConsoleAuditUserSummary(String status, String quota) {
    return '状态=$status · 配额=$quota';
  }

  @override
  String adminConsoleAuditWorkspaceMembership(
    String action,
    String userId,
    String role,
    String workspaceId,
    String detail,
  ) {
    return '操作=$action · 用户=$userId · 角色=$role · 工作区=$workspaceId · 详情=$detail';
  }

  @override
  String adminConsoleAuditOwnerTransfer(
    String previousOwner,
    String newOwner,
    String role,
    String reset,
  ) {
    return '所有权转移：$previousOwner → $newOwner · 角色=$role · 重置=$reset';
  }

  @override
  String adminConsoleAuditArchiveNote(String archivedAt, String note) {
    return '归档 $archivedAt · 备注 $note';
  }

  @override
  String adminConsoleAuditProjectOwnerTransfer(
    String previousOwner,
    String newOwner,
    String projectId,
  ) {
    return '项目所有权转移：$previousOwner → $newOwner · $projectId';
  }

  @override
  String get adminConsoleFieldUserId => '用户 ID';

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
  String agentWorkspaceProductionCandidateIds(int count, String preview) {
    return '候选 $count 项：$preview';
  }

  @override
  String get agentWorkspaceProductionPromptPreviewTitle => '执行提示';

  @override
  String get agentWorkspaceProductionStagesTitle => '执行阶段';

  @override
  String get agentWorkspaceProductionStageFlowScriptPlan => '导演计划';

  @override
  String get agentWorkspaceProductionStageFlowAssets => '资产准备';

  @override
  String get agentWorkspaceProductionStageFlowStoryboardTable => '分镜表';

  @override
  String get agentWorkspaceProductionStageFlowStoryboard => '分镜画面';

  @override
  String get agentWorkspaceProductionStageStatusSupervisionNeedsRework => '需返工';

  @override
  String get agentWorkspaceProductionStageStatusSupervisionPendingRevision =>
      '待修订';

  @override
  String get agentWorkspaceProductionStageStatusSupervisionCanAdvance => '可推进';

  @override
  String get agentWorkspaceProductionStageStatusSupervisionApproved => '已通过';

  @override
  String get agentWorkspaceProductionStageStatusPendingGenerate => '待生成';

  @override
  String get agentWorkspaceProductionStageStatusPendingRefineScriptPlan =>
      '待完善';

  @override
  String get agentWorkspaceProductionStageStatusPendingReview => '待审核';

  @override
  String get agentWorkspaceProductionStageStatusSuggestRefresh => '建议刷新';

  @override
  String get agentWorkspaceProductionStageStatusPendingRead => '待读取';

  @override
  String get agentWorkspaceProductionStageStatusPendingAssetPlan => '待规划';

  @override
  String get agentWorkspaceProductionStageStatusNeedsAssetImages => '需补图';

  @override
  String get agentWorkspaceProductionStageStatusAssetsReady => '已齐备';

  @override
  String get agentWorkspaceProductionStageStatusAssetsScopedFromRefs => '已定位';

  @override
  String get agentWorkspaceProductionStageStatusWaitingScriptPlanDepth =>
      '等待导演计划完善';

  @override
  String get agentWorkspaceProductionStageStatusAssetsNarrowedFromScriptPlan =>
      '已收紧';

  @override
  String get agentWorkspaceProductionStageStatusWaitingScriptPlan => '等待导演计划';

  @override
  String get agentWorkspaceProductionStageStatusStoryboardTableSampled => '已抽样';

  @override
  String get agentWorkspaceProductionStageStatusStoryboardTableExpandRead =>
      '待扩读';

  @override
  String get agentWorkspaceProductionStageStatusBackfillScriptPlanFromTable =>
      '回补导演计划';

  @override
  String get agentWorkspaceProductionStageStatusNeedsStoryboardFrames => '需补帧';

  @override
  String get agentWorkspaceProductionStageStatusStoryboardFramesPending =>
      '待补帧';

  @override
  String get agentWorkspaceProductionStageStatusStoryboardPendingVerify =>
      '待核对';

  @override
  String get agentWorkspaceProductionStageStatusStoryboardComplete => '已完成';

  @override
  String get agentWorkspaceProductionStageStatusWaitingStoryboardTable =>
      '等待分镜表';

  @override
  String
  get agentWorkspaceProductionStageStatusWaitingStoryboardTableCoverage =>
      '等待分镜表完善';

  @override
  String get agentWorkspaceProductionDomainReadFlow => '读取 flow';

  @override
  String get agentWorkspaceProductionDomainExpandStoryboardTable => '扩读分镜表';

  @override
  String get agentWorkspaceProductionDomainReadScriptPlan => '读取导演计划';

  @override
  String get agentWorkspaceProductionDomainRefreshScriptPlan => '刷新导演计划';

  @override
  String get agentWorkspaceProductionDomainRereadAffectedAssets => '回读受影响资产';

  @override
  String get agentWorkspaceProductionDomainRefreshAssets => '刷新资产结果';

  @override
  String get agentWorkspaceProductionDomainRereadPartialStoryboardTable =>
      '回读局部分镜表';

  @override
  String get agentWorkspaceProductionDomainRefreshStoryboardTable => '刷新分镜表';

  @override
  String get agentWorkspaceProductionDomainRereadMissingFrames => '回读缺帧状态';

  @override
  String get agentWorkspaceProductionDomainRefreshStoryboard => '刷新分镜结果';

  @override
  String get agentWorkspaceProductionSubAgentRefineDirectorPlan => '细化导演计划';

  @override
  String get agentWorkspaceProductionSubAgentFillStoryboardTable => '补分镜表';

  @override
  String get agentWorkspaceProductionSubAgentAdvanceStage => '推进阶段';

  @override
  String agentWorkspaceProductionBlockerHeadline(
    Object reason,
    Object status,
    Object title,
  ) {
    return '当前卡点：$title · $status；$reason';
  }

  @override
  String get agentWorkspaceProductionBlockerExpandTable =>
      '先继续扩读关键分镜表窗口，再决定是否推进下游出图。';

  @override
  String agentWorkspaceProductionBlockerExpandTableWithCoverage(
    Object coverage,
  ) {
    return '先继续扩读关键分镜表窗口；$coverage。';
  }

  @override
  String get agentWorkspaceProductionBlockerRefineScriptPlan =>
      '当前更缺导演计划里的分场景情绪/画面意图，先细化 scriptPlan 再拆分镜表。';

  @override
  String get agentWorkspaceProductionBlockerExpandTableCoverage =>
      '分镜表已有基础内容，但覆盖还不够，先补齐关键镜头表再推进 storyboard。';

  @override
  String agentWorkspaceProductionBlockerExpandTableCoverageWithDigest(
    Object coverage,
  ) {
    return '分镜表已有基础内容，但覆盖还不够；$coverage。';
  }

  @override
  String agentWorkspaceProductionAppliedRefineDirectorPlan(Object title) {
    return '已应用阶段动作：$title，下一步先细化导演计划。';
  }

  @override
  String agentWorkspaceProductionAppliedExpandStoryboardTable(Object title) {
    return '已应用阶段动作：$title，下一步先扩读关键分镜表窗口。';
  }

  @override
  String agentWorkspaceProductionAppliedStageGeneric(Object title) {
    return '已应用阶段动作：$title';
  }

  @override
  String agentWorkspaceProductionFlowChip(String flowKey) {
    return 'flow=$flowKey';
  }

  @override
  String get agentWorkspaceProductionApplyStage => '应用阶段';

  @override
  String get agentWorkspaceProductionDiagnosisTitle => '下一步建议';

  @override
  String agentWorkspaceProductionToolChip(String tool) {
    return 'tool=$tool';
  }

  @override
  String agentWorkspaceProductionAgentChip(String agent) {
    return 'agent=$agent';
  }

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
  String agentWorkspaceProductionPromptRewriteFocus(String focus) {
    return '改写焦点：$focus';
  }

  @override
  String agentWorkspaceProductionPromptVisualPacing(String pacing) {
    return '视觉节奏：$pacing';
  }

  @override
  String agentWorkspaceProductionPromptExtraConstraint(String constraint) {
    return '额外约束：$constraint';
  }

  @override
  String agentWorkspaceProductionPromptAssetFocus(String scope) {
    return '资产焦点：$scope';
  }

  @override
  String get agentWorkspaceProductionPromptExecutionOrder =>
      '执行顺序：先核对导演计划点名资产，再补分镜表和镜头结果。';

  @override
  String get agentWorkspaceProductionStoryboardPriorityMissing => '优先展示缺帧相关镜头';

  @override
  String agentWorkspaceProductionCollapsedRows(int count) {
    return '其余 $count 行已折叠';
  }

  @override
  String agentWorkspaceProductionReviewTarget(String target) {
    return '目标：$target';
  }

  @override
  String agentWorkspaceProductionReviewGrade(String grade) {
    return '等级：$grade';
  }

  @override
  String agentWorkspaceProductionReviewIssues(
    int severe,
    int medium,
    int minor,
  ) {
    return '问题：严重 $severe，中等 $medium，轻微 $minor';
  }

  @override
  String agentWorkspaceProductionReviewNextStep(String nextAction) {
    return '下一步：$nextAction';
  }

  @override
  String agentWorkspaceProductionReviewAssetIds(String assetIds) {
    return '资产：$assetIds';
  }

  @override
  String agentWorkspaceProductionReviewAssetScope(String scope) {
    return '资产范围：$scope';
  }

  @override
  String agentWorkspaceProductionReviewStoryboardIds(String ids) {
    return '镜头：$ids';
  }

  @override
  String agentWorkspaceProductionReviewSummary(String summary) {
    return '结论：$summary';
  }

  @override
  String agentWorkspaceProductionShotLabel(int id) {
    return '镜头 $id';
  }

  @override
  String agentWorkspaceProductionSceneLabel(String scene) {
    return '场景 $scene';
  }

  @override
  String get agentWorkspaceProductionClauseJoiner => '，';

  @override
  String get agentWorkspaceProductionSentenceJoinerSemicolon => '；';

  @override
  String get agentWorkspaceProductionAssetTypeRole => '角色';

  @override
  String get agentWorkspaceProductionAssetTypeScene => '场景';

  @override
  String get agentWorkspaceProductionAssetTypeTool => '道具';

  @override
  String agentWorkspaceProductionAssetScopeIds(Object ids) {
    return '资产 #$ids';
  }

  @override
  String agentWorkspaceProductionAssetScopeTypes(Object types) {
    return '$types资产';
  }

  @override
  String get agentWorkspaceProductionAssetScopeCompact => '紧凑资产摘要';

  @override
  String agentWorkspaceProductionAssetFocusIdsShort(Object visible) {
    return '资产 #$visible';
  }

  @override
  String agentWorkspaceProductionAssetFocusIdsMore(
    Object total,
    Object visible,
  ) {
    return '资产 #$visible 等 $total 项';
  }

  @override
  String get agentWorkspaceProductionAssetReadinessEmpty => '资产为空';

  @override
  String agentWorkspaceProductionAssetReadinessRoots(
    Object ready,
    Object total,
  ) {
    return '主资产 $ready/$total 已就绪';
  }

  @override
  String agentWorkspaceProductionAssetReadinessDeriveGap(Object count) {
    return '衍生缺口 $count 项';
  }

  @override
  String agentWorkspaceProductionAssetReadinessRootMissing(Object count) {
    return '主资产待补 $count 项';
  }

  @override
  String get agentWorkspaceProductionStoryboardReadinessEmpty => '分镜为空';

  @override
  String agentWorkspaceProductionStoryboardReadinessFrames(
    Object needed,
    Object ready,
  ) {
    return '画面结果 $ready/$needed 已就绪';
  }

  @override
  String agentWorkspaceProductionStoryboardReadinessMissing(Object count) {
    return '待补帧 $count 项';
  }

  @override
  String agentWorkspaceProductionStoryboardReadinessTextOnly(Object count) {
    return '纯文本 $count 项';
  }

  @override
  String get agentWorkspaceProductionStoryboardTableCoverageUnread => '分镜表未读取';

  @override
  String agentWorkspaceProductionStoryboardTableCoverageRowsOnly(Object count) {
    return '分镜表已读 $count 行';
  }

  @override
  String agentWorkspaceProductionStoryboardTableCoverageProgress(
    Object sampled,
    Object total,
  ) {
    return '分镜表已读 $sampled/$total 行';
  }

  @override
  String agentWorkspaceProductionStoryboardTableCoverageWithPending(
    Object remaining,
    Object sampled,
    Object total,
  ) {
    return '分镜表已读 $sampled/$total 行，待展开 $remaining 行';
  }

  @override
  String agentWorkspaceProductionPlanningScriptWindow(
    Object end,
    Object maxChars,
    Object start,
  ) {
    return '剧本 $start-$end 行（<=$maxChars 字）';
  }

  @override
  String agentWorkspaceProductionStoryboardShotsHashShort(Object ids) {
    return '镜头 #$ids';
  }

  @override
  String agentWorkspaceProductionStoryboardShotsHashMore(
    Object ids,
    Object total,
  ) {
    return '镜头 #$ids 等 $total 个';
  }

  @override
  String agentWorkspaceProductionStoryboardScriptWindow(
    Object end,
    Object maxChars,
    Object start,
  ) {
    return '剧本 $start-$end 行（<=$maxChars 字）';
  }

  @override
  String agentWorkspaceProductionStoryboardTableRereadShots(Object shots) {
    return '分镜表仅回看$shots对应行';
  }

  @override
  String agentWorkspaceProductionStoryboardReviewScriptGlue(Object window) {
    return '剧本仅回看$window';
  }

  @override
  String agentWorkspaceProductionPromptStoryboardShotCount(Object count) {
    return '优先处理这 $count 个镜头';
  }

  @override
  String get agentWorkspaceProductionPromptStoryboardFallbackMissingFrames =>
      '优先只补缺少画面结果的镜头';

  @override
  String get agentWorkspaceProductionPromptStoryboardFallbackRevision =>
      '优先修订当前审核聚焦的分镜表问题';

  @override
  String get agentWorkspaceProductionPromptStoryboardContextEmpty =>
      '如需核对依据，先只回看同批 storyboardTable 行和局部剧本窗口。';

  @override
  String agentWorkspaceProductionPromptStoryboardContextTable(
    Object tableFocus,
  ) {
    return '先只回看$tableFocus对应的 storyboardTable 行';
  }

  @override
  String agentWorkspaceProductionPromptStoryboardContextScript(
    Object scriptWindow,
  ) {
    return '剧本仅回看$scriptWindow';
  }

  @override
  String agentWorkspaceProductionPromptStoryboardContextLead(Object parts) {
    return '如需核对依据，$parts。';
  }

  @override
  String agentWorkspaceProductionPromptStoryboardNote(Object summary) {
    return '注意：$summary';
  }

  @override
  String agentWorkspaceProductionPromptExecutionConstraint(Object hint) {
    return '执行约束：$hint';
  }

  @override
  String agentWorkspaceProductionPromptProductionPrioritySummary(
    String summary,
  ) {
    return '优先解决：$summary';
  }

  @override
  String agentWorkspaceProductionPromptScriptPlanExecutionHint(
    String sections,
  ) {
    return '承接 scriptPlan：$sections。人物情绪保持递进，避免生硬直述。';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardSupervisionCombined(
    String reviewDetail,
    String scope,
  ) {
    return '$reviewDetail$scope';
  }

  @override
  String agentWorkspaceProductionStagePromptAssetsGenerateFocused(
    int count,
    String priority,
    String execution,
  ) {
    return '请优先只核对并生成这 $count 个资产；若其中已有结果则跳过，只补剩余缺口，不要扩读无关 assets。$priority$execution';
  }

  @override
  String agentWorkspaceProductionStagePromptAssetsGenerateNoIds(
    String priority,
    String execution,
  ) {
    return '请基于最新 assets flow 判断哪些衍生资产仍缺图，只对真实缺口发起最小可行生成，不要重跑已有结果或扩读无关素材。$priority$execution';
  }

  @override
  String agentWorkspaceProductionPromptStoryboardGenBody(
    Object assetHint,
    Object contextHint,
    Object execution,
    Object note,
    Object scope,
  ) {
    return '$scope，不要重跑已有结果或 shouldGenerateImage=false 的镜头。$contextHint$assetHint$note$execution';
  }

  @override
  String agentWorkspaceProductionPromptStoryboardTableRevisionBody(
    Object assetHint,
    Object contextHint,
    Object scope,
    Object solve,
  ) {
    return '$scope 对应的 storyboardTable 行，保持其余行不动。$contextHint$assetHint$solve';
  }

  @override
  String agentWorkspaceProductionPromptStoryboardTableSolve(Object summary) {
    return '优先解决：$summary';
  }

  @override
  String agentWorkspaceProductionPromptStoryboardAssetHint(Object count) {
    return '如需核对素材，仅看这 $count 个关联资产。';
  }

  @override
  String get agentWorkspaceProductionStageReviewSummaryFallback =>
      '请按审核结果推进下一步。';

  @override
  String agentWorkspaceProductionStageReviewBody(
    Object assetScope,
    Object grade,
    Object medium,
    Object minor,
    Object severe,
    Object storyboardScope,
    Object summary,
  ) {
    return '审核等级 $grade，严重 $severe / 中等 $medium / 轻微 $minor。$summary$storyboardScope$assetScope';
  }

  @override
  String agentWorkspaceProductionStageReviewStoryboardScope(Object scope) {
    return ' 局部范围：$scope。';
  }

  @override
  String agentWorkspaceProductionStageReviewAssetScope(Object scope) {
    return ' 资产范围：$scope。';
  }

  @override
  String agentWorkspaceProductionStageDetailScriptPlanSectionLine(
    Object count,
  ) {
    return '已覆盖 $count/6 个规划维度，';
  }

  @override
  String agentWorkspaceProductionStagePromptReviseScriptPlan(Object summary) {
    return '请根据最近审核意见修订 scriptPlan，优先解决：$summary';
  }

  @override
  String get agentWorkspaceProductionStageDetailScriptPlanEmpty =>
      'scriptPlan 仍为空，先产出导演计划再推进资产与分镜。';

  @override
  String get agentWorkspaceProductionStagePromptScriptPlanEmpty =>
      '请基于当前 production 上下文生成一版导演计划，并给出执行优先级。';

  @override
  String agentWorkspaceProductionStageDetailScriptPlanRefine(
    Object chars,
    Object sectionLine,
  ) {
    return '已读取 scriptPlan，$sectionLine当前约 $chars 字；下游暂不放行，建议先补到至少 3 个规划维度，再进入审核与 assets/storyboard 主链。';
  }

  @override
  String get agentWorkspaceProductionStagePromptScriptPlanRefine =>
      '请继续完善当前 scriptPlan，至少补齐 3 个规划维度，并明确情绪推进、资产依赖与镜头意图。';

  @override
  String agentWorkspaceProductionStageDetailScriptPlanReview(
    Object chars,
    Object scriptWindow,
    Object sectionLine,
  ) {
    return '已读取 scriptPlan，$sectionLine当前约 $chars 字；复核时先只回看$scriptWindow，再做导演规划审核并推进 assets 与 storyboard。';
  }

  @override
  String get agentWorkspaceProductionStagePromptScriptPlanReview =>
      '请审核当前导演规划，重点检查剧情覆盖、资产匹配与节奏合理性。';

  @override
  String get agentWorkspaceProductionStageDetailScriptPlanRefresh =>
      '导演计划刚变更或正在处理，建议先刷新导演计划，确认最新内容后再推进下游阶段。';

  @override
  String get agentWorkspaceProductionStageDetailScriptPlanPendingRead =>
      '先读取 scriptPlan，确认制作优先级与执行顺序。';

  @override
  String agentWorkspaceProductionStageDetailAssetsAfterReview(
    Object assetScope,
    Object reviewDetail,
  ) {
    return '$reviewDetail 优先只核对$assetScope，确认后回到 scriptPlan 收束导演计划。';
  }

  @override
  String get agentWorkspaceProductionStageDetailAssetsEmpty =>
      'assets 为空，先规划衍生素材并补齐最小可行资产集。';

  @override
  String get agentWorkspaceProductionStagePromptAssetsEmpty =>
      '请基于当前空白 assets flow 规划最小可行的衍生素材集合，并说明优先级。';

  @override
  String agentWorkspaceProductionStageDetailAssetsMissingGeneric(
    Object missing,
    Object readiness,
    Object total,
  ) {
    return '共 $total 项资产，仍有 $missing 项缺少图像结果，适合继续运行素材生成。$readiness';
  }

  @override
  String agentWorkspaceProductionStageDetailAssetsMissingFocused(
    Object pendingScope,
    Object readiness,
    Object total,
  ) {
    return '共 $total 项资产，$pendingScope 仍缺图，优先只补这批衍生资产更省 token。$readiness';
  }

  @override
  String agentWorkspaceProductionStageDetailAssetsReady(
    Object readiness,
    Object total,
  ) {
    return '共 $total 项资产，图像结果已齐，可继续检查 storyboard 与导演计划。$readiness';
  }

  @override
  String agentWorkspaceProductionStageDetailAssetsScopedTable(Object count) {
    return '当前分镜表窗口引用了 $count 项资产，优先核对这批素材更省 token。';
  }

  @override
  String agentWorkspaceProductionStageDetailAssetsScopedStoryboard(
    Object count,
  ) {
    return '当前分镜窗口引用了 $count 项资产，优先核对这批素材更省 token。';
  }

  @override
  String get agentWorkspaceProductionStageDetailAssetsWaitScriptDepth =>
      '当前 scriptPlan 已有内容但还不够完整，先补齐导演计划的关键维度，再规划 assets，避免素材准备跑偏。';

  @override
  String agentWorkspaceProductionStageDetailAssetsNarrowedScriptPlan(
    Object scope,
  ) {
    return '已从 scriptPlan 收紧到$scope，优先核对这批素材更省 token；信息不足时再扩读。';
  }

  @override
  String get agentWorkspaceProductionStageDetailAssetsWaitScript =>
      '先读取或生成 scriptPlan，再规划 assets，避免素材补齐脱离导演节奏与改写约束。';

  @override
  String get agentWorkspaceProductionStageDetailAssetsRefreshNarrow =>
      '资产生成动作刚执行，建议先回读本次受影响资产，确认结果后再决定是否扩读。';

  @override
  String get agentWorkspaceProductionStageDetailAssetsRefreshWide =>
      '资产相关动作刚执行，建议先刷新资产结果，确认最新状态后再决定是否继续补素材。';

  @override
  String get agentWorkspaceProductionStageDetailAssetsPendingRead =>
      '读取 assets flow 后可判断是否需要继续做衍生资产或素材生成。';

  @override
  String agentWorkspaceProductionStagePromptStoryboardTableReviseLead(
    Object tail,
  ) {
    return '请根据最近审核意见修订 storyboardTable。$tail';
  }

  @override
  String get agentWorkspaceProductionStageDetailStoryboardTableEmpty =>
      'storyboardTable 为空，适合先补结构化镜头表。';

  @override
  String get agentWorkspaceProductionStagePromptStoryboardTableEmpty =>
      '请先产出结构化 storyboardTable，并保持字段清晰可回写。';

  @override
  String agentWorkspaceProductionStageDetailStoryboardTableString(
    Object chars,
    Object coverage,
    Object rowDigest,
  ) {
    return 'storyboardTable 已有内容，$rowDigest约 $chars 字，建议先做分镜表审核再推进 storyboard 画面结果。$coverage';
  }

  @override
  String agentWorkspaceProductionStageDigestStoryboardTableRows(
    Object rowCount,
  ) {
    return '共 $rowCount 行';
  }

  @override
  String agentWorkspaceProductionStageDigestStoryboardTableAssets(
    Object assetCount,
  ) {
    return '关联 $assetCount 项资产';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardTableWindowReady(
    Object coverage,
    Object sampled,
    Object total,
  ) {
    return '已窗口读取 $sampled/$total 行关键列，适合继续审核或修订 storyboardTable。$coverage';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardTableWindowBackfill(
    Object coverage,
    Object sampled,
    Object total,
  ) {
    return '已窗口读取 $sampled/$total 行关键列，但当前 scriptPlan 还缺少足够明确的分场景情绪或画面意图，先回补导演计划，再继续扩读 storyboardTable。$coverage';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardTableWindowExpand(
    Object coverage,
    Object sampled,
    Object total,
  ) {
    return '已窗口读取 $sampled/$total 行关键列，但覆盖还不够，先扩读或补齐关键镜头表，再推进 storyboard。$coverage';
  }

  @override
  String get agentWorkspaceProductionStagePromptStoryboardTableReview =>
      '请审核当前分镜表，重点检查覆盖度、资产关联与拆分粒度。';

  @override
  String get agentWorkspaceProductionStageDetailStoryboardTableWaitScript =>
      '先读取或生成 scriptPlan，再拆分 storyboardTable，避免镜头表脱离导演计划。';

  @override
  String
  get agentWorkspaceProductionStageDetailStoryboardTableWaitScriptDepth =>
      '当前 scriptPlan 已有内容但还不够完整，先补齐导演计划的关键维度，再拆分 storyboardTable。';

  @override
  String get agentWorkspaceProductionStageDetailStoryboardTableRefreshWide =>
      '分镜表刚变更或正在处理，建议先刷新分镜表，再判断是否继续审核或修订。';

  @override
  String agentWorkspaceProductionStageDetailStoryboardTableRefreshNarrow(
    Object ids,
  ) {
    return '分镜表刚变更，建议先回读镜头 #$ids 对应的局部分镜表行。';
  }

  @override
  String get agentWorkspaceProductionStageDetailStoryboardTablePendingRead =>
      '需要时可读取 storyboardTable 审阅结构化镜头表。';

  @override
  String
  get agentWorkspaceProductionStageDetailStoryboardSupervisionGenerateScopeEmpty =>
      '建议先读取缺帧镜头状态，再最小化补图。';

  @override
  String
  get agentWorkspaceProductionStageDetailStoryboardSupervisionCheckScopeEmpty =>
      '建议先读取紧凑 storyboard 状态，确认审核涉及的镜头。';

  @override
  String agentWorkspaceProductionStageDetailStoryboardSupervisionScoped(
    Object count,
    Object reviewScope,
  ) {
    return '审核已定位 $count 个镜头，优先只看这批 storyboard 更省 token。$reviewScope';
  }

  @override
  String agentWorkspaceProductionSupervisionReviewScopeAppend(
    String reviewScope,
  ) {
    return ' $reviewScope。';
  }

  @override
  String agentWorkspaceProductionStagePromptStoryboardSupervisionGenerate(
    Object tail,
  ) {
    return '请根据最近审核意见继续推进 storyboard。$tail';
  }

  @override
  String get agentWorkspaceProductionStageDetailStoryboardEmpty =>
      'storyboard 为空，先生成第一版分镜画面。';

  @override
  String get agentWorkspaceProductionStagePromptStoryboardEmpty =>
      '请基于当前 production 上下文生成第一版 storyboard，并保持最小可行镜头集。';

  @override
  String agentWorkspaceProductionStageDetailStoryboardMissing(
    Object idsPreview,
    Object idsTail,
    Object missingCount,
    Object needImageCount,
    Object readiness,
    Object reviewClause,
    Object skippedClause,
  ) {
    return '需出图 $needImageCount 个镜头，仍有 $missingCount 个缺少画面结果（#$idsPreview$idsTail）$skippedClause$reviewClause $readiness';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardMissingIdsTail(
    Object total,
  ) {
    return ' 等 $total 个镜头';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardMissingSkipped(
    Object count,
  ) {
    return '；另有 $count 个镜头为纯文本模式，无需出图。';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardMissingReview(
    Object reviewScope,
  ) {
    return ' $reviewScope';
  }

  @override
  String agentWorkspaceProductionStagePromptStoryboardContinue(Object tail) {
    return '请继续推进 storyboard。$tail';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardComplete(
    Object needImageCount,
    Object readiness,
    Object skippedClause,
  ) {
    return '需出图 $needImageCount 个镜头，画面结果齐备$skippedClause，可准备写回或继续导演计划。 $readiness';
  }

  @override
  String agentWorkspaceProductionStageDetailStoryboardCompleteSkipped(
    Object count,
  ) {
    return '；另有 $count 个纯文本镜头按设计无需出图';
  }

  @override
  String get agentWorkspaceProductionStageDetailStoryboardWaitScript =>
      '先读取或生成 scriptPlan，再推进 storyboard，避免直接补图但情绪和镜头意图未定。';

  @override
  String get agentWorkspaceProductionStageDetailStoryboardWaitScriptDepth =>
      '当前 scriptPlan 已有内容但还不够完整，先补齐导演计划的关键维度，再推进 storyboard，避免补图时情绪和镜头意图仍发散。';

  @override
  String get agentWorkspaceProductionStageDetailStoryboardWaitTable =>
      '先补 storyboardTable 再推进 storyboard，避免直接出图时镜头拆分和资产关联还没定型。';

  @override
  String get agentWorkspaceProductionStageDetailStoryboardBackfillFromTable =>
      'storyboardTable 已有基础内容，但当前 scriptPlan 对分场景情绪或画面意图交代还不够，先细化导演计划，再继续扩读分镜表并推进 storyboard。';

  @override
  String get agentWorkspaceProductionStageDetailStoryboardWaitTableCoverage =>
      'storyboardTable 已有基础内容，但覆盖还不够，先扩读或补齐关键镜头表，再推进 storyboard，避免在镜头拆分未定型时直接出图。';

  @override
  String get agentWorkspaceProductionStageDetailStoryboardRefreshGenWide =>
      '分镜动作刚执行，建议先刷新分镜结果，再决定是否继续补帧或写回。';

  @override
  String agentWorkspaceProductionStageDetailStoryboardRefreshGenNarrow(
    Object ids,
  ) {
    return '分镜动作刚执行，建议先回读本次镜头 #$ids 的缺帧状态。';
  }

  @override
  String get agentWorkspaceProductionStageDetailStoryboardRefreshOther =>
      '分镜动作刚执行，建议先刷新分镜结果，再决定是否写回。';

  @override
  String get agentWorkspaceProductionStageDetailStoryboardPendingRead =>
      '读取 storyboard 后可判断是否需要继续补图或直接写回结果。';

  @override
  String agentWorkspaceProductionDurationLabel(String duration) {
    return '时长 $duration';
  }

  @override
  String agentWorkspaceProductionAssetsLabel(String assets) {
    return '资产 $assets';
  }

  @override
  String agentWorkspaceProductionStateLabel(String state) {
    return '状态 $state';
  }

  @override
  String get agentWorkspaceProductionModeTextOnly => '结果: 已有画面';

  @override
  String get agentWorkspaceProductionResultHasImage => '结果: 缺帧待补图';

  @override
  String agentWorkspaceProductionResultMissingImage(String assets) {
    return '缺少图片 $assets';
  }

  @override
  String agentWorkspaceProductionContextFromTool(String toolName) {
    return '来自工具 $toolName';
  }

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
  String agentWorkspaceSummaryReturnedList(int count) {
    return '返回列表 $count 项';
  }

  @override
  String agentWorkspaceSummaryReturnedText(int chars) {
    return '返回文本 $chars 字';
  }

  @override
  String agentWorkspaceProductionSummaryItems(int count) {
    return '返回 items $count 项';
  }

  @override
  String agentWorkspaceProductionSummaryReviewHeadline(
    String target,
    String grade,
  ) {
    return '聚焦 $target：$grade 级';
  }

  @override
  String agentWorkspaceProductionSummaryIssueBreakdown(
    int severe,
    int medium,
    int minor,
  ) {
    return '问题：严重 $severe，中等 $medium，轻微 $minor';
  }

  @override
  String agentWorkspaceProductionSummaryFocusedAssets(int count) {
    return '聚焦资产 $count 项';
  }

  @override
  String agentWorkspaceProductionSummaryFocusedAssetScope(String scope) {
    return '聚焦资产范围 $scope';
  }

  @override
  String agentWorkspaceProductionSummaryFocusedShots(int count) {
    return '聚焦镜头 $count 项';
  }

  @override
  String agentWorkspaceSummaryReturnedObjectKeys(String keys) {
    return '返回对象 keys=$keys';
  }

  @override
  String get agentWorkspaceProductionSummaryFlowEmpty => '当前 flow 为空';

  @override
  String get agentWorkspaceProductionSummaryFlowEmptyString => '当前 flow 为空字符串';

  @override
  String agentWorkspaceProductionSummaryTextChars(int chars) {
    return '文本 $chars 字';
  }

  @override
  String agentWorkspaceProductionSummaryLineCount(int count) {
    return '行数 $count';
  }

  @override
  String agentWorkspaceProductionSummaryPlanSections(int count) {
    return '计划章节 $count';
  }

  @override
  String get agentWorkspaceProductionSummaryRewriteInherited => '改写约束下沉';

  @override
  String agentWorkspaceProductionSummaryStoryboardRows(int count) {
    return '分镜 $count 条';
  }

  @override
  String agentWorkspaceProductionSummaryLinkedAssets(int count) {
    return '关联资产 $count';
  }

  @override
  String agentWorkspaceProductionSummaryListCount(int count) {
    return '列表 $count 项';
  }

  @override
  String agentWorkspaceProductionSummaryPrompts(int count) {
    return '提示词 $count';
  }

  @override
  String agentWorkspaceProductionSummaryMediaUrls(int count) {
    return '媒体 URL $count';
  }

  @override
  String agentWorkspaceProductionSummaryNeedImages(int count) {
    return '需要图片 $count';
  }

  @override
  String agentWorkspaceProductionSummaryMissingFrames(int count) {
    return '缺帧 $count 项';
  }

  @override
  String agentWorkspaceProductionSummaryTextOnlyCount(int count) {
    return '纯文本 $count';
  }

  @override
  String agentWorkspaceProductionSummaryStateTypes(int count) {
    return '状态类型 $count';
  }

  @override
  String agentWorkspaceProductionSummaryObjectKeyCount(int count) {
    return '对象 keys=$count 个';
  }

  @override
  String agentWorkspaceProductionSummaryObjectListEntry(String key, int count) {
    return '$key: $count 项';
  }

  @override
  String agentWorkspaceProductionSummaryObjectTextEntry(String key, int chars) {
    return '$key: $chars 字';
  }

  @override
  String agentWorkspaceProductionSummaryReturnedType(String type) {
    return '返回 $type';
  }

  @override
  String get agentWorkspaceProductionIdleHint => '等待执行：可直接用引导任务或表单按钮。';

  @override
  String agentWorkspaceProductionLatestToolResult(String detail) {
    return '最新工具结果：$detail';
  }

  @override
  String get agentWorkspaceProductionResultSummary => '结果摘要';

  @override
  String agentWorkspaceProductionSuggestedFlowKey(String flowKey) {
    return '建议写回 key：$flowKey';
  }

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
  String agentWorkspaceScriptToolChip(String tool) {
    return 'tool=$tool';
  }

  @override
  String agentWorkspaceScriptAgentChip(String agent) {
    return 'agent=$agent';
  }

  @override
  String get agentWorkspaceScriptApplySuggestion => '应用建议';

  @override
  String agentWorkspaceScriptContextSkeletonFocus(String focus) {
    return '骨架焦点：$focus';
  }

  @override
  String agentWorkspaceScriptContextAdaptationFocus(String focus) {
    return '改编焦点：$focus';
  }

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
  String agentWorkspaceScriptContextChapterPrefix(
    int chapterIndex,
    String chapter,
  ) {
    return '第 $chapterIndex 章 · $chapter';
  }

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
  String agentWorkspaceScriptWritebackSource(String source) {
    return '写回来源：$source';
  }

  @override
  String get agentWorkspaceScriptSummaryReviewReturned => '审核结果已返回';

  @override
  String agentWorkspaceScriptSummaryReviewLine(
    String target,
    String grade,
    int issueCount,
    String summary,
  ) {
    return '审核 $target：$grade 级，问题 $issueCount 项$summary';
  }

  @override
  String get agentWorkspaceScriptSummaryPlanDataMissing => 'planData 缺少 data';

  @override
  String get agentWorkspaceScriptSummaryStorySkeletonReady => '故事骨架已就绪';

  @override
  String get agentWorkspaceScriptSummaryAdaptationReady => '改编策略已就绪';

  @override
  String agentWorkspaceScriptSummaryPlanScripts(int count) {
    return '计划剧本 $count 条';
  }

  @override
  String get agentWorkspaceScriptSummaryRewriteReady => '改写约束已可下游消费';

  @override
  String get agentWorkspaceScriptSummaryPlanDataReturned => 'planData 已返回';

  @override
  String agentWorkspaceScriptSummaryScriptEmpty(int chars) {
    return '剧本正文 $chars 字';
  }

  @override
  String agentWorkspaceScriptSummaryScriptChars(int chars) {
    return '剧本正文 $chars 字';
  }

  @override
  String agentWorkspaceScriptSummaryNovelTextEmpty(int count) {
    return '章节材料 $count 条';
  }

  @override
  String agentWorkspaceScriptSummaryNovelTextCount(int count) {
    return '章节材料 $count 条';
  }

  @override
  String agentWorkspaceScriptSummaryNovelEventsEmpty(int count) {
    return '小说事件 $count 条';
  }

  @override
  String agentWorkspaceScriptSummaryNovelEventsCount(int count) {
    return '小说事件 $count 条';
  }

  @override
  String get agentWorkspaceScriptStageTitleStorySkeleton => '故事骨架';

  @override
  String get agentWorkspaceScriptStageTitleAdaptationStrategy => '改编策略';

  @override
  String get agentWorkspaceScriptStageTitleChapterMaterial => '章节材料';

  @override
  String get agentWorkspaceScriptStageTitleScriptBody => '剧本正文';

  @override
  String get agentWorkspaceScriptStageStatusReady => '已就绪';

  @override
  String get agentWorkspaceScriptStageStatusReusable => '可沿用';

  @override
  String get agentWorkspaceScriptStageStatusNeedsRevision => '待修订';

  @override
  String get agentWorkspaceScriptStageStatusPendingGenerate => '待生成';

  @override
  String get agentWorkspaceScriptStageStatusPendingRead => '待读取';

  @override
  String get agentWorkspaceScriptStageStatusSupplementNeeded => '待补充';

  @override
  String get agentWorkspaceScriptStageStatusCompleted => '已完成';

  @override
  String get agentWorkspaceScriptStageDetailStorySkeletonReady =>
      'storySkeleton 已存在，可继续收束改编策略或对照剧本正文。';

  @override
  String get agentWorkspaceScriptStageDetailReviewStorySkeletonEmpty =>
      '审核已覆盖 storySkeleton，可按建议继续修订。';

  @override
  String get agentWorkspaceScriptStageDetailReviewAdaptationEmpty =>
      '审核已覆盖 adaptationStrategy，可按建议继续修订。';

  @override
  String get agentWorkspaceScriptStageDetailReviewScriptEmpty =>
      '审核已覆盖剧本正文，可按建议继续改稿。';

  @override
  String agentWorkspaceScriptStageDetailReviewConclusion(String summary) {
    return '审核结论：$summary';
  }

  @override
  String get agentWorkspaceScriptStagePromptReviseStorySkeleton =>
      '请先读取 storySkeleton 与相关事件窗口，再针对审核意见局部修订故事骨架。';

  @override
  String get agentWorkspaceScriptStageDetailStorySkeletonPendingGen =>
      '先补故事骨架，明确主冲突、转折与结局走向。';

  @override
  String get agentWorkspaceScriptStagePromptGenerateStorySkeleton =>
      '请基于当前项目上下文生成一版清晰的故事骨架，并突出主冲突与反转节点。';

  @override
  String get agentWorkspaceScriptStageDetailStorySkeletonPendingRead =>
      '先读取 planData，确认 storySkeleton 是否齐备。';

  @override
  String get agentWorkspaceScriptStageDetailAdaptationReady =>
      'adaptationStrategy 已存在，可继续读取章节材料或生成正文。';

  @override
  String get agentWorkspaceScriptStagePromptReviseAdaptationStrategy =>
      '请先读取 adaptationStrategy 与 storySkeleton，再针对审核意见局部修订改编策略。';

  @override
  String get agentWorkspaceScriptStageDetailAdaptationPendingGen =>
      '当前缺少 adaptationStrategy，适合先收束人物与节奏策略。';

  @override
  String get agentWorkspaceScriptStagePromptGenerateAdaptationStrategy =>
      '请基于现有故事骨架补齐改编策略，突出节奏、人物弧光与集数拆分原则。';

  @override
  String get agentWorkspaceScriptStageDetailAdaptationPendingRead =>
      '回看 planData，判断 adaptationStrategy 是否已具备。';

  @override
  String agentWorkspaceScriptStageDetailChapterMaterialReady(int count) {
    return '已读取 $count 条小说上下文，可继续生成剧本正文或对照现有 script。';
  }

  @override
  String get agentWorkspaceScriptStageDetailChapterMaterialEmptyNovel =>
      '小说上下文为空，建议继续读取章节正文或事件脉络。';

  @override
  String get agentWorkspaceScriptStageDetailChapterMaterialPendingRead =>
      '先读取章节正文或事件列表，再决定如何改写剧本。';

  @override
  String get agentWorkspaceScriptStageDetailScriptBodyReady =>
      '当前 script 正文已存在，可直接写回或回看计划数据继续改稿。';

  @override
  String get agentWorkspaceScriptStagePromptReviseScript =>
      '请先读取当前集尾段窗口、storySkeleton、adaptationStrategy；如仍不足再补读章节正文窗口，并针对审核意见定向修订本集剧本。';

  @override
  String get agentWorkspaceScriptStageDetailScriptPendingGen =>
      '当前 script 正文为空，适合直接运行 script 子代理生成首版内容。';

  @override
  String get agentWorkspaceScriptStagePromptGenerateScript =>
      '请先读取当前集计划与目标章节事件；只有在承接上一集时才补读上一集尾段，其余细节再按需补正文窗口，生成下一版剧本正文并输出可直接写回的完整内容。';

  @override
  String get agentWorkspaceScriptStageDetailScriptPendingRead =>
      '读取当前剧本正文，再判断是否需要直接生成下一版。';

  @override
  String get agentWorkspaceScriptRecipeFillStorySkeletonTitle => '补故事骨架';

  @override
  String get agentWorkspaceScriptRecipeFillStorySkeletonDetail =>
      'planData 还没有 storySkeleton，先让骨架子代理补结构。';

  @override
  String get agentWorkspaceScriptRecipeFillStorySkeletonPrompt =>
      '请基于当前项目上下文生成一版清晰的故事骨架，并突出主冲突与反转节点。';

  @override
  String get agentWorkspaceScriptRecipeFillAdaptationTitle => '补改编策略';

  @override
  String get agentWorkspaceScriptRecipeFillAdaptationDetail =>
      '骨架之外还缺 adaptationStrategy，适合先收束改编路径。';

  @override
  String get agentWorkspaceScriptRecipeFillAdaptationPrompt =>
      '请基于现有故事骨架补齐改编策略，突出节奏、人物弧光与集数拆分原则。';

  @override
  String get agentWorkspaceScriptRecipeReadScriptBodyTitle => '读取当前剧本正文';

  @override
  String get agentWorkspaceScriptRecipeReadScriptBodyDetail =>
      'planData 已准备好后，下一步通常要对比当前 script 正文是否偏离。';

  @override
  String get agentWorkspaceScriptRecipeReadPlanScriptDraftTitle => '读取计划剧本草稿';

  @override
  String get agentWorkspaceScriptRecipeReadPlanScriptDraftDetail =>
      'planData.script 已有当前集草稿，先消费这份结构化草稿，再决定是否补读章节正文更省 token。';

  @override
  String get agentWorkspaceScriptRecipePullChapterMaterialTitle => '拉取章节材料';

  @override
  String get agentWorkspaceScriptRecipePullChapterMaterialDetail =>
      '计划里还没有剧本草稿，先读取小说章节文本补上下文。';

  @override
  String get agentWorkspaceScriptRecipeGenerateNextScriptTitle => '生成下一版剧本';

  @override
  String get agentWorkspaceScriptRecipeGenerateNextScriptDetail =>
      '计划信息已具备，先消费计划剧本草稿和必要事件，再让 script 子代理输出下一版可写回正文。';

  @override
  String get agentWorkspaceScriptRecipeGenerateNextScriptPrompt =>
      '请先读取当前集 planData.script 草稿、storySkeleton、adaptationStrategy，再补最少的目标章节事件；只有细节或衔接不足时才补读上一集尾段或章节正文窗口，然后输出可直接写回的完整剧本正文。';

  @override
  String get agentWorkspaceScriptRecipePreferEventsTitle => '改看事件脉络';

  @override
  String get agentWorkspaceScriptRecipePreferEventsDetail =>
      '章节文本为空时，先读事件列表更容易定位剧情骨架缺口。';

  @override
  String get agentWorkspaceScriptRecipeReadMatchingEventsTitle => '读取对应事件';

  @override
  String get agentWorkspaceScriptRecipeReadMatchingEventsDetail =>
      '章节文本已到位，继续按同一章节拉取事件脉络更利于总结冲突。';

  @override
  String get agentWorkspaceScriptRecipeGenerateAdaptationFromTextTitle =>
      '生成改编策略';

  @override
  String get agentWorkspaceScriptRecipeGenerateAdaptationFromTextDetail =>
      '章节材料已经可读，适合直接让改编策略子代理给出收束方案。';

  @override
  String get agentWorkspaceScriptRecipeGenerateAdaptationFromTextPrompt =>
      '请基于当前章节文本总结改编策略，输出 3 到 5 条可直接执行的改写原则。';

  @override
  String get agentWorkspaceScriptRecipeReviewPreviousTailTitle => '回看上一版尾段';

  @override
  String get agentWorkspaceScriptRecipeReviewPreviousTailDetail =>
      '在章节材料明确后，对照当前集尾段更容易定位衔接缺口且 token 更省。';

  @override
  String get agentWorkspaceScriptRecipePullChapterTextFirstTitle => '先拉章节正文';

  @override
  String get agentWorkspaceScriptRecipePullChapterTextFirstDetail =>
      '事件列表为空时，先读章节文本更容易判断是数据空还是事件未抽取。';

  @override
  String get agentWorkspaceScriptRecipeDistillSkeletonFromEventsTitle =>
      '整理故事骨架';

  @override
  String get agentWorkspaceScriptRecipeDistillSkeletonFromEventsDetail =>
      '事件脉络已清晰，适合先收束成 storySkeleton。';

  @override
  String get agentWorkspaceScriptRecipeDistillSkeletonFromEventsPrompt =>
      '请基于当前事件列表提炼故事骨架，保留关键冲突、转折与结局走向。';

  @override
  String get agentWorkspaceScriptRecipeGenerateScriptFromEventsTitle =>
      '生成剧本初稿';

  @override
  String get agentWorkspaceScriptRecipeGenerateScriptFromEventsDetail =>
      '如果事件链路基本齐全，可直接让 script 子代理生成可写回正文。';

  @override
  String get agentWorkspaceScriptRecipeGenerateScriptFromEventsPrompt =>
      '请先结合当前事件脉络，并优先读取 planData.script、storySkeleton 与 adaptationStrategy；只有细节不足时再补章节正文窗口，生成一版可直接写回的剧本正文。';

  @override
  String get agentWorkspaceScriptRecipeCompareExistingScriptTitle => '对比现有剧本';

  @override
  String get agentWorkspaceScriptRecipeCompareExistingScriptDetail =>
      '用当前事件链路反查现有正文，能更快定位缺场或冲突偏移。';

  @override
  String get agentWorkspaceScriptRecipeGenerateScriptBodyTitle => '生成剧本正文';

  @override
  String get agentWorkspaceScriptRecipeGenerateScriptBodyDetail =>
      '当前正文为空，直接让 script 子代理产出首版内容更合适。';

  @override
  String get agentWorkspaceScriptRecipeGenerateScriptBodyPrompt =>
      '请先读取当前集 planData.script、storySkeleton、adaptationStrategy 与目标章节事件；只有细节不足时再补读正文窗口，然后生成一版完整剧本正文。';

  @override
  String get agentWorkspaceScriptRecipeRefreshPlanDataTitle => '刷新计划数据';

  @override
  String get agentWorkspaceScriptRecipeRefreshPlanDataDetail =>
      '若正文为空且上下文不完整，也可先回到 planData 校验骨架与策略。';

  @override
  String get agentWorkspaceScriptRecipeRefreshPlanAfterBodyTitle => '刷新计划数据';

  @override
  String get agentWorkspaceScriptRecipeRefreshPlanAfterBodyDetail =>
      '已有正文后，通常要回看 planData 判断是否需要同步骨架或策略。';

  @override
  String get agentWorkspaceScriptRecipeAddChapterMaterialTitle => '补章节材料';

  @override
  String get agentWorkspaceScriptRecipeAddChapterMaterialDetail =>
      '如果要继续改稿，可先拉小说正文与事件，避免只盯着当前 script。';

  @override
  String get agentWorkspaceScriptRecipeReviseStorySkeletonTitle => '修故事骨架';

  @override
  String get agentWorkspaceScriptRecipeReviseStorySkeletonDetail =>
      '审核指出骨架仍有缺口，先回到 storySkeleton 做定向修订。';

  @override
  String get agentWorkspaceScriptRecipeReviseStorySkeletonPrompt =>
      '请先读取 storySkeleton 与相关事件窗口，信息不足再补章节正文窗口，针对审核问题局部修订故事骨架。';

  @override
  String get agentWorkspaceScriptRecipeReviseAdaptationTitle => '修改编策略';

  @override
  String get agentWorkspaceScriptRecipeReviseAdaptationDetail =>
      '审核认为策略与骨架或载体约束不一致，适合先局部修策略。';

  @override
  String get agentWorkspaceScriptRecipeReviseAdaptationPrompt =>
      '请先读取 adaptationStrategy 与 storySkeleton，再按需补事件窗口，针对审核问题局部修订改编策略。';

  @override
  String get agentWorkspaceScriptRecipeReviseScriptTitle => '修剧本正文';

  @override
  String get agentWorkspaceScriptRecipeReviseScriptDetail =>
      '审核已定位剧本正文问题，先读取当前集尾段窗口再定向改稿。';

  @override
  String get agentWorkspaceScriptRecipeReviseScriptPrompt =>
      '请先读取当前集尾段窗口、storySkeleton、adaptationStrategy；如仍不足再补读章节正文窗口，并针对审核问题定向修订本集剧本。';

  @override
  String get agentWorkspaceScriptRecipeVerifyEventsTitle => '核对事件脉络';

  @override
  String get agentWorkspaceScriptRecipeVerifyEventsDetail =>
      '审核建议回看事件链路，优先读取小说事件而不是整章原文。';

  @override
  String get agentWorkspaceScriptRecipeAddNovelTextWindowTitle => '补原文章节窗口';

  @override
  String get agentWorkspaceScriptRecipeAddNovelTextWindowDetail =>
      '审核需要追溯原文时，先读取章节窗口，避免整章搬运。';

  @override
  String get agentWorkspaceScriptRecipeRereadCurrentScriptTitle => '回看当前剧本';

  @override
  String get agentWorkspaceScriptRecipeRereadCurrentScriptDetail =>
      '先重新读取当前集尾段窗口，再决定是否继续改稿。';

  @override
  String get agentWorkspaceScriptRecipeReviewTargetPeekTitle => '回看审核对象';

  @override
  String get agentWorkspaceScriptRecipeReviewTargetPeekDetail =>
      '先读取审核指向的核心内容，再决定是否重跑子代理。';

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
  String agentWorkspaceActivityLatest(String eventType) {
    return '最新：$eventType';
  }

  @override
  String agentWorkspaceActivityLatestToolResult(String detail) {
    return '最新工具结果：$detail';
  }

  @override
  String get agentWorkspaceActivityLatestAssistantText => '最新助手文本';

  @override
  String get agentWorkspaceActivityNoWsEvents => '暂无 WS 事件。';

  @override
  String get agentWorkspaceProductionCardTitle => '制作工作区';

  @override
  String get agentWorkspaceGuidedTasksTitle => '引导任务';

  @override
  String get agentWorkspaceScriptWritebackSourceAssistant => '助手主输出';

  @override
  String agentWorkspaceScriptPlanHint(int pid) {
    return '计划 $pid';
  }

  @override
  String agentWorkspaceScriptPlanWritebackReady(
    String planHint,
    int scriptCount,
  ) {
    return '计划回写就绪：$planHint，$scriptCount 条剧本';
  }

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
  String contentComplianceSlaOpenOver24h(int count) {
    return 'open>24h $count';
  }

  @override
  String contentComplianceSlaOpenOver72h(int count) {
    return 'open>72h $count';
  }

  @override
  String contentComplianceSlaClaimedOver24h(int count) {
    return 'claimed>24h $count';
  }

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
  String contentComplianceSlaChip(String bucket) {
    return 'SLA: $bucket';
  }

  @override
  String contentComplianceMetricPending(int count) {
    return '待处理 $count';
  }

  @override
  String contentComplianceMetricClaimed(int count) {
    return '已认领 $count';
  }

  @override
  String contentComplianceMetricResolved(int count) {
    return '已解决 $count';
  }

  @override
  String contentComplianceMetricDismissed(int count) {
    return '已忽略 $count';
  }

  @override
  String contentComplianceMetricCritical(int count) {
    return '严重 $count';
  }

  @override
  String contentComplianceMetricHigh(int count) {
    return '高优先级 $count';
  }

  @override
  String contentComplianceMetricOverdue(int count) {
    return '逾期 $count';
  }

  @override
  String contentComplianceOldestHours(int hours) {
    return '最旧 ${hours}h';
  }

  @override
  String contentComplianceCapacityPerReviewer(int capacity) {
    return '容量 $capacity/reviewer';
  }

  @override
  String contentComplianceOwnerCounts(int pending, int claimed) {
    return '待处理 $pending · 已认领 $claimed';
  }

  @override
  String contentComplianceOwnerDetail(String detail) {
    return '详情 $detail';
  }

  @override
  String contentComplianceWorkspaceCounts(int open, int pending, int claimed) {
    return '打开 $open · 待处理 $pending · 已认领 $claimed';
  }

  @override
  String contentComplianceWorkspaceDetail(
    int critical,
    int high,
    int breached,
    int oldestHours,
  ) {
    return '严重 $critical · 高优先级 $high · SLA 违约 $breached · 最久 ${oldestHours}h';
  }

  @override
  String contentComplianceReportInfo(
    String reporter,
    String reportedAt,
    String detail,
  ) {
    return '上报人 $reporter · $reportedAt · $detail';
  }

  @override
  String get contentComplianceActorInternalOps => '内部运营';

  @override
  String contentComplianceItemLineCreated(String createdAt) {
    return '创建于 $createdAt';
  }

  @override
  String contentComplianceItemLineClaimed(String actor) {
    return '认领人 $actor';
  }

  @override
  String contentComplianceItemLineClaimedWithTime(
    String actor,
    String claimedAt,
  ) {
    return '认领人 $actor · $claimedAt';
  }

  @override
  String contentComplianceItemLineOutcome(String status, String resolutionBy) {
    return '$status · $resolutionBy';
  }

  @override
  String contentComplianceItemLineOutcomeWithTime(
    String status,
    String resolutionBy,
    String resolvedAt,
  ) {
    return '$status · $resolutionBy · $resolvedAt';
  }

  @override
  String get contentComplianceAuditVerbClaim => '认领';

  @override
  String get contentComplianceAuditVerbResolve => '结案';

  @override
  String get contentComplianceAuditVerbDismiss => '忽略';

  @override
  String get contentComplianceAuditVerbReassign => '改派';

  @override
  String get contentComplianceAuditVerbAutoRebalance => '自动再平衡';

  @override
  String contentComplianceAuditStatusChanged(String from, String to) {
    return '$from → $to';
  }

  @override
  String contentComplianceAuditDispositionEntry(String value) {
    return '处置：$value';
  }

  @override
  String contentComplianceResolutionLine(String note) {
    return '处理说明：$note';
  }

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
  String jobsKindCountEntry(String kind, int jobCount) {
    return '$kind：$jobCount';
  }

  @override
  String jobsStatusCountEntry(String status, int jobCount) {
    return '$status：$jobCount';
  }

  @override
  String jobsIdempotencyMismatch(String firstId, String secondId) {
    return 'POST /api/v1/jobs 幂等：期望同一 id，实际 $firstId 与 $secondId';
  }

  @override
  String jobsUpdatedAt(String updatedAt) {
    return '更新于 $updatedAt';
  }

  @override
  String jobsClaimedBy(String claimedBy) {
    return '认领者：$claimedBy';
  }

  @override
  String jobsFailedReason(String reason) {
    return '失败原因：$reason';
  }

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
  String jobsDetailLabel(String detail) {
    return '作业详情：$detail';
  }

  @override
  String jobsKindsLabel(String kinds) {
    return '作业类型：$kinds';
  }

  @override
  String jobsKindSummaryLabel(String summary) {
    return '类型汇总：$summary';
  }

  @override
  String jobsStatusSummaryLabel(String summary) {
    return '状态汇总：$summary';
  }

  @override
  String jobsCountLabel(int count) {
    return '$count 条作业';
  }

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
  String notificationsPlatformStatusAffectedEndpoints(String endpoints) {
    return '受影响端点：$endpoints';
  }

  @override
  String notificationsComplianceAlertTitle(String title) {
    return '内容合规告警：$title';
  }

  @override
  String notificationsDownloadUnsupported(String fileName, int bytes) {
    return '当前平台不支持下载：$fileName（$bytes 字节）';
  }

  @override
  String get notificationsComplianceSharedAsyncExportCompleted =>
      'notifications compliance shared async export completed';

  @override
  String notificationsComplianceSharedAsyncExportCancelled(int taskId) {
    return '工作区共享审计后台导出已取消（任务 #$taskId）。';
  }

  @override
  String notificationsComplianceSharedAsyncExportFailed(int taskId) {
    return '工作区共享审计后台导出失败（任务 #$taskId）。';
  }

  @override
  String notificationsComplianceSharedAsyncExportFailedWithDetail(
    int taskId,
    String detail,
  ) {
    return '工作区共享审计后台导出失败（任务 #$taskId）：$detail';
  }

  @override
  String get notificationsComplianceSharedAsyncExportTimedOut =>
      'notifications compliance shared async export timed out';

  @override
  String get notificationsImportJsonObjectRequired =>
      'notifications import json object required';

  @override
  String notificationsImportJsonParseFailed(String message) {
    return '导入 JSON 解析失败：$message';
  }

  @override
  String notificationsUnknownTemplate(String templateId) {
    return '未知模板：$templateId';
  }

  @override
  String platformStatusChipLabel(String title, String value) {
    return '$title: $value';
  }

  @override
  String opsWhActivityEntryTitle(String action, String webhookId) {
    return '$action · $webhookId';
  }

  @override
  String opsWhFieldId(String id) {
    return 'ID: $id';
  }

  @override
  String opsWhFieldUrl(String url) {
    return '网址：$url';
  }

  @override
  String opsWhFieldSecret(String secret) {
    return '密钥：$secret';
  }

  @override
  String opsWhFieldCreatedAt(String createdAt) {
    return '创建时间: $createdAt';
  }

  @override
  String opsWhFieldUpdatedAt(String updatedAt) {
    return '更新时间: $updatedAt';
  }

  @override
  String opsWhApiEventTypes(String eventTypes) {
    return 'API: $eventTypes';
  }

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

  @override
  String notificationsFilterCount(int count) {
    return '筛选 $count';
  }

  @override
  String notificationsUnreadCount(int count) {
    return '未读 $count';
  }

  @override
  String get apiKeysSnackFillName => '请先填写密钥名称';

  @override
  String get apiKeysSnackPickExpiry => '请先选择过期日期';

  @override
  String get apiKeysDatePickerHelp => '选择过期日期';

  @override
  String apiKeysRotateTitle(String displayName) {
    return '轮换 $displayName';
  }

  @override
  String get apiKeysRotateBody => '轮换会立即作废旧 secret，并只显示一次新的明文 token。';

  @override
  String get apiKeysExpiryPolicy => '过期策略';

  @override
  String get apiKeysExpiryKeepCurrent => '保留当前';

  @override
  String get apiKeysExpiryClearExpiry => '清除过期';

  @override
  String get apiKeysExpirySevenDays => '7 天';

  @override
  String get apiKeysExpiryThirtyDays => '30 天';

  @override
  String get apiKeysExpiryNinetyDays => '90 天';

  @override
  String get apiKeysExpiryCustomDate => '自定义日期';

  @override
  String apiKeysExpiresAtUtc(String date) {
    return '将于 $date 23:59 UTC 过期';
  }

  @override
  String get apiKeysActionRotate => '轮换';

  @override
  String apiKeysRevokeTitle(String displayName) {
    return '撤销 $displayName';
  }

  @override
  String get apiKeysRevokeBody => '撤销后现有 token 将立即失效，直到再次恢复或轮换。';

  @override
  String get apiKeysRevokeReasonLabel => '原因（可选）';

  @override
  String get apiKeysRevokeReasonHint => '例如：凭据暴露、环境下线、机器人停用';

  @override
  String get apiKeysActionRevoke => '撤销';

  @override
  String get apiKeysSectionTitle => 'API 密钥';

  @override
  String get apiKeysRiskyPrefsTooltip => '本机客户端偏好（密钥轮换/删除等「不再提示」与恢复确认）';

  @override
  String get apiKeysIntroBody =>
      '为服务端自动化、CLI、CI/CD 与内部集成签发用户级凭据。只读 key 只能调用 GET/HEAD/OPTIONS；读写 key 才允许执行变更类 REST 接口。';

  @override
  String get apiKeysCreateNewTitle => '签发新密钥';

  @override
  String get apiKeysRefresh => '刷新';

  @override
  String get apiKeysDisplayNameLabel => '名称';

  @override
  String get apiKeysDisplayNameHint =>
      '例如 CI deploy / data export / internal bot';

  @override
  String get apiKeysPermissionTitle => '权限';

  @override
  String get apiKeysScopeReadOnly => '只读';

  @override
  String get apiKeysScopeReadWrite => '读写';

  @override
  String get apiKeysExpiryNever => '不过期';

  @override
  String get apiKeysCreating => '签发中…';

  @override
  String get apiKeysCreateButton => '创建 API key';

  @override
  String get apiKeysPlaintextOnceTitle => '一次性明文';

  @override
  String get apiKeysPlaintextOnceBody =>
      '这个 secret 只会显示这一次。请立刻复制到凭据管理器、CI secret 或你的集成配置里。';

  @override
  String get apiKeysCopiedPlaintextSnack => '已复制一次性明文 API key';

  @override
  String get apiKeysCopyPlaintext => '复制明文';

  @override
  String get apiKeysHidePlaintext => '隐藏';

  @override
  String get apiKeysExistingKeysTitle => '现有密钥';

  @override
  String get apiKeysEmptyList => '还没有 API key。';

  @override
  String get apiKeysChipUsable => '可用';

  @override
  String get apiKeysChipUnusable => '不可用';

  @override
  String get apiKeysChipActive => '生效';

  @override
  String get apiKeysChipRevoked => '已撤销';

  @override
  String get apiKeysChipExpired => '已过期';

  @override
  String apiKeysStatActive(int count) {
    return '活跃 $count';
  }

  @override
  String apiKeysStatRevoked(int count) {
    return '已吊销 $count';
  }

  @override
  String apiKeysStatTotal(int count) {
    return '合计 $count';
  }

  @override
  String apiKeysPublicIdLine(String value) {
    return 'publicId：$value';
  }

  @override
  String get apiKeysCopyPublicIdTooltip => '复制 publicId';

  @override
  String get apiKeysCopiedPublicIdSnack => '已复制 publicId';

  @override
  String apiKeysMetaLine(String createdAt, String updatedAt, int useCount) {
    return '创建 $createdAt · 更新 $updatedAt · 使用 $useCount 次';
  }

  @override
  String apiKeysLastUsedLine(String lastUsedAt, String method, String path) {
    return '最近使用 $lastUsedAt · $method $path';
  }

  @override
  String apiKeysSourceLine(String source) {
    return '来源 $source';
  }

  @override
  String apiKeysExpiresAtLine(String expiresAt) {
    return '过期时间 $expiresAt';
  }

  @override
  String apiKeysRotatedAtLine(String rotatedAt) {
    return '最近轮换 $rotatedAt';
  }

  @override
  String apiKeysRevokedAtLine(String revokedAt) {
    return '撤销时间 $revokedAt';
  }

  @override
  String get apiKeysExpiredNeedsRotate => '已过期，需轮换';

  @override
  String get apiKeysRestore => '恢复';

  @override
  String get apiKeysDeleteTitle => '删除 API key';

  @override
  String apiKeysDeleteBody(String displayName, String keyHint) {
    return '即将删除 $displayName\n$keyHint';
  }

  @override
  String get apiKeysDelete => '删除';

  @override
  String get apiKeysAuditTitle => '管理审计';

  @override
  String get apiKeysAuditEmpty => '还没有 API key 生命周期记录。';

  @override
  String get statusPageTitle => 'Toonflow 状态';

  @override
  String get statusPageRefreshTooltip => '刷新';

  @override
  String get statusPageHeadline => '公开只读状态页';

  @override
  String get statusPageIntroBase =>
      '聚合 /health、/api/v1/health、/api/v1/ready、/api/v1/version。';

  @override
  String get statusPageIntroInternalSuffix =>
      ' 当前 dart-define 带 INTERNAL_OPS_TOKEN，因此附带内部队列统计。';

  @override
  String get statusPageRefreshing => '刷新中…';

  @override
  String get statusPageRefreshAction => '刷新状态';

  @override
  String statusPageLastUpdated(String time) {
    return '最近刷新：$time';
  }

  @override
  String get statusPageRequestFailed => '请求失败';

  @override
  String get statusPageVersionSectionTitle => '版本信息';

  @override
  String get statusPageInternalQueueSectionTitle => '内部队列统计';

  @override
  String statusPageApiBaseLabel(String baseUrl) {
    return 'API：$baseUrl';
  }

  @override
  String get benchmarkSectionTitle => '质量基线与实验';

  @override
  String get benchmarkIntroBody =>
      '在同一入口管理样本池、实验运行、人工复核、ROI、放行门和趋势，避免后续质量优化只靠感觉判断。';

  @override
  String get benchmarkActionFetchSamplePool => '读取样本池';

  @override
  String get benchmarkActionFetchExperiments => '读取实验';

  @override
  String get benchmarkActionFetchReviewQueue => '读取复核队列';

  @override
  String get benchmarkActionFetchMemoryTier => '读取记忆档';

  @override
  String get benchmarkActionFetchTrends => '读取趋势';

  @override
  String get benchmarkActionPromoteFromReview => '从评审提升样本';

  @override
  String get benchmarkActionFetchExperimentDetail => '读取实验详情';

  @override
  String get benchmarkActionStartExperiment => '启动实验';

  @override
  String get benchmarkActionCancelExperiment => '取消实验';

  @override
  String get benchmarkActionFetchRoi => '读取 ROI';

  @override
  String get benchmarkActionFetchGate => '读取放行门';

  @override
  String get benchmarkActionCreateExperiment => '创建实验';

  @override
  String get benchmarkActionSubmitReview => '提交复核';

  @override
  String get benchmarkActionSkipReview => '跳过复核';

  @override
  String get benchmarkActionSubmitGateDecision => '提交放行决策';

  @override
  String get benchmarkActionRunAbCompare => '执行 A/B 对比';

  @override
  String get benchmarkActionSaveRunAbCompare => '保存并执行 A/B 对比';

  @override
  String get benchmarkActionFetchAbHistory => '读取 A/B 历史';

  @override
  String get benchmarkActionFetchAbDetail => '读取 A/B 详情';

  @override
  String get benchmarkActionReplaySave => '复跑并保存';

  @override
  String benchmarkStatusNeedSignIn(String action) {
    return '当前未登录，无法执行 $action';
  }

  @override
  String benchmarkStatusRunning(String action) {
    return '正在执行：$action';
  }

  @override
  String benchmarkStatusCompleted(String action) {
    return '已完成：$action';
  }

  @override
  String benchmarkStatusFailedHttp(
    String action,
    String statusCode,
    String message,
  ) {
    return '失败：$action（$statusCode $message）';
  }

  @override
  String benchmarkStatusFailed(String action, String error) {
    return '失败：$action（$error）';
  }

  @override
  String get benchmarkProjectIdOptional => '项目 ID（可选，用于样本筛选）';

  @override
  String benchmarkCaseRowSubtitle(String summary, String weight, String tags) {
    return '$summary · 权重 $weight · 标签 $tags';
  }

  @override
  String benchmarkExperimentRowSubtitle(
    String sampleTier,
    String stages,
    String id,
  ) {
    return '$sampleTier · 阶段 $stages · $id';
  }

  @override
  String benchmarkMemoryProfilesLine(String tiers) {
    return '记忆预算档：$tiers';
  }

  @override
  String benchmarkExperimentDetailHeader(String name, int variantCount) {
    return '实验详情：$name · $variantCount 个变体';
  }

  @override
  String benchmarkRoiHeader(String conclusion, String rationale) {
    return 'ROI：$conclusion · $rationale';
  }

  @override
  String benchmarkRoiVariantLine(
    String variantLabel,
    String scoreDelta,
    String tokenDeltaPct,
  ) {
    return '$variantLabel · scoreΔ $scoreDelta · tokenΔ $tokenDeltaPct%';
  }

  @override
  String benchmarkGateAssessmentRow(
    String variantLabel,
    String decision,
    String scoreDelta,
    String severe,
  ) {
    return '$variantLabel · $decision · scoreΔ $scoreDelta · severeGuard $severe';
  }

  @override
  String benchmarkTrendWeekRow(
    String weekStart,
    String quality,
    String tokens,
    String approved,
    String blocked,
  ) {
    return '$weekStart · 质量 $quality · token $tokens · approved $approved / blocked $blocked';
  }

  @override
  String get benchmarkAbOutcomePassed => '通过';

  @override
  String get benchmarkAbOutcomeFailed => '未通过';

  @override
  String benchmarkAbAggregateSummary(
    String outcome,
    int passedCases,
    int totalCases,
    String tokenPct,
    String qualityDiff,
  ) {
    return 'A/B 汇总：$outcome · 通过 $passedCases/$totalCases · 平均 token 降幅 $tokenPct% · 平均质量差 $qualityDiff';
  }

  @override
  String benchmarkHistoryReplay(String nameOrId, String createdAt) {
    return '历史回放：$nameOrId · $createdAt';
  }

  @override
  String get benchmarkPromoteCardTitle => '从质量评审提升样本';

  @override
  String get benchmarkLabelQualityReviewId => '质量评审 ID';

  @override
  String get benchmarkLabelSampleType => '样本类型';

  @override
  String get benchmarkSampleTypeBadCase => '坏例';

  @override
  String get benchmarkSampleTypeGolden => '黄金样本';

  @override
  String get benchmarkSampleTypeRegressionGuard => '回归守护';

  @override
  String get benchmarkExperimentSuiteSmoke => '冒烟';

  @override
  String get benchmarkExperimentSuiteCore => '核心';

  @override
  String get benchmarkExperimentSuiteFull => '全量';

  @override
  String get benchmarkLabelSampleSummary => '样本摘要';

  @override
  String get benchmarkLabelTagsCommaSeparated => '标签（逗号分隔）';

  @override
  String get benchmarkButtonPromoteToSample => '提升为样本';

  @override
  String get benchmarkExperimentCardTitle => '实验运行';

  @override
  String get benchmarkLabelExperimentId => '实验 ID';

  @override
  String get benchmarkButtonLoadDetail => '读取详情';

  @override
  String get benchmarkButtonStart => '启动';

  @override
  String get benchmarkButtonCancel => '取消';

  @override
  String get benchmarkLabelNewExperimentName => '新实验名称';

  @override
  String get benchmarkLabelSampleTierSet => '样本集';

  @override
  String get benchmarkLabelStageScopeComma => '阶段范围（逗号分隔）';

  @override
  String get benchmarkLabelBaselineVariantLabel => '基线变体 label';

  @override
  String get benchmarkLabelVariantsJsonArray => '变体 JSON（数组）';

  @override
  String get benchmarkButtonCreateExperiment => '创建实验';

  @override
  String get benchmarkReviewCardTitle => '人工复核';

  @override
  String get benchmarkLabelReviewQueueId => '复核队列 ID';

  @override
  String get benchmarkLabelSubmittedScoreJson => '提交评分 JSON';

  @override
  String get benchmarkLabelSkipReasonOptional => '跳过原因（可选）';

  @override
  String get benchmarkGateCardTitle => '放行门决策';

  @override
  String get benchmarkLabelGateVariantId => '变体 ID';

  @override
  String get benchmarkLabelGateDecisionOptionalAuto =>
      '决策（留空则使用 auto decision）';

  @override
  String get benchmarkGateDecisionHint =>
      'approved / approved_limited / blocked / needs_review';

  @override
  String benchmarkGateAssessmentsSummary(int count) {
    return '放行门评估：$count 个变体';
  }

  @override
  String benchmarkTrendsDataSummary(int weeks) {
    return '趋势数据：$weeks 周';
  }

  @override
  String get benchmarkLabelGateDecisionNote => '决策说明';

  @override
  String get shellJobQueueStatsTitle => '任务队列统计（内部）';

  @override
  String get shellJobQueueStatsSubtitle =>
      '使用 INTERNAL_OPS_TOKEN dart-define → GET /api/v1/jobs/queue/stats';

  @override
  String shellJobQueueStatsStatsLine(
    String pending,
    String claimable,
    String running,
    String dead,
    String failed24h,
    String oldestClaimable,
  ) {
    return 'pending=$pending claimable=$claimable running=$running dead=$dead failed_24h=$failed24h oldest_claimable_s=$oldestClaimable';
  }

  @override
  String shellJobQueueStatsPendingByKind(String kinds) {
    return 'pending_by_kind: $kinds';
  }

  @override
  String get benchmarkGatePromoteBaselineTitle => '同时提升为新基线';

  @override
  String get benchmarkGatePromoteBaselineSubtitle =>
      '仅对 approved / approved_limited 生效';

  @override
  String get benchmarkAbCardTitle => 'A/B 对比评估';

  @override
  String get benchmarkLabelAbSaveNameOptional => '保存名称（可选）';

  @override
  String get benchmarkLabelAbCaseLines =>
      '案例列表（每行：testCaseId,baselineJobId,optimizedJobId）';

  @override
  String get benchmarkLabelAbMinTokenReductionPct => '最小 token 降幅 %';

  @override
  String get benchmarkLabelAbMaxQualityDrop => '最大质量下降';

  @override
  String get benchmarkLabelAbMinQualityScore => '最小质量分';

  @override
  String get benchmarkLabelAbSignificanceP => '显著性阈值 p';

  @override
  String get benchmarkButtonRunAbCompare => '执行 A/B 对比';

  @override
  String get benchmarkButtonSaveAndRun => '保存并执行';

  @override
  String get benchmarkButtonFetchHistory => '读取历史';

  @override
  String get benchmarkButtonLoadDetailAndFill => '读取详情并回填';

  @override
  String get benchmarkButtonReplaySave => '回放参数复跑并保存';

  @override
  String benchmarkErrorInvalidCaseRow(String line) {
    return '无效案例行：$line';
  }

  @override
  String get benchmarkErrorAbThresholdFormat => 'A/B 阈值参数格式错误';

  @override
  String get benchmarkErrorVariantsMustBeJsonArray => 'variants JSON 必须是数组';

  @override
  String get benchmarkErrorSubmittedScoreMustBeObject => 'submittedScore 必须是对象';

  @override
  String get benchmarkSummaryCasesEmpty => '当前没有基线样本';

  @override
  String benchmarkSummaryCases(int count, String preview) {
    return '样本 $count 条 · $preview';
  }

  @override
  String get benchmarkSummaryExperimentsEmpty => '当前没有实验运行';

  @override
  String benchmarkSummaryExperiments(int count, String preview) {
    return '实验 $count 条 · $preview';
  }

  @override
  String get benchmarkSummaryReviewQueueEmpty => '当前没有待复核队列';

  @override
  String benchmarkSummaryReviewQueue(int total, int pending) {
    return '复核 $total 条 · 待处理 $pending 条';
  }

  @override
  String get benchmarkSummaryGateEmpty => '尚未读取放行门结果';

  @override
  String benchmarkSummaryGate(
    int count,
    int approved,
    int limited,
    int blocked,
  ) {
    return '放行评估 $count 个 · approved $approved / limited $limited / blocked $blocked';
  }

  @override
  String get benchmarkSummaryTrendsEmpty => '尚未读取趋势';

  @override
  String benchmarkSummaryTrends(
    int weeks,
    String weekStart,
    String quality,
    String tokens,
  ) {
    return '趋势 $weeks 周 · 最新 $weekStart 质量 $quality / token $tokens';
  }

  @override
  String get agentWorkspaceProductionFlowRecipeDiagnosisRefineIntentFirst =>
      '当前更建议先细化导演计划里的分场景情绪/画面意图，再继续拆分分镜表。';

  @override
  String get agentWorkspaceProductionFlowRecipeDiagnosisExpandTableFirst =>
      '当前更建议先扩读关键分镜表窗口，再决定是否推进 storyboard。';

  @override
  String get agentWorkspaceProductionFlowRecipeDiagnosisCheapestFirst =>
      '当前建议按第一张卡开始推进，优先执行最靠前的低成本动作。';

  @override
  String get agentWorkspaceProductionSupervisionSummaryFallback => '按审核结论继续推进。';

  @override
  String get agentWorkspaceProductionFlowRecipeSbGenRefreshTitle => '刷新分镜结果';

  @override
  String get agentWorkspaceProductionFlowRecipeSbGenRereadTitle => '回读缺帧状态';

  @override
  String get agentWorkspaceProductionFlowRecipeSbGenRefreshDetail =>
      '分镜生成动作已执行，先刷新分镜结果，再决定是否写回。';

  @override
  String get agentWorkspaceProductionFlowRecipeContinueDirectorTitle =>
      '继续导演计划';

  @override
  String get agentWorkspaceProductionFlowRecipeContinueDirectorAfterSbDetail =>
      '如分镜结果还不稳定，回到 scriptPlan 生成下一轮导演决策。';

  @override
  String get agentWorkspaceProductionFlowRecipeSbTableRefreshTitle => '刷新分镜表';

  @override
  String get agentWorkspaceProductionFlowRecipeSbTablePartialTitle => '回读局部分镜表';

  @override
  String get agentWorkspaceProductionFlowRecipeSbTableRefreshDetail =>
      '分镜表子代理已执行，先刷新分镜表，再决定是否继续修订。';

  @override
  String get agentWorkspaceProductionFlowRecipeSbTableCrosscheckTitle =>
      '核对对应分镜';

  @override
  String get agentWorkspaceProductionFlowRecipeSbTableCrosscheckDetailAll =>
      '必要时切回 storyboard，确认分镜表调整是否已经落实到画面结果。';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsRefreshTitle => '刷新资产结果';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsRereadTitle => '回读受影响资产';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsRefreshDetail =>
      '资产动作已执行，先刷新资产结果，再决定是否写回。';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsContinueSubTitle =>
      '继续资产子代理';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsContinueSubDetail =>
      '若仍缺素材，可直接衔接资产子代理推进下一轮生成。';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsPlanFirstTitle =>
      '先生成资产计划';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsPlanFirstDetail =>
      '当前 assets 为空，优先让子代理补齐衍生素材规划。';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsPlanFirstPrompt =>
      '请基于当前空白 assets flow 规划最小可行的衍生素材集合，并说明优先级。';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsContinueGenTitle =>
      '继续资产生成';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsContinueGenDetailGeneric =>
      '仍有素材缺少图像结果，适合直接运行素材生成子代理。';

  @override
  String get agentWorkspaceProductionFlowRecipeRefreshStoryboardNeedTitle =>
      '刷新分镜需求';

  @override
  String get agentWorkspaceProductionFlowRecipeRefreshStoryboardNeedDetail =>
      '素材缺口补齐后通常需要回看 storyboard 是否还能沿用当前方案。';

  @override
  String get agentWorkspaceProductionFlowRecipeCheckStoryboardFlowTitle =>
      '检查分镜 flow';

  @override
  String get agentWorkspaceProductionFlowRecipeCheckStoryboardFlowDetail =>
      '资产已具备基础结果，可切到 storyboard 评估镜头生成状态。';

  @override
  String get agentWorkspaceProductionFlowRecipeTidyDirectorPlanTitle =>
      '整理导演计划';

  @override
  String get agentWorkspaceProductionFlowRecipeTidyDirectorPlanDetail =>
      '若素材已基本齐全，可生成下一轮导演计划收束 production 节奏。';

  @override
  String get agentWorkspaceProductionFlowRecipeTidyDirectorPlanPrompt =>
      '请结合现有素材状态与 scriptPlan，输出下一轮导演计划与执行优先级。';

  @override
  String get agentWorkspaceProductionFlowRecipeFirstStoryboardTitle =>
      '生成第一版分镜';

  @override
  String get agentWorkspaceProductionFlowRecipeFirstStoryboardDetail =>
      '当前 storyboard 为空，优先运行分镜生成子代理建立初版镜头。';

  @override
  String get agentWorkspaceProductionFlowRecipeFirstStoryboardPrompt =>
      '请基于当前 production 上下文生成第一版 storyboard，并保持最小可行镜头集。';

  @override
  String get agentWorkspaceProductionFlowRecipeFillStoryboardFramesTitle =>
      '继续补齐分镜图';

  @override
  String get agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsTitle =>
      '核对关联资产';

  @override
  String
  get agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsDetailFromRefs =>
      '优先只看当前分镜窗口实际引用的资产，避免把无关素材带入分镜补图。';

  @override
  String get agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsDetailNoIds =>
      '当前分镜摘要尚未定位出明确资产 ID，退回紧凑 assets 摘要读取。';

  @override
  String get agentWorkspaceProductionFlowRecipeCheckStoryboardTableTitle =>
      '检查分镜表';

  @override
  String get agentWorkspaceProductionFlowRecipeCheckStoryboardTableDetail =>
      '必要时切到 storyboardTable 审阅结构化镜头表后再回写。';

  @override
  String
  get agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsDetailReadyIds =>
      '分镜已引用明确资产，可先核对这批资产是否足够支撑后续导演调整。';

  @override
  String
  get agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsDetailReadyNoIds =>
      '当前分镜摘要未定位出明确资产 ID，先读紧凑 assets 摘要即可。';

  @override
  String get agentWorkspaceProductionFlowRecipeRefreshDirectorPlanTitle =>
      '刷新导演计划';

  @override
  String get agentWorkspaceProductionFlowRecipeRefreshDirectorPlanDetail =>
      '分镜已有基础结果，适合回到 scriptPlan 整理下一轮导演决策。';

  @override
  String get agentWorkspaceProductionFlowRecipeCreateDirectorPlanTitle =>
      '先生成导演计划';

  @override
  String get agentWorkspaceProductionFlowRecipeCreateDirectorPlanDetail =>
      '当前 scriptPlan 为空，优先建立导演计划再推进资产或分镜。';

  @override
  String get agentWorkspaceProductionFlowRecipeCreateDirectorPlanPrompt =>
      '请基于当前 production 上下文生成一版导演计划，并给出执行优先级。';

  @override
  String get agentWorkspaceProductionFlowRecipeReviewDirectorPlanTitle =>
      '审核导演计划';

  @override
  String get agentWorkspaceProductionFlowRecipeReviewDirectorPlanDetail =>
      '导演计划已有内容，先做一次监督审核更容易在低成本阶段发现节奏和资产问题。';

  @override
  String get agentWorkspaceProductionFlowRecipeReviewDirectorPlanPrompt =>
      '请审核当前导演规划，重点检查剧情覆盖、资产匹配与节奏合理性。';

  @override
  String get agentWorkspaceProductionFlowRecipeRereadScriptTitle => '回看剧本依据';

  @override
  String get agentWorkspaceProductionFlowRecipeCheckKeyAssetsTitle => '检查关键资产';

  @override
  String get agentWorkspaceProductionFlowRecipeRefineSceneIntentTitle =>
      '补足分场景意图';

  @override
  String get agentWorkspaceProductionFlowRecipePreviewStoryboardTableTitle =>
      '先看分镜表落地';

  @override
  String get agentWorkspaceProductionFlowRecipeRefineSceneIntentDetail =>
      '当前导演计划还缺少足够明确的分场景情绪/画面意图，先补这层再拆 storyboardTable，能减少后续反复返工。';

  @override
  String get agentWorkspaceProductionFlowRecipePreviewStoryboardTableDetail =>
      '如计划已定，先抽样检查 storyboardTable 结构更省 token，再决定是否读取 storyboard 画面结果。';

  @override
  String get agentWorkspaceProductionFlowRecipeRefineSceneIntentPrompt =>
      '请继续细化当前 scriptPlan，优先补足分场景情绪推进、画面意图与镜头落点，再进入 storyboardTable 拆分。';

  @override
  String get agentWorkspaceProductionFlowRecipeCreateStoryboardTableTitle =>
      '生成分镜表';

  @override
  String get agentWorkspaceProductionFlowRecipeCreateStoryboardTableDetail =>
      '当前 storyboardTable 为空，适合先用分镜表子代理补结构。';

  @override
  String get agentWorkspaceProductionFlowRecipeCreateStoryboardTablePrompt =>
      '请先产出结构化 storyboardTable，并保持字段清晰可回写。';

  @override
  String get agentWorkspaceProductionFlowRecipeReviewStoryboardTableTitle =>
      '审核分镜表';

  @override
  String get agentWorkspaceProductionFlowRecipeReviewStoryboardTableDetail =>
      '分镜表已有内容，先做监督审核可避免把错误结构继续放大到 storyboard。';

  @override
  String get agentWorkspaceProductionFlowRecipeReviewStoryboardTablePrompt =>
      '请审核当前分镜表，重点检查覆盖度、资产关联与拆分粒度。';

  @override
  String get agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsTableRefs =>
      '优先只看当前分镜窗口实际引用的资产，减少无关素材上下文。';

  @override
  String get agentWorkspaceProductionFlowRecipeVerifyLinkedAssetsTableNoIds =>
      '当前窗口暂未解析出关联资产 ID，退回紧凑 assets 摘要读取。';

  @override
  String get agentWorkspaceProductionFlowRecipeSwitchStoryboardResultsTitle =>
      '切回分镜结果';

  @override
  String
  get agentWorkspaceProductionFlowRecipeSwitchStoryboardResultsDetailAll =>
      '分镜表已有内容，可继续查看 storyboard 画面结果是否跟上。';

  @override
  String get agentWorkspaceProductionFlowRecipeSampleStoryboardTableTitle =>
      '抽样读取分镜表';

  @override
  String get agentWorkspaceProductionFlowRecipeSampleStoryboardTableDetail =>
      '先只看前 8 行关键列，通常足够判断是否继续审核或回写。';

  @override
  String get agentWorkspaceProductionFlowRecipeReviseDirectorPlanTitle =>
      '修导演计划';

  @override
  String get agentWorkspaceProductionFlowRecipeRecheckAssetSupportTitle =>
      '复查资产支撑';

  @override
  String get agentWorkspaceProductionFlowRecipeRecheckAssetSupportDetail =>
      '导演计划常先卡在资产准备，先看 assets 能减少返工。';

  @override
  String get agentWorkspaceProductionFlowRecipeVerifyAssetSupportTitle =>
      '核对资产支撑';

  @override
  String get agentWorkspaceProductionFlowRecipeRereadDirectorPlanTitle =>
      '回看导演计划';

  @override
  String
  get agentWorkspaceProductionFlowRecipeRereadDirectorPlanAfterAssetsDetail =>
      '资产核对后回到精简 scriptPlan，确认是否还需要修订计划再推进分镜。';

  @override
  String get agentWorkspaceProductionFlowRecipeInspectStoryboardResultsTitle =>
      '检查分镜结果';

  @override
  String get agentWorkspaceProductionFlowRecipeCompareStoryboardTableTitle =>
      '对照分镜表';

  @override
  String
  get agentWorkspaceProductionFlowRecipeCompareStoryboardTableDetailGeneric =>
      '先复读关键列窗口，避免把整张分镜表重新带入上下文。';

  @override
  String get agentWorkspaceProductionFlowRecipeRereadScriptNeedWindowDetail =>
      '需要时再回看紧凑剧本窗口，确认镜头依据。';

  @override
  String get agentWorkspaceProductionFlowRecipeReviseStoryboardTableTitle =>
      '修分镜表';

  @override
  String
  get agentWorkspaceProductionFlowRecipeSampleRereadStoryboardTableTitle =>
      '抽样复读分镜表';

  @override
  String
  get agentWorkspaceProductionFlowRecipeSampleRereadStoryboardTableDetailEmpty =>
      '先读取关键列窗口，避免把整张表反复带入上下文。';

  @override
  String
  get agentWorkspaceProductionFlowRecipeSampleRereadStoryboardTableDetailFocused =>
      '先只复读审核聚焦镜头对应的分镜表行，避免回到整表窗口。';

  @override
  String get agentWorkspaceProductionFlowRecipeContinueStoryboardGenTitle =>
      '继续生成分镜图';

  @override
  String
  get agentWorkspaceProductionFlowRecipeCompareStoryboardTableBeforeFillDetail =>
      '补图前先复读关键列窗口，避免为整批镜头重建上下文。';

  @override
  String get agentWorkspaceProductionArgSuggestDeriveNameFallback => '新衍生资产';

  @override
  String get agentWorkspaceProductionArgSuggestFillFirst => '填充首项';

  @override
  String get agentWorkspaceProductionArgSuggestFillFirstThree => '填充前 3 项';

  @override
  String get agentWorkspaceProductionArgSuggestFillAll => '填充全部';

  @override
  String get agentWorkspaceProductionFlowRecipeAssetsGenHadSummaryNote =>
      '先检查本次刚生成资产的结果再决定是否补跑';

  @override
  String agentWorkspaceProductionArgSuggestAddTo(String id) {
    return '新增到 #$id';
  }

  @override
  String agentWorkspaceProductionArgSuggestDelete(String id) {
    return '删除 #$id';
  }

  @override
  String agentWorkspaceProductionFlowRecipeSbGenRereadDetail(String ids) {
    return '分镜生成动作已执行，先回读本次镜头 #$ids 的缺帧状态。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeSbTablePartialDetail(String ids) {
    return '分镜表子代理已执行，先回读本次镜头 #$ids 对应的局部分镜表行。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeSbTableCrosscheckDetailFocused(
    String ids,
  ) {
    return '优先只回读镜头 #$ids 的 storyboard 结果，确认表格修改没有放大到整段。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeAssetsRereadDetail(String ids) {
    return '资产生成动作已执行，先回读本次资产 #$ids 的最新状态。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeAssetsGenDetailScoped(String scope) {
    return '$scope 仍缺图，优先只补这批衍生资产更省 token。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeSbFillGapDetail(
    String idsLabel,
    String idTail,
  ) {
    return '优先只补缺帧镜头 #$idsLabel$idTail，避免把已完成镜头整批重跑。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeRereadScriptScriptPlanDetail(
    String scriptWindow,
  ) {
    return '先只回看$scriptWindow，确认导演计划与原文节奏一致，再决定是否扩读。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeCheckKeyAssetsDetailIds(
    String assetScope,
  ) {
    return '导演计划已点名$assetScope，先精确核对再决定是否扩读其他素材。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeCheckKeyAssetsDetailNoIds(
    String assetScope,
  ) {
    return '导演计划已有内容，先核对$assetScope是否支撑执行，信息不足时再补更多资产。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeContinueDirectorDetailIds(
    String assetScope,
  ) {
    return '优先围绕$assetScope收束导演决策，让后续分镜和素材动作先继承这批受改写约束的重点。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeContinueDirectorDetailNoIds(
    String assetScope,
  ) {
    return '先围绕$assetScope继续收束导演决策，让后续分镜和素材动作继承当前改写约束。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeContinueDirectorPromptIds(
    String assetScope,
  ) {
    return '请在当前 scriptPlan 上继续收束导演计划，优先围绕$assetScope安排镜头和素材优先级，确保后续分镜执行继承上游改写约束。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeContinueDirectorPromptNoIds(
    String assetScope,
  ) {
    return '请在当前 scriptPlan 上继续收束导演计划，优先围绕$assetScope安排镜头和素材优先级，确保后续分镜执行继承上游改写约束。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeRereadScriptRevisePlanDetail(
    String scriptWindow,
  ) {
    return '修订前先只回看$scriptWindow，避免为 scriptPlan 扩读整段剧本。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeReviseDirectorPlanDetail(
    String summary,
  ) {
    return '审核结论：$summary';
  }

  @override
  String agentWorkspaceProductionFlowRecipeReviseDirectorPlanPrompt(
    String summary,
  ) {
    return '请根据最近审核意见修订 scriptPlan，优先解决：$summary';
  }

  @override
  String agentWorkspaceProductionFlowRecipeVerifyAssetSupportDetail(
    String summary,
    String assetScope,
  ) {
    return '审核结论：$summary；优先只看$assetScope，确认导演计划缺口。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeInspectSbResultsDetail(
    String summary,
    String focusClause,
  ) {
    return '审核结论：$summary；优先只看$focusClause';
  }

  @override
  String agentWorkspaceProductionFlowRecipeCompareStoryboardTableDetailFocus(
    String storyboardFocus,
  ) {
    return '优先只复读$storyboardFocus对应的分镜表行，避免退回整表。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeRereadScriptReviewDetail(
    String reviewScope,
  ) {
    return '如需核对镜头依据，优先只用局部范围：$reviewScope。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeInspectStoryboardResultsDetailScript(
    String summary,
    String reviewScope,
  ) {
    return '审核结论：$summary；优先只用局部范围：$reviewScope。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeSwitchStoryboardResultsDetailCount(
    int count,
  ) {
    return '优先只回看当前分镜表窗口对应的 $count 个镜头，避免退回通用分镜摘要。';
  }

  @override
  String
  agentWorkspaceProductionFlowRecipeCompareStoryboardTableBeforeFillDetailFocus(
    String storyboardFocus,
  ) {
    return '补图前先只复读$storyboardFocus对应的分镜表行。';
  }

  @override
  String agentWorkspaceProductionFlowRecipePromptStoryboardContinue(
    String body,
  ) {
    return '请继续推进 storyboard。$body';
  }

  @override
  String agentWorkspaceProductionFlowRecipePromptReviseStoryboardTable(
    String body,
  ) {
    return '请根据最近审核意见修订 storyboardTable。$body';
  }

  @override
  String agentWorkspaceProductionFlowRecipePromptStoryboardFromReview(
    String body,
  ) {
    return '请基于最近审核结论继续推进 storyboard。$body';
  }

  @override
  String agentWorkspaceProductionFlowRecipeShotCountTail(int count) {
    return ' 等 $count 个镜头';
  }

  @override
  String
  agentWorkspaceProductionFlowRecipeInspectStoryboardResultsDetailSummaryOnly(
    String summary,
  ) {
    return '审核结论：$summary';
  }

  @override
  String
  agentWorkspaceProductionFlowRecipeInspectStoryboardResultsDetailWithScope(
    String summary,
    String reviewScope,
  ) {
    return '审核结论：$summary；$reviewScope。';
  }

  @override
  String agentWorkspaceProductionFlowRecipeArgDeriveNameFromParent(
    String name,
  ) {
    return '$name-衍生';
  }

  @override
  String agentWorkspaceProductionAssetReviewPromptFocused(
    int count,
    String priority,
  ) {
    return '请优先只核对这 $count 个资产是否支撑当前导演规划；仅补必要缺口，不扩读无关素材。$priority';
  }

  @override
  String agentWorkspaceProductionAssetReviewPromptScoped(
    String scope,
    String priority,
  ) {
    return '请先核对$scope是否支撑当前导演规划；信息不足时再最小补读，不要整包扩读 assets。$priority';
  }

  @override
  String agentWorkspaceProductionAssetReviewPromptPriority(String summary) {
    return '优先解决：$summary';
  }

  @override
  String agentWorkspaceProductionRecipeAppliedFollowRefine(String title) {
    return '已应用任务建议：$title，下一步先细化导演计划。';
  }

  @override
  String agentWorkspaceProductionRecipeAppliedFollowExpandTable(String title) {
    return '已应用任务建议：$title，下一步先扩读关键分镜表窗口。';
  }

  @override
  String agentWorkspaceProductionRecipeAppliedGeneric(String title) {
    return '已应用任务建议：$title';
  }

  @override
  String get agentWorkspaceDefaultScriptPrompt =>
      '先用 get_planData 读取 planData.script、storySkeleton、adaptationStrategy 的必要片段，再读目标章节事件；只有细节不足时才补正文窗口，最后给出下一轮 script 建议。';

  @override
  String get agentWorkspaceDefaultProductionPrompt =>
      '先调用 get_flowData key=scriptPlan 读取紧凑导演规划，再按需补最小化 assets 或 storyboardTable，上来不要整包读取 production flow。';

  @override
  String get agentWorkspaceScriptArgTemplateCurrentWindow => '模板: 当前剧本窗口';

  @override
  String get agentWorkspaceScriptArgTemplateCurrentTail => '模板: 当前剧本尾段';

  @override
  String get agentWorkspaceScriptArgTemplatePreviousEpisodeTail => '模板: 上一集尾段';

  @override
  String get agentWorkspaceScriptArgTemplateStorySkeletonSlice => '模板: 骨架片段';

  @override
  String get agentWorkspaceScriptArgTemplateAdaptationSlice => '模板: 策略片段';

  @override
  String get agentWorkspaceScriptArgTemplateNovelTextWindow => '模板: 正文窗口';

  @override
  String get agentWorkspaceScriptArgTemplateNovelEventsWindow => '模板: 事件窗口';

  @override
  String get agentWorkspaceScriptArgTemplateEmptyArgs => '模板: 空参数';

  @override
  String get agentWorkspaceProductionArgTemplateCompactRead => '模板: 紧凑读取';

  @override
  String get agentWorkspaceProductionArgTemplateDirectorPlan => '模板: 导演计划';

  @override
  String get agentWorkspaceProductionArgTemplateAssetSummary => '模板: 资产摘要';

  @override
  String get agentWorkspaceProductionArgTemplateIdList => '模板: ID 列表';

  @override
  String get agentWorkspaceProductionArgTemplateStoryboardIds => '模板: 分镜 ID';

  @override
  String agentWorkspaceFilledArgTemplate(String label) {
    return '已填充参数模板：$label';
  }

  @override
  String agentWorkspaceFilledCandidateArgs(String label) {
    return '已填充候选参数：$label';
  }

  @override
  String get agentWorkspaceScriptInterceptArgsMustBeJsonObject =>
      '拦截：剧本工具参数必须是 JSON object。';

  @override
  String get agentWorkspaceScriptInterceptArgsJsonParseFailed =>
      '拦截：剧本工具参数 JSON 解析失败。';

  @override
  String agentWorkspaceScriptInterceptPromptRequired(String action) {
    return '拦截：$action 需要非空工作区提示词。';
  }

  @override
  String get agentWorkspaceScriptInterceptSelectDomainToolFirst =>
      '拦截：读取前需要选择剧本域工具。';

  @override
  String get agentWorkspaceScriptInterceptGetScriptContentNeedsScriptId =>
      '拦截：get_script_content 需要有效剧本 ID。';

  @override
  String agentWorkspaceScriptSyncedScriptContentScriptId(String scriptId) {
    return '已同步：get_script_content arguments.scriptId -> $scriptId';
  }

  @override
  String get agentWorkspaceScriptInterceptSelectSubAgentToolFirst =>
      '拦截：运行子代理前需要选择剧本子代理工具。';

  @override
  String get agentWorkspaceScriptActionRunWorkflow => '运行剧本工作流';

  @override
  String get agentWorkspaceScriptActionRunSubAgent => '运行子代理';

  @override
  String get agentWorkspaceScriptTriggeredRunWorkflow => '已触发：运行剧本工作流';

  @override
  String agentWorkspaceScriptTriggeredProbeContext(String tool) {
    return '已触发：读取剧本上下文 ($tool)';
  }

  @override
  String agentWorkspaceScriptTriggeredRunSubAgent(String tool) {
    return '已触发：运行子代理 ($tool)';
  }

  @override
  String get agentWorkspaceScriptInterceptNoScriptWritebackResult =>
      '拦截：暂无剧本结果可写回。';

  @override
  String get agentWorkspaceScriptTriggeredWritebackScript => '已触发：写回剧本';

  @override
  String get agentWorkspaceScriptInterceptNoPlanDataWritebackResult =>
      '拦截：暂无 planData 结果可写回。';

  @override
  String get agentWorkspaceScriptTriggeredWritebackPlanData => '已触发：写回计划数据';

  @override
  String get agentWorkspaceScriptInterceptPlanWritebackNeedsPlanId =>
      '拦截：需要 planId（拉取 get_planData）与 planData。';

  @override
  String get agentWorkspaceScriptTriggeredPlanRowUpdateData =>
      '已触发：update-data 写回计划行';

  @override
  String agentWorkspaceScriptAppliedRecipe(String title) {
    return '已应用任务建议：$title';
  }

  @override
  String agentWorkspaceScriptAppliedStage(String title) {
    return '已应用阶段动作：$title';
  }

  @override
  String get agentWorkspaceScriptGuidedGenerateDraftPrompt =>
      '请先读取当前集计划与目标章节事件；只有在衔接需要时才补读上一集尾段，其他细节再按需补章节正文窗口，然后生成下一版剧本正文并输出可直接写回的完整内容。';

  @override
  String get agentWorkspaceScriptPresetPlotSkeletonLabel => '剧情骨架';

  @override
  String get agentWorkspaceScriptPresetPlotSkeletonPrompt =>
      '先读取 get_planData 的 planData.script、storySkeleton、adaptationStrategy 片段，再补最少的 get_novel_events 或剧本窗口，总结当前剧情骨架缺口。';

  @override
  String get agentWorkspaceScriptPresetChapterAdaptLabel => '章节改编';

  @override
  String get agentWorkspaceScriptPresetChapterAdaptPrompt =>
      '先用 get_planData 读取计划剧本草稿与改编策略，再结合 get_novel_text 与 get_script_content 的窗口片段，对当前章节做改写建议，输出 3 条可执行脚本改写项。';

  @override
  String get agentWorkspaceProductionPresetDirectorPlanLabel => '导演计划';

  @override
  String get agentWorkspaceProductionPresetDirectorPlanPrompt =>
      '先调用 get_flowData key=scriptPlan，读取紧凑导演规划，再决定是否继续读 assets 或 storyboardTable。';

  @override
  String get agentWorkspaceProductionPresetAssetInventoryLabel => '资产盘点';

  @override
  String get agentWorkspaceProductionPresetAssetInventoryPrompt =>
      '先调用 get_flowData key=assets 并读取最小字段子集，盘点现有资产状态并给出下一步 production 任务建议。';

  @override
  String get agentWorkspaceProductionPresetStoryboardProgressLabel => '分镜推进';

  @override
  String get agentWorkspaceProductionPresetStoryboardProgressPrompt =>
      '读取 get_flowData key=storyboard 的紧凑镜头状态，评估当前分镜完成度并给出下一次 generate_storyboard 的执行建议。';

  @override
  String get agentWorkspaceProductionPresetProductionReviewLabel => '制作审核';

  @override
  String get agentWorkspaceProductionPresetProductionReviewPrompt =>
      '请先读取 get_flowData key=scriptPlan 或 storyboardTable，再调用 production supervision 审核当前制作结果。';

  @override
  String get agentWorkspaceProductionRunningRunWorkflow => '执行中：运行制作工作流';

  @override
  String get agentWorkspaceProductionRunningProbeTool => '执行中：读取制作工具结果';

  @override
  String get agentWorkspaceProductionRunningSubAgent => '执行中：运行子代理';

  @override
  String get agentWorkspaceProductionRunningWriteback => '执行中：写回工具结果';

  @override
  String get agentWorkspaceProductionInterceptArgsMustBeJsonObject =>
      '拦截：制作工具参数必须是 JSON object。';

  @override
  String get agentWorkspaceProductionInterceptArgsJsonParseFailed =>
      '拦截：制作工具参数 JSON 解析失败。';

  @override
  String agentWorkspaceProductionInterceptPromptRequired(String action) {
    return '拦截：$action 需要非空工作区提示词。';
  }

  @override
  String get agentWorkspaceProductionInterceptSelectDomainToolFirst =>
      '拦截：读取前需要选择制作域工具。';

  @override
  String get agentWorkspaceProductionInterceptGetFlowDataNeedsKey =>
      '拦截：get_flowData 需要有效 flow key。';

  @override
  String agentWorkspaceProductionSyncedFlowDataKey(String key) {
    return '已同步：get_flowData arguments.key -> $key';
  }

  @override
  String get agentWorkspaceProductionInterceptSelectSubAgentToolFirst =>
      '拦截：运行子代理前需要选择制作子代理工具。';

  @override
  String get agentWorkspaceProductionActionRunWorkflow => '运行制作工作流';

  @override
  String get agentWorkspaceProductionActionRunSubAgent => '运行子代理';

  @override
  String get agentWorkspaceProductionTriggeredRunWorkflow => '已触发：运行制作工作流';

  @override
  String agentWorkspaceProductionTriggeredProbeContext(String detail) {
    return '已触发：读取制作工具 ($detail)';
  }

  @override
  String agentWorkspaceProductionTriggeredRunSubAgentTool(String tool) {
    return '已触发：运行子代理 ($tool)';
  }

  @override
  String get agentWorkspaceProductionInterceptNoToolWriteback =>
      '拦截：暂无工具结果可写回。';

  @override
  String get agentWorkspaceProductionInterceptWritebackNeedsFlowKey =>
      '拦截：写回前请提供有效 flow key。';

  @override
  String agentWorkspaceProductionTriggeredWritebackFlow(String key) {
    return '已触发：写回工具结果 -> flow[$key]';
  }

  @override
  String get agentWorkspaceProductionGuidedDeriveAssetsPrompt =>
      '请基于当前资产 flow 给出下一轮衍生素材生成建议，并执行最小可行推进。';

  @override
  String get agentWorkspaceProductionGuidedStoryboardGenPrompt =>
      '请基于当前分镜 flow 输出下一轮分镜生成计划，并执行最小可行生成动作。';

  @override
  String get agentWorkspaceProductionGuidedDirectorPlanPrompt =>
      '请结合 scriptPlan 与现有素材状态，产出下一轮导演计划并给出执行优先级。';

  @override
  String get projectsCreativeManualDefaultSlotsTemplate =>
      '场景|scene|\n角色|role|';

  @override
  String l10nBatch_078b5e4699(String p0, String p1) {
    return '$p0: $p1';
  }

  @override
  String l10nBatch_c084376ea9(String p0, String p1) {
    return '$p0 · $p1';
  }

  @override
  String l10nBatch_775383c7b6(int p0) {
    return '$p0';
  }

  @override
  String l10nBatch_a242ae1254(int p0, String p1) {
    return '#$p0 $p1';
  }

  @override
  String l10nBatch_46f00a087b(int p0) {
    return '#$p0';
  }

  @override
  String l10nBatch_978d9d9f6f(int p0, String p1) {
    return '#$p0 · $p1';
  }
}
