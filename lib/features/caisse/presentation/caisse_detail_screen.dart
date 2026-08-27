import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';
// Importez votre modèle d'opération ici (ex: caisse_operation.dart)

class CaisseDetailScreen extends StatelessWidget {
  final dynamic operation; // Remplacez par votre modèle CaisseOperation

  const CaisseDetailScreen({super.key, required this.operation});

  @override
  Widget build(BuildContext context) {
    final isEntree = operation.type == 'entree';
    
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.detailsDeLOperation)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: Text(context.l10n.champMontant),
              subtitle: Text(
                '${operation.montant} DZD',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isEntree ? Colors.green : Colors.red,
                ),
              ),
              trailing: Icon(
                isEntree ? Icons.arrow_downward : Icons.arrow_upward,
                color: isEntree ? Colors.green : Colors.red,
              ),
            ),
          ),
          _buildInfoTile('Catégorie', operation.categorie),
          _buildInfoTile('Description', operation.description),
          _buildInfoTile('Date', DateFormat('dd/MM/yyyy HH:mm').format(operation.createdAt)),
          if (operation.vehiculeId != null)
            _buildInfoTile('Véhicule lié', 'ID: ${operation.vehiculeId}'),
          const SizedBox(height: 20),
          if (operation.photoFactureUrl != null)
            ElevatedButton.icon(
              onPressed: () { /* Logique pour voir la facture */ },
              icon: const Icon(Icons.receipt_long),
              label: Text(context.l10n.voirLaFacture),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(value),
    );
  }
}