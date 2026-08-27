// lib/features/gps/domain/gps_alerte.dart
//
// Entité pure représentant une alerte GPS.
// Stockée dans la table Supabase `gps_alertes`.
//
// Table Supabase requise :
//
//   create table gps_alertes (
//     id           uuid        default gen_random_uuid() primary key,
//     showroom_id  uuid        references showrooms(id),  -- isolation multi-tenant
//     vehicule_id  uuid        references vehicules(id) on delete cascade,
//     vehicule_nom text,
//     type         text        not null,   -- 'vitesse' | 'zone' | 'kilometrage' | 'autre'
//     message      text        not null,
//     lue          boolean     default false,
//     date_alerte  timestamptz default now()
//   );
//
//   create index on gps_alertes (showroom_id, date_alerte desc);
//   create index on gps_alertes (lue, date_alerte desc);

class GpsAlerte {
  final String   id;
  final String   showroomId;
  final String   vehiculeId;
  final String   vehiculeNom;
  final String   type;       // 'vitesse' | 'zone' | 'kilometrage' | 'autre'
  final String   message;
  final bool     lue;
  final DateTime dateAlerte;

  const GpsAlerte({
    required this.id,
    required this.showroomId,
    required this.vehiculeId,
    required this.vehiculeNom,
    required this.type,
    required this.message,
    required this.lue,
    required this.dateAlerte,
  });

  factory GpsAlerte.fromJson(Map<String, dynamic> json) => GpsAlerte(
    id:          json['id'] as String,
    showroomId:  json['showroom_id'] as String? ?? '',
    vehiculeId:  json['vehicule_id'] as String,
    vehiculeNom: json['vehicule_nom'] as String,
    type:        json['type'] as String,
    message:     json['message'] as String,
    lue:         json['lue'] as bool? ?? false,
    dateAlerte:  DateTime.parse(json['date_alerte'] as String),
  );

  GpsAlerte copyWith({bool? lue}) => GpsAlerte(
    id:          id,
    showroomId:  showroomId,
    vehiculeId:  vehiculeId,
    vehiculeNom: vehiculeNom,
    type:        type,
    message:     message,
    lue:         lue ?? this.lue,
    dateAlerte:  dateAlerte,
  );
}