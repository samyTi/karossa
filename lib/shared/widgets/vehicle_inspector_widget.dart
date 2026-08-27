// lib/shared/widgets/vehicle_inspector_widget.dart
//
// Widget "pin libre" — identique au comportement HTML/JS fourni :
//   • Tap sur l'image → ouvre un sélecteur de type → place un pin rouge
//   • Tap sur un pin existant → supprime ou modifie
//   • Coordonnées stockées en pourcentage (responsive)
//   • 5 images SVG via CustomPainter (car_painters.dart)
/*
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/vehicules/domain/etat_carrosserie_model.dart';
import '../../core/theme/app_colors.dart';
import 'car_painters.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER PAR VUE
// ─────────────────────────────────────────────────────────────────────────────

CustomPainter _painterForVue(VueVoiture vue) => switch (vue) {
  VueVoiture.profilGauche => const CarSidePainter(mirrored: false),
  VueVoiture.profilDroit  => const CarSidePainter(mirrored: true),
  VueVoiture.dessus       => const CarTopPainter(),
  VueVoiture.avant        => const CarFrontPainter(),
  VueVoiture.arriere      => const CarRearPainter(),
};

// Ratio W/H de chaque vue (aspectRatio pour AspectRatio widget)
double _aspectRatioForVue(VueVoiture vue) => switch (vue) {
  VueVoiture.profilGauche || VueVoiture.profilDroit => 2.1,
  VueVoiture.dessus                                  => 0.46,
  VueVoiture.avant || VueVoiture.arriere             => 0.92,
};

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class VehicleInspectorWidget extends StatefulWidget {
  final EtatCarrosserie etat;
  final bool readOnly;
  final ValueChanged<EtatCarrosserie>? onChanged;
  final GlobalKey? repaintKey;

  const VehicleInspectorWidget({
    super.key,
    required this.etat,
    this.readOnly = false,
    this.onChanged,
    this.repaintKey,
  });

  @override
  State<VehicleInspectorWidget> createState() => _VehicleInspectorWidgetState();
}

class _VehicleInspectorWidgetState extends State<VehicleInspectorWidget> {
  late EtatCarrosserie _etat;

  @override
  void initState() {
    super.initState();
    _etat = widget.etat;
  }

  @override
  void didUpdateWidget(VehicleInspectorWidget old) {
    super.didUpdateWidget(old);
    if (old.etat != widget.etat) _etat = widget.etat;
  }

  // ── Ajout d'un pin ─────────────────────────────────────────────────────────

  Future<void> _onImageTap(VueVoiture vue, double xPct, double yPct) async {
    if (widget.readOnly) return;

    // Feedback haptique
    HapticFeedback.lightImpact();

    // Sélection du type de dommage
    final type = await _showTypePicker();
    if (type == null || !mounted) return;

    final pin = PinDommage(
      id:   '${vue.name}_${DateTime.now().millisecondsSinceEpoch}',
      vue:  vue,
      xPct: xPct,
      yPct: yPct,
      type: type,
    );

    final updated = _etat.addPin(pin);
    setState(() => _etat = updated);
    widget.onChanged?.call(updated);
  }

  // ── Tap sur un pin existant ────────────────────────────────────────────────

  Future<void> _onPinTap(PinDommage pin) async {
    if (widget.readOnly) return;
    HapticFeedback.mediumImpact();

    final action = await _showPinActions(pin);
    if (action == null || !mounted) return;

    EtatCarrosserie updated;
    if (action == 'delete') {
      updated = _etat.removePin(pin.id);
    } else {
      // action == TypeDommage.name
      final newType = TypeDommage.values.firstWhere((t) => t.name == action);
      updated = _etat.updatePin(pin.id, type: newType);
    }
    setState(() => _etat = updated);
    widget.onChanged?.call(updated);
  }

  // ── Sélecteur de type (bottom sheet) ──────────────────────────────────────

  Future<TypeDommage?> _showTypePicker() {
    return showModalBottomSheet<TypeDommage>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TypePickerSheet(),
    );
  }

  Future<String?> _showPinActions(PinDommage pin) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinActionsSheet(pin: pin),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final child = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.readOnly) _buildHint(),
        const SizedBox(height: 8),
        _buildLegend(),
        const SizedBox(height: 10),
        _buildAllViews(),
        if (_etat.hasAnyDamage) ...[
          const SizedBox(height: 10),
          _buildDommagesList(),
        ],
      ],
    );

    if (widget.repaintKey != null) {
      return RepaintBoundary(key: widget.repaintKey, child: child);
    }
    return child;
  }

  Widget _buildHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Icon(Icons.touch_app_rounded, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Appuyez sur la zone endommagée pour marquer un dommage. Appuyez sur un pin pour le modifier ou supprimer.',
            style: TextStyle(fontSize: 11, color: AppColors.primary, height: 1.4),
          ),
        ),
      ]),
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TypeDommage.values.map((t) =>
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: t.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(t.label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
        ).toList(),
      ),
    );
  }

  Widget _buildAllViews() {
    return Column(children: [
      // Ligne 1 : 2 profils
      Row(children: [
        Expanded(child: _buildVueCard(VueVoiture.profilGauche)),
        const SizedBox(width: 8),
        Expanded(child: _buildVueCard(VueVoiture.profilDroit)),
      ]),
      const SizedBox(height: 8),
      // Ligne 2 : vue dessus (centré, largeur limitée)
      Center(
        child: SizedBox(
          width: 160,
          child: _buildVueCard(VueVoiture.dessus),
        ),
      ),
      const SizedBox(height: 8),
      // Ligne 3 : avant + arrière
      Row(children: [
        Expanded(child: _buildVueCard(VueVoiture.avant)),
        const SizedBox(width: 8),
        Expanded(child: _buildVueCard(VueVoiture.arriere)),
      ]),
    ]);
  }

  Widget _buildVueCard(VueVoiture vue) {
    final pins      = _etat.pinsParVue(vue);
    final hasDamage = pins.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasDamage
              ? AppColors.warning.withValues(alpha: 0.5)
              : AppColors.border,
          width: hasDamage ? 1.5 : 1,
        ),
      ),
      child: Column(children: [
        // Label
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: hasDamage
                ? AppColors.warning.withValues(alpha: 0.08)
                : AppColors.inputFill,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasDamage) ...[
                Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.warning, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                vue.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: hasDamage ? AppColors.warning : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasDamage) ...[
                const SizedBox(width: 4),
                Text(
                  '${pins.length}',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        // Zone interactive
        AspectRatio(
          aspectRatio: _aspectRatioForVue(vue),
          child: _CarViewInteractive(
            vue:      vue,
            pins:     pins,
            readOnly: widget.readOnly,
            onTap:    (x, y) => _onImageTap(vue, x, y),
            onPinTap: _onPinTap,
          ),
        ),
      ]),
    );
  }

  Widget _buildDommagesList() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              '${_etat.pins.length} dommage${_etat.pins.length > 1 ? "s" : ""} constaté${_etat.pins.length > 1 ? "s" : ""}',
              style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6, runSpacing: 6,
            children: _etat.pins.map((p) => _PinBadge(pin: p)).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VUE INTERACTIVE — dessin + tap + pins
// ─────────────────────────────────────────────────────────────────────────────

class _CarViewInteractive extends StatelessWidget {
  final VueVoiture vue;
  final List<PinDommage> pins;
  final bool readOnly;
  final void Function(double xPct, double yPct) onTap;
  final void Function(PinDommage) onPinTap;

  const _CarViewInteractive({
    required this.vue,
    required this.pins,
    required this.readOnly,
    required this.onTap,
    required this.onPinTap,
  });

  static const double _pinSize = 18.0;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
      child: LayoutBuilder(builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: readOnly
              ? null
              : (details) {
                  // Convertir en pourcentage
                  final xPct = (details.localPosition.dx / w) * 100;
                  final yPct = (details.localPosition.dy / h) * 100;
                  onTap(xPct.clamp(0, 100), yPct.clamp(0, 100));
                },
          child: Stack(
            children: [
              // ── Dessin de la voiture ───────────────────────────────────────
              Positioned.fill(
                child: CustomPaint(
                  painter: _painterForVue(vue),
                ),
              ),

              // ── Overlay curseur (non-readOnly) ─────────────────────────────
              if (!readOnly)
                Positioned.fill(
                  child: Container(
                    color: Colors.transparent,
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.precise,
                    ),
                  ),
                ),

              // ── Pins ────────────────────────────────────────────────────────
              ...pins.map((pin) {
                final left = (pin.xPct / 100) * w - _pinSize / 2;
                final top  = (pin.yPct / 100) * h - _pinSize / 2;

                return Positioned(
                  left: left.clamp(0, w - _pinSize),
                  top:  top.clamp(0, h - _pinSize),
                  child: GestureDetector(
                    onTap: () => onPinTap(pin),
                    child: _PinWidget(type: pin.type),
                  ),
                );
              }),
            ],
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN WIDGET — cercle rouge animé (style HTML/JS)
// ─────────────────────────────────────────────────────────────────────────────

class _PinWidget extends StatefulWidget {
  final TypeDommage type;
  const _PinWidget({required this.type});

  @override
  State<_PinWidget> createState() => _PinWidgetState();
}

class _PinWidgetState extends State<_PinWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: widget.type.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: widget.type.color.withValues(alpha: 0.45),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.type.emoji,
            style: const TextStyle(fontSize: 7, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE DANS LA LISTE RÉCAP
// ─────────────────────────────────────────────────────────────────────────────

class _PinBadge extends StatelessWidget {
  final PinDommage pin;
  const _PinBadge({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: pin.type.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pin.type.color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 7, height: 7,
          decoration: BoxDecoration(color: pin.type.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '${pin.vue.label} — ${pin.type.label}',
          style: TextStyle(
            fontSize: 10,
            color: pin.type.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET : CHOIX DU TYPE DE DOMMAGE
// ─────────────────────────────────────────────────────────────────────────────

class _TypePickerSheet extends StatelessWidget {
  const _TypePickerSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),
          Text(context.l10n.typeDeDommage, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(context.l10n.selectionnezLeTypeCorrespondantAuDommage, style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ...TypeDommage.values.map((type) => _TypeOption(
            type: type,
            onTap: () => Navigator.pop(context, type),
          )),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final TypeDommage type;
  final VoidCallback onTap;
  const _TypeOption({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: type.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(type.emoji,
                style: TextStyle(fontSize: 16, color: type.color)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              type.label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEET : ACTIONS SUR UN PIN EXISTANT
// ─────────────────────────────────────────────────────────────────────────────

class _PinActionsSheet extends StatelessWidget {
  final PinDommage pin;
  const _PinActionsSheet({required this.pin});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: pin.type.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(pin.type.emoji,
                  style: TextStyle(fontSize: 18, color: pin.type.color)),
              ),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pin.type.label,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text(
                '${pin.vue.label}  •  X:${pin.xPct.toStringAsFixed(0)}% Y:${pin.yPct.toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ]),
          ]),
          const SizedBox(height: 16),
          Text(context.l10n.changerLeType, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: TypeDommage.values.map((t) =>
            GestureDetector(
              onTap: () => Navigator.pop(context, t.name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: t == pin.type
                      ? t.color.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: t == pin.type ? t.color : AppColors.border,
                    width: t == pin.type ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t.emoji, style: TextStyle(fontSize: 14, color: t.color)),
                  const SizedBox(width: 5),
                  Text(t.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: t == pin.type ? t.color : AppColors.textPrimary,
                      fontWeight: t == pin.type ? FontWeight.w700 : FontWeight.w400,
                    )),
                ]),
              ),
            ),
          ).toList()),
          const SizedBox(height: 16),
          // Supprimer
          GestureDetector(
            onTap: () => Navigator.pop(context, 'delete'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                  SizedBox(width: 8),
                  Text(context.l10n.supprimerCeDommage, style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}*/