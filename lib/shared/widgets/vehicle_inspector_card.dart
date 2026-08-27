// lib/shared/widgets/vehicle_inspector_card.dart
//
// Carte de saisie de l'état carrosserie à intégrer dans les formulaires
// de location (départ & retour), vente et échange.
/*
import 'package:flutter/material.dart';
import '../../features/vehicules/domain/etat_carrosserie_model.dart';
import '../../core/theme/app_colors.dart';
import 'vehicle_inspector_widget.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class VehicleInspectorCard extends StatefulWidget {
  final String title;
  final EtatCarrosserie etat;
  final ValueChanged<EtatCarrosserie> onChanged;
  final GlobalKey? repaintKey;

  const VehicleInspectorCard({
    super.key,
    this.title = 'État de la carrosserie',
    required this.etat,
    required this.onChanged,
    this.repaintKey,
  });

  @override
  State<VehicleInspectorCard> createState() => _VehicleInspectorCardState();
}

class _VehicleInspectorCardState extends State<VehicleInspectorCard> {
  bool _expanded = true;
  final _obsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _obsCtrl.text = widget.etat.observations ?? '';
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final damaged = widget.etat.zonesEndommagees;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: damaged.isNotEmpty
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.border,
          width: damaged.isNotEmpty ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── En-tête cliquable ─────────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (damaged.isNotEmpty ? AppColors.warning : AppColors.primary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.directions_car_outlined,
                    size: 18,
                    color: damaged.isNotEmpty ? AppColors.warning : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(
                        damaged.isEmpty
                            ? 'Appuyez sur une zone pour marquer un dommage'
                            : '${damaged.length} zone(s) endommagée(s)',
                        style: TextStyle(
                          fontSize: 11,
                          color: damaged.isNotEmpty ? AppColors.warning : AppColors.textSecondary,
                          fontWeight: damaged.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                // Badges des dommages
                if (damaged.isNotEmpty)
                  Wrap(spacing: 4, children: damaged.take(3).map((z) =>
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(color: z.type.color, shape: BoxShape.circle),
                    )
                  ).toList()),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                ),
              ]),
            ),
          ),

          // ── Corps ──────────────────────────────────────────────────────────
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: Column(children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Schéma voiture
                SizedBox(
                  height: 420,
                  child: VehicleInspectorWidget(
                    etat:       widget.etat,
                    readOnly:   false,
                    repaintKey: widget.repaintKey,
                    onChanged:  (updated) {
                      widget.onChanged(updated.copyWithObservations(_obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim()));
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Observations
                TextField(
                  controller: _obsCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.l10n.observationsComplementaires,
                    hintText: context.l10n.exPneuAvantUseJanteRayee,
                    filled: true,
                    fillColor: AppColors.inputFill,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    prefixIcon: const Icon(Icons.edit_note, size: 20),
                  ),
                  onChanged: (v) {
                    widget.onChanged(
                      widget.etat.copyWithObservations(v.trim().isEmpty ? null : v.trim()),
                    );
                  },
                ),
                // Bouton reset
                if (widget.etat.hasAnyDamage)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        _obsCtrl.clear();
                        widget.onChanged(const EtatCarrosserie());
                      },
                      icon: const Icon(Icons.clear, size: 14),
                      label: Text(context.l10n.toutEffacer, style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: AppColors.retard),
                    ),
                  ),
              ]),
            ),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VERSION LECTURE SEULE (pour le détail / historique)
// ─────────────────────────────────────────────────────────────────────────────

class VehicleInspectorReadOnly extends StatelessWidget {
  final EtatCarrosserie? etat;
  final String title;

  const VehicleInspectorReadOnly({
    super.key,
    required this.etat,
    this.title = 'État carrosserie',
  });

  @override
  Widget build(BuildContext context) {
    final e = etat ?? const EtatCarrosserie();
    if (!e.hasAnyDamage && (e.observations == null || e.observations!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.directions_car_outlined, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 10),
          if (e.hasAnyDamage) ...[
            SizedBox(
              height: 300,
              child: VehicleInspectorWidget(etat: e, readOnly: true),
            ),
            const SizedBox(height: 8),
          ],
          if (e.observations != null && e.observations!.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.note_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(e.observations!,
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
              ]),
            ),
        ],
      ),
    );
  }
}*/