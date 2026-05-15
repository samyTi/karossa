import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../data/caisse_operation.dart';
// Import du dossier screens qui est au même niveau que presentation/
import './caisse_detail_screen.dart';

class CaisseOpTile extends ConsumerWidget {
  final CaisseOperation op;
  const CaisseOpTile({super.key, required this.op});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Utilisation des couleurs définies dans votre thème
    final color = op.isEntree ? AppColors.secondary : AppColors.retard;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // ✅ Correction : Accès direct à 'op' (pas de 'widget.operation')
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CaisseDetailScreen(operation: op),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // Icône du type d'opération (Entrée / Sortie)
            Container(
              width: 36, 
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                op.isEntree
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: color, 
                size: 18),
            ),
            const SizedBox(width: 10),

            // Contenu principal (Description + Catégorie + Liens)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    op.description,
                    style: AppTextStyles.heading3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      _CatBadge(categorie: op.categorie),
                      const SizedBox(width: 6),
                      if (op.vehicule != null) ...[
                        const Icon(Icons.directions_car, size: 11, color: Colors.grey),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            '${op.vehicule!['marque']} ${op.vehicule!['modele']}',
                            style: AppTextStyles.label,
                            overflow: TextOverflow.ellipsis
                          )
                        ),
                      ],
                      // Badges automatiques selon les IDs présents
                      if (op.locationId != null)
                        const _LinkBadge('Location', Icons.home_outlined, Colors.blue),
                      if (op.venteId != null)
                        const _LinkBadge('Vente', Icons.sell_outlined, Colors.green),
                      if (op.reparationId != null)
                        const _LinkBadge('Répar.', Icons.build_outlined, Colors.orange),
                      if (op.echangeId != null)
                        const _LinkBadge('Échange', Icons.swap_horiz, Colors.purple),
                    ],
                  ),
                ],
              ),
            ),

            // Section Montant et Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${op.isEntree ? '+' : '-'}${op.montant.toStringAsFixed(0)} DA',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(_fmtDate(op.dateOp), style: AppTextStyles.label),
                if (op.photoFactureUrl != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.receipt_outlined, size: 12, color: Colors.grey),
                  ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  // Formatage simple de la date DD/MM/YYYY
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// Widget pour le badge de catégorie
class _CatBadge extends StatelessWidget {
  final String categorie;
  const _CatBadge({required this.categorie});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        // Accès à la map statique des labels dans votre modèle CaisseOperation
        CaisseOperation.categorieLabels[categorie] ?? categorie,
        style: const TextStyle(fontSize: 10, color: Colors.grey),
      ),
    );
  }
}

// Widget pour les petits badges de liens (Vente, Location, etc.)
class _LinkBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _LinkBadge(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(
            label, 
            style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600)
          ),
        ],
      ),
    );
  }
}