import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/theme_tokens.dart';

/// AppBar modernisée avec dégradé et animations
class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final bool showHomeButton;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Gradient? gradient;
  final bool useGradient;
  final Widget? leading;
  final double? elevation;

  const ModernAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.showHomeButton = false,
    this.actions,
    this.backgroundColor,
    this.gradient,
    this.useGradient = true,
    this.leading,
    this.elevation,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 20);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = backgroundColor ?? (isDark ? AppColors.surfaceDark : AppColors.primary);
    final gradient = this.gradient ?? (useGradient
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.primaryDarkMode,
                    AppColors.primary,
                  ]
                : [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
          )
        : null);

    return AppBar(
      elevation: elevation ?? 0,
      scrolledUnderElevation: 2,
      backgroundColor: gradient == null ? bgColor : Colors.transparent,
      flexibleSpace: gradient != null
          ? Container(
              decoration: BoxDecoration(gradient: gradient),
            )
          : null,
      leading: leading ?? (showBackButton ? const BackButton(color: Colors.white) : null),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      centerTitle: false,
      actions: [
        if (showHomeButton)
          _HomeButton(),
        if (actions != null) ...actions!,
      ],
    );
  }
}

/// Bouton retour accueil
class _HomeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Retour à l\'accueil',
      onPressed: () => context.go('/dashboard'),
      color: Colors.white,
    );
  }
}

/// AppBar transparente qui devient colorée au scroll
class ScrollAwareAppBar extends StatefulWidget {
  final String title;
  final double scrollThreshold;
  final List<Widget>? actions;
  final Widget? leading;

  const ScrollAwareAppBar({
    super.key,
    required this.title,
    this.scrollThreshold = 10,
    this.actions,
    this.leading,
  });

  @override
  State<ScrollAwareAppBar> createState() => _ScrollAwareAppBarState();
}

class _ScrollAwareAppBarState extends State<ScrollAwareAppBar> {
  double _scrollOffset = 0;

  void _onScroll(double offset) {
    if (mounted) {
      setState(() {
        _scrollOffset = offset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isScrolled = _scrollOffset > widget.scrollThreshold;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: ThemeTokens.normalDuration,
      decoration: BoxDecoration(
        color: isScrolled
            ? (isDark ? AppColors.surfaceDark : AppColors.primary)
            : Colors.transparent,
        gradient: isScrolled
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.primaryDarkMode, AppColors.primary]
                    : [AppColors.primary, AppColors.primaryDark],
              )
            : null,
        boxShadow: isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.leading ?? const BackButton(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: widget.actions,
      ),
    );
  }
}

/// Notification Bell avec badge
class NotificationBell extends StatelessWidget {
  final int? badgeCount;
  final VoidCallback? onTap;

  const NotificationBell({
    super.key,
    this.badgeCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: Colors.white,
          onPressed: onTap ?? () {},
        ),
        if (badgeCount != null && badgeCount! > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                badgeCount! > 99 ? '99+' : '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Search Bar intégrée dans l'AppBar
class SearchAppBar extends StatefulWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClose;

  const SearchAppBar({
    super.key,
    this.hint = 'Rechercher...',
    this.onChanged,
    this.onClose,
  });

  @override
  State<SearchAppBar> createState() => _SearchAppBarState();
}

class _SearchAppBarState extends State<SearchAppBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;
  final TextEditingController _textController = TextEditingController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: ThemeTokens.normalDuration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: ThemeTokens.smoothCurve),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
        _textController.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: _isExpanded
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: _toggleSearch,
            )
          : const BackButton(color: Colors.white),
      title: _isExpanded
          ? TextField(
              controller: _textController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                border: InputBorder.none,
              suffixIcon: _textController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          _textController.clear();
                          widget.onChanged?.call('');
                        },
                      )
                    : null,
              ),
              onChanged: widget.onChanged,
            )
          : const Text(
              'Recherche',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
      actions: [
        if (!_isExpanded)
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _toggleSearch,
          ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );
  }
}