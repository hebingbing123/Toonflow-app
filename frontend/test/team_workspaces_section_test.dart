import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations_zh.dart';
import 'package:openflow_app/rust_api/workspaces/workspaces.dart';
import 'package:openflow_app/team_workspaces/invite_deep_link.dart';
import 'package:openflow_app/team_workspaces/section.dart';
import 'package:openflow_app/team_workspaces/strings.dart';

void main() {
  WorkspaceMemberResponse member({
    required String userId,
    required String role,
  }) {
    final now = DateTime.utc(2026, 1, 1);
    return WorkspaceMemberResponse(
      workspaceId: 'workspace-1',
      userId: userId,
      role: role,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('filterWorkspaceMembers filters by user id and role', () {
    final rows = <WorkspaceMemberResponse>[
      member(userId: 'user-alpha', role: 'owner'),
      member(userId: 'user-bravo', role: 'admin'),
      member(userId: 'user-charlie', role: 'member'),
    ];

    expect(filterWorkspaceMembers(rows, '').length, 3);
    expect(filterWorkspaceMembers(rows, 'bravo').single.userId, 'user-bravo');
    expect(filterWorkspaceMembers(rows, 'ADMIN').single.userId, 'user-bravo');
    expect(filterWorkspaceMembers(rows, 'unknown'), isEmpty);
  });

  WorkspaceInviteResponse invite({
    required String email,
    required String role,
    String status = 'pending',
  }) {
    final now = DateTime.utc(2026, 1, 1);
    return WorkspaceInviteResponse(
      id: 'invite-1',
      workspaceId: 'workspace-1',
      email: email,
      token: 'token-1',
      role: role,
      invitedBy: 'user-owner',
      status: status,
      expiresAt: now.add(const Duration(days: 7)),
      acceptedBy: null,
      acceptedAt: null,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('filterWorkspaceInvites filters by email role and status', () {
    final rows = <WorkspaceInviteResponse>[
      invite(email: 'alpha@example.com', role: 'member', status: 'pending'),
      invite(email: 'bravo@example.com', role: 'admin', status: 'pending'),
      invite(email: 'charlie@example.com', role: 'member', status: 'accepted'),
    ];

    expect(filterWorkspaceInvites(rows, '').length, 3);
    expect(
      filterWorkspaceInvites(rows, 'bravo').single.email,
      'bravo@example.com',
    );
    expect(
      filterWorkspaceInvites(rows, 'ADMIN').single.email,
      'bravo@example.com',
    );
    expect(
      filterWorkspaceInvites(rows, 'accepted').single.email,
      'charlie@example.com',
    );
    expect(filterWorkspaceInvites(rows, 'unknown'), isEmpty);
  });

  test('formatWorkspaceInviteMeta contains status and expiry', () {
    final row = invite(
      email: 'meta@example.com',
      role: 'member',
      status: 'pending',
    );
    final text = formatWorkspaceInviteMeta(row);
    expect(text, contains('状态: 已过期'));
    expect(text, contains('过期:'));
    expect(text, contains('2026-01-08'));
  });

  test('sortWorkspaceInvitesByExpiry orders ascending by expiresAt', () {
    final rows = <WorkspaceInviteResponse>[
      invite(
        email: 'late@example.com',
        role: 'member',
      ).copyWithExpiresAt(DateTime.utc(2026, 1, 12)),
      invite(
        email: 'early@example.com',
        role: 'member',
      ).copyWithExpiresAt(DateTime.utc(2026, 1, 5)),
      invite(
        email: 'mid@example.com',
        role: 'member',
      ).copyWithExpiresAt(DateTime.utc(2026, 1, 8)),
    ];
    final sorted = sortWorkspaceInvitesByExpiry(rows);
    expect(sorted.map((e) => e.email).toList(), <String>[
      'early@example.com',
      'mid@example.com',
      'late@example.com',
    ]);
  });

  test('inviteStatusLabel marks pending invite as valid', () {
    final row = invite(
      email: 'valid@example.com',
      role: 'member',
      status: 'pending',
    ).copyWithExpiresAt(DateTime.utc(2099, 1, 1));
    expect(inviteStatusLabel(row), '有效');
  });

  test('inviteStatusLabel shows revoked and accepted', () {
    final revoked = invite(
      email: 'r@example.com',
      role: 'member',
      status: 'revoked',
    );
    expect(inviteStatusLabel(revoked), '已撤销');
    final accepted = invite(
      email: 'a@example.com',
      role: 'member',
      status: 'accepted',
    ).copyWithExpiresAt(DateTime.utc(2099, 1, 1));
    expect(inviteStatusLabel(accepted), '已接受');
  });

  test('filterInvitesByExpiryVisibility hides expired by default', () {
    final rows = <WorkspaceInviteResponse>[
      invite(
        email: 'expired@example.com',
        role: 'member',
      ).copyWithExpiresAt(DateTime.utc(2020, 1, 1)),
      invite(
        email: 'active@example.com',
        role: 'member',
      ).copyWithExpiresAt(DateTime.utc(2099, 1, 1)),
    ];
    final visible = filterInvitesByExpiryVisibility(
      rows,
      includeExpired: false,
    );
    expect(visible.map((e) => e.email).toList(), <String>[
      'active@example.com',
    ]);
    final all = filterInvitesByExpiryVisibility(rows, includeExpired: true);
    expect(all.length, 2);
  });

  test('extractWorkspaceInviteTokenFromQuery supports multiple query keys', () {
    expect(
      extractWorkspaceInviteTokenFromQuery(
        Uri.parse('https://example.com/?invite_token=abc123'),
      ),
      'abc123',
    );
    expect(
      extractWorkspaceInviteTokenFromQuery(
        Uri.parse('https://example.com/?inviteToken=xyz789'),
      ),
      'xyz789',
    );
    expect(
      extractWorkspaceInviteTokenFromQuery(
        Uri.parse('https://example.com/?token=tok456'),
      ),
      'tok456',
    );
    expect(
      extractWorkspaceInviteTokenFromQuery(
        Uri.parse('https://example.com/?invite_token='),
      ),
      isNull,
    );
  });

  test(
    'extractWorkspaceInviteTokenFromPath supports /join-workspace/:token',
    () {
      expect(
        extractWorkspaceInviteTokenFromPath(
          Uri.parse('https://example.com/join-workspace/abc123'),
        ),
        'abc123',
      );
      expect(
        extractWorkspaceInviteTokenFromPath(
          Uri.parse('https://example.com/join-workspace'),
        ),
        isNull,
      );
    },
  );

  test('removeWorkspaceInviteTokenFromUri strips invite token query keys', () {
    final cleaned = removeWorkspaceInviteTokenFromUri(
      Uri.parse(
        'https://example.com/path?invite_token=a&inviteToken=b&token=c&foo=bar',
      ),
    );
    expect(cleaned.queryParameters['foo'], 'bar');
    expect(cleaned.queryParameters.containsKey('invite_token'), isFalse);
    expect(cleaned.queryParameters.containsKey('inviteToken'), isFalse);
    expect(cleaned.queryParameters.containsKey('token'), isFalse);
  });

  test(
    'removeWorkspaceInviteTokenFromUri resets join-workspace path and keeps query',
    () {
      final cleaned = removeWorkspaceInviteTokenFromUri(
        Uri.parse('https://example.com/join-workspace/tok123?foo=bar'),
      );
      expect(cleaned.path, '/');
      expect(cleaned.queryParameters['foo'], 'bar');
    },
  );

  test(
    'resolveWorkspaceInvitePrefill prefers explicit token over uri token',
    () {
      final prefill = resolveWorkspaceInvitePrefill(
        initialInviteToken: 'manual-token',
        uriBase: Uri.parse('https://example.com/?invite_token=abc123'),
      );
      expect(prefill.token, 'manual-token');
      expect(prefill.tokenFromUri, isFalse);
      expect(prefill.shouldAutoOpenTeamWorkspace, isFalse);
    },
  );

  test('resolveWorkspaceInvitePrefill falls back to deep-link path token', () {
    final prefill = resolveWorkspaceInvitePrefill(
      initialInviteToken: '   ',
      uriBase: Uri.parse('https://example.com/join-workspace/path-token'),
    );
    expect(prefill.token, 'path-token');
    expect(prefill.tokenFromUri, isTrue);
    expect(prefill.shouldAutoOpenTeamWorkspace, isTrue);
  });

  test('resolveWorkspaceInvitePrefill falls back to uri query token', () {
    final prefill = resolveWorkspaceInvitePrefill(
      initialInviteToken: '   ',
      uriBase: Uri.parse('https://example.com/?inviteToken=xyz789'),
    );
    expect(prefill.token, 'xyz789');
    expect(prefill.tokenFromUri, isTrue);
    expect(prefill.shouldAutoOpenTeamWorkspace, isTrue);
  });

  test(
    'shouldShowInviteTokenHint requires uri autofill and non-empty token',
    () {
      expect(
        shouldShowInviteTokenHint(
          tokenAutoFilledFromUri: true,
          tokenText: 'abc',
        ),
        isTrue,
      );
      expect(
        shouldShowInviteTokenHint(
          tokenAutoFilledFromUri: true,
          tokenText: '   ',
        ),
        isFalse,
      );
      expect(
        shouldShowInviteTokenHint(
          tokenAutoFilledFromUri: false,
          tokenText: 'abc',
        ),
        isFalse,
      );
    },
  );

  test('buildInviteCopyText includes key fields', () {
    final row = invite(
      email: 'copy@example.com',
      role: 'admin',
      status: 'pending',
    ).copyWithExpiresAt(DateTime.utc(2026, 2, 1));
    final text = buildInviteCopyText(row);
    expect(text, contains('workspace=workspace-1'));
    expect(text, contains('email=copy@example.com'));
    expect(text, contains('role=admin'));
    expect(text, contains('status=pending'));
    expect(text, contains('expires_at=2026-02-01T00:00:00.000Z'));
    expect(text, contains('token=token-1'));
  });

  test('hasActiveEnterpriseWorkspace requires unarchived enterprise item', () {
    final now = DateTime.utc(2026, 1, 1);
    WorkspaceListItem row({
      required String workspaceType,
      DateTime? archivedAt,
    }) {
      return WorkspaceListItem(
        workspace: WorkspaceResponse(
          id: '$workspaceType-${archivedAt == null ? 'active' : 'archived'}',
          ownerUserId: 'user-owner',
          name: workspaceType,
          workspaceType: workspaceType,
          metadata: const <String, dynamic>{},
          archivedAt: archivedAt,
          createdAt: now,
          updatedAt: now,
        ),
        role: 'owner',
      );
    }

    expect(
      hasActiveEnterpriseWorkspace(<WorkspaceListItem>[
        row(workspaceType: 'personal'),
      ]),
      isFalse,
    );
    expect(
      hasActiveEnterpriseWorkspace(<WorkspaceListItem>[
        row(workspaceType: 'enterprise', archivedAt: now),
      ]),
      isFalse,
    );
    expect(
      hasActiveEnterpriseWorkspace(<WorkspaceListItem>[
        row(workspaceType: 'personal'),
        row(workspaceType: 'enterprise'),
      ]),
      isTrue,
    );
  });

  test('isCurrentWorkspaceRow matches current workspace id', () {
    final now = DateTime.utc(2026, 1, 1);
    final row = WorkspaceListItem(
      workspace: WorkspaceResponse(
        id: 'workspace-1',
        ownerUserId: 'user-owner',
        name: 'Team Alpha',
        workspaceType: 'enterprise',
        metadata: const <String, dynamic>{},
        archivedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
      role: 'owner',
    );

    expect(isCurrentWorkspaceRow(row, 'workspace-1'), isTrue);
    expect(isCurrentWorkspaceRow(row, 'workspace-2'), isFalse);
    expect(isCurrentWorkspaceRow(row, '   '), isFalse);
  });

  test('buildWorkspaceRowSemanticsLabel describes current archived state', () {
    final now = DateTime.utc(2026, 1, 1);
    final row = WorkspaceListItem(
      workspace: WorkspaceResponse(
        id: 'workspace-1',
        ownerUserId: 'user-owner',
        name: 'Team Alpha',
        workspaceType: 'enterprise',
        metadata: const <String, dynamic>{},
        archivedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      role: 'admin',
    );

    expect(
      buildWorkspaceRowSemanticsLabel(row, isCurrent: true),
      'Team Alpha，enterprise 空间，你的角色是 admin，已归档，当前工作区',
    );
    expect(
      buildWorkspaceRowSemanticsLabel(row, isCurrent: false),
      'Team Alpha，enterprise 空间，你的角色是 admin，已归档',
    );
  });

  test('buildWorkspaceActionTooltip includes workspace name', () {
    expect(
      buildWorkspaceActionTooltip(
        actionLabel: '管理邀请',
        workspaceName: 'Team Alpha',
      ),
      '管理邀请 Team Alpha',
    );
  });

  test(
    'buildEnterpriseProjectsEmptyStateBody falls back when name missing',
    () {
      final zh = AppLocalizationsZh();
      expect(
        buildEnterpriseProjectsEmptyStateBody(zh, 'Team Alpha'),
        contains('Team Alpha 还没有任何项目'),
      );
      expect(
        buildEnterpriseProjectsEmptyStateBody(zh, '   '),
        contains(zh.projectsEnterpriseEmptyUnnamedFallback),
      );
      expect(
        buildEnterpriseProjectsEmptyStateBody(zh, '   '),
        contains('还没有任何项目'),
      );
    },
  );

  test('paginateWorkspaceInvites returns current page slice', () {
    final rows = <WorkspaceInviteResponse>[
      invite(email: 'a@example.com', role: 'member'),
      invite(email: 'b@example.com', role: 'member').copyWithId('invite-2'),
      invite(email: 'c@example.com', role: 'member').copyWithId('invite-3'),
    ];

    expect(
      paginateWorkspaceInvites(
        rows,
        pageIndex: 0,
        pageSize: 2,
      ).map((e) => e.email).toList(),
      <String>['a@example.com', 'b@example.com'],
    );
    expect(
      paginateWorkspaceInvites(
        rows,
        pageIndex: 1,
        pageSize: 2,
      ).map((e) => e.email).toList(),
      <String>['c@example.com'],
    );
    expect(paginateWorkspaceInvites(rows, pageIndex: 2, pageSize: 2), isEmpty);
  });

  test('workspaceInvitePageCount rounds up by page size', () {
    final rows = <WorkspaceInviteResponse>[
      invite(email: 'a@example.com', role: 'member'),
      invite(email: 'b@example.com', role: 'member').copyWithId('invite-2'),
      invite(email: 'c@example.com', role: 'member').copyWithId('invite-3'),
    ];
    expect(workspaceInvitePageCount(rows, pageSize: 2), 2);
    expect(workspaceInvitePageCount(rows, pageSize: 10), 1);
    expect(
      workspaceInvitePageCount(const <WorkspaceInviteResponse>[], pageSize: 10),
      0,
    );
  });
}

extension on WorkspaceInviteResponse {
  WorkspaceInviteResponse copyWithExpiresAt(DateTime expiresAt) {
    return WorkspaceInviteResponse(
      id: id,
      workspaceId: workspaceId,
      email: email,
      token: token,
      role: role,
      invitedBy: invitedBy,
      status: status,
      expiresAt: expiresAt,
      acceptedBy: acceptedBy,
      acceptedAt: acceptedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  WorkspaceInviteResponse copyWithId(String id) {
    return WorkspaceInviteResponse(
      id: id,
      workspaceId: workspaceId,
      email: email,
      token: token,
      role: role,
      invitedBy: invitedBy,
      status: status,
      expiresAt: expiresAt,
      acceptedBy: acceptedBy,
      acceptedAt: acceptedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
