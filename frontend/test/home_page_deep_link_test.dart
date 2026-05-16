import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/home_page.dart';

void main() {
  test('team workspace deep-link path auto-opens team workspace pane', () {
    expect(
      shouldAutoOpenTeamWorkspacesForInitialUri(
        Uri.parse('https://example.com/join-workspace/invite-token'),
      ),
      isTrue,
    );
  });

  test('invite token query auto-opens team workspace pane', () {
    expect(
      shouldAutoOpenTeamWorkspacesForInitialUri(
        Uri.parse('https://example.com/?invite_token=invite-token'),
      ),
      isTrue,
    );
    expect(
      shouldAutoOpenTeamWorkspacesForInitialUri(
        Uri.parse('https://example.com/?inviteToken=invite-token'),
      ),
      isTrue,
    );
    expect(
      shouldAutoOpenTeamWorkspacesForInitialUri(
        Uri.parse('https://example.com/?token=invite-token'),
      ),
      isTrue,
    );
  });

  test('regular routes do not auto-open team workspace pane', () {
    expect(
      shouldAutoOpenTeamWorkspacesForInitialUri(
        Uri.parse('https://example.com/projects/123'),
      ),
      isFalse,
    );
  });

  test('bare join-workspace route still opens team workspace pane', () {
    expect(
      shouldAutoOpenTeamWorkspacesForInitialUri(
        Uri.parse('https://example.com/join-workspace'),
      ),
      isTrue,
    );
  });
}
