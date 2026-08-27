// lib/features/gps/domain/gps_position.dart
//
// Entité représentant un point GPS enrichi d'un véhicule.
// Stockée dans la table Supabase `gps_positions`.
//
// ────────────────────────────────────────────────────────────────────────────
// CHAMPS FLESPI MAINTENANT CAPTURÉS
// ────────────────────────────────────────────────────────────────────────────
//
//  position.latitude / longitude / speed / altitude / direction  → de base
//  engine.ignition.status   → moteur allumé/éteint (fiabilité isMoving)
//  battery.level            → niveau batterie tracker (0–100 %)
//  fuel.level.1             → carburant (0–100 %)  [si capteur installé]
//  door.open.status         → porte ouverte (alerte intrusion)
//  gnss.status              → fix GPS valide
//  position.valid           → position GPS fiable
//  server.timestamp         → heure de réception Flespi (pour isOnline fiable)
//
// Migration SQL requise : voir gps_positions_migration.sql
// ────────────────────────────────────────────────────────────────────────────

class GpsPosition {
  // ── Identité ─────────────────────────────────────────────────────────────
  final String vehiculeId;

  // ── Position ─────────────────────────────────────────────────────────────
  final double  latitude;
  final double  longitude;
  final double? speed;     // km/h
  final double? altitude;  // mètres
  final double? heading;   // degrés (0–360), 0 = Nord

  // ── Horodatage ───────────────────────────────────────────────────────────
  final DateTime fixTime;     // heure du fix GPS côté tracker (UTC)
  final DateTime serverTime;  // heure de réception Flespi (UTC) — plus fiable pour isOnline

  // ── Télémétrie enrichie ───────────────────────────────────────────────────
  final bool?   ignitionOn;    // engine.ignition.status
  final int?    batteryLevel;  // battery.level (0–100 %)
  final int?    fuelLevel;     // fuel.level.1  (0–100 %) — null si pas de capteur
  final bool?   doorOpen;      // door.open.status
  final bool?   gnssValid;     // gnss.status
  final bool?   positionValid; // position.valid

  // ── Statut calculé ───────────────────────────────────────────────────────
  /// En ligne si Flespi a reçu un message il y a moins de 30 min,
  /// OU si le moteur est allumé (le tracker peut envoyer moins souvent à l'arrêt).
  final bool isOnline;

  /// True pour un point RECONSTITUÉ (comblement de trou GPS via calage sur
  /// la route la plus probable) — jamais persisté en base, uniquement généré
  /// en mémoire pour le playback. Voir `gps_route_gap_filler.dart`.
  final bool isInterpolated;

  const GpsPosition({
    required this.vehiculeId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.altitude,
    this.heading,
    required this.fixTime,
    required this.serverTime,
    this.ignitionOn,
    this.batteryLevel,
    this.fuelLevel,
    this.doorOpen,
    this.gnssValid,
    this.positionValid,
    this.isOnline = false,
    this.isInterpolated = false,
  });

  // ── Helpers sémantiques ───────────────────────────────────────────────────

  /// Véhicule en mouvement : vitesse > 2 km/h OU moteur allumé + vitesse inconnue.
  bool get isMoving {
    if ((speed ?? 0) > 2) return true;
    // Si le tracker ne transmet pas la vitesse, on se rabat sur l'allumage
    if (speed == null && (ignitionOn ?? false)) return true;
    return false;
  }

  /// Libellé d'état pour l'UI.
  String get statusLabel {
    if (!isOnline)        return 'Hors ligne';
    if (isMoving)         return speed != null ? '${speed!.toStringAsFixed(0)} km/h' : 'En route';
    if (ignitionOn == true) return 'Moteur allumé';
    return 'Arrêté';
  }

  /// Durée depuis le dernier message Flespi (server_time = plus fiable que fix_time).
  Duration get age => DateTime.now().toUtc().difference(serverTime);

  String get ageLabel {
    final d = age;
    if (d.inSeconds < 60)  return 'À l\'instant';
    if (d.inMinutes < 60)  return '${d.inMinutes} min';
    if (d.inHours   < 24)  return '${d.inHours} h';
    return '${d.inDays} j';
  }

  /// Alerte batterie faible (seuil 20 %).
  bool get hasBatteryWarning => (batteryLevel ?? 100) < 20;

  /// Alerte carburant bas (seuil 15 %).
  bool get hasFuelWarning => fuelLevel != null && fuelLevel! < 15;

  // ── Sérialisation ─────────────────────────────────────────────────────────

  factory GpsPosition.fromSupabase(Map<String, dynamic> row) {
    final serverTime = DateTime.parse(row['server_time'] as String).toUtc();
    final fixTime    = DateTime.parse(row['fix_time']    as String).toUtc();
    final now        = DateTime.now().toUtc();
    final ignitionOn = row['ignition_on'] as bool?;

    return GpsPosition(
      vehiculeId:    row['vehicule_id']   as String,
      latitude:     (row['latitude']      as num).toDouble(),
      longitude:    (row['longitude']     as num).toDouble(),
      speed:        (row['speed']         as num?)?.toDouble(),
      altitude:     (row['altitude']      as num?)?.toDouble(),
      heading:      (row['cap']           as num?)?.toDouble(),
      fixTime:       fixTime,
      serverTime:    serverTime,
      ignitionOn:    ignitionOn,
      batteryLevel:  row['battery_level'] as int?,
      fuelLevel:     row['fuel_level']    as int?,
      doorOpen:      row['door_open']     as bool?,
      gnssValid:     row['gnss_valid']    as bool?,
      positionValid: row['position_valid'] as bool?,
      isOnline: now.difference(serverTime).inMinutes < 30 || (ignitionOn ?? false),
    );
  }

  Map<String, dynamic> toSupabase() => {
    'vehicule_id':    vehiculeId,
    'latitude':       latitude,
    'longitude':      longitude,
    'speed':          speed,
    'altitude':       altitude,
    'cap':            heading,
    'fix_time':       fixTime.toIso8601String(),
    'server_time':    serverTime.toIso8601String(),
    'ignition_on':    ignitionOn,
    'battery_level':  batteryLevel,
    'fuel_level':     fuelLevel,
    'door_open':      doorOpen,
    'gnss_valid':     gnssValid,
    'position_valid': positionValid,
  };

  // ── Copie ──────────────────────────────────────────────────────────────────

  GpsPosition copyWith({
    double? speed,
    double? heading,
    bool?   isOnline,
    bool?   ignitionOn,
    int?    batteryLevel,
    int?    fuelLevel,
    bool?   doorOpen,
    bool?   isInterpolated,
  }) =>
      GpsPosition(
        vehiculeId:    vehiculeId,
        latitude:      latitude,
        longitude:     longitude,
        speed:         speed        ?? this.speed,
        altitude:      altitude,
        heading:       heading      ?? this.heading,
        fixTime:       fixTime,
        serverTime:    serverTime,
        ignitionOn:    ignitionOn   ?? this.ignitionOn,
        batteryLevel:  batteryLevel ?? this.batteryLevel,
        fuelLevel:     fuelLevel    ?? this.fuelLevel,
        doorOpen:      doorOpen     ?? this.doorOpen,
        gnssValid:     gnssValid,
        positionValid: positionValid,
        isOnline:      isOnline     ?? this.isOnline,
        isInterpolated: isInterpolated ?? this.isInterpolated,
      );

  @override
  bool operator ==(Object other) =>
      other is GpsPosition &&
      other.vehiculeId == vehiculeId &&
      other.fixTime    == fixTime;

  @override
  int get hashCode => Object.hash(vehiculeId, fixTime);

  @override
  String toString() =>
      'GpsPosition($vehiculeId — lat=$latitude, lon=$longitude, '
      'speed=$speed, ignition=$ignitionOn, online=$isOnline)';
}