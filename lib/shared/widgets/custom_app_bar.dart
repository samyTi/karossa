import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// Widget AppBar personnalisé avec bouton retour et bouton accueil
/// - Si [showBackButton] est true, affiche une flèche retour
/// - Si [showHomeButton] est true, affiche une icône maison pour retourner à l'accueil
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showHomeButton;
  final List<Widget>? actions;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.showHomeButton = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      leading: showBackButton ? const BackButton() : null,
      actions: [
        if (showHomeButton)
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Retour à l\'accueil',
            onPressed: () => context.go('/dashboard'),
            color: AppColors.textSecondary,
          ),
        if (actions != null) ...actions!,
      ],
    );
  }
}