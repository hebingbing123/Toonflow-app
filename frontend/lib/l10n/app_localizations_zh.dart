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
}
