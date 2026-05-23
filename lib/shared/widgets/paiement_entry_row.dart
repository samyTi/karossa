// lib/features/locations/presentation/widgets/paiement_entry_row.dart
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class PaiementEntry {
  double montant = 0;
  DateTime date = DateTime.now();
  String mode = 'especes';
}

class PaiementEntryRow extends StatefulWidget {
  final PaiementEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const PaiementEntryRow({
    super.key,
    required this.entry,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<PaiementEntryRow> createState() => _PaiementEntryRowState();
}

class _PaiementEntryRowState extends State<PaiementEntryRow> {
  late final TextEditingController _montantCtrl;

  @override
  void initState() {
    super.initState();
    _montantCtrl = TextEditingController(
        text: widget.entry.montant > 0 ? widget.entry.montant.toInt().toString() : '');
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  static const _modes = ['especes', 'virement', 'cheque', 'mixte'];
  static const _modesLabels = ['Espèces', 'Virement', 'Chèque', 'Mixte'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _montantCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant', suffixText: 'DA', isDense: true),
                  onChanged: (v) {
                    widget.entry.montant = double.tryParse(v) ?? 0;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: widget.entry.mode,
                  isDense: true,
                  decoration: const InputDecoration(labelText: 'Mode', isDense: true),
                  items: List.generate(_modes.length, (i) =>
                      DropdownMenuItem(value: _modes[i], child: Text(_modesLabels[i]))),
                  onChanged: (v) {
                    if (v != null) {
                      widget.entry.mode = v;
                      widget.onChanged();
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.retard, size: 20),
                onPressed: widget.onDelete,
              ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: widget.entry.date,
                firstDate: DateTime(2015),
                lastDate: DateTime.now(),
              );
              if (d != null) {
                setState(() => widget.entry.date = d);
                widget.onChanged();
              }
            },
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Date : ${widget.entry.date.day.toString().padLeft(2, '0')}/${widget.entry.date.month.toString().padLeft(2, '0')}/${widget.entry.date.year}',
                  style: AppTextStyles.label,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}