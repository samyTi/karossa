// lib/shared/widgets/car_damage_map.dart
//
// Équivalent Flutter exact du code HTML/JS fourni :
//   • Image de carrosserie en background (AssetImage)
//   • Tap sur l'image → pin rouge 14px centré à la position exacte
//   • Tap sur un pin → le supprime (comme e.target.remove())
//   • Coordonnées stockées en % (responsive)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/vehicules/domain/etat_carrosserie_model.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

// ── CHEMIN DE L'IMAGE DANS VOS ASSETS ────────────────────────────────────────
// N'oubliez pas de déclarer ce dossier/fichier dans votre pubspec.yaml !
const _kCarAssetPath = 'assets/images/car_blueprint.jpg';

const _kPinSize = 14.0;

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────────────────────

class CarDamageMap extends StatefulWidget {
  final EtatCarrosserie etat;
  final bool readOnly;
  final ValueChanged<EtatCarrosserie>? onChanged;
  final String? title;

  const CarDamageMap({
    super.key,
    required this.etat,
    this.readOnly = false,
    this.onChanged,
    this.title,
  });

  @override
  State<CarDamageMap> createState() => _CarDamageMapState();
}

class _CarDamageMapState extends State<CarDamageMap> {
  late EtatCarrosserie _etat;

  @override
  void initState() {
    super.initState();
    _etat = widget.etat;
  }

  @override
  void didUpdateWidget(CarDamageMap old) {
    super.didUpdateWidget(old);
    if (old.etat != widget.etat) setState(() => _etat = widget.etat);
  }

  // Tap sur le fond → place un pin (équivalent du addEventListener click)
  void _onTapBackground(TapUpDetails details, double w, double h) {
    if (widget.readOnly) return;
    HapticFeedback.lightImpact();
    final xPct = (details.localPosition.dx / w * 100).clamp(0.0, 100.0);
    final yPct = (details.localPosition.dy / h * 100).clamp(0.0, 100.0);
    debugPrint('Nouvel impact à : Coordonnées [${xPct.toStringAsFixed(2)}% , ${yPct.toStringAsFixed(2)}%]');
    final pin = PinDommage(
      id:   'pin_${DateTime.now().millisecondsSinceEpoch}',
      vue:  VueVoiture.dessus,
      xPct: xPct,
      yPct: yPct,
      type: TypeDommage.bosse, // type par défaut — rouge comme l'original
    );
    final updated = _etat.addPin(pin);
    setState(() => _etat = updated);
    widget.onChanged?.call(updated);
  }

  // Tap sur un pin → ouvre l'éditeur (type + titre/description, ou suppression)
  Future<void> _onTapPin(PinDommage pin) async {
    if (widget.readOnly) return;
    HapticFeedback.mediumImpact();

    final result = await showModalBottomSheet<_PinEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinEditorSheet(pin: pin),
    );
    if (result == null || !mounted) return;

    EtatCarrosserie updated;
    if (result.delete) {
      updated = _etat.removePin(pin.id);
    } else {
      updated = _etat.updatePin(pin.id, type: result.type, note: result.note);
    }
    setState(() => _etat = updated);
    widget.onChanged?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // En-tête optionnel
        if (widget.title != null || !widget.readOnly) ...[
          _buildHeader(),
          SizedBox(height: 8),
        ],

        // ── Zone principale : image + pins ──────────────────────────────────
        _buildZone(),

        // Compteur de dommages
        if (_etat.pins.isNotEmpty) ...[
          SizedBox(height: 8),
          _buildDamageCount(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    final count = _etat.pins.length;
    return Row(children: [
      Icon(Icons.directions_car_outlined, size: 15, color: Color(0xFF6B7280)),
      SizedBox(width: 6),
      Expanded(
        child: Text(
          widget.title ?? 'État de la carrosserie',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: Color(0xFF111827)),
        ),
      ),
      if (!widget.readOnly)
        Text(
          count == 0
              ? 'Touchez pour marquer un dommage'
              : '$count dommage${count > 1 ? "s" : ""}',
          style: TextStyle(
            fontSize: 11,
            color: count > 0 ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
            fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
    ]);
  }

  Widget _buildZone() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _etat.pins.isNotEmpty
              ? const Color(0xFFEF4444).withValues(alpha: 0.35)
              : const Color(0xFFE5E7EB),
          width: _etat.pins.isNotEmpty ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: LayoutBuilder(builder: (_, constraints) {
          final w = constraints.maxWidth;
          // Ratio de l'image (environ paysage)
          final h = w * 0.56;

          return SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              // ── IMAGE — Chargée depuis les assets ──────────────────────────
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: widget.readOnly
                      ? null
                      : (d) => _onTapBackground(d, w, h),
                  child: MouseRegion(
                    cursor: widget.readOnly
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.precise,
                    child: Image.asset(
                      _kCarAssetPath,
                      width: w,
                      height: h,
                      // 🐛 CORRECTIF décalage des points d'impact : le PDF
                      // (vehicle_schema_pdf_renderer.dart) affiche l'image
                      // entière avec BoxFit.fill (étirée, non rognée). Si ce
                      // widget utilisait BoxFit.cover et que l'image source
                      // n'a pas exactement le même ratio que le conteneur
                      // (w × 0.56·w), Flutter rognait une partie de l'image
                      // pour remplir le cadre — les pourcentages (x%, y%)
                      // étaient alors calculés par rapport à cette zone
                      // rognée, pas par rapport à l'image entière comme dans
                      // le PDF, d'où un point qui ne tombait plus au même
                      // endroit une fois le contrat généré. `fill` garantit
                      // que le referentiel (image entière, 0–100 %) est
                      // strictement identique ici et dans le PDF.
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),

              // ── PINS — équivalent des <div class="impact-pin"> ────────────
              ..._etat.pins.map((pin) {
                // Position absolue centrée
                final left = pin.xPct / 100 * w;
                final top  = pin.yPct / 100 * h;

                return Positioned(
                  left: left - _kPinSize / 2,
                  top:  top  - _kPinSize / 2,
                  child: GestureDetector(
                    onTap: () => _onTapPin(pin),
                    child: _ImpactPin(
                      color: pin.type.color,
                      hasNote: pin.note != null && pin.note!.isNotEmpty,
                    ),
                  ),
                );
              }),

              // ── Hint "tap" en bas à droite (non readOnly) ─────────────────
              if (!widget.readOnly && _etat.pins.isEmpty)
                Positioned(
                  right: 10, bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.touch_app_outlined, size: 11, color: Colors.white),
                      SizedBox(width: 5),
                      Text(context.l10n.toucherPourMarquer, style: TextStyle(fontSize: 10, color: Colors.white)),
                    ]),
                  ),
                ),
            ]),
          );
        }),
      ),
    );
  }

  Widget _buildDamageCount() {
    final count = _etat.pins.length;
    return Row(children: [
      Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(
            color: Color(0xFFEF4444), shape: BoxShape.circle),
      ),
      SizedBox(width: 6),
      Text(
        '$count impact${count > 1 ? "s" : ""} enregistré${count > 1 ? "s" : ""}'
        '${widget.readOnly ? "" : " — touchez un point pour le modifier"}',
        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIN — Animation d'apparition
// ─────────────────────────────────────────────────────────────────────────────

class _ImpactPin extends StatefulWidget {
  final Color color;
  final bool hasNote;
  const _ImpactPin({required this.color, this.hasNote = false});

  @override
  State<_ImpactPin> createState() => _ImpactPinState();
}

class _ImpactPinState extends State<_ImpactPin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width:  _kPinSize,
            height: _kPinSize,
            decoration: BoxDecoration(
              color:  widget.color,
              shape:  BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          // Petit indicateur "a une note" — visible sans avoir à cliquer.
          if (widget.hasNote)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.color, width: 1.2),
                ),
                child: Icon(Icons.circle, size: 2.5, color: widget.color),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WRAPPER CARD — VehicleInspectorCard
// ─────────────────────────────────────────────────────────────────────────────

class VehicleInspectorCard extends StatefulWidget {
  final String title;
  final EtatCarrosserie etat;
  final ValueChanged<EtatCarrosserie> onChanged;
  final GlobalKey? repaintKey;
  final Color? accentColor; // 1. Déclaration de la propriété

  const VehicleInspectorCard({
    super.key,
    this.title = 'État de la carrosserie',
    required this.etat,
    required this.onChanged,
    this.repaintKey,
    this.accentColor, // 2. Ajout au constructeur
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
    final hasPin = widget.etat.pins.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPin
              ? const Color(0xFFEF4444).withValues(alpha: 0.35)
              : const Color(0xFFE5E7EB),
          width: hasPin ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (hasPin
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF3B82F6)).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.directions_car_outlined, size: 17,
                  color: hasPin
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF3B82F6)),
              ),
              SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  Text(
                    hasPin
                        ? '${widget.etat.pins.length} impact${widget.etat.pins.length > 1 ? "s" : ""} enregistré${widget.etat.pins.length > 1 ? "s" : ""}'
                        : 'Touchez la carrosserie pour marquer un impact',
                    style: TextStyle(fontSize: 11,
                      color: hasPin
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF6B7280),
                      fontWeight: hasPin ? FontWeight.w600 : FontWeight.normal),
                  ),
                ],
              )),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down,
                    color: Color(0xFF9CA3AF)),
              ),
            ]),
          ),
        ),

        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: Column(children: [
              Divider(height: 1, color: Colors.grey.shade100),
              SizedBox(height: 12),
              RepaintBoundary(
                key: widget.repaintKey,
                child: CarDamageMap(
                  etat:      widget.etat,
                  readOnly:  false,
                  onChanged: (updated) {
                    final obs = _obsCtrl.text.trim();
                    widget.onChanged(updated.copyWithObservations(
                        obs.isEmpty ? null : obs));
                  },
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _obsCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.l10n.observations,
                  hintText: context.l10n.exPneuUseJanteRayee,
                  filled: true,
                  fillColor: const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  prefixIcon: Icon(Icons.edit_note, size: 20),
                ),
                onChanged: (v) => widget.onChanged(
                  widget.etat.copyWithObservations(
                      v.trim().isEmpty ? null : v.trim())),
              ),
              if (hasPin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      _obsCtrl.clear();
                      widget.onChanged(const EtatCarrosserie());
                    },
                    icon: Icon(Icons.clear, size: 14),
                    label: Text(context.l10n.toutEffacer, style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444)),
                  ),
                ),
            ]),
          ),
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }
}

// ── LECTURE SEULE ────────────────────────────────────────────────────────────

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
    if (!e.hasAnyDamage &&
        (e.observations == null || e.observations!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.directions_car_outlined,
              size: 15, color: Color(0xFF6B7280)),
          SizedBox(width: 6),
          Text(title,
            style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
        ]),
        SizedBox(height: 10),
        if (e.hasAnyDamage) CarDamageMap(etat: e, readOnly: true),
        if (e.observations != null && e.observations!.isNotEmpty) ...[
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.note_outlined,
                  size: 14, color: Color(0xFF6B7280)),
              SizedBox(width: 6),
              Expanded(child: Text(e.observations!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF111827)))),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ÉDITEUR D'UN POINT — type + titre/description + suppression
// ─────────────────────────────────────────────────────────────────────────────

class _PinEditResult {
  final TypeDommage? type;
  final String? note;
  final bool delete;
  const _PinEditResult({this.type, this.note, this.delete = false});
}

class _PinEditorSheet extends StatefulWidget {
  final PinDommage pin;
  const _PinEditorSheet({required this.pin});

  @override
  State<_PinEditorSheet> createState() => _PinEditorSheetState();
}

class _PinEditorSheetState extends State<_PinEditorSheet> {
  late TypeDommage _type;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.pin.type;
    _noteCtrl = TextEditingController(text: widget.pin.note ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(
      context,
      _PinEditResult(type: _type, note: _noteCtrl.text.trim()),
    );
  }

  void _delete() {
    Navigator.pop(context, const _PinEditResult(delete: true));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Remonte le sheet au-dessus du clavier.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Modifier le point d\'impact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),

            // ── Type de dommage ──────────────────────────────────────────
            const Text('Type de dommage',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TypeDommage.values.map((t) {
                final selected = t == _type;
                return GestureDetector(
                  onTap: () => setState(() => _type = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? t.color.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? t.color : const Color(0xFFE5E7EB),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(t.emoji, style: TextStyle(fontSize: 14, color: t.color)),
                      const SizedBox(width: 5),
                      Text(t.label, style: TextStyle(
                        fontSize: 12,
                        color: selected ? t.color : const Color(0xFF111827),
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Titre / description ──────────────────────────────────────
            const Text('Titre / description',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Ex : rayure porte avant gauche, ~5cm',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 18),

            // ── Actions ───────────────────────────────────────────────────
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                  label: const Text('Supprimer',
                      style: TextStyle(color: Color(0xFFEF4444))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _type.color,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Enregistrer',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}