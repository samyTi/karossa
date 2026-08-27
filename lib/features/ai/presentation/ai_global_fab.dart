// lib/features/ai/presentation/ai_global_fab.dart
//
// Point d'accès unique à KarossaAI depuis n'importe quel écran de l'app.
// À poser UNE FOIS dans le widget racine qui contient votre BottomNavigationBar
// (ex: MainNavigationShell / HomeShell), en floatingActionButton, PAS dans
// chaque écran individuellement.
//
// Usage :
//   Scaffold(
//     body: ...,
//     bottomNavigationBar: ...,
//     floatingActionButton: const AiGlobalFab(),
//   )

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import 'ai_alertes_provider.dart';
import 'ai_chat_screen.dart';

class AiGlobalFab extends ConsumerWidget {
  const AiGlobalFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertesAsync = ref.watch(aiAlertesNonLuesProvider);
    final hasUrgent = alertesAsync.maybeWhen(
      data: (alertes) => alertes.any((a) => a.severite == 'urgent'),
      orElse: () => false,
    );
    final unreadCount = alertesAsync.maybeWhen(
      data: (alertes) => alertes.length,
      orElse: () => 0,
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          heroTag: 'ai_global_fab',
          backgroundColor: AppColors.primary,
          elevation: 4,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AiChatScreen()),
          ),
          child: hasUrgent
              ? const _PulsingIcon()
              : const Icon(Icons.auto_awesome, color: Colors.white),
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

/// Icône qui pulse doucement quand une alerte urgente attend — attire l'œil
/// sans être intrusif (pas de son, pas de popup forcée).
class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: const Icon(Icons.auto_awesome, color: Colors.white),
    );
  }
}