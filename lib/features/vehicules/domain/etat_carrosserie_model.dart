// lib/features/vehicules/domain/etat_carrosserie_model.dart
//
// Modèle "pin libre" : l'utilisateur clique n'importe où sur l'image
// → un pin (x%, y%) est créé avec un type de dommage.
// Compatible avec les colonnes etat_carrosserie_depart / _retour (jsonb).

import 'dart:convert';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TYPE DE DOMMAGE
// ─────────────────────────────────────────────────────────────────────────────

enum TypeDommage {
  rayure,
  bosse,
  casse,
  autre;

  String get label => switch (this) {
    TypeDommage.rayure => 'Rayure',
    TypeDommage.bosse  => 'Bosse',
    TypeDommage.casse  => 'Cassé',
    TypeDommage.autre  => 'Autre',
  };

  String get emoji => switch (this) {
    TypeDommage.rayure => '〜',
    TypeDommage.bosse  => '◉',
    TypeDommage.casse  => '✕',
    TypeDommage.autre  => '?',
  };

  Color get color => switch (this) {
    TypeDommage.rayure => const Color(0xFFF59E0B),
    TypeDommage.bosse  => const Color(0xFFEF4444),
    TypeDommage.casse  => const Color(0xFF7C3AED),
    TypeDommage.autre  => const Color(0xFF6B7280),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// VUE DE LA VOITURE
// ─────────────────────────────────────────────────────────────────────────────

enum VueVoiture {
  profilGauche,
  profilDroit,
  dessus,
  avant,
  arriere;

  String get label => switch (this) {
    VueVoiture.profilGauche => 'Profil gauche',
    VueVoiture.profilDroit  => 'Profil droit',
    VueVoiture.dessus       => 'Vue dessus',
    VueVoiture.avant        => 'Vue avant',
    VueVoiture.arriere      => 'Vue arrière',
  };

  String get assetKey => switch (this) {
    VueVoiture.profilGauche => 'profil_gauche',
    VueVoiture.profilDroit  => 'profil_droit',
    VueVoiture.dessus       => 'dessus',
    VueVoiture.avant        => 'avant',
    VueVoiture.arriere      => 'arriere',
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN — un dommage libre placé par clic
// ─────────────────────────────────────────────────────────────────────────────

class PinDommage {
  final String id;          // uuid local
  final VueVoiture vue;
  final double xPct;        // 0.0 → 100.0 (pourcentage)
  final double yPct;
  final TypeDommage type;
  final String? note;

  const PinDommage({
    required this.id,
    required this.vue,
    required this.xPct,
    required this.yPct,
    required this.type,
    this.note,
  });

  PinDommage copyWith({TypeDommage? type, String? note}) => PinDommage(
    id:   id,
    vue:  vue,
    xPct: xPct,
    yPct: yPct,
    type: type ?? this.type,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id':   id,
    'vue':  vue.name,
    'x':    xPct,
    'y':    yPct,
    'type': type.name,
    if (note != null) 'note': note,
  };

  static PinDommage? fromJson(Map<String, dynamic> j) {
    try {
      return PinDommage(
        id:   j['id'] as String,
        vue:  VueVoiture.values.firstWhere((v) => v.name == j['vue']),
        xPct: (j['x'] as num).toDouble(),
        yPct: (j['y'] as num).toDouble(),
        type: TypeDommage.values.firstWhere((t) => t.name == j['type']),
        note: j['note'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÉTAT CARROSSERIE COMPLET
// ─────────────────────────────────────────────────────────────────────────────

class EtatCarrosserie {
  final List<PinDommage> pins;
  final String? observations;

  const EtatCarrosserie({
    this.pins = const [],
    this.observations,
  });

  bool get hasAnyDamage => pins.isNotEmpty;

  List<PinDommage> pinsParVue(VueVoiture vue) =>
      pins.where((p) => p.vue == vue).toList();

  // ── Sérialisation ──────────────────────────────────────────────────────────

  String toJsonString() => jsonEncode({
    'pins':         pins.map((p) => p.toJson()).toList(),
    'observations': observations,
  });

  static EtatCarrosserie fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return const EtatCarrosserie();
    try {
      final data  = jsonDecode(jsonStr) as Map<String, dynamic>;
      final pins  = ((data['pins'] as List?) ?? [])
          .map((e) => PinDommage.fromJson(e as Map<String, dynamic>))
          .whereType<PinDommage>()
          .toList();
      return EtatCarrosserie(
        pins:         pins,
        observations: data['observations'] as String?,
      );
    } catch (_) {
      return const EtatCarrosserie();
    }
  }

  // 🔧 CORRECTIF (points "perdus" en édition) : selon l'endroit d'où vient
  // la donnée, une colonne jsonb Supabase peut arriver côté Dart soit déjà
  // décodée en Map<String, dynamic>, soit comme une String JSON brute (si
  // elle a été re-sérialisée avant l'envoi), soit déjà comme un objet
  // EtatCarrosserie (quand elle vient directement du formulaire, sans
  // passer par la base). Utiliser un simple cast `as String?` sur une
  // valeur qui est en réalité un Map lève une exception de type, souvent
  // avalée silencieusement par un try/catch en amont → l'état retombe sur
  // "vide" sans erreur visible.
  //
  // Ce parseur unique gère les 3 cas de façon défensive. À utiliser
  // PARTOUT où un état carrosserie est lu depuis une source externe
  // (Supabase, formulaire, etc.) — au lieu de dupliquer des casts
  // différents (et donc incohérents) à chaque endroit.
  static EtatCarrosserie fromDynamic(dynamic raw) {
    if (raw == null) return const EtatCarrosserie();
    try {
      if (raw is EtatCarrosserie) return raw;
      if (raw is String) return fromJsonString(raw);
      if (raw is Map<String, dynamic>) return fromJsonString(jsonEncode(raw));
      if (raw is Map) {
        return fromJsonString(jsonEncode(Map<String, dynamic>.from(raw)));
      }
    } catch (_) {}
    return const EtatCarrosserie();
  }

  // ── Mutations immuables ────────────────────────────────────────────────────

  EtatCarrosserie addPin(PinDommage pin) =>
      EtatCarrosserie(pins: [...pins, pin], observations: observations);

  EtatCarrosserie removePin(String id) =>
      EtatCarrosserie(pins: pins.where((p) => p.id != id).toList(), observations: observations);

  EtatCarrosserie updatePin(String id, {TypeDommage? type, String? note}) =>
      EtatCarrosserie(
        pins: pins.map((p) => p.id == id ? p.copyWith(type: type, note: note) : p).toList(),
        observations: observations,
      );

  EtatCarrosserie copyWithObservations(String? obs) =>
      EtatCarrosserie(pins: pins, observations: obs);

  // ── Compat ancien modèle (zone fixe) ─────────────────────────────────────
  // Conservé pour ne pas casser les écrans qui appelaient copyWithZone
  EtatCarrosserie copyWithZone(String zoneId, dynamic type) => this;

  // Compat : zonesEndommagees → liste vide (les pins remplacent les zones)
  List<PinDommage> get zonesEndommagees => pins;
}