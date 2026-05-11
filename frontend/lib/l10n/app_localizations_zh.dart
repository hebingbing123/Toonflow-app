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
}
