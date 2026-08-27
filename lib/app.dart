import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'shared/services/notification_service.dart';
import 'core/providers/locale_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class GarageApp extends ConsumerWidget {
  const GarageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService().init(context);
    });

    return MaterialApp.router(
      title: 'Karossa',  // l10n non disponible ici
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: const [
        Locale('fr'),
        Locale('ar'),
        Locale('en'),
      ],
      locale: ref.watch(localeProvider),
    );
  }
}