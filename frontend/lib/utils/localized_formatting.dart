import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';

/// Utility class for localized date, time, and number formatting
/// Implements task I2.10: 日期、时间、数字格式按目标语言本地化
class LocalizedFormatting {
  /// Get the appropriate locale for formatting based on the current app locale
  static Locale _getFormattingLocale(BuildContext context) {
    final appLocalizations = AppLocalizations.of(context);
    if (appLocalizations == null) {
      return const Locale('en');
    }
    
    // Use the locale from AppLocalizations
    final locale = Localizations.localeOf(context);
    return locale;
  }

  /// Format a DateTime as a localized date string
  /// Chinese: 2024年1月15日
  /// English: January 15, 2024
  static String formatDate(BuildContext context, DateTime dateTime) {
    final locale = _getFormattingLocale(context);
    final formatter = DateFormat.yMMMMd(locale.toString());
    return formatter.format(dateTime);
  }

  /// Format a DateTime as a localized short date string
  /// Chinese: 2024/1/15
  /// English: 1/15/2024
  static String formatShortDate(BuildContext context, DateTime dateTime) {
    final locale = _getFormattingLocale(context);
    final formatter = DateFormat.yMd(locale.toString());
    return formatter.format(dateTime);
  }

  /// Format a DateTime as a localized time string
  /// Chinese: 14:30
  /// English: 2:30 PM
  static String formatTime(BuildContext context, DateTime dateTime) {
    final locale = _getFormattingLocale(context);
    final formatter = DateFormat.Hm(locale.toString());
    return formatter.format(dateTime);
  }

  /// Format a DateTime as a localized date and time string
  /// Chinese: 2024年1月15日 14:30
  /// English: January 15, 2024 at 2:30 PM
  static String formatDateTime(BuildContext context, DateTime dateTime) {
    final locale = _getFormattingLocale(context);
    final formatter = DateFormat.yMMMMd(locale.toString()).add_Hm();
    return formatter.format(dateTime);
  }

  /// Format a DateTime as a localized short date and time string
  /// Chinese: 2024/1/15 14:30
  /// English: 1/15/2024, 2:30 PM
  static String formatShortDateTime(BuildContext context, DateTime dateTime) {
    final locale = _getFormattingLocale(context);
    final formatter = DateFormat.yMd(locale.toString()).add_Hm();
    return formatter.format(dateTime);
  }

  /// Format a number with localized decimal separators
  /// Chinese: 1,234.56
  /// English: 1,234.56
  static String formatNumber(BuildContext context, num number) {
    final locale = _getFormattingLocale(context);
    final formatter = NumberFormat.decimalPattern(locale.toString());
    return formatter.format(number);
  }

  /// Format a number as currency (without currency symbol)
  /// Chinese: 1,234.56
  /// English: 1,234.56
  static String formatCurrency(BuildContext context, num amount) {
    final locale = _getFormattingLocale(context);
    final formatter = NumberFormat.currency(
      locale: locale.toString(),
      symbol: '', // No currency symbol
      decimalDigits: 2,
    );
    return formatter.format(amount).trim();
  }

  /// Format a number as a percentage
  /// Chinese: 85%
  /// English: 85%
  static String formatPercentage(BuildContext context, double ratio) {
    final locale = _getFormattingLocale(context);
    final formatter = NumberFormat.percentPattern(locale.toString());
    return formatter.format(ratio);
  }

  /// Format a number with a specific number of decimal places
  static String formatDecimal(BuildContext context, num number, int decimalPlaces) {
    final locale = _getFormattingLocale(context);
    final formatter = NumberFormat.decimalPattern(locale.toString());
    formatter.minimumFractionDigits = decimalPlaces;
    formatter.maximumFractionDigits = decimalPlaces;
    return formatter.format(number);
  }

  /// Format a relative time (e.g., "2 hours ago", "刚刚")
  /// This uses the existing ARB keys for consistency
  static String formatRelativeTime(BuildContext context, DateTime dateTime) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return l10n.globalSearchTimeJustNow;
    } else if (difference.inHours < 1) {
      return l10n.globalSearchTimeMinutesAgo(difference.inMinutes);
    } else if (difference.inDays < 1) {
      return l10n.globalSearchTimeHoursAgo(difference.inHours);
    } else if (difference.inDays < 7) {
      return l10n.globalSearchTimeDaysAgo(difference.inDays);
    } else {
      // For older dates, use localized short date format
      return formatShortDate(context, dateTime);
    }
  }

  /// Format file size with localized number formatting
  /// Chinese: 1,234 KB
  /// English: 1,234 KB
  static String formatFileSize(BuildContext context, int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes == 0) return '0 B';
    
    int i = 0;
    double size = bytes.toDouble();
    
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    
    final formattedSize = size < 10 && i > 0 
        ? formatDecimal(context, size, 1)
        : formatNumber(context, size.round());
    
    return '$formattedSize ${suffixes[i]}';
  }

  /// Format duration in a localized way
  /// Chinese: 2小时30分钟
  /// English: 2h 30m
  static String formatDuration(BuildContext context, Duration duration) {
    final locale = _getFormattingLocale(context);
    final isZh = locale.languageCode == 'zh';
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    final parts = <String>[];
    
    if (hours > 0) {
      parts.add(isZh ? '$hours小时' : '${hours}h');
    }
    
    if (minutes > 0) {
      parts.add(isZh ? '$minutes分钟' : '${minutes}m');
    }
    
    if (seconds > 0 && hours == 0) {
      parts.add(isZh ? '$seconds秒' : '${seconds}s');
    }
    
    if (parts.isEmpty) {
      return isZh ? '0秒' : '0s';
    }
    
    return parts.join(isZh ? '' : ' ');
  }
}