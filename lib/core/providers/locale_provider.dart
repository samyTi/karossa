// lib/core/providers/locale_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  static const _key = 'app_locale';

  LocaleNotifier() : super(const Locale('fr')) {
    _loadSaved(); // ← charge la locale sauvegardée au démarrage
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString(_key) ?? 'fr';
    state = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  // Raccourcis pratiques
  void toFrench()  => setLocale(const Locale('fr'));
  void toArabic()  => setLocale(const Locale('ar'));
  void toEnglish() => setLocale(const Locale('en'));
}