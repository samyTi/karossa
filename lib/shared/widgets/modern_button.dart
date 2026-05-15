import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/theme_tokens.dart';

/// Types de boutons disponibles
enum ModernButtonType {
  primary,
  secondary,
  outlined,
  text,
  danger,
  success,
}

/// Widget bouton modernisé avec animations et états
class ModernButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final ModernButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final VoidCallback? onPressed;
  final double? width;

  const ModernButton({
    super.key,
    required this.text,
    this.icon,
    this.type = ModernButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = false,
    this.onPressed,
    this.width,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

class _ModernButtonState extends State<ModernButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: ThemeTokens.normalDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: ThemeTokens.smoothCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isLoading || widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.isLoading || widget.onPressed == null) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    if (widget.isLoading || widget.onPressed == null) return;
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  Color _getBackgroundColor() {
    if (widget.isLoading || widget.onPressed == null) {
      return AppColors.disabled;
    }

    switch (widget.type) {
      case ModernButtonType.primary:
        return AppColors.primary;
      case ModernButtonType.secondary:
        return AppColors.secondary;
      case ModernButtonType.outlined:
        return Colors.transparent;
      case ModernButtonType.text:
        return Colors.transparent;
      case ModernButtonType.danger:
        return AppColors.error;
      case ModernButtonType.success:
        return AppColors.success;
    }
  }

  Color _getTextColor() {
    if (widget.isLoading || widget.onPressed == null) {
      return Colors.white.withValues(alpha: 0.7);
    }

    switch (widget.type) {
      case ModernButtonType.primary:
      case ModernButtonType.secondary:
      case ModernButtonType.danger:
      case ModernButtonType.success:
        return Colors.white;
      case ModernButtonType.outlined:
      case ModernButtonType.text:
        return _getPrimaryColor();
    }
  }

  Color _getPrimaryColor() {
    switch (widget.type) {
      case ModernButtonType.primary:
        return AppColors.primary;
      case ModernButtonType.secondary:
        return AppColors.secondary;
      case ModernButtonType.outlined:
      case ModernButtonType.text:
        return AppColors.primary;
      case ModernButtonType.danger:
        return AppColors.error;
      case ModernButtonType.success:
        return AppColors.success;
    }
  }

  Border? _getBorder() {
    if (widget.type == ModernButtonType.outlined) {
      return Border.all(
        color: widget.isLoading || widget.onPressed == null
            ? AppColors.disabled
            : _getPrimaryColor(),
        width: 1.5,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();
    final textColor = _getTextColor();
    final border = _getBorder();
    final isFilled = widget.type == ModernButtonType.primary ||
        widget.type == ModernButtonType.secondary ||
        widget.type == ModernButtonType.danger ||
        widget.type == ModernButtonType.success;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: ThemeTokens.normalDuration,
          width: widget.isFullWidth ? double.infinity : widget.width,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isFilled ? backgroundColor : Colors.transparent,
            borderRadius: AppSpacing.buttonRadius,
            border: border,
            boxShadow: isFilled && !_isPressed
                ? [
                    BoxShadow(
                      color: backgroundColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.type == ModernButtonType.outlined ||
                              widget.type == ModernButtonType.text
                          ? _getPrimaryColor()
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                )
              else ...[
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 18,
                    color: textColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton rapide avec icône seule (pour les icon buttons)
class ModernIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;
  final String? tooltip;

  const ModernIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size,
    this.tooltip,
  });

  @override
  State<ModernIconButton> createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<ModernIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: ThemeTokens.fastDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: ThemeTokens.smoothCurve),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppColors.primary;
    final iconClr = widget.iconColor ?? Colors.white;
    final buttonSize = widget.size ?? AppSpacing.md * 2.5;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onPressed,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: ThemeTokens.normalDuration,
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              color: _isHovered ? bgColor.withValues(alpha: 0.9) : bgColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: bgColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              widget.icon,
              color: iconClr,
              size: buttonSize * 0.4,
            ),
          ),
        ),
      ),
    );
  }
}