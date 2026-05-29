import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/l10n/app_localizations.dart';
import 'package:openflow_app/native_bridge/native_bridge_bootstrap.dart';
import 'package:openflow_app/short_video_space/desktop_capability.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  test('desktop runtime descriptor marks desktop app as bridge-capable', () {
    final runtime = resolveDesktopRuntimeDescriptor(
      l10n: en,
      isWeb: false,
      platform: TargetPlatform.macOS,
    );

    expect(runtime.kind, DesktopRuntimeKind.desktopApp);
    expect(runtime.supportsDesktopBridge, isTrue);
    expect(runtime.showDownloadCallToAction, isFalse);
  });

  test('web runtime descriptor promotes desktop download', () {
    final runtime = resolveDesktopRuntimeDescriptor(
      l10n: en,
      isWeb: true,
      platform: TargetPlatform.windows,
    );

    expect(runtime.kind, DesktopRuntimeKind.webBrowser);
    expect(runtime.supportsDesktopBridge, isFalse);
    expect(runtime.showDownloadCallToAction, isTrue);
  });

  test('mobile browser descriptor promotes desktop workflow', () {
    final runtime = resolveDesktopRuntimeDescriptor(
      l10n: en,
      isWeb: true,
      platform: TargetPlatform.iOS,
    );

    expect(runtime.kind, DesktopRuntimeKind.mobileBrowser);
    expect(runtime.supportsDesktopBridge, isFalse);
    expect(runtime.showDownloadCallToAction, isTrue);
  });

  test('local assembly actions require ready desktop bridge', () {
    final runtime = resolveDesktopRuntimeDescriptor(
      l10n: en,
      isWeb: false,
      platform: TargetPlatform.macOS,
    );

    expect(
      canUseLocalAssemblyActions(
        runtime: runtime,
        snapshot: const NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.idle,
        ),
      ),
      isFalse,
    );
    expect(
      canUseLocalAssemblyActions(
        runtime: runtime,
        snapshot: const NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.ready,
        ),
      ),
      isTrue,
    );
  });

  test('blocked hint prefers runtime detail for web and bridge message for desktop failures', () {
    final webRuntime = resolveDesktopRuntimeDescriptor(
      l10n: en,
      isWeb: true,
      platform: TargetPlatform.windows,
    );
    final desktopRuntime = resolveDesktopRuntimeDescriptor(
      l10n: en,
      isWeb: false,
      platform: TargetPlatform.macOS,
    );

    expect(
      resolveLocalAssemblyBlockedHint(
        l10n: en,
        runtime: webRuntime,
        snapshot: const NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.skipped,
        ),
      ),
      webRuntime.detail,
    );
    expect(
      resolveLocalAssemblyBlockedHint(
        l10n: en,
        runtime: desktopRuntime,
        snapshot: const NativeBridgeStartupSnapshot(
          state: NativeBridgeStartupState.failed,
        ),
      ),
      en.nativeBridgeMessageInitFailed,
    );
  });
}
