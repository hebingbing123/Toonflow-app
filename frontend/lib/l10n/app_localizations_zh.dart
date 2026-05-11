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
}
