import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Service de notification pour afficher des toasts élégants
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  OverlayState? _overlayState;
  OverlayEntry? _currentOverlay;

  /// Initialise le service avec le BuildContext de l'application
  void init(BuildContext context) {
    _overlayState = Overlay.of(context);
  }

  /// Affiche une notification toast
  void show({
    required String message,
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    IconData? icon,
    VoidCallback? onTap,
  }) {
    _hideCurrent();

    _currentOverlay = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        icon: icon ?? _getDefaultIcon(type),
        onTap: onTap,
        onDismiss: _hideCurrent,
      ),
    );

    _overlayState?.insert(_currentOverlay!);

    Future.delayed(duration, _hideCurrent);
  }

  /// Affiche une notification de succès
  void success(String message, {VoidCallback? onTap}) {
    show(message: message, type: NotificationType.success, onTap: onTap);
  }

  /// Affiche une notification d'erreur
  void error(String message, {VoidCallback? onTap}) {
    show(message: message, type: NotificationType.error, onTap: onTap);
  }

  /// Affiche une notification d'avertissement
  void warning(String message, {VoidCallback? onTap}) {
    show(message: message, type: NotificationType.warning, onTap: onTap);
  }

  /// Affiche une notification d'information
  void info(String message, {VoidCallback? onTap}) {
    show(message: message, type: NotificationType.info, onTap: onTap);
  }

  void _hideCurrent() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  IconData _getDefaultIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }
}

/// Types de notifications
enum NotificationType { success, error, warning, info }

/// Widget de toast personnalisé
class _ToastWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.icon,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.of(context).padding.top + 8,
    left: 16,
    right: 16,
    child: SlideTransition(
      position: _offsetAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _getBackgroundColor(),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: _getBorderColor(),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  color: _getIconColor(),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: _getTextColor(),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: widget.onDismiss,
                  child: Icon(
                    Icons.close,
                    color: _getTextColor().withValues(alpha: 0.6),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Color _getBackgroundColor() {
    switch (widget.type) {
      case NotificationType.success:
        return AppColors.secondary.withValues(alpha: 0.95);
      case NotificationType.error:
        return AppColors.retard.withValues(alpha: 0.95);
      case NotificationType.warning:
        return AppColors.accent.withValues(alpha: 0.95);
      case NotificationType.info:
        return AppColors.primary.withValues(alpha: 0.95);
    }
  }

  Color _getBorderColor() {
    switch (widget.type) {
      case NotificationType.success:
        return AppColors.secondary;
      case NotificationType.error:
        return AppColors.retard;
      case NotificationType.warning:
        return AppColors.accent;
      case NotificationType.info:
        return AppColors.primary;
    }
  }

  Color _getIconColor() => Colors.white;
  Color _getTextColor() => Colors.white;
}

/// Extension pour afficher facilement des notifications depuis un BuildContext
extension NotificationContext on BuildContext {
  void showNotification({
    required String message,
    NotificationType type = NotificationType.info,
    IconData? icon,
    VoidCallback? onTap,
  }) {
    NotificationService().show(
      message: message,
      type: type,
      icon: icon,
      onTap: onTap,
    );
  }

  void showSuccess(String message) {
    NotificationService().success(message);
  }

  void showError(String message) {
    NotificationService().error(message);
  }

  void showWarning(String message) {
    NotificationService().warning(message);
  }

  void showInfo(String message) {
    NotificationService().info(message);
  }
}