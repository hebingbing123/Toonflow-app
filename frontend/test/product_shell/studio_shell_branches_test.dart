import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/product_shell/studio_shell_branches.dart';
import 'package:openflow_app/shell/navigation_controller.dart';

void main() {
  test('studioPaneFromUri parses query-synced panes', () {
    expect(
      studioPaneFromUri(Uri.parse('https://example.com/?pane=notifications')),
      ProductWorkspacePane.notifications,
    );
    expect(
      studioPaneFromUri(Uri.parse('https://example.com/?pane=settings')),
      ProductWorkspacePane.account,
    );
    expect(
      studioPaneFromUri(Uri.parse('https://example.com/?pane=shortVideo')),
      ProductWorkspacePane.shortVideoSpace,
    );
    expect(
      studioPaneFromUri(Uri.parse('https://example.com/?pane=quality')),
      ProductWorkspacePane.quality,
    );
  });

  test('studioPaneFromUri parses legacy utility paths and defaults home', () {
    expect(
      studioPaneFromUri(Uri.parse('https://example.com/notifications')),
      ProductWorkspacePane.notifications,
    );
    expect(
      studioPaneFromUri(Uri.parse('https://example.com/settings')),
      ProductWorkspacePane.account,
    );
    expect(
      studioPaneFromUri(Uri.parse('https://example.com/help')),
      ProductWorkspacePane.helpHub,
    );
    expect(
      studioPaneFromUri(Uri.parse('https://example.com/unknown')),
      ProductWorkspacePane.projects,
    );
  });

  test('studioUriForUtilityPane returns canonical shell locations', () {
    expect(studioUriForUtilityPane(ProductWorkspacePane.projects), '/');
    expect(
      studioUriForUtilityPane(ProductWorkspacePane.notifications),
      '/?pane=notifications',
    );
    expect(
      studioUriForUtilityPane(ProductWorkspacePane.account),
      '/?pane=settings',
    );
    expect(
      studioUriForUtilityPane(ProductWorkspacePane.helpHub),
      '/?pane=help',
    );
    expect(studioUriForUtilityPane(ProductWorkspacePane.tasks), '/?pane=tasks');
  });

  test(
    'studioUriIsShellHome accepts shell aliases and rejects studio flows',
    () {
      expect(studioUriIsShellHome(Uri.parse('https://example.com/')), isTrue);
      expect(
        studioUriIsShellHome(Uri.parse('https://example.com/notifications')),
        isTrue,
      );
      expect(
        studioUriIsShellHome(Uri.parse('https://example.com/settings')),
        isTrue,
      );
      expect(
        studioUriIsShellHome(Uri.parse('https://example.com/help')),
        isTrue,
      );
      expect(
        studioUriIsShellHome(
          Uri.parse('https://example.com/projects/42/script'),
        ),
        isFalse,
      );
    },
  );
}
