// lib/core/services/realtime_service.dart
//
// Petit wrapper autour de Supabase Realtime pour éviter de dupliquer la
// logique d'abonnement (channel + postgres_changes) dans chaque provider.
//
// Usage typique dans un provider Riverpod :
//
// final myRealtimeProvider = Provider.autoDispose<void>((ref) {
//   final client = ref.watch(supabaseClientProvider);
//   final showroomId = ref.watch(currentShowroomIdProvider);
//   if (showroomId == null) return;
//
//   final sub = RealtimeSubscription(
//     client: client,
//     table: 'caisse_operations',
//     showroomId: showroomId,
//     onChange: () => ref.invalidate(caisseOperationsProvider),
//   )..listen();
//
//   ref.onDispose(sub.dispose);
// });

import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/app_logger.dart';

class RealtimeSubscription {
  final SupabaseClient client;
  final String table;
  final String? showroomId;
  final void Function() onChange;

  RealtimeChannel? _channel;

  RealtimeSubscription({
    required this.client,
    required this.table,
    required this.onChange,
    this.showroomId,
  });

  void listen() {
    try {
      final channelName = 'realtime:$table:${showroomId ?? 'global'}';
      _channel = client.channel(channelName).onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: showroomId != null
                ? PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'showroom_id',
                    value: showroomId,
                  )
                : null,
            callback: (payload) => onChange(),
          );
      _channel?.subscribe();
    } catch (e, st) {
      // Le realtime est un "plus" — une erreur d'abonnement ne doit jamais
      // casser l'écran, l'app retombe simplement sur le mode pull existant.
      AppLogger.e('RealtimeSubscription.listen($table)', error: e, stackTrace: st);
    }
  }

  void dispose() {
    if (_channel != null) {
      client.removeChannel(_channel!);
      _channel = null;
    }
  }
}

/// Combine plusieurs abonnements réutilisant le même callback
/// (ex: 4 tables différentes qui doivent toutes rafraîchir les notifications).
class RealtimeSubscriptionGroup {
  final List<RealtimeSubscription> _subs = [];

  void add(RealtimeSubscription sub) {
    sub.listen();
    _subs.add(sub);
  }

  void dispose() {
    for (final s in _subs) {
      s.dispose();
    }
    _subs.clear();
  }
}
