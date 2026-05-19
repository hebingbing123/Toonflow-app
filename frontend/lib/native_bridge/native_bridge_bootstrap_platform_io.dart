import 'dart:io';

import 'package:flutter/foundation.dart';

import '../config.dart';
import 'native_bridge_bootstrap_platform.dart';

NativeBridgePlatformSupport createNativeBridgePlatformSupport() {
  return const _IoNativeBridgePlatformSupport();
}

class _IoNativeBridgePlatformSupport extends NativeBridgePlatformSupport {
  const _IoNativeBridgePlatformSupport();

  @override
  bool get supportsExplicitLibraryLoading => true;

  @override
  List<String> candidateLibraryPaths() {
    return computeNativeBridgeCandidateLibraryPaths(
      operatingSystem: Platform.operatingSystem,
      resolvedExecutablePath: Platform.resolvedExecutable,
      currentDirectoryPath: Directory.current.path,
      overrideNativeLibDir: kOpenflowNativeLibDir,
    );
  }
}

@visibleForTesting
List<String> computeNativeBridgeCandidateLibraryPaths({
  required String operatingSystem,
  required String resolvedExecutablePath,
  required String currentDirectoryPath,
  required String overrideNativeLibDir,
}) {
  final fileName = switch (operatingSystem) {
    'macos' => 'libopenflow_core_bridge.dylib',
    'linux' => 'libopenflow_core_bridge.so',
    'windows' => 'openflow_core_bridge.dll',
    _ => '',
  };
  if (fileName.isEmpty) {
    return const <String>[];
  }

  final executableDirPath = _dirname(resolvedExecutablePath, operatingSystem);
  final frameworkDirectory = _joinPath(
    _dirname(executableDirPath, operatingSystem),
    'Frameworks',
  );

  final directories = <String>[
    executableDirPath,
    if (operatingSystem == 'linux') _joinPath(executableDirPath, 'lib'),
    if (operatingSystem == 'macos') frameworkDirectory,
    currentDirectoryPath,
    if (overrideNativeLibDir.isNotEmpty) overrideNativeLibDir,
    '../rust_core/target/debug',
    '../rust_core/target/release',
    'rust_core/target/debug',
    'rust_core/target/release',
  ];

  final seen = <String>{};
  final candidates = <String>[];
  for (final directory in directories) {
    final trimmed = _normalizeDirectoryPath(directory.trim(), operatingSystem);
    if (trimmed.isEmpty) {
      continue;
    }
    final path = _joinPath(trimmed, fileName);
    if (seen.add(path)) {
      candidates.add(path);
    }
  }
  return candidates;
}

String _joinPath(String directory, String fileName) {
  final separator = _pathSeparatorFor(directory);
  final normalized = directory.endsWith(separator)
      ? directory.substring(0, directory.length - 1)
      : directory;
  return '$normalized$separator$fileName';
}

String _normalizeDirectoryPath(String directory, String operatingSystem) {
  if (directory.isEmpty) {
    return directory;
  }
  if (operatingSystem == 'windows') {
    return directory.replaceAll('/', r'\');
  }
  return directory.replaceAll(r'\', '/');
}

String _dirname(String path, String operatingSystem) {
  final separator = operatingSystem == 'windows' ? r'\' : '/';
  final normalized = path.endsWith(separator)
      ? path.substring(0, path.length - 1)
      : path;
  final index = normalized.lastIndexOf(separator);
  if (index <= 0) {
    return index == 0 ? separator : '.';
  }
  return normalized.substring(0, index);
}

String _pathSeparatorFor(String path) {
  return path.contains(r'\') ? r'\' : '/';
}
