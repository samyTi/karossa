// lib/features/contrats/domain/contract_article_model.dart

/// Langue de l'article : 'fr' pour français, 'ar' pour arabe.
/// Ce champ détermine dans quelle section du PDF l'article sera injecté :
///   - 'fr' → page "CONDITIONS GENERALES" (version française, LTR)
///   - 'ar' → page "الشروط العامة" (version arabe, RTL)
enum ArticleLangue {
  fr,
  ar;

  static ArticleLangue fromString(String? value) =>
      value == 'ar' ? ArticleLangue.ar : ArticleLangue.fr;

  String get value => name; // 'fr' | 'ar'

  String get label => this == ArticleLangue.fr ? 'Français' : 'Arabe / عربي';
}

class ContractArticle {
  final String id;
  final String contratType; // 'location' | 'vente' | 'echange'
  final String titre;
  final String corps;
  final int ordre;
  final bool obligatoire;
  final bool actif;

  /// Langue de l'article : détermine dans quelle version du PDF il apparaît.
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
        id: json['id'] as String,
        contratType: json['contrat_type'] as String,
        titre: json['titre'] as String,
        corps: json['corps'] as String,
        ordre: json['ordre'] as int? ?? 0,
        obligatoire: json['obligatoire'] as bool? ?? false,
        actif: json['actif'] as bool? ?? true,
        langue: ArticleLangue.fromString(json['langue'] as String?),
        conditionJson: json['condition_json'] != null
            ? Map<String, dynamic>.from(json['condition_json'])
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'contrat_type': contratType,
        'titre': titre,
        'corps': corps,
        'ordre': ordre,
        'obligatoire': obligatoire,
        'actif': actif,
        'langue': langue.value,
        'condition_json': conditionJson,
      };

  ContractArticle copyWith({
    String? titre,
    String? corps,
    int? ordre,
    bool? obligatoire,
    bool? actif,
    ArticleLangue? langue,
    Map<String, dynamic>? conditionJson,
  }) =>
      ContractArticle(
        id: id,
        contratType: contratType,
        titre: titre ?? this.titre,
        corps: corps ?? this.corps,
        ordre: ordre ?? this.ordre,
        obligatoire: obligatoire ?? this.obligatoire,
        actif: actif ?? this.actif,
        langue: langue ?? this.langue,
        conditionJson: conditionJson ?? this.conditionJson,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  /// Résout les {{variables}} avec les données fournies.
  String get corpsResolu => corps;

  String resolveVariables(Map<String, String> data) {
    var result = corps;
    data.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });
    return result;
  }

  String resolveTitre(Map<String, String> data) {
    var result = titre;
    data.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value);
    });
    return result;
  }

  /// Évalue la condition d'affichage si elle existe.
  bool evaluerCondition(Map<String, dynamic> contextData) {
    if (conditionJson == null) return true;
    try {
      final champ = conditionJson!['champ'] as String;
      final op = conditionJson!['op'] as String;
      final valeur = conditionJson!['valeur'];
      final contextVal = contextData[champ];
      if (contextVal == null) return false;
      final cv = num.tryParse(contextVal.toString()) ?? 0;
      final vv = num.tryParse(valeur.toString()) ?? 0;
      switch (op) {
        case '>':  return cv > vv;
        case '>=': return cv >= vv;
        case '<':  return cv < vv;
        case '<=': return cv <= vv;
        case '==': return cv == vv || contextVal.toString() == valeur.toString();
        case '!=': return cv != vv;
        default:   return true;
      }
    } catch (_) {
      return true;
    }
  }
}