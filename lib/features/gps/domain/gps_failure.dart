// lib/features/gps/domain/gps_failure.dart
//
// Hiérarchie d'erreurs du domaine GPS.
// La couche presentation affiche ces types sans connaître Flespi.

sealed class GpsFailure {
  final String message;
  const GpsFailure(this.message);
}

/// Token Flespi invalide ou expiré
final class GpsUnauthorizedFailure extends GpsFailure {
  const GpsUnauthorizedFailure([super.message = 'Token GPS invalide. Vérifiez la configuration.']);
}

/// Device ID introuvable sur Flespi
final class GpsDeviceNotFoundFailure extends GpsFailure {
  const GpsDeviceNotFoundFailure([super.message = 'Tracker GPS introuvable. Vérifiez le Device ID.']);
}

/// Tracker allumé mais pas de signal GPS
final class GpsOfflineFailure extends GpsFailure {
  const GpsOfflineFailure([super.message = 'Tracker hors ligne ou sans signal GPS.']);
}

/// Aucun message reçu du tracker
final class GpsNoDataFailure extends GpsFailure {
  const GpsNoDataFailure([super.message = 'Aucune donnée GPS disponible pour ce véhicule.']);
}

/// Erreur réseau (pas de connexion internet)
final class GpsNetworkFailure extends GpsFailure {
  const GpsNetworkFailure([super.message = 'Erreur réseau. Vérifiez votre connexion.']);
}

/// Erreur inattendue
final class GpsUnknownFailure extends GpsFailure {
  const GpsUnknownFailure([super.message = 'Erreur GPS inattendue.']);
}
