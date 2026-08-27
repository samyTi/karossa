// lib/features/ai/presentation/ai_insight_of_the_day_card.dart
//
// À poser en haut de votre écran de dashboard principal (avant la liste des
// KPIs classiques). Affiche l'alerte non lue la plus sévère générée par
// ai-daily-digest ; tap → ouvre le chat avec la question pré-remplie.
// Si aucune alerte : ne s'affiche pas (pas de placeholder vide moche).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import 'ai_alertes_provider.dart';
import 'ai_chat_screen.dart';

class AiInsightOfTheDayCard extends ConsumerWidget {
  const AiInsightOfTheDayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertesAsync = ref.watch(aiAlertesNonLuesProvider);

    return alertesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (alertes) {
        if (alertes.isEmpty) return const SizedBox.shrink();

        // La plus sévère d'abord (urgent > attention > info), puis la plus récente.
        const ordre = {'urgent': 0, 'attention': 1, 'info': 2};
        final sorted = [...alertes]
          ..sort((a, b) => (ordre[a.severite] ?? 3).compareTo(ordre[b.severite] ?? 3));
        final top = sorted.first;
        final autres = alertes.length - 1;

        final color = switch (top.severite) {
          'urgent' => Colors.red,
          'attention' => Colors.orange,
          _ => AppColors.primary,
        };

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                ref.read(aiAlertesActionsProvider).marquerCommeLue(top.id);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiChatScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.12), color.withValues(alpha: 0.04)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: Icon(Icons.auto_awesome, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('KarossaAI',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                              const SizedBox(width: 6),
                              Text(context.l10n.insightDuJour,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(top.titre,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(top.message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                          if (autres > 0) ...[
                            const SizedBox(height: 6),
                            Text(context.l10n.autresPointsAConsulter(autres.toString(), autres > 1 ? 's' : ''),
                                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: color),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}