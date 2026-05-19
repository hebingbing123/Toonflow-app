import 'package:flutter_test/flutter_test.dart';
import 'package:openflow_app/native_bridge/native_bridge_bootstrap_platform_io.dart';

void main() {
  test('macOS candidate paths include app Frameworks and workspace targets', () {
    final candidates = computeNativeBridgeCandidateLibraryPaths(
      operatingSystem: 'macos',
      resolvedExecutablePath:
          '/repo/frontend/build/macos/Build/Products/Debug/openflow_app.app/Contents/MacOS/openflow_app',
      currentDirectoryPath: '/repo/frontend',
      overrideNativeLibDir: '',
    );

    expect(
      candidates,
      contains(
        '/repo/frontend/build/macos/Build/Products/Debug/openflow_app.app/Contents/Frameworks/libopenflow_core_bridge.dylib',
      ),
    );
    expect(
      candidates,
      contains('../rust_core/target/debug/libopenflow_core_bridge.dylib'),
    );
    expect(
      candidates,
      contains('rust_core/target/debug/libopenflow_core_bridge.dylib'),
    );
  });

  test('linux candidate paths include bundle lib directory and override path', () {
    final candidates = computeNativeBridgeCandidateLibraryPaths(
      operatingSystem: 'linux',
      resolvedExecutablePath: '/tmp/openflow_app',
      currentDirectoryPath: '/repo/frontend',
      overrideNativeLibDir: '/custom/lib',
    );

    expect(candidates, contains('/tmp/lib/libopenflow_core_bridge.so'));
    expect(candidates, contains('/custom/lib/libopenflow_core_bridge.so'));
  });

  test('windows candidate paths use backslashes', () {
    final candidates = computeNativeBridgeCandidateLibraryPaths(
      operatingSystem: 'windows',
      resolvedExecutablePath: r'C:\repo\frontend\build\windows\x64\runner\Debug\openflow_app.exe',
      currentDirectoryPath: r'C:\repo\frontend',
      overrideNativeLibDir: r'D:\native',
    );

    expect(
      candidates,
      contains(
        r'C:\repo\frontend\build\windows\x64\runner\Debug\openflow_core_bridge.dll',
      ),
    );
    expect(candidates, contains(r'D:\native\openflow_core_bridge.dll'));
    expect(
      candidates,
      contains(r'..\rust_core\target\debug\openflow_core_bridge.dll'),
    );
  });
}
