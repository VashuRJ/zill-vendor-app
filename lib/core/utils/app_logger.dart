import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Professional MNC-grade logger.
/// - Pretty color-coded output in debug mode.
/// - Completely silent in release mode.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 4,
      lineLength: 90,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
    level: kReleaseMode ? Level.off : Level.debug,
  );

  /// Verbose – noisy, only for deep debugging.
  static void t(String message) => _logger.t(message);

  /// Debug – development info.
  static void d(String message) => _logger.d(message);

  /// Info – normal operational events.
  static void i(String message) => _logger.i(message);

  /// Warning – something unexpected but recoverable.
  static void w(String message) => _logger.w(message);

  /// Error – something failed.
  static void e(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  /// Network request log – one-liner: METHOD URL → STATUS
  static void network(String method, String url, int? statusCode) {
    if (kReleaseMode) return;
    final code = statusCode ?? '???';
    _logger.i('🌐 $method $url → $code');
  }

  /// Network error log – shows body only on error.
  static void networkError(
    String method,
    String url,
    int? statusCode,
    dynamic body,
  ) {
    if (kReleaseMode) return;
    _logger.e('🌐 $method $url → ${statusCode ?? '???'}\n$body');
  }
}
