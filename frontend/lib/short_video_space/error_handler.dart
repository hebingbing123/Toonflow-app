import 'dart:async';

import 'package:flutter/material.dart';

import '../rust_api/core.dart';

/// 错误严重程度
enum ErrorSeverity {
  /// 信息提示（不影响操作）
  info,

  /// 警告（操作可能受影响）
  warning,

  /// 错误（操作失败）
  error,

  /// 致命错误（需要用户干预）
  critical,
}

/// 错误处理结果
class ErrorHandlingResult {
  const ErrorHandlingResult({
    required this.shouldRetry,
    required this.userMessage,
    this.retryDelayMs,
    this.severity = ErrorSeverity.error,
  });

  /// 是否应该重试
  final bool shouldRetry;

  /// 显示给用户的消息
  final String userMessage;

  /// 重试延迟（毫秒）
  final int? retryDelayMs;

  /// 错误严重程度
  final ErrorSeverity severity;
}

/// 前端错误处理器
///
/// 提供统一的错误处理、用户友好的错误消息和自动重试逻辑
class ShortVideoErrorHandler {
  /// 处理 API 错误并返回处理结果
  static ErrorHandlingResult handleApiError(
    Object error, {
    String? context,
  }) {
    if (error is RustApiException) {
      return _handleRustApiException(error, context: context);
    }

    if (error is TimeoutException) {
      return ErrorHandlingResult(
        shouldRetry: true,
        userMessage: '请求超时${context != null ? '（$context）' : ''}，请检查网络连接后重试。',
        retryDelayMs: 2000,
        severity: ErrorSeverity.warning,
      );
    }

    // 通用错误
    return ErrorHandlingResult(
      shouldRetry: false,
      userMessage: '操作失败${context != null ? '（$context）' : ''}：${error.toString()}',
      severity: ErrorSeverity.error,
    );
  }

  /// 处理 RustApiException
  static ErrorHandlingResult _handleRustApiException(
    RustApiException error, {
    String? context,
  }) {
    final statusCode = error.statusCode;
    final details = RustApiErrorDetails.tryParse(error.message);

    // 429 频率限制
    if (statusCode == 429 || details?.code == 'quota_exceeded') {
      final waitMs = details?.retryAfterMs ?? error.retryAfterMsHint ?? 5000;
      final waitText = formatRetryAfterMs(waitMs);
      return ErrorHandlingResult(
        shouldRetry: true,
        userMessage: '请求过于频繁${context != null ? '（$context）' : ''}，$waitText。',
        retryDelayMs: waitMs,
        severity: ErrorSeverity.warning,
      );
    }

    // 404 未找到
    if (statusCode == 404) {
      return ErrorHandlingResult(
        shouldRetry: false,
        userMessage: '未找到对应记录${context != null ? '（$context）' : ''}。',
        severity: ErrorSeverity.error,
      );
    }

    // 401/403 权限问题
    if (statusCode == 401 || statusCode == 403) {
      return ErrorHandlingResult(
        shouldRetry: false,
        userMessage: '权限不足${context != null ? '（$context）' : ''}，请检查登录状态。',
        severity: ErrorSeverity.critical,
      );
    }

    // 400 请求参数错误
    if (statusCode == 400) {
      final message = details?.message ?? '请求参数错误';
      return ErrorHandlingResult(
        shouldRetry: false,
        userMessage: '$message${context != null ? '（$context）' : ''}',
        severity: ErrorSeverity.error,
      );
    }

    // 500+ 服务器错误
    if (statusCode != null && statusCode >= 500) {
      return ErrorHandlingResult(
        shouldRetry: true,
        userMessage: '服务器错误${context != null ? '（$context）' : ''}，请稍后重试。',
        retryDelayMs: 3000,
        severity: ErrorSeverity.error,
      );
    }

    // 使用详细错误信息（如果有）
    if (details != null) {
      return ErrorHandlingResult(
        shouldRetry: false,
        userMessage: '${details.message}${context != null ? '（$context）' : ''}',
        severity: ErrorSeverity.error,
      );
    }

    // 默认错误处理
    return ErrorHandlingResult(
      shouldRetry: false,
      userMessage: '操作失败${context != null ? '（$context）' : ''}：${formatRustApiException(error)}',
      severity: ErrorSeverity.error,
    );
  }

  /// 显示错误消息给用户
  static void showErrorMessage(
    BuildContext context,
    ErrorHandlingResult result, {
    VoidCallback? onRetry,
  }) {
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final snackBar = SnackBar(
      content: Text(result.userMessage),
      backgroundColor: _getBackgroundColor(result.severity),
      duration: _getDuration(result.severity),
      action: result.shouldRetry && onRetry != null
          ? SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: onRetry,
            )
          : null,
    );

    messenger.showSnackBar(snackBar);
  }

  /// 根据严重程度获取背景颜色
  static Color _getBackgroundColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Colors.blue;
      case ErrorSeverity.warning:
        return Colors.orange;
      case ErrorSeverity.error:
        return Colors.red;
      case ErrorSeverity.critical:
        return Colors.red.shade900;
    }
  }

  /// 根据严重程度获取显示时长
  static Duration _getDuration(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return const Duration(seconds: 2);
      case ErrorSeverity.warning:
        return const Duration(seconds: 4);
      case ErrorSeverity.error:
        return const Duration(seconds: 6);
      case ErrorSeverity.critical:
        return const Duration(seconds: 10);
    }
  }

  /// 执行带错误处理的 API 调用
  ///
  /// [operation] - 要执行的异步操作
  /// [context] - 操作上下文描述（用于错误消息）
  /// [maxRetries] - 最大重试次数（默认 2 次）
  /// [onError] - 错误回调（可选）
  /// [showErrorToUser] - 是否向用户显示错误（默认 true）
  ///
  /// 返回操作结果，如果失败则返回 null
  static Future<T?> executeWithErrorHandling<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? operationContext,
    int maxRetries = 2,
    void Function(ErrorHandlingResult)? onError,
    bool showErrorToUser = true,
  }) async {
    int attemptCount = 0;

    while (attemptCount <= maxRetries) {
      try {
        return await operation();
      } catch (error) {
        attemptCount++;

        final result = handleApiError(
          error,
          context: operationContext,
        );

        // 调用错误回调
        onError?.call(result);

        // 如果不应该重试或已达到最大重试次数
        if (!result.shouldRetry || attemptCount > maxRetries) {
          if (showErrorToUser && context.mounted) {
            showErrorMessage(context, result);
          }
          return null;
        }

        // 等待后重试
        if (result.retryDelayMs != null && result.retryDelayMs! > 0) {
          await Future.delayed(Duration(milliseconds: result.retryDelayMs!));
        }

        // 如果是最后一次重试失败，显示错误
        if (attemptCount == maxRetries && showErrorToUser && context.mounted) {
          showErrorMessage(context, result);
        }
      }
    }

    return null;
  }

  /// 执行带进度显示的批量操作
  ///
  /// [operations] - 要执行的操作列表
  /// [context] - Flutter 上下文
  /// [operationName] - 操作名称（用于进度显示）
  /// [onProgress] - 进度回调 (completed, total, failed)
  /// [maxConcurrent] - 最大并发数（默认 5）
  ///
  /// 返回 (成功数, 失败数, 失败详情列表)
  static Future<(int, int, List<String>)> executeBatchWithErrorHandling<T>({
    required List<Future<T> Function()> operations,
    required BuildContext context,
    required String operationName,
    void Function(int completed, int total, int failed)? onProgress,
    int maxConcurrent = 5,
  }) async {
    int completed = 0;
    int failed = 0;
    final List<String> failureDetails = [];
    final total = operations.length;

    // 分批执行
    for (int i = 0; i < operations.length; i += maxConcurrent) {
      final batch = operations.skip(i).take(maxConcurrent).toList();
      final results = await Future.wait(
        batch.map((op) async {
          try {
            await op();
            return (true, null);
          } catch (error) {
            final result = handleApiError(error, context: operationName);
            return (false, result.userMessage);
          }
        }),
      );

      for (final (success, errorMsg) in results) {
        completed++;
        if (success) {
          // 成功
        } else {
          failed++;
          if (errorMsg != null) {
            failureDetails.add(errorMsg);
          }
        }
      }

      // 更新进度
      onProgress?.call(completed, total, failed);
    }

    return (completed - failed, failed, failureDetails);
  }
}

/// 错误恢复策略
class ErrorRecoveryStrategy {
  const ErrorRecoveryStrategy({
    required this.canRecover,
    required this.recoveryAction,
    required this.recoveryDescription,
  });

  /// 是否可以恢复
  final bool canRecover;

  /// 恢复操作
  final VoidCallback? recoveryAction;

  /// 恢复描述
  final String recoveryDescription;

  /// 创建一个不可恢复的策略
  static ErrorRecoveryStrategy unrecoverable(String reason) {
    return ErrorRecoveryStrategy(
      canRecover: false,
      recoveryAction: null,
      recoveryDescription: reason,
    );
  }

  /// 创建一个可恢复的策略
  static ErrorRecoveryStrategy recoverable({
    required VoidCallback action,
    required String description,
  }) {
    return ErrorRecoveryStrategy(
      canRecover: true,
      recoveryAction: action,
      recoveryDescription: description,
    );
  }
}

/// 错误日志记录器（用于调试和监控）
class ErrorLogger {
  static final List<ErrorLogEntry> _logs = [];
  static const int _maxLogs = 100;

  /// 记录错误
  static void logError({
    required Object error,
    required StackTrace stackTrace,
    String? context,
    Map<String, dynamic>? metadata,
  }) {
    final entry = ErrorLogEntry(
      timestamp: DateTime.now(),
      error: error,
      stackTrace: stackTrace,
      context: context,
      metadata: metadata,
    );

    _logs.add(entry);

    // 保持日志数量在限制内
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    // 在调试模式下打印到控制台
    debugPrint('ERROR [${entry.timestamp}] ${entry.context ?? 'Unknown'}: $error');
  }

  /// 获取所有错误日志
  static List<ErrorLogEntry> getLogs() => List.unmodifiable(_logs);

  /// 清除所有日志
  static void clearLogs() => _logs.clear();

  /// 获取最近的错误
  static ErrorLogEntry? getLastError() => _logs.isEmpty ? null : _logs.last;
}

/// 错误日志条目
class ErrorLogEntry {
  const ErrorLogEntry({
    required this.timestamp,
    required this.error,
    required this.stackTrace,
    this.context,
    this.metadata,
  });

  final DateTime timestamp;
  final Object error;
  final StackTrace stackTrace;
  final String? context;
  final Map<String, dynamic>? metadata;

  @override
  String toString() {
    return 'ErrorLogEntry(timestamp: $timestamp, context: $context, error: $error)';
  }
}
