import 'dart:io';

const _agentDebugLogPath =
    '/Users/clive/Documents/source/cousor/Toonflow-app/.cursor/debug-2b69d7.log';

Future<void> appendAgentDebugLogLine(String line) async {
  try {
    await File(_agentDebugLogPath).writeAsString(
      '$line\n',
      mode: FileMode.append,
      flush: true,
    );
  } catch (_) {
    // Ignore log file failures.
  }
}
