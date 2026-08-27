//lib/shared/widgets/custom_app_bar.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/extensions/l10n_extension.dart';

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
            tooltip: context.l10n.retourALAccueil,
            onPressed: () => context.go('/dashboard'),
            color: AppColors.textInverse,
          ),
        if (actions != null) ...actions!,
      ],
    );
  }
}