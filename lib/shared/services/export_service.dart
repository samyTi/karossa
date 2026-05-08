// lib/shared/services/export_service.dart

// Service d'export des données en CSV



import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';

import 'package:intl/intl.dart';



class ExportService {

  static final _dateFormat = DateFormat('dd/MM/yyyy', 'fr');

  static final _nowFormat  = DateFormat('yyyyMMdd_HHmm');



  // ── Export Caisse ────────────────────────────────────────────

  static Future<void> exportCaisseCSV(List<Map<String, dynamic>> ops) async {

    final rows = <String>[];

    rows.add('Date;Type;Catégorie;Montant (DA);Description;Véhicule');



    for (final op in ops) {

      final date = op['date_op'] != null

        ? _dateFormat.format(DateTime.parse(op['date_op']))

        : '';

      final type = op['type'] == 'entree' ? 'Entrée' : 'Sortie';

      final cat  = _catLabel(op['categorie'] ?? '');

      final desc = (op['description'] as String? ?? '').replaceAll(';', ',');

      final mnt  = (op['montant'] as num?)?.toStringAsFixed(2) ?? '';

      final veh  = (op['vehicules'] as Map?)?['marque'] != null

        ? "${op['vehicules']['marque']} ${op['vehicules']['modele']}"

        : '';

      rows.add('$date;$type;$cat;$mnt;$desc;$veh');

    }



    await _shareCSV(rows.join('\n'), 'caisse_${_nowFormat.format(DateTime.now())}.csv');

  }



  // ── Export Locations ─────────────────────────────────────────

  static Future<void> exportLocationsCSV(List<dynamic> locations) async {

    final rows = <String>[];

    rows.add('Véhicule;Client;Début;Fin prévue;Fin réelle;Prix/j;Jours;Montant;Statut');



    for (final loc in locations) {

      rows.add(

        '\${loc.vehiculeNom ?? ''};\${loc.clientNom ?? ''};'

        '\$debut;\$finP;\$finR;\${loc.prixJour.toInt()};'

        '\${loc.nbJours ?? ''};\$mnt;\${loc.statut.name}'

      );

    }



    await _shareCSV(rows.join('\n'), 'locations_\${_nowFormat.format(DateTime.now())}.csv');

  }



  // ── Export Clients ───────────────────────────────────────────

  static Future<void> exportClientsCSV(List<dynamic> clients) async {

    final rows = <String>[];

    rows.add('Prénom;Nom;Téléphone;Email;Adresse;N° CNI;N° Permis;Statut');



    for (final c in clients) {

      rows.add(

        '\${c.prenom};\${c.nom};\${c.telephone};'

        '\${c.email ?? ''};\${c.adresse ?? ''};'

        '\${c.numCni ?? ''};\${c.numPermis ?? ''};'

        '\${c.statut.name}'

      );

    }



    await _shareCSV(rows.join('\n'), 'clients_\${_nowFormat.format(DateTime.now())}.csv');

  }



  // ── Utilitaire ───────────────────────────────────────────────

  static Future<void> _shareCSV(String content, String filename) async {

    final file = File('\${dir.path}/\$filename');

    // BOM UTF-8 pour Excel

    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...content.codeUnits]);

    await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Export \$filename'));

  }



  static String _catLabel(String cat) {

    const m = {

      'loyer_location': 'Loyer/Location',

      'vente_vehicule': 'Vente véhicule',

      'echange': 'Échange',

      'reparation': 'Réparation',

      'entretien': 'Entretien',

      'carburant': 'Carburant',

      'assurance': 'Assurance',

      'controle_technique': 'Contrôle tech.',

      'lavage': 'Lavage',

      'autre': 'Autre',

    };

    return m[cat] ?? cat;

  }

}

