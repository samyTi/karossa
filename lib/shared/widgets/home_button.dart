import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/extensions/l10n_extension.dart';

/// Bouton pour retourner à l'accueil depuis n'importe quel écran
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: context.l10n.retourALAccueil,
      onPressed: () => context.go('/dashboard'),
      color: AppColors.textInverse,
    );
  }
}