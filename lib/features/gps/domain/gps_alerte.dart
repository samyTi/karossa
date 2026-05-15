// lib/features/gps/domain/gps_alerte.dart
//
// Entité pure représentant une alerte GPS.
// Stockée dans la table Supabase `gps_alertes`.
//
// Table Supabase requise :
//
//   create table gps_alertes (
//     id           uuid        default gen_random_uuid() primary key,
//     vehicule_id  text        not null references vehicules(id) on delete cascade,
//     vehicule_nom text        not null,
//     type         text        not null,   -- 'vitesse' | 'zone' | 'kilometrage' | 'autre'
//     message      text        not null,
//     lue          boolean     not null default false,
//     date_alerte  timestamptz not null default now(),
//     created_at   timestamptz not null default now()
//   );
//
//   create index on gps_alertes (vehicule_id, date_alerte desc);
//   create index on gps_alertes (lue, date_alerte desc);

class GpsAlerte {
  final String   id;
  final String   vehiculeId;
  final String   vehiculeNom;
  final String   type;       // 'vitesse' | 'zone' | 'kilometrage' | 'autre'
  final String   message;
  final bool     lue;
  final DateTime dateAlerte;
  final DateTime createdAt;

  const GpsAlerte({
    required this.id,
    required this.vehiculeId,
    required this.vehiculeNom,
    required this.type,
    required this.message,
    required this.lue,
    required this.dateAlerte,
    required this.createdAt,
  });

  factory GpsAlerte.fromJson(Map<String, dynamic> json) => GpsAlerte(
    id:          json['id'] as String,
    vehiculeId:  json['vehicule_id'] as String,
    vehiculeNom: json['vehicule_nom'] as String,
    type:        json['type'] as String,
    message:     json['message'] as String,
    lue:         json['lue'] as bool? ?? false,
    dateAlerte:  DateTime.parse(json['date_alerte'] as String),
    createdAt:   DateTime.parse(json['created_at'] as String),
  );

  GpsAlerte copyWith({bool? lue}) => GpsAlerte(
    id:          id,
    vehiculeId:  vehiculeId,
    vehiculeNom: vehiculeNom,
    type:        type,
    message:     message,
    lue:         lue ?? this.lue,
    dateAlerte:  dateAlerte,
    createdAt:   createdAt,
  );
}
