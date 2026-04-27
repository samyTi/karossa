import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'app.dart';
import 'core/utils/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://mkrbhyrkrajicthcqjtj.supabase.co',
    anonKey: 'sb_publishable_UyjVexlQkh_qO0yiPoiTuA_eJfdz23w',
  );

  await Hive.initFlutter();
  tz.initializeTimeZones();
  await NotificationService.init();

  runApp(const ProviderScope(child: GarageApp()));
}

final supabase = Supabase.instance.client;
