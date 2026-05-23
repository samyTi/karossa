// lib/shared/services/notification_service.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Service de notification pour afficher des toasts élégants sans blocage de cycle de vie
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  /// Clé globale du navigateur pour accéder à l'Overlay de manière sécurisée n'importe où
  static final navigatorKey = GlobalKey<NavigatorState>();

  OverlayEntry? _currentOverlay;

  /// Optionnel : Conservez la méthode init pour ne pas casser votre code existant dans app.dart
  void init(BuildContext context) {
    // Plus besoin de faire _overlayState = Overlay.of(context) ici, ce qui causait le crash.
    // L'Overlay sera récupéré dynamiquement via le navigatorKey au moment de l'affichage.
  }

  /// Récupère l'état actuel de l'Overlay via la clé globale
  OverlayState? get _overlayState {
    return navigatorKey.currentState?.overlay;
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

    final overlay = _overlayState;
    if (overlay == null) {
      // Sécurité si l'application n'est pas encore totalement prête
      debugPrint("NotificationService: Impossible d'afficher le toast, l'Overlay n'est pas encore disponible.");
      return;
    }

    _currentOverlay = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        type: type,
        icon: icon ?? _getDefaultIcon(type),
        onTap: onTap,
        onDismiss: _hideCurrent,
      ),
    );

    overlay.insert(_currentOverlay!);

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
    if (_currentOverlay != null) {
      try {
        _currentOverlay!.remove();
      } catch (e) {
        // Ignorer si déjà supprimé de l'arbre
      } finally {
        _currentOverlay = null;
      }
    }
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
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    
    return Positioned(
      top: mediaQuery.padding.top + 8,
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
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close,
                        color: _getTextColor().withValues(alpha: 0.6),
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

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