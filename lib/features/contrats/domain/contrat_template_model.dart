// lib/features/contrats/domain/contrat_template_model.dart

/// Types de contrat supportés.
/// Doit rester synchronisé avec ContratArticleType dans contract_article_model.dart.
enum ContratTemplateType {
  location,
  vente,
  echange,
  achat;

  static ContratTemplateType fromString(String? value) =>
      ContratTemplateType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => ContratTemplateType.vente,
      );

  String get value => name;

  String get label => switch (this) {
    ContratTemplateType.location => 'Location',
    ContratTemplateType.vente    => 'Vente',
    ContratTemplateType.echange  => 'Échange',
    ContratTemplateType.achat    => 'Achat',
  };
}

class ContratTemplate {
  final String id;
  final ContratTemplateType type;
  final String nom;
  final String? templateUrl;
  final Map<String, dynamic> config;
  final bool isActive;
  final DateTime createdAt;

  const ContratTemplate({
    required this.id,
    required this.type,
    required this.nom,
    this.templateUrl,
    this.config   = const {},
    required this.isActive,
    required this.createdAt,
  });

  // ── Informations showroom (extraites de config) ────────────

  String  get showroomNom     => config['showroom_nom']     as String? ?? 'Garage Auto';
  String  get showroomAdresse => config['showroom_adresse'] as String? ?? '';
  String  get showroomTel     => config['showroom_tel']     as String? ?? '';
  String  get showroomEmail   => config['showroom_email']   as String? ?? '';
  String  get showroomRc      => config['showroom_rc']      as String? ?? '';
  String? get logoUrl         => config['logo_url']         as String?;

  // ── Personnalisation visuelle ──────────────────────────────

  String get couleurPrimaire  => config['couleur_primaire'] as String? ?? '#1A6FD4';
  String get couleurSecondaire => config['couleur_secondaire'] as String? ?? '#F59E0B';
  String? get piedDePage      => config['pied_de_page']     as String?;

  // ── Sérialisation ──────────────────────────────────────────

  factory ContratTemplate.fromJson(Map<String, dynamic> json) => ContratTemplate(
    id:          json['id']           as String,
    type:        ContratTemplateType.fromString(json['type'] as String?),
    nom:         json['nom']          as String? ?? '',
    templateUrl: json['template_url'] as String?,
    config:      json['config'] != null
                   ? Map<String, dynamic>.from(json['config'] as Map)
                   : const {},
    isActive:    json['is_active']    as bool? ?? true,
    createdAt:   DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'type':         type.value,
    'nom':          nom,
    'template_url': templateUrl,
    'config':       config,
    'is_active':    isActive,
  };

  ContratTemplate copyWith({
    String?               nom,
    String?               templateUrl,
    Map<String, dynamic>? config,
    bool?                 isActive,
  }) => ContratTemplate(
    id:          id,
    type:        type,
    nom:         nom         ?? this.nom,
    templateUrl: templateUrl ?? this.templateUrl,
    config:      config      ?? this.config,
    isActive:    isActive    ?? this.isActive,
    createdAt:   createdAt,
  );

  /// Construit le contexte showroom pour la résolution des {{variables}} PDF.
  Map<String, String> toShowroomContext() => {
    'agence_nom':     showroomNom,
    'agence_adresse': showroomAdresse,
    'agence_tel':     showroomTel,
    'agence_email':   showroomEmail,
    'agence_rc':      showroomRc,
    'agence_logo':    logoUrl ?? '',
  };

  // ── Égalité & debug ────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContratTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ContratTemplate(${type.value}, "$nom", active: $isActive)';
}