// lib/features/admin/domain/showroom_settings_model.dart

enum CommissionType { pct, fixe }

extension CommissionTypeExt on CommissionType {
  String get label => this == CommissionType.pct ? '%' : 'DA fixe';
  String get dbValue => name; // 'pct' | 'fixe'
  static CommissionType fromDb(String? v) =>
      v == 'fixe' ? CommissionType.fixe : CommissionType.pct;
}

/// Config de commission pour un type d'opération.
class CommissionConfig {
  final CommissionType type;
  final double valeur;

  const CommissionConfig({
    required this.type,
    required this.valeur,
  });

  /// Calcule le montant de commission à partir d'une base.
  double calculer(double base) =>
      type == CommissionType.pct ? base * valeur / 100 : valeur;

  /// Retourne le pourcentage effectif (pour affichage) si type == pct,
  /// sinon retourne null.
  double? get pct => type == CommissionType.pct ? valeur : null;

  CommissionConfig copyWith({CommissionType? type, double? valeur}) =>
      CommissionConfig(type: type ?? this.type, valeur: valeur ?? this.valeur);

  static CommissionConfig fromSettings(
      Map<String, dynamic> s, String opKey, double defaultValeur) {
    return CommissionConfig(
      type: CommissionTypeExt.fromDb(s['commission_${opKey}_type'] as String?),
      valeur: (s['commission_${opKey}_valeur'] as num?)?.toDouble() ??
          defaultValeur,
    );
  }
}

/// Modèle complet des paramètres du showroom.
class ShowroomSettings {
  final String? id;
  final String nom;
  final String? adresse;
  final String? tel;
  final String? email;
  final String? rc;
  final String? logoUrl;

  // GPS
  final String? flespiUrl;
  final String? flespiUser;
  final String? flespiPassword;
  final String? flespiToken;

  // IA
  final String? geminiApiKey;
  final String? geminiModel;

  // Commissions
  final CommissionConfig commissionVente;
  final CommissionConfig commissionEchange;
  final CommissionConfig commissionLocation;
  final CommissionConfig commissionAchat;

  const ShowroomSettings({
    this.id,
    required this.nom,
    this.adresse,
    this.tel,
    this.email,
    this.rc,
    this.logoUrl,
    this.flespiUrl,
    this.flespiUser,
    this.flespiPassword,
    this.flespiToken,
    this.geminiApiKey,
    this.geminiModel,
    required this.commissionVente,
    required this.commissionEchange,
    required this.commissionLocation,
    required this.commissionAchat,
  });

  factory ShowroomSettings.fromJson(Map<String, dynamic> j) {
    return ShowroomSettings(
      id: j['id'] as String?,
      nom: j['nom'] as String? ?? 'Garage Auto',
      adresse: j['adresse'] as String?,
      tel: j['tel'] as String?,
      email: j['email'] as String?,
      rc: j['rc'] as String?,
      logoUrl: j['logo_url'] as String?,
      flespiUrl: j['flespi_url'] as String?,
      flespiUser: j['flespi_user'] as String?,
      flespiPassword: j['flespi_password'] as String?,
      flespiToken: j['flespi_token'] as String?,
      geminiApiKey: j['gemini_api_key'] as String?,
      geminiModel: j['gemini_model'] as String?,
      commissionVente:
          CommissionConfig.fromSettings(j, 'vente', 5),
      commissionEchange:
          CommissionConfig.fromSettings(j, 'echange', 5),
      commissionLocation:
          CommissionConfig.fromSettings(j, 'location', 10),
      commissionAchat:
          CommissionConfig.fromSettings(j, 'achat', 5),
    );
  }

  /// Defaults quand la table est vide
  factory ShowroomSettings.defaults() => ShowroomSettings(
        nom: 'Garage Auto',
        commissionVente:    CommissionConfig(type: CommissionType.pct, valeur: 5),
        commissionEchange:  CommissionConfig(type: CommissionType.pct, valeur: 5),
        commissionLocation: CommissionConfig(type: CommissionType.pct, valeur: 10),
        commissionAchat:    CommissionConfig(type: CommissionType.pct, valeur: 5),
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nom': nom,
        'adresse': adresse,
        'tel': tel,
        'email': email,
        'rc': rc,
        'logo_url': logoUrl,
        'flespi_url': flespiUrl,
        'flespi_user': flespiUser,
        'flespi_password': flespiPassword,
        'flespi_token': flespiToken,
        'gemini_api_key': geminiApiKey,
        'gemini_model': geminiModel,
        'commission_vente_type':     commissionVente.type.dbValue,
        'commission_vente_valeur':   commissionVente.valeur,
        'commission_echange_type':   commissionEchange.type.dbValue,
        'commission_echange_valeur': commissionEchange.valeur,
        'commission_location_type':  commissionLocation.type.dbValue,
        'commission_location_valeur':commissionLocation.valeur,
        'commission_achat_type':     commissionAchat.type.dbValue,
        'commission_achat_valeur':   commissionAchat.valeur,
      };
}