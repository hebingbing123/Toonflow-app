import 'package:flutter/material.dart';

import '../config.dart';
import '../rust_api.dart';

typedef AdminConsoleErrorSink = void Function(String? error);

class AdminConsoleController extends ChangeNotifier {
  AdminConsoleController({required AdminConsoleErrorSink onErrorChanged})
    : _onErrorChanged = onErrorChanged;

  final AdminConsoleErrorSink _onErrorChanged;

  bool searching = false;
  bool loadingDetail = false;
  bool savingGovernance = false;
  bool savingWorkspaceContext = false;
  bool savingWorkspaceMembership = false;
  bool savingOwnershipRemediation = false;
  String? selectedKind;
  String? selectedId;
  AdminSearchResponseV1? searchResult;
  AdminUserDetailResponseV1? userDetail;
  AdminWorkspaceDetailResponseV1? workspaceDetail;
  AdminProjectDetailResponseV1? projectDetail;

  String get _internalOpsToken => kInternalOpsToken;

  bool get enabled => _internalOpsToken.trim().isNotEmpty;

  void _setError(String? value) => _onErrorChanged(value);

  Future<void> search(String query) async {
    if (!enabled || searching) {
      return;
    }
    final needle = query.trim();
    if (needle.length < 2) {
      _setError('请输入至少 2 个字符');
      return;
    }
    searching = true;
    _setError(null);
    notifyListeners();
    try {
      searchResult = await fetchAdminSearchV1(_internalOpsToken, query: needle);
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  Future<void> loadUser(String userId) async {
    await _loadDetail('user', userId, () async {
      userDetail = await fetchAdminUserDetailV1(
        _internalOpsToken,
        userId: userId,
      );
      workspaceDetail = null;
      projectDetail = null;
    });
  }

  Future<void> loadWorkspace(String workspaceId) async {
    await _loadDetail('workspace', workspaceId, () async {
      workspaceDetail = await fetchAdminWorkspaceDetailV1(
        _internalOpsToken,
        workspaceId: workspaceId,
      );
      userDetail = null;
      projectDetail = null;
    });
  }

  Future<void> loadProject(String projectId) async {
    await _loadDetail('project', projectId, () async {
      projectDetail = await fetchAdminProjectDetailV1(
        _internalOpsToken,
        projectId: projectId,
      );
      userDetail = null;
      workspaceDetail = null;
    });
  }

  Future<void> _loadDetail(
    String kind,
    String id,
    Future<void> Function() action,
  ) async {
    if (!enabled || loadingDetail) {
      return;
    }
    loadingDetail = true;
    selectedKind = kind;
    selectedId = id;
    _setError(null);
    notifyListeners();
    try {
      await action();
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      loadingDetail = false;
      notifyListeners();
    }
  }

  Future<void> updateUserGovernance({
    required String userId,
    required AdminOperationalStatusV1 operationalStatus,
    String? operationalStatusReason,
    String? opsNote,
    required AdminQuotaOverrideActionV1 dailyJobQuotaAction,
    int? dailyJobQuota,
  }) async {
    if (!enabled || savingGovernance) {
      return;
    }
    final normalizedReason = operationalStatusReason?.trim();
    final normalizedNote = opsNote?.trim();
    if (operationalStatus == AdminOperationalStatusV1.suspended &&
        (normalizedReason == null || normalizedReason.isEmpty)) {
      _setError('暂停用户时必须填写暂停原因');
      notifyListeners();
      return;
    }
    if (dailyJobQuotaAction == AdminQuotaOverrideActionV1.set &&
        (dailyJobQuota == null || dailyJobQuota <= 0)) {
      _setError('设置日配额时必须填写大于 0 的整数');
      notifyListeners();
      return;
    }
    savingGovernance = true;
    _setError(null);
    notifyListeners();
    try {
      userDetail = await updateAdminUserGovernanceV1(
        _internalOpsToken,
        userId: userId,
        operationalStatus: operationalStatus,
        operationalStatusReason:
            operationalStatus == AdminOperationalStatusV1.active
            ? null
            : normalizedReason,
        opsNote: normalizedNote == null || normalizedNote.isEmpty
            ? null
            : normalizedNote,
        dailyJobQuotaAction: dailyJobQuotaAction,
        dailyJobQuota: dailyJobQuotaAction == AdminQuotaOverrideActionV1.set
            ? dailyJobQuota
            : null,
      );
      final current = searchResult;
      if (current != null) {
        searchResult = AdminSearchResponseV1(
          query: current.query,
          users: current.users
              .map(
                (item) => item.userId == userId
                    ? AdminUserSearchHitV1(
                        userId: item.userId,
                        email: item.email,
                        planTier: item.planTier,
                        operationalStatus: userDetail!.operationalStatus,
                        currentWorkspaceId: item.currentWorkspaceId,
                        workspaceCount: item.workspaceCount,
                        projectCount: item.projectCount,
                        activeJobCount: item.activeJobCount,
                      )
                    : item,
              )
              .toList(growable: false),
          workspaces: current.workspaces,
          projects: current.projects,
          jobs: current.jobs,
        );
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      savingGovernance = false;
      notifyListeners();
    }
  }

  Future<void> updateUserWorkspaceContext({
    required String userId,
    required AdminUserWorkspaceContextActionV1 action,
    String? workspaceId,
  }) async {
    if (!enabled || savingWorkspaceContext) {
      return;
    }
    savingWorkspaceContext = true;
    _setError(null);
    notifyListeners();
    try {
      userDetail = await updateAdminUserWorkspaceContextV1(
        _internalOpsToken,
        userId: userId,
        action: action,
        workspaceId: workspaceId,
      );
      final current = searchResult;
      if (current != null) {
        searchResult = AdminSearchResponseV1(
          query: current.query,
          users: current.users
              .map(
                (item) => item.userId == userId
                    ? AdminUserSearchHitV1(
                        userId: item.userId,
                        email: item.email,
                        planTier: item.planTier,
                        operationalStatus: item.operationalStatus,
                        currentWorkspaceId:
                            userDetail?.currentWorkspace?.workspaceId,
                        workspaceCount: item.workspaceCount,
                        projectCount: item.projectCount,
                        activeJobCount: item.activeJobCount,
                      )
                    : item,
              )
              .toList(growable: false),
          workspaces: current.workspaces,
          projects: current.projects,
          jobs: current.jobs,
        );
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      savingWorkspaceContext = false;
      notifyListeners();
    }
  }

  Future<void> updateWorkspaceGovernance({
    required String workspaceId,
    required AdminWorkspaceLifecycleActionV1 workspaceLifecycle,
    required AdminWorkspaceOpsNoteActionV1 opsNoteAction,
    String? opsNote,
  }) async {
    if (!enabled || savingGovernance) {
      return;
    }
    final trimmed = opsNote?.trim();
    if (opsNoteAction == AdminWorkspaceOpsNoteActionV1.set &&
        (trimmed == null || trimmed.isEmpty)) {
      _setError('设置内部备注时必须填写内容');
      notifyListeners();
      return;
    }
    savingGovernance = true;
    _setError(null);
    notifyListeners();
    try {
      workspaceDetail = await updateAdminWorkspaceGovernanceV1(
        _internalOpsToken,
        workspaceId: workspaceId,
        workspaceLifecycle: workspaceLifecycle,
        opsNoteAction: opsNoteAction,
        opsNote: opsNoteAction == AdminWorkspaceOpsNoteActionV1.set
            ? trimmed
            : null,
      );
      final current = searchResult;
      if (current != null) {
        searchResult = AdminSearchResponseV1(
          query: current.query,
          users: current.users,
          workspaces: current.workspaces
              .map(
                (item) => item.workspaceId == workspaceId
                    ? AdminWorkspaceSearchHitV1(
                        workspaceId: item.workspaceId,
                        name: item.name,
                        workspaceType: item.workspaceType,
                        archivedAt: workspaceDetail!.archivedAt,
                        ownerUserId: item.ownerUserId,
                        ownerEmail: item.ownerEmail,
                        memberCount: item.memberCount,
                        projectCount: item.projectCount,
                        activeJobCount: item.activeJobCount,
                      )
                    : item,
              )
              .toList(growable: false),
          projects: current.projects,
          jobs: current.jobs,
        );
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      savingGovernance = false;
      notifyListeners();
    }
  }

  Future<void> updateWorkspaceMemberRemediation({
    required String workspaceId,
    required AdminWorkspaceMemberRemediationActionV1 action,
    required String userId,
    AdminWorkspaceMemberRoleV1? role,
  }) async {
    if (!enabled || savingWorkspaceMembership) {
      return;
    }
    final trimmedUserId = userId.trim();
    if (trimmedUserId.isEmpty) {
      _setError('成员 userId 不能为空');
      notifyListeners();
      return;
    }
    if (action == AdminWorkspaceMemberRemediationActionV1.upsert &&
        role == null) {
      _setError('新增或更新成员时必须指定角色');
      notifyListeners();
      return;
    }
    savingWorkspaceMembership = true;
    _setError(null);
    notifyListeners();
    try {
      workspaceDetail = await updateAdminWorkspaceMemberRemediationV1(
        _internalOpsToken,
        workspaceId: workspaceId,
        action: action,
        userId: trimmedUserId,
        role: role,
      );
      final current = searchResult;
      if (current != null) {
        searchResult = AdminSearchResponseV1(
          query: current.query,
          users: current.users,
          workspaces: current.workspaces
              .map(
                (item) => item.workspaceId == workspaceId
                    ? AdminWorkspaceSearchHitV1(
                        workspaceId: item.workspaceId,
                        name: item.name,
                        workspaceType: item.workspaceType,
                        archivedAt: item.archivedAt,
                        ownerUserId: item.ownerUserId,
                        ownerEmail: item.ownerEmail,
                        memberCount: workspaceDetail!.memberCount,
                        projectCount: item.projectCount,
                        activeJobCount: item.activeJobCount,
                      )
                    : item,
              )
              .toList(growable: false),
          projects: current.projects,
          jobs: current.jobs,
        );
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      savingWorkspaceMembership = false;
      notifyListeners();
    }
  }

  Future<void> updateProjectGovernance({
    required String projectId,
    required AdminProjectLifecycleActionV1 projectLifecycle,
    required AdminWorkspaceOpsNoteActionV1 opsNoteAction,
    String? opsNote,
  }) async {
    if (!enabled || savingGovernance) {
      return;
    }
    final trimmed = opsNote?.trim();
    if (opsNoteAction == AdminWorkspaceOpsNoteActionV1.set &&
        (trimmed == null || trimmed.isEmpty)) {
      _setError('设置内部备注时必须填写内容');
      notifyListeners();
      return;
    }
    savingGovernance = true;
    _setError(null);
    notifyListeners();
    try {
      projectDetail = await updateAdminProjectGovernanceV1(
        _internalOpsToken,
        projectId: projectId,
        projectLifecycle: projectLifecycle,
        opsNoteAction: opsNoteAction,
        opsNote: opsNoteAction == AdminWorkspaceOpsNoteActionV1.set
            ? trimmed
            : null,
      );
      final current = searchResult;
      if (current != null) {
        searchResult = AdminSearchResponseV1(
          query: current.query,
          users: current.users,
          workspaces: current.workspaces,
          projects: current.projects
              .map(
                (item) => item.projectId == projectId
                    ? AdminProjectSearchHitV1(
                        projectId: item.projectId,
                        numericId: item.numericId,
                        name: item.name,
                        workspaceId: item.workspaceId,
                        workspaceName: item.workspaceName,
                        ownerUserId: item.ownerUserId,
                        ownerEmail: item.ownerEmail,
                        archivedAt: projectDetail!.archivedAt,
                        updatedAt: item.updatedAt,
                      )
                    : item,
              )
              .toList(growable: false),
          jobs: current.jobs,
        );
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      savingGovernance = false;
      notifyListeners();
    }
  }

  Future<void> transferWorkspaceOwner({
    required String workspaceId,
    required String targetUserId,
  }) async {
    if (!enabled || savingOwnershipRemediation) {
      return;
    }
    final trimmedTarget = targetUserId.trim();
    if (trimmedTarget.isEmpty) {
      _setError('目标 owner userId 不能为空');
      notifyListeners();
      return;
    }
    savingOwnershipRemediation = true;
    _setError(null);
    notifyListeners();
    try {
      workspaceDetail = await updateAdminWorkspaceOwnerTransferV1(
        _internalOpsToken,
        workspaceId: workspaceId,
        targetUserId: trimmedTarget,
      );
      final current = searchResult;
      if (current != null) {
        searchResult = AdminSearchResponseV1(
          query: current.query,
          users: current.users,
          workspaces: current.workspaces
              .map(
                (item) => item.workspaceId == workspaceId
                    ? AdminWorkspaceSearchHitV1(
                        workspaceId: item.workspaceId,
                        name: item.name,
                        workspaceType: item.workspaceType,
                        archivedAt: item.archivedAt,
                        ownerUserId: workspaceDetail!.ownerUserId,
                        ownerEmail: workspaceDetail!.ownerEmail,
                        memberCount: workspaceDetail!.memberCount,
                        projectCount: item.projectCount,
                        activeJobCount: item.activeJobCount,
                      )
                    : item,
              )
              .toList(growable: false),
          projects: current.projects,
          jobs: current.jobs,
        );
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      savingOwnershipRemediation = false;
      notifyListeners();
    }
  }

  Future<void> transferProjectOwner({
    required String projectId,
    required String targetUserId,
  }) async {
    if (!enabled || savingOwnershipRemediation) {
      return;
    }
    final trimmedTarget = targetUserId.trim();
    if (trimmedTarget.isEmpty) {
      _setError('目标 owner userId 不能为空');
      notifyListeners();
      return;
    }
    savingOwnershipRemediation = true;
    _setError(null);
    notifyListeners();
    try {
      projectDetail = await updateAdminProjectOwnerTransferV1(
        _internalOpsToken,
        projectId: projectId,
        targetUserId: trimmedTarget,
      );
      final current = searchResult;
      if (current != null) {
        searchResult = AdminSearchResponseV1(
          query: current.query,
          users: current.users,
          workspaces: current.workspaces,
          projects: current.projects
              .map(
                (item) => item.projectId == projectId
                    ? AdminProjectSearchHitV1(
                        projectId: item.projectId,
                        numericId: item.numericId,
                        name: item.name,
                        workspaceId: item.workspaceId,
                        workspaceName: item.workspaceName,
                        ownerUserId: projectDetail!.ownerUserId,
                        ownerEmail: projectDetail!.ownerEmail,
                        archivedAt: projectDetail!.archivedAt,
                        updatedAt: item.updatedAt,
                      )
                    : item,
              )
              .toList(growable: false),
          jobs: current.jobs,
        );
      }
    } on RustApiException catch (error) {
      reportRustApiError(error, onErrorChanged: _setError);
    } catch (error) {
      _setError('$error');
    } finally {
      savingOwnershipRemediation = false;
      notifyListeners();
    }
  }

  void clearDetail() {
    selectedKind = null;
    selectedId = null;
    userDetail = null;
    workspaceDetail = null;
    projectDetail = null;
    savingGovernance = false;
    savingWorkspaceContext = false;
    savingWorkspaceMembership = false;
    savingOwnershipRemediation = false;
    notifyListeners();
  }
}
