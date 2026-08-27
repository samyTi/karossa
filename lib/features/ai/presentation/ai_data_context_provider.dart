// lib/features/ai/presentation/ai_data_context_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Données chargées dynamiquement dans le contexte du chat IA
/// [label] : Libellé affiché dans l'interface (ex: "14 locations chargées")
/// [data]  : Liste de Maps nettoyée et allégée prête à être sérialisée pour Gemini
class AiDataContext {
  final String label;
  final List<Map<String, dynamic>> data;

  const AiDataContext({
    required this.label,
    required this.data,
  });
}

/// Provider d'état pour piloter le contexte additionnel de la discussion active
final aiDataContextProvider = StateProvider<AiDataContext?>((ref) => null);