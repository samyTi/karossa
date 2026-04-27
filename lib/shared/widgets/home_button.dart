import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

/// Bouton pour retourner à l'accueil depuis n'importe quel écran
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Retour à l\'accueil',
      onPressed: () => context.go('/dashboard'),
      color: AppColors.textSecondary,
    );
  }
}