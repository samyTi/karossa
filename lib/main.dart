// lib/main.dart
//
// CHANGEMENT : suppression de `final supabase = Supabase.instance.client;`
// Le client est désormais fourni par supabaseClientProvider (core/providers/supabase_provider.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr');
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  await Hive.initFlutter();
  tz.initializeTimeZones();

  runApp(const ProviderScope(child: GarageApp()));
}

// ✅ SUPPRIMÉ : `final supabase = Supabase.instance.client;`
// Utilisez supabaseClientProvider à la place.
