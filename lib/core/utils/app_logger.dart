// lib/core/utils/app_logger.dart
// Logger centralisé — remplace tous les debugPrint éparpillés
// En mode release, tous les logs sont désactivés automatiquement.
//
// Usage :
//   AppLogger.d('message debug');
//   AppLogger.w('avertissement');
//   AppLogger.e('erreur', error: e, stackTrace: st);

import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  /// Log de debug (désactivé en release)
  static void d(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[DEBUG] $message');
      if (error != null) debugPrint('[DEBUG] Error: $error');
      if (stackTrace != null) debugPrint('[DEBUG] Stack: $stackTrace');
    }
  }

  /// Log d'information
  static void i(String message) {
    if (kDebugMode) debugPrint('[INFO]  $message');
  }

  /// Log d'avertissement
  static void w(String message, {Object? error}) {
    if (kDebugMode) {
      debugPrint('[WARN]  $message');
      if (error != null) debugPrint('[WARN]  Error: $error');
    }
    // TODO: envoyer à Sentry/Crashlytics en production
  }

  /// Log d'erreur — toujours visible même en release (sans données sensibles)
  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[ERROR] $message');
      if (error != null) debugPrint('[ERROR] Error: $error');
      if (stackTrace != null) debugPrint('[ERROR] Stack: $stackTrace');
    }
    // TODO: reporter à Sentry.captureException(error, stackTrace: stackTrace)
  }
}
