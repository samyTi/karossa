// lib/shared/widgets/commission_field.dart
//
// Widget réutilisable pour saisir une commission (% ou montant fixe).
// Affiche en temps réel le montant calculé.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../features/admin/domain/showroom_settings_model.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

/// Résultat de la saisie de commission.
class CommissionValue {
  final CommissionType type;
  final double valeur;   // % ou DA selon type
  final double montant;  // DA calculé

  const CommissionValue({
    required this.type,
    required this.valeur,
    required this.montant,
  });

  double get pct => type == CommissionType.pct ? valeur : 0;
}

/// Widget de saisie de commission paramétrable.
///
/// [base]         : montant de référence pour le calcul (prix vente, etc.)
/// [config]       : config par défaut du showroom
/// [onChanged]    : appelé à chaque changement
/// [label]        : libellé affiché (défaut : 'Commission gérant')
class CommissionField extends StatefulWidget {
  final double base;
  final CommissionConfig? config;
  final ValueChanged<CommissionValue>? onChanged;
  final String label;

  const CommissionField({
    super.key,
    required this.base,
    this.config,
    this.onChanged,
    this.label = 'Commission gérant',
  });

  @override
  State<CommissionField> createState() => _CommissionFieldState();
}

class _CommissionFieldState extends State<CommissionField> {
  late CommissionType _type;
  late TextEditingController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _type = widget.config?.type ?? CommissionType.pct;
    final v = widget.config?.valeur ?? 5.0;
    _ctrl = TextEditingController(text: _fmt(v));
  }

  @override
  void didUpdateWidget(CommissionField old) {
    super.didUpdateWidget(old);
    // Pré-remplir seulement au premier chargement du config
    if (!_initialized && widget.config != null) {
      _initialized = true;
      _type = widget.config!.type;
      _ctrl.text = _fmt(widget.config!.valeur);
      WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  double get _valeur => double.tryParse(_ctrl.text) ?? 0;

  double get _montant {
    if (widget.base <= 0) return 0;
    return _type == CommissionType.pct
        ? widget.base * _valeur / 100
        : _valeur;
  }

  void _notify() {
    widget.onChanged?.call(CommissionValue(
      type: _type,
      valeur: _valeur,
      montant: _montant,
    ));
  }

  void _toggleType(CommissionType t) {
    if (_type == t) return;
    setState(() {
      // Conversion intelligente : pct → fixe conserve le montant calculé,
      // fixe → pct recalcule le % équivalent
      if (t == CommissionType.fixe) {
        _ctrl.text = _fmt(_montant);
      } else {
        final pctEquiv = widget.base > 0 ? (_valeur / widget.base * 100) : 5.0;
        _ctrl.text = _fmt(pctEquiv.clamp(0, 100));
      }
      _type = t;
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final montant = _montant;
    final suffix = _type == CommissionType.pct ? '%' : 'DA';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ligne label + toggle ─────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(widget.label, style: AppTextStyles.heading3),
            ),
            _TypeToggle(
              current: _type,
              onChanged: _toggleType,
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Champ de saisie ─────────────────────────────────────────
        TextFormField(
          controller: _ctrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText: widget.label,
            suffixText: suffix,
            suffixStyle: TextStyle(
              color: AppColors.gerant,
              fontWeight: FontWeight.bold,
            ),
            prefixIcon: Icon(
              _type == CommissionType.pct
                  ? Icons.percent
                  : Icons.attach_money,
              color: AppColors.gerant,
              size: 20,
            ),
          ),
          onChanged: (_) {
            setState(() {});
            _notify();
          },
        ),
        const SizedBox(height: 6),

        // ── Résumé calculé ──────────────────────────────────────────
        if (widget.base > 0)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.gerant.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.gerant.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate_outlined,
                    size: 16, color: AppColors.gerant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _type == CommissionType.pct
                        ? 'Commission : ${_valeur.toStringAsFixed(1)}% de ${widget.base.toInt()} DA'
                        : 'Montant fixe',
                    style: AppTextStyles.bodySecondary
                        .copyWith(fontSize: 12),
                  ),
                ),
                Text(
                  '${montant.toInt()} DA',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gerant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Toggle % / Fixe ────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final CommissionType current;
  final ValueChanged<CommissionType> onChanged;

  const _TypeToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gerant.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Chip(
            label: '%',
            active: current == CommissionType.pct,
            onTap: () => onChanged(CommissionType.pct),
          ),
          _Chip(
            label: context.l10n.uniteDa,
            active: current == CommissionType.fixe,
            onTap: () => onChanged(CommissionType.fixe),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.gerant : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.gerant,
            ),
          ),
        ),
      );
}