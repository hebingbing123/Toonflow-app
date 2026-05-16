/// 应用日志工具类
///
/// 提供统一的日志记录接口，用于跟踪用户操作和错误。
/// 支持不同级别的日志记录（debug, info, warning, error）。
library;

import 'package:logger/logger.dart';

/// 全局日志实例
final AppLogger appLogger = AppLogger._();

/// 应用日志类
class AppLogger {
  late final Logger _logger;

  AppLogger._() {
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      level: _getLogLevel(),
    );
  }

  /// 根据环境变量获取日志级别
  Level _getLogLevel() {
    const env = String.fromEnvironment('LOG_LEVEL', defaultValue: 'info');
    switch (env.toLowerCase()) {
      case 'trace':
        return Level.trace;
      case 'debug':
        return Level.debug;
      case 'info':
        return Level.info;
      case 'warning':
        return Level.warning;
      case 'error':
        return Level.error;
      case 'fatal':
        return Level.fatal;
      default:
        return Level.info;
    }
  }

  /// 记录调试信息
  void debug(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  /// 记录一般信息
  void info(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  /// 记录警告信息
  void warning(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  /// 记录错误信息
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// 记录致命错误
  void fatal(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  /// 记录用户操作
  void logUserAction(String action, {Map<String, dynamic>? metadata}) {
    final message = 'User Action: $action';
    if (metadata != null && metadata.isNotEmpty) {
      _logger.i('$message | Metadata: $metadata');
    } else {
      _logger.i(message);
    }
  }

  /// 记录 API 调用
  void logApiCall(String endpoint, String method, {int? statusCode, Duration? duration}) {
    final parts = <String>[
      'API Call: $method $endpoint',
      if (statusCode != null) 'Status: $statusCode',
      if (duration != null) 'Duration: ${duration.inMilliseconds}ms',
    ];
    _logger.i(parts.join(' | '));
  }

  /// 记录性能指标
  void logPerformance(String operation, Duration duration, {Map<String, dynamic>? metadata}) {
    final message = 'Performance: $operation took ${duration.inMilliseconds}ms';
    if (metadata != null && metadata.isNotEmpty) {
      _logger.i('$message | Metadata: $metadata');
    } else {
      _logger.i(message);
    }
  }
}
