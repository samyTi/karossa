// lib/features/contrats/domain/contrat_template_model.dart

class ContratTemplate {
  final String id;
  final String type;        // location | vente | echange
  final String nom;
  final String? templateUrl; // URL Supabase Storage (si template externe)
  final Map<String, dynamic> config; // logo, couleurs, pied de page, etc.
  final bool isActive;
  final DateTime createdAt;

  const ContratTemplate({
    required this.id,
    required this.type,
    required this.nom,
    this.templateUrl,
    this.config = const {},
    required this.isActive,
    required this.createdAt,
  });

  // Informations du showroom dans la config
  String get showroomNom     => config['showroom_nom']     ?? 'Garage Auto';
  String get showroomAdresse => config['showroom_adresse'] ?? '';
  String get showroomTel     => config['showroom_tel']     ?? '';
  String get showroomEmail   => config['showroom_email']   ?? '';
  String get showroomRc      => config['showroom_rc']      ?? '';
  String? get logoUrl        => config['logo_url'];

  // Couleurs personnalisables
  String get couleurPrimaire => config['couleur_primaire'] ?? '#1A6FD4';

  factory ContratTemplate.fromJson(Map<String, dynamic> json) => ContratTemplate(
    id:          json['id'],
    type:        json['type'],
    nom:         json['nom'],
    templateUrl: json['template_url'],
    config:      Map<String, dynamic>.from(json['config'] ?? {}),
    isActive:    json['is_active'] ?? true,
    createdAt:   DateTime.parse(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'type':         type,
    'nom':          nom,
    'template_url': templateUrl,
    'config':       config,
    'is_active':    isActive,
  };

  ContratTemplate copyWith({
    String? nom,
    String? templateUrl,
    Map<String, dynamic>? config,
    bool? isActive,
  }) => ContratTemplate(
    id:          id,
    type:        type,
    nom:         nom ?? this.nom,
    templateUrl: templateUrl ?? this.templateUrl,
    config:      config ?? this.config,
    isActive:    isActive ?? this.isActive,
    createdAt:   createdAt,
  );
}
