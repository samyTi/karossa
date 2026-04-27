#!/usr/bin/env python3
"""
fix_garage_auto.py
==================
Script de correction automatique pour le projet Flutter "garage_auto".
Corrige tous les bugs détectés lors de l'analyse du code source.

Usage:
    python fix_garage_auto.py [--project-dir <chemin>]

Par défaut, le script s'exécute depuis le répertoire courant.
"""

import os
import re
import sys
import shutil
import argparse
from pathlib import Path

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

parser = argparse.ArgumentParser(description="Corrige les bugs du projet garage_auto")
parser.add_argument("--project-dir", default=".", help="Répertoire racine du projet Flutter")
args = parser.parse_args()

PROJECT = Path(args.project_dir).resolve()
LIB     = PROJECT / "lib"

FIXES_APPLIED  = []
FIXES_SKIPPED  = []

def log_ok(msg):  print(f"  ✅  {msg}")
def log_skip(msg): print(f"  ⏭  {msg}")
def log_info(msg): print(f"  ℹ️  {msg}")
def log_warn(msg): print(f"  ⚠️  {msg}")
def log_section(title): print(f"\n{'─'*60}\n🔧  {title}\n{'─'*60}")

def read(path): return path.read_text(encoding="utf-8")
def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")

def replace_in_file(path, old, new, description):
    """Remplace old par new dans path. Retourne True si modification effectuée."""
    if not path.exists():
        log_warn(f"Fichier introuvable : {path.relative_to(PROJECT)}")
        FIXES_SKIPPED.append(description)
        return False
    content = read(path)
    if old in content:
        write(path, content.replace(old, new, 1))
        log_ok(description)
        FIXES_APPLIED.append(description)
        return True
    else:
        log_skip(f"Déjà corrigé ou non trouvé : {description}")
        FIXES_SKIPPED.append(description)
        return False

def create_file(path, content, description):
    """Crée ou remplace un fichier."""
    write(path, content)
    log_ok(description)
    FIXES_APPLIED.append(description)


# ─────────────────────────────────────────────────────────────────────────────
# BUG 1 — Provider en double : ventesProvider déclaré dans DEUX fichiers
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 1 — Provider en double : ventesProvider")

ventes_screen = LIB / "features/ventes/presentation/ventes_screen.dart"

# Supprimer la déclaration locale du provider dans ventes_screen.dart
# et ajouter l'import depuis ventes_provider.dart
old_dup = """import '../../../main.dart';

// Provider pour la liste des ventes
final ventesProvider = FutureProvider.autoDispose((ref) async {
  final data = await supabase
    .from('ventes')
    .select('*, vehicules(marque, modele, annee), clients(prenom, nom)')
    .order('created_at', ascending: false);
  return data as List<Map<String, dynamic>>;
});"""

new_dup = """import '../../../main.dart';
import 'ventes_provider.dart';"""

replace_in_file(
    ventes_screen,
    old_dup, new_dup,
    "ventes_screen.dart : suppression du provider en double + ajout import ventes_provider.dart"
)


# ─────────────────────────────────────────────────────────────────────────────
# BUG 2 — EmptyState : paramètres title / subtitle inexistants
#          Le widget n'accepte que icon + message.
#          Fichier concerné : gps_alerts_screen.dart
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 2 — EmptyState : paramètres title/subtitle inexistants")

gps_alerts = LIB / "features/gps/presentation/gps_alerts_screen.dart"

replace_in_file(
    gps_alerts,
    """return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'Aucune alerte',
              subtitle: 'Toutes les alertes GPS apparaîtront ici', message: '',
            );""",
    """return const EmptyState(
              icon: Icons.check_circle_outline,
              message: 'Aucune alerte GPS — toutes les alertes apparaîtront ici',
            );""",
    "gps_alerts_screen.dart : suppression des paramètres title/subtitle invalides dans EmptyState"
)


# ─────────────────────────────────────────────────────────────────────────────
# BUG 3 — Couche data/domain manquante pour le module Ventes
#          Le module n'a ni data/ ni domain/, contrairement aux autres modules.
#          On crée un VenteModel et un VentesRepository cohérents avec le reste.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 3 — Module Ventes : couches data/domain manquantes")

vente_model_path = LIB / "features/ventes/domain/vente_model.dart"
if not vente_model_path.exists():
    create_file(vente_model_path, """\
// lib/features/ventes/domain/vente_model.dart

enum VenteStatutPaiement { complet, partiel }

extension VenteStatutPaiementExt on VenteStatutPaiement {
  String get label => switch (this) {
    VenteStatutPaiement.complet  => 'Soldé',
    VenteStatutPaiement.partiel  => 'Partiel',
  };
}

class Vente {
  final String id;
  final String vehiculeId;
  final String? vehiculeNom;
  final String clientId;
  final String? clientNom;
  final double? prixCatalogue;
  final double prixVente;
  final double acompte;
  final double soldeRestant;
  final String modePaiement;
  final double commissionGerantPct;
  final double commissionGerantMnt;
  final VenteStatutPaiement statutPaiement;
  final String? notes;
  final String? contratPdfUrl;
  final DateTime createdAt;

  const Vente({
    required this.id,
    required this.vehiculeId,
    this.vehiculeNom,
    required this.clientId,
    this.clientNom,
    this.prixCatalogue,
    required this.prixVente,
    required this.acompte,
    required this.soldeRestant,
    required this.modePaiement,
    required this.commissionGerantPct,
    required this.commissionGerantMnt,
    required this.statutPaiement,
    this.notes,
    this.contratPdfUrl,
    required this.createdAt,
  });

  bool get isSolde => statutPaiement == VenteStatutPaiement.complet;

  factory Vente.fromJson(Map<String, dynamic> json) {
    final veh = json['vehicules'];
    final cli = json['clients'];
    return Vente(
      id:                    json['id'],
      vehiculeId:            json['vehicule_id'],
      vehiculeNom:           veh != null
                               ? '${veh["marque"]} ${veh["modele"]} ${veh["annee"] ?? ""}'.trim()
                               : null,
      clientId:              json['client_id'],
      clientNom:             cli != null
                               ? '${cli["prenom"]} ${cli["nom"]}'
                               : null,
      prixCatalogue:         (json['prix_catalogue'] as num?)?.toDouble(),
      prixVente:             (json['prix_vente'] as num? ?? 0).toDouble(),
      acompte:               (json['acompte'] as num? ?? 0).toDouble(),
      soldeRestant:          (json['solde_restant'] as num? ?? 0).toDouble(),
      modePaiement:          json['mode_paiement'] ?? 'especes',
      commissionGerantPct:   (json['commission_gerant_pct'] as num? ?? 0).toDouble(),
      commissionGerantMnt:   (json['commission_gerant_mnt'] as num? ?? 0).toDouble(),
      statutPaiement:        json['statut_paiement'] == 'complet'
                               ? VenteStatutPaiement.complet
                               : VenteStatutPaiement.partiel,
      notes:                 json['notes'],
      contratPdfUrl:         json['contrat_pdf_url'],
      createdAt:             DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'vehicule_id':            vehiculeId,
    'client_id':              clientId,
    'prix_catalogue':         prixCatalogue,
    'prix_vente':             prixVente,
    'acompte':                acompte,
    'solde_restant':          soldeRestant,
    'mode_paiement':          modePaiement,
    'commission_gerant_pct':  commissionGerantPct,
    'commission_gerant_mnt':  commissionGerantMnt,
    'statut_paiement':        statutPaiement.name,
    'notes':                  notes,
  };
}
""", "Création de lib/features/ventes/domain/vente_model.dart")
else:
    log_skip("vente_model.dart existe déjà")

ventes_repo_path = LIB / "features/ventes/data/ventes_repository.dart"
if not ventes_repo_path.exists():
    create_file(ventes_repo_path, """\
// lib/features/ventes/data/ventes_repository.dart

import 'package:flutter/foundation.dart';
import '../../../main.dart';
import '../domain/vente_model.dart';

class VentesRepository {
  static final VentesRepository _i = VentesRepository._internal();
  factory VentesRepository() => _i;
  VentesRepository._internal();

  Future<List<Vente>> getAll() async {
    try {
      final data = await supabase
          .from('ventes')
          .select('''
            *,
            vehicules(marque, modele, annee, immatriculation),
            clients(prenom, nom, telephone)
          ''')
          .order('created_at', ascending: false);
      return (data as List).map((j) => Vente.fromJson(j)).toList();
    } catch (e) {
      debugPrint('VentesRepository.getAll: $e');
      return [];
    }
  }

  Future<Vente?> getById(String id) async {
    try {
      final data = await supabase
          .from('ventes')
          .select('*, vehicules(marque, modele, annee), clients(prenom, nom)')
          .eq('id', id)
          .single();
      return Vente.fromJson(data);
    } catch (e) {
      debugPrint('VentesRepository.getById: $e');
      return null;
    }
  }

  Future<Vente?> create(Map<String, dynamic> payload) async {
    try {
      final data = await supabase
          .from('ventes')
          .insert(payload)
          .select()
          .single();
      return Vente.fromJson(data);
    } catch (e) {
      debugPrint('VentesRepository.create: $e');
      return null;
    }
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    try {
      await supabase.from('ventes').update(payload).eq('id', id);
    } catch (e) {
      debugPrint('VentesRepository.update: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    try {
      final ventes = await supabase
          .from('ventes')
          .select('prix_vente, acompte, statut_paiement, created_at');
      final list = ventes as List;
      final total   = list.length;
      final revenu  = list.fold<double>(
          0, (s, v) => s + ((v['prix_vente'] as num?)?.toDouble() ?? 0));
      final encaisse = list.fold<double>(
          0, (s, v) => s + ((v['acompte'] as num?)?.toDouble() ?? 0));
      return {
        'total':    total,
        'revenu':   revenu,
        'encaisse': encaisse,
        'moyen':    total > 0 ? revenu / total : 0.0,
      };
    } catch (e) {
      debugPrint('VentesRepository.getStats: $e');
      return {'total': 0, 'revenu': 0.0, 'encaisse': 0.0, 'moyen': 0.0};
    }
  }
}
""", "Création de lib/features/ventes/data/ventes_repository.dart")
else:
    log_skip("ventes_repository.dart existe déjà")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 4 — settings_screen.dart utilise AppTextStyles.heading3.copyWith(...)
#          mais heading3 est de type TextStyle (pas ThemeExtension).
#          On vérifie que la méthode copyWith() est bien disponible.
#          (heading3 est déjà un TextStyle → c'est valide, pas de bug ici)
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 4 — Vérification AppTextStyles.heading3.copyWith (OK)")
log_skip("heading3 est un TextStyle — copyWith() est valide, aucune correction nécessaire")
FIXES_SKIPPED.append("AppTextStyles.heading3.copyWith() — valide")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 5 — ventes_provider.dart redéfinit ventesProvider avec un type différent
#          (List<Map<...>> vs type inféré). Harmonisation du type de retour.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 5 — ventes_provider.dart : harmonisation du type de retour")

ventes_provider = LIB / "features/ventes/presentation/ventes_provider.dart"

# Le statsVentesProvider dans ventes_provider.dart accède à (ventes as List)
# alors que la requête retourne déjà un List. Supprimer le cast inutile et
# potentiellement buggé.
replace_in_file(
    ventes_provider,
    "  final total  = (ventes as List).length;",
    "  final total  = (ventes as List<dynamic>).length;",
    "ventes_provider.dart : cast explicite List<dynamic> pour éviter l'erreur de type"
)


# ─────────────────────────────────────────────────────────────────────────────
# BUG 6 — Module Home : dossier presentation/ vide (aucun fichier)
#          Le router ne référence pas de HomeScreen mais le dossier doit rester.
#          Aucune action requise (le _MoreScreen dans le router remplace Home).
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 6 — Module Home : dossier presentation/ vide")
log_skip("Le dossier home/presentation/ est vide intentionnellement — le dashboard remplace l'écran d'accueil. Aucune correction nécessaire.")
FIXES_SKIPPED.append("home/presentation/ vide — intentionnel")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 7 — Contrats : aucun écran de gestion des templates de contrats
#          Le module a un provider + repository mais pas de page d'interface.
#          On crée l'écran de gestion des templates.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 7 — Module Contrats : écran de gestion manquant")

contrats_screen_path = LIB / "features/contrats/presentation/contrats_screen.dart"
if not contrats_screen_path.exists():
    create_file(contrats_screen_path, """\
// lib/features/contrats/presentation/contrats_screen.dart
// Gestion des templates de contrats et paramètres showroom

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import 'contrats_provider.dart';
import '../domain/contrat_template_model.dart';
import '../data/contrats_repository.dart';

class ContratsScreen extends ConsumerWidget {
  const ContratsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(contractTemplatesProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Modèles de contrats',
        showBackButton: true,
        showHomeButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau modèle'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur : $e')),
        data: (templates) {
          if (templates.isEmpty) {
            return const EmptyState(
              icon: Icons.description_outlined,
              message: 'Aucun modèle de contrat configuré',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (_, i) => _TemplateCard(template: templates[i]),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nomCtrl  = TextEditingController();
    String type    = 'location';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nouveau modèle de contrat'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nomCtrl,
              decoration: const InputDecoration(labelText: 'Nom du modèle'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'location', child: Text('Location')),
                DropdownMenuItem(value: 'vente',    child: Text('Vente')),
                DropdownMenuItem(value: 'echange',  child: Text('Échange')),
              ],
              onChanged: (v) => setS(() => type = v!),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                if (nomCtrl.text.trim().isEmpty) return;
                await ContratsRepository().createTemplate(
                  ContratTemplate(
                    id:        '',
                    type:      type,
                    nom:       nomCtrl.text.trim(),
                    isActive:  true,
                    createdAt: DateTime.now(),
                  ),
                );
                ref.refresh(contractTemplatesProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final ContratTemplate template;
  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (template.type) {
      'location' => (Icons.car_rental, AppColors.primary),
      'vente'    => (Icons.sell,       AppColors.secondary),
      'echange'  => (Icons.swap_horiz, AppColors.accent),
      _          => (Icons.description, AppColors.textSecondary),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title:    Text(template.nom, style: AppTextStyles.heading3),
        subtitle: Text(
          'Type : ${template.type}   •   '
          '${template.isActive ? "Actif" : "Inactif"}',
          style: AppTextStyles.bodySecondary,
        ),
        trailing: template.isActive
            ? const Icon(Icons.check_circle, color: AppColors.secondary, size: 20)
            : const Icon(Icons.cancel_outlined, color: AppColors.textHint, size: 20),
      ),
    );
  }
}
""", "Création de lib/features/contrats/presentation/contrats_screen.dart")
else:
    log_skip("contrats_screen.dart existe déjà")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 8 — app_router.dart : la route /admin/settings mène à SettingsScreen
#          qui charge les paramètres Traccar, mais il n'existe pas de route
#          dédiée pour /contrats. On ajoute la route dans le router.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 8 — Router : route /contrats manquante")

router_file = LIB / "core/router/app_router.dart"

# Ajouter l'import de contrats_screen
replace_in_file(
    router_file,
    "import '../../features/gps/presentation/gps_alerts_screen.dart';",
    "import '../../features/gps/presentation/gps_alerts_screen.dart';\n"
    "import '../../features/contrats/presentation/contrats_screen.dart';",
    "app_router.dart : ajout import ContratsScreen"
)

# Ajouter la route /contrats dans la liste des routes
replace_in_file(
    router_file,
    "      GoRoute(path: '/gps',\n        builder: (_, __) => const GpsMapScreen()),",
    "      GoRoute(path: '/contrats',\n        builder: (_, __) => const ContratsScreen()),\n\n      // ── GPS (NOUVEAU) ─────────────────────────────────────\n      GoRoute(path: '/gps',\n        builder: (_, __) => const GpsMapScreen()),",
    "app_router.dart : ajout route /contrats"
)

# Ajouter le lien vers /contrats dans le _MoreScreen menu Administration
replace_in_file(
    router_file,
    "_MenuCategory(title: 'Administration', items: [\n            _MI('Utilisateurs', Icons.manage_accounts, AppColors.primary, '/admin/users'),\n            _MI('Paramètres',   Icons.settings,        AppColors.textSecondary, '/admin/settings'),\n            _MI('Mon profil',   Icons.person,          AppColors.primary, '/profil'),",
    "_MenuCategory(title: 'Administration', items: [\n            _MI('Utilisateurs', Icons.manage_accounts, AppColors.primary, '/admin/users'),\n            _MI('Paramètres',   Icons.settings,        AppColors.textSecondary, '/admin/settings'),\n            _MI('Contrats',     Icons.description,     AppColors.accent,  '/contrats'),\n            _MI('Mon profil',   Icons.person,          AppColors.primary, '/profil'),",
    "app_router.dart : ajout entrée Contrats dans le menu Administration"
)


# ─────────────────────────────────────────────────────────────────────────────
# BUG 9 — gps_map_screen.dart : Navigator.push() au lieu de context.go()
#          pour naviguer vers GpsAlertsScreen — incohérence de navigation
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 9 — gps_map_screen.dart : Navigator.push → context.push")

gps_map = LIB / "features/gps/presentation/gps_map_screen.dart"

replace_in_file(
    gps_map,
    "import 'package:flutter_map/flutter_map.dart';",
    "import 'package:flutter_map/flutter_map.dart';\nimport 'package:go_router/go_router.dart';",
    "gps_map_screen.dart : ajout import go_router"
)

replace_in_file(
    gps_map,
    "                  onPressed: () => Navigator.push(context,\n                    MaterialPageRoute(builder: (_) => const GpsAlertsScreen())),",
    "                  onPressed: () => context.push('/gps/alertes'),",
    "gps_map_screen.dart : remplacement Navigator.push par context.push('/gps/alertes')"
)


# ─────────────────────────────────────────────────────────────────────────────
# BUG 10 — location_form_screen.dart : orElse retourne .first sans null-check
#           Si la liste est vide, .first lèvera une exception.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 10 — location_form_screen.dart : orElse potentiellement null")

loc_form = LIB / "features/locations/presentation/location_form_screen.dart"

replace_in_file(
    loc_form,
    "        final veh = ref.read(vehiculesProvider).valueOrNull\n          ?.firstWhere((v) => v.id == widget.vehiculeId,\n            orElse: () => ref.read(vehiculesProvider)\n              .valueOrNull!.first);",
    "        final allVehicules = ref.read(vehiculesProvider).valueOrNull ?? [];\n        final veh = allVehicules.isNotEmpty\n            ? allVehicules.firstWhere(\n                (v) => v.id == widget.vehiculeId,\n                orElse: () => allVehicules.first)\n            : null;",
    "location_form_screen.dart : correction orElse avec null-safety sur liste vide"
)


# ─────────────────────────────────────────────────────────────────────────────
# BUG 11 — pubspec.yaml : dossier assets/ déclaré mais potentiellement absent
#           On crée les dossiers vides avec un .gitkeep pour éviter l'erreur
#           "No file or variants found for asset" au build.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 11 — Dossiers assets/ manquants")

for folder in ["assets/images", "assets/icons", "assets/fonts"]:
    asset_dir = PROJECT / folder
    asset_dir.mkdir(parents=True, exist_ok=True)
    keep_file = asset_dir / ".gitkeep"
    if not keep_file.exists():
        keep_file.touch()
        log_ok(f"Création de {folder}/.gitkeep")
        FIXES_APPLIED.append(f"Création dossier {folder}/")
    else:
        log_skip(f"{folder}/ existe déjà")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 12 — ventes_screen.dart : statsVentesProvider importé depuis
#           ventes_provider.dart n'est jamais utilisé dans l'écran
#           (le calcul est fait localement dans _StatsBanner).
#           Pas d'erreur de compilation, mais provider inutilisé → OK.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 12 — statsVentesProvider non utilisé dans ventes_screen (warning)")
log_skip("statsVentesProvider est défini dans ventes_provider.dart mais non utilisé dans ventes_screen.dart — pas d'erreur de compilation, juste un dead-code provider.")
FIXES_SKIPPED.append("statsVentesProvider non utilisé — avertissement seulement")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 13 — fichiers .bak présents dans lib/ — Flutter les compile aussi !
#           Il faut les déplacer hors du dossier lib/.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 13 — Fichiers .bak dans lib/ (compilés par Flutter)")

bak_dir = PROJECT / "_bak"
bak_dir.mkdir(exist_ok=True)
bak_files = list(LIB.rglob("*.bak"))

if bak_files:
    for bak in bak_files:
        rel = bak.relative_to(LIB)
        dest = bak_dir / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(bak), str(dest))
        log_ok(f"Déplacé : lib/{rel} → _bak/{rel}")
        FIXES_APPLIED.append(f"Fichier .bak déplacé : {rel}")
else:
    log_skip("Aucun fichier .bak trouvé dans lib/")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 14 — auth_provider.dart : authProvider renvoie AuthProvider (classe)
#           dont le nom entre en conflit avec le nom du Provider lui-même.
#           Renommage de la classe en AuthService pour éviter la confusion.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 14 — auth_provider.dart : conflit de nom AuthProvider (Provider vs Classe)")

auth_provider_file = LIB / "features/auth/presentation/auth_provider.dart"

replace_in_file(
    auth_provider_file,
    "/// Provider pour l'authentification (connexion/déconnexion)\nfinal authProvider = Provider<AuthProvider>((ref) {\n  return AuthProvider();\n});\n\n/// Classe pour gérer l'authentification\nclass AuthProvider {",
    "/// Provider pour l'authentification (connexion/déconnexion)\nfinal authProvider = Provider<AuthService>((ref) {\n  return AuthService();\n});\n\n/// Classe pour gérer l'authentification\nclass AuthService {",
    "auth_provider.dart : renommage AuthProvider (classe) → AuthService pour éviter conflit de nom"
)

# Mettre à jour les utilisations éventuelles de AuthProvider dans d'autres fichiers
for dart_file in LIB.rglob("*.dart"):
    if dart_file == auth_provider_file:
        continue
    content = read(dart_file)
    if "AuthProvider" in content and "auth_provider" in content:
        new_content = content.replace("AuthProvider()", "AuthService()")
        new_content = new_content.replace("Provider<AuthProvider>", "Provider<AuthService>")
        if new_content != content:
            write(dart_file, new_content)
            log_ok(f"{dart_file.name} : mise à jour référence AuthProvider → AuthService")
            FIXES_APPLIED.append(f"{dart_file.name} : référence AuthService mise à jour")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 15 — caisse_screen.dart : FloatingActionButton absent pour les rôles
#           autorisés. Le bouton "Nouvelle opération" s'affiche via _showOpDialog
#           mais il n'y a pas de FAB visible dans le Scaffold principal.
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 15 — caisse_screen.dart : FAB manquant dans le Scaffold principal")

caisse = LIB / "features/caisse/presentation/caisse_screen.dart"
content = read(caisse) if caisse.exists() else ""

# Vérifier si le FAB est déjà présent
if caisse.exists() and "floatingActionButton" not in content:
    # Trouver le pattern du Scaffold pour insérer le FAB
    old_scaffold = "      body: ops.when("
    new_scaffold = """\
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _showOpDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle opération'),
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
            )
          : null,
      body: ops.when("""
    replace_in_file(
        caisse,
        old_scaffold,
        new_scaffold,
        "caisse_screen.dart : ajout du FloatingActionButton conditionnel"
    )
else:
    log_skip("caisse_screen.dart : FAB déjà présent ou fichier introuvable")


# ─────────────────────────────────────────────────────────────────────────────
# BUG 16 — main.dart : vérifier la présence de supabase global + ProviderScope
# ─────────────────────────────────────────────────────────────────────────────
log_section("BUG 16 — main.dart : vérification configuration Supabase")

main_file = LIB / "main.dart"
if main_file.exists():
    main_content = read(main_file)
    if "supabase" not in main_content:
        log_warn("main.dart : variable 'supabase' introuvable ! Vérifiez la configuration Supabase.")
    else:
        log_skip("main.dart : configuration Supabase présente — OK")
else:
    log_warn("main.dart introuvable !")


# ─────────────────────────────────────────────────────────────────────────────
# RÉSUMÉ FINAL
# ─────────────────────────────────────────────────────────────────────────────

print(f"""
{'═'*60}
📋  RÉSUMÉ DES CORRECTIONS
{'═'*60}
✅  Corrections appliquées  : {len(FIXES_APPLIED)}
⏭   Déjà corrigés / ignorés : {len(FIXES_SKIPPED)}

DÉTAIL DES CORRECTIONS :
""")

for i, f in enumerate(FIXES_APPLIED, 1):
    print(f"  {i:2}. {f}")

print(f"""
{'─'*60}
PROCHAINES ÉTAPES :
  1. Vérifiez que Flutter SDK est installé
  2. Exécutez : flutter pub get
  3. Exécutez : flutter analyze
  4. Testez sur Android, iOS et Desktop avec : flutter run

En cas d'erreurs résiduelles, vérifiez :
  • La configuration Supabase dans lib/main.dart (URL + anon key)
  • Les tables Supabase : ventes, locations, vehicules, clients,
    echanges, achats, caisse_operations, contract_templates,
    showroom_settings, profiles
  • L'accès réseau au serveur Traccar (GPS)
{'═'*60}
""")
