// lib/features/gps/domain/gps_position.dart
//
// Entité pure du domaine GPS.
// Aucune dépendance vers Flespi, Supabase ou Flutter.

class GpsPosition {
  final String vehiculeId;
  final double latitude;
  final double longitude;
  final double? speed;      // km/h
  final double? altitude;   // mètres
  final double? heading;    // cap en degrés (0–360)
  final DateTime fixTime;   // heure GPS (UTC)
  final DateTime serverTime;
  final bool isOnline;      // true si données < 5 min

  const GpsPosition({
    required this.vehiculeId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.altitude,
    this.heading,
    required this.fixTime,
    required this.serverTime,
    required this.isOnline,
  });

  /// Copie avec remplacement de champs
  GpsPosition copyWith({
    String? vehiculeId,
    double? latitude,
    double? longitude,
    double? speed,
    double? altitude,
    double? heading,
    DateTime? fixTime,
    DateTime? serverTime,
    bool? isOnline,
  }) {
    return GpsPosition(
      vehiculeId:  vehiculeId  ?? this.vehiculeId,
      latitude:    latitude    ?? this.latitude,
      longitude:   longitude   ?? this.longitude,
      speed:       speed       ?? this.speed,
      altitude:    altitude    ?? this.altitude,
      heading:     heading     ?? this.heading,
      fixTime:     fixTime     ?? this.fixTime,
      serverTime:  serverTime  ?? this.serverTime,
      isOnline:    isOnline    ?? this.isOnline,
    );
  }

  @override
  String toString() =>
      'GpsPosition(vehicule: $vehiculeId, lat: $latitude, lng: $longitude, '
      'speed: $speed, online: $isOnline)';
}
