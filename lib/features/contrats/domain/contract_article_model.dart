// lib/features/contrats/domain/contract_article_model.dart

/// Langue de l'article : 'fr' pour français, 'ar' pour arabe.
/// Détermine dans quelle section du PDF l'article sera injecté :
///   - 'fr' → page "CONDITIONS GENERALES" (LTR)
///   - 'ar' → page "الشروط العامة" (RTL)
enum ArticleLangue {
  fr,
  ar;

  static ArticleLangue fromString(String? value) =>
      value == 'ar' ? ArticleLangue.ar : ArticleLangue.fr;

  String get value => name; // 'fr' | 'ar'

  String get label => switch (this) {
    ArticleLangue.fr => 'Français',
    ArticleLangue.ar => 'Arabe / عربي',
  };
}

/// Types de contrat supportés par l'application.
enum ContratArticleType {
  location,
  vente,
  echange,
  achat;

  static ContratArticleType fromString(String? value) =>
      ContratArticleType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => ContratArticleType.vente,
      );

  String get value => name;
}

/// Opérateurs supportés pour les conditions d'affichage.
enum ConditionOp { gt, gte, lt, lte, eq, neq }

class ContractArticle {
  final String id;
  final ContratArticleType contratType;
  final String titre;
  final String corps;
  final int ordre;
  final bool obligatoire;
  final bool actif;
  final ArticleLangue langue;
  final Map<String, dynamic>? conditionJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ContractArticle({
    required this.id,
    required this.contratType,
    required this.titre,
    required this.corps,
    required this.ordre,
    this.obligatoire = false,
    this.actif = true,
    this.langue = ArticleLangue.fr,
    this.conditionJson,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ContractArticle.fromJson(Map<String, dynamic> json) => ContractArticle(
        id:           json['id'] as String,
        contratType:  ContratArticleType.fromString(json['contrat_type'] as String?),
        titre:        json['titre'] as String? ?? '',
        corps:        json['corps'] as String? ?? '',
        ordre:        json['ordre'] as int? ?? 0,
        obligatoire:  json['obligatoire'] as bool? ?? false,
        actif:        json['actif'] as bool? ?? true,
        langue:       ArticleLangue.fromString(json['langue'] as String?),
        conditionJson: json['condition_json'] != null
            ? Map<String, dynamic>.from(json['condition_json'] as Map)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'contrat_type':  contratType.value,
        'titre':         titre,
        'corps':         corps,
        'ordre':         ordre,
        'obligatoire':   obligatoire,
        'actif':         actif,
        'langue':        langue.value,
        'condition_json': conditionJson,
      };

  ContractArticle copyWith({
    String?               titre,
    String?               corps,
    int?                  ordre,
    bool?                 obligatoire,
    bool?                 actif,
    ArticleLangue?        langue,
    Map<String, dynamic>? conditionJson,
  }) => ContractArticle(
        id:            id,
        contratType:   contratType,
        titre:         titre        ?? this.titre,
        corps:         corps        ?? this.corps,
        ordre:         ordre        ?? this.ordre,
        obligatoire:   obligatoire  ?? this.obligatoire,
        actif:         actif        ?? this.actif,
        langue:        langue       ?? this.langue,
        conditionJson: conditionJson ?? this.conditionJson,
        createdAt:     createdAt,
        updatedAt:     DateTime.now(),
      );

  // ── Résolution des variables ────────────────────────────────

  /// Résout les {{variables}} dans le corps avec les données fournies.
  String resolveVariables(Map<String, String> data) =>
      _resolveTemplate(corps, data);

  /// Résout les {{variables}} dans le titre avec les données fournies.
  String resolveTitre(Map<String, String> data) =>
      _resolveTemplate(titre, data);

  String _resolveTemplate(String template, Map<String, String> data) {
    var result = template;
    for (final entry in data.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  // ── Évaluation de condition d'affichage ────────────────────

  /// Retourne `true` si l'article doit être affiché selon sa condition.
  /// Si aucune condition n'est définie, l'article est toujours affiché.
  bool evaluerCondition(Map<String, dynamic> contextData) {
    if (conditionJson == null) return true;
    try {
      final champ  = conditionJson!['champ']  as String?;
      final op     = conditionJson!['op']     as String?;
      final valeur = conditionJson!['valeur'];

      if (champ == null || op == null) return true;

      final contextVal = contextData[champ];
      if (contextVal == null) return false;

      // Comparaison numérique si possible, sinon comparaison de chaînes
      final cv = num.tryParse(contextVal.toString());
      final vv = num.tryParse(valeur.toString());

      if (cv != null && vv != null) {
        return switch (op) {
          '>'  => cv > vv,
          '>=' => cv >= vv,
          '<'  => cv < vv,
          '<=' => cv <= vv,
          '==' => cv == vv,
          '!=' => cv != vv,
          _    => true,
        };
      }

      // Fallback : comparaison de chaînes
      final cs = contextVal.toString();
      final vs = valeur.toString();
      return switch (op) {
        '==' => cs == vs,
        '!=' => cs != vs,
        _    => true,
      };
    } catch (_) {
      return true; // en cas d'erreur, on affiche l'article par défaut
    }
  }

  // ── Égalité & debug ────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContractArticle &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'ContractArticle(${contratType.value}, ${langue.value}, ordre: $ordre, "$titre")';
}