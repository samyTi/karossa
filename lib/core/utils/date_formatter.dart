//lib/core/utils/date_formatter.dart
import 'package:intl/intl.dart'; // Optionnel, si vous voulez des formats plus poussés

extension DateFormatExt on DateTime? {
  /// Retourne la date au format 'dd/MM'. 
  /// Si la date est nulle, retourne '---' (ou une autre valeur par défaut).
  String toDashboardFormat() {
    if (this == null) {
      return '---';
    }
    
    // Utilisation de padLeft pour garantir le format 01/01 au lieu de 1/1
    final day = this!.day.toString().padLeft(2, '0');
    final month = this!.month.toString().padLeft(2, '0');
    
    return '$day/$month';
  }
}