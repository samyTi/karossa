import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/theme_tokens.dart';

/// Widget carte modernisé avec élévation dynamique et animations
class ModernCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final bool isClickable;
  final VoidCallback? onTap;
  final Color? shadowColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Border? border;

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.isClickable = false,
    this.onTap,
    this.shadowColor,
    this.elevation,
    this.borderRadius,
    this.border,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: ThemeTokens.normalDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: ThemeTokens.smoothCurve),
    );
    _elevationAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: ThemeTokens.smoothCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _elevation {
    if (_isPressed) return 0.5;
    if (_isHovered) return 2.0;
    return 1.0;
  }

  List<BoxShadow> get _shadows {
    final color = widget.shadowColor ?? AppColors.primary;
    final elevation = _elevation;
    
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.05 * elevation),
        blurRadius: 8 * elevation,
        offset: Offset(0, 2 * elevation),
      ),
      if (elevation > 1)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02 * elevation),
          blurRadius: 16 * elevation,
          offset: Offset(0, 4 * elevation),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.color ?? AppColors.getSurface(context);
    final radius = widget.borderRadius ?? AppSpacing.cardRadius;
    final border = widget.border ?? Border.all(color: AppColors.border, width: 0.5);

    Widget card = AnimatedContainer(
      duration: ThemeTokens.normalDuration,
      padding: widget.padding ?? AppSpacing.cardPadding,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: radius,
        border: border,
        boxShadow: _shadows,
      ),
      child: widget.child,
    );

    if (widget.isClickable) {
      card = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) {
            setState(() => _isPressed = true);
            _controller.forward();
          },
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _controller.reverse();
            widget.onTap?.call();
          },
          onTapCancel: () {
            setState(() => _isPressed = false);
            _controller.reverse();
          },
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: card,
          ),
        ),
      );
    } else {
      card = MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: card,
      );
    }

    return card;
  }
}

/// Carte avec en-tête personnalisable
class ModernCardWithHeader extends StatelessWidget {
  final String title;
  final Widget? subtitle;
  final Widget? action;
  final Widget child;
  final Color? headerColor;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const ModernCardWithHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    required this.child,
    this.headerColor,
    this.color,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      margin: margin,
      padding: EdgeInsets.zero,
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: headerColor?.withValues(alpha: 0.05) ?? AppColors.inputFill,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusLg),
                topRight: Radius.circular(AppSpacing.radiusLg),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.border,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: headerColor ?? AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        DefaultTextStyle.merge(
                          style: AppTextStyles.bodySecondarySmall,
                          child: subtitle!,
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          // Content
          Padding(
            padding: padding ?? AppSpacing.cardPadding,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Carte statistique avec valeur et label
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final String? suffix;
  final double? trend;
  final bool showTrend;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.suffix,
    this.trend,
    this.showTrend = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? AppColors.primary;

    return ModernCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                icon,
                size: 20,
                color: cardColor.withValues(alpha: 0.7),
              ),
              if (showTrend && trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: trend! >= 0
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15),
                    borderRadius: AppSpacing.badgeRadius,
                  ),
                  child: Icon(
                    trend! >= 0 ? Icons.trending_up : Icons.trending_down,
                    size: 12,
                    color: trend! >= 0 ? AppColors.success : AppColors.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: cardColor,
                  letterSpacing: -0.5,
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    suffix!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cardColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}