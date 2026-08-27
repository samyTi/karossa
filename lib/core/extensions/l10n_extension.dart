// lib/core/extensions/l10n_extension.dart
import 'package:flutter/material.dart';
import 'package:garage_auto/l10n/app_localizations.dart';

export 'package:garage_auto/l10n/app_localizations.dart';

extension BuildContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this) ?? (throw FlutterError("AppLocalizations not found. Vérifiez que localizationsDelegates est configuré dans MaterialApp."));
}
