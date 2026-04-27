// lib/features/gps/domain/gps_models.dart
// Modèles de données pour l'intégration Traccar GPS

class TraccarDevice {
  final int id;
  final String name;
  final String uniqueId;   // = immatriculation du véhicule
  final String status;     // online | offline | unknown
  final DateTime? lastUpdate;
  final String? vehiculeId; // liaison avec la table vehicules

  const TraccarDevice({
    required this.id,
    required this.name,
    required this.uniqueId,
    required this.status,
    this.lastUpdate,
    this.vehiculeId,
  });

  bool get isOnline => status == 'online';

  factory TraccarDevice.fromJson(Map<String, dynamic> json) => TraccarDevice(
    id:         json['id'],
    name:       json['name'] ?? '',
    uniqueId:   json['uniqueId'] ?? '',
    status:     json['status'] ?? 'unknown',
    lastUpdate: json['lastUpdate'] != null
        ? DateTime.tryParse(json['lastUpdate']) : null,
    vehiculeId: json['vehiculeId'],
  );
}

class TraccarPosition {
  final int id;
  final int deviceId;
  final DateTime fixTime;
  final double latitude;
  final double longitude;
  final double altitude;
  final double speed;        // km/h
  final double course;       // degrés
  final double accuracy;
  final String? address;
  final Map<String, dynamic> attributes;

  const TraccarPosition({
    required this.id,
    required this.deviceId,
    required this.fixTime,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.speed,
    required this.course,
    required this.accuracy,
    this.address,
    this.attributes = const {},
  });

  /// Kilométrage total depuis le boîtier (si disponible)
  double? get totalKm {
    final v = attributes['totalDistance'];
    return v != null ? (v as num).toDouble() / 1000 : null;
  }

  /// Niveau de carburant en % (si capteur branché)
  double? get fuelLevel => attributes['fuel'] != null
      ? (attributes['fuel'] as num).toDouble() : null;

  factory TraccarPosition.fromJson(Map<String, dynamic> json) => TraccarPosition(
    id:        json['id'],
    deviceId:  json['deviceId'],
    fixTime:   DateTime.parse(json['fixTime']),
    latitude:  (json['latitude']  as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    altitude:  (json['altitude']  as num? ?? 0).toDouble(),
    speed:     (json['speed']     as num? ?? 0).toDouble(),
    course:    (json['course']    as num? ?? 0).toDouble(),
    accuracy:  (json['accuracy']  as num? ?? 0).toDouble(),
    address:   json['address'],
    attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
  );
}

class TraccarGeofence {
  final int id;
  final String name;
  final String description;
  final String area; // WKT format: CIRCLE(lat lon radius) ou POLYGON(...)

  const TraccarGeofence({
    required this.id,
    required this.name,
    required this.description,
    required this.area,
  });

  factory TraccarGeofence.fromJson(Map<String, dynamic> json) => TraccarGeofence(
    id:          json['id'],
    name:        json['name'] ?? '',
    description: json['description'] ?? '',
    area:        json['area'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'area': area,
  };
}

class TraccarEvent {
  final int id;
  final int deviceId;
  final String type;
  final DateTime eventTime;
  final int? geofenceId;
  final Map<String, dynamic> attributes;

  const TraccarEvent({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.eventTime,
    this.geofenceId,
    this.attributes = const {},
  });

  String get typeLabel => switch (type) {
    'deviceOnline'     => 'Appareil connecté',
    'deviceOffline'    => 'Appareil déconnecté',
    'geofenceEnter'    => 'Entrée de zone',
    'geofenceExit'     => 'Sortie de zone',
    'speedLimit'       => 'Dépassement vitesse',
    'alarm'            => 'Alarme',
    'ignitionOn'       => 'Démarrage moteur',
    'ignitionOff'      => 'Arrêt moteur',
    _                  => type,
  };

  bool get isAlert => ['geofenceExit', 'speedLimit', 'alarm'].contains(type);

  factory TraccarEvent.fromJson(Map<String, dynamic> json) => TraccarEvent(
    id:          json['id'],
    deviceId:    json['deviceId'],
    type:        json['type'] ?? '',
    eventTime:   DateTime.parse(json['eventTime']),
    geofenceId:  json['geofenceId'],
    attributes:  Map<String, dynamic>.from(json['attributes'] ?? {}),
  );
}

class TraccarTrip {
  final int deviceId;
  final DateTime startTime;
  final DateTime endTime;
  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final double distance;     // mètres
  final double averageSpeed; // km/h
  final double maxSpeed;     // km/h
  final int duration;        // secondes

  const TraccarTrip({
    required this.deviceId,
    required this.startTime,
    required this.endTime,
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.distance,
    required this.averageSpeed,
    required this.maxSpeed,
    required this.duration,
  });

  double get distanceKm => distance / 1000;

  String get durationLabel {
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }

  factory TraccarTrip.fromJson(Map<String, dynamic> json) => TraccarTrip(
    deviceId:     json['deviceId'],
    startTime:    DateTime.parse(json['startTime']),
    endTime:      DateTime.parse(json['endTime']),
    startLat:     (json['startLat']      as num).toDouble(),
    startLon:     (json['startLon']      as num).toDouble(),
    endLat:       (json['endLat']        as num).toDouble(),
    endLon:       (json['endLon']        as num).toDouble(),
    distance:     (json['distance']      as num).toDouble(),
    averageSpeed: (json['averageSpeed']  as num? ?? 0).toDouble(),
    maxSpeed:     (json['maxSpeed']      as num? ?? 0).toDouble(),
    duration:     json['duration'] ?? 0,
  );
}

/// Alerte GPS enregistrée localement / dans Supabase
class GpsAlerte {
  final String id;
  final String vehiculeId;
  final String vehiculeNom;
  final String type;         // vitesse | zone | kilometrage | connexion
  final String message;
  final DateTime dateAlerte;
  final bool lue;

  const GpsAlerte({
    required this.id,
    required this.vehiculeId,
    required this.vehiculeNom,
    required this.type,
    required this.message,
    required this.dateAlerte,
    this.lue = false,
  });

  factory GpsAlerte.fromJson(Map<String, dynamic> json) => GpsAlerte(
    id:          json['id'],
    vehiculeId:  json['vehicule_id'],
    vehiculeNom: json['vehicule_nom'] ?? '',
    type:        json['type'] ?? '',
    message:     json['message'] ?? '',
    dateAlerte:  DateTime.parse(json['date_alerte']),
    lue:         json['lue'] ?? false,
  );

  Map<String, dynamic> toJson() => {
    'vehicule_id':  vehiculeId,
    'vehicule_nom': vehiculeNom,
    'type':         type,
    'message':      message,
    'date_alerte':  dateAlerte.toIso8601String(),
    'lue':          lue,
  };
}
