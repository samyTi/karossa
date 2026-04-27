import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../domain/achat_model.dart';
import '../data/achats_repository.dart';
import 'achats_provider.dart';

class AchatDetailScreen extends ConsumerStatefulWidget {
  final String achatId;
  const AchatDetailScreen({super.key, required this.achatId});

  @override
  ConsumerState<AchatDetailScreen> createState() => _AchatDetailScreenState();
}

class _AchatDetailScreenState extends ConsumerState<AchatDetailScreen> {
  bool _loading = false;

  Color _colorFromStatut(AchatStatut s) =>
    Color(int.parse('0x${s.color.substring(1)}'));

  @override
  Widget build(BuildContext context) {
    final achatsAsync = ref.watch(achatsProvider);

    return achatsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Erreur: $e'))),
      data: (achats) {
        final achat = achats.where((a) => a.id == widget.achatId).firstOrNull;
        if (achat == null) {
          return const Scaffold(
            body: Center(child: Text('Achat introuvable')));
        }

        final color = _colorFromStatut(achat.statut);

        return Scaffold(
          appBar: CustomAppBar(
            title: 'Détail achat',
            showBackButton: true,
            showHomeButton: true,
            actions: [
              PopupMenuButton<AchatStatut>(
                tooltip: 'Changer le statut',
                icon: const Icon(Icons.more_vert),
                onSelected: (s) => _changerStatut(achat, s),
                itemBuilder: (_) => AchatStatut.values
                  .where((s) => s != achat.statut)
                  .map((s) => PopupMenuItem(
                    value: s,
                    child: Text(s.label),
                  )).toList(),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [

              // Badge statut
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(achat.statut.label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    )),
                ),
              ),
              const SizedBox(height: 20),

              // Véhicule
              _Section(
                title: 'Véhicule',
                icon: Icons.directions_car_outlined,
                children: [
                  _Row('Véhicule', achat.vehiculeNom ?? 'ID: ${achat.vehiculeId.substring(0, 8)}...'),
                ],
              ),

              // Vendeur
              _Section(
                title: 'Vendeur',
                icon: Icons.person_outline,
                children: [
                  _Row('Nom',       achat.vendeurNom),
                  _Row('Téléphone', achat.vendeurTelephone),
                  if (achat.vendeurEmail.isNotEmpty)
                    _Row('Email', achat.vendeurEmail),
                ],
              ),

              // Prix
              _Section(
                title: 'Négociation',
                icon: Icons.attach_money,
                children: [
                  _Row('Prix demandé',
                    '${achat.prixPropose.toInt()} DA'),
                  _Row('Prix accordé',
                    '${achat.prixAccorde.toInt()} DA',
                    valueColor: AppColors.secondary,
                    bold: true),
                  if (achat.prixPropose > 0 && achat.prixPropose > achat.prixAccorde)
                    _Row('Économie',
                      '${(achat.prixPropose - achat.prixAccorde).toInt()} DA',
                      valueColor: AppColors.secondary),
                  _Row('Date achat',
                    '${achat.dateAchat.day.toString().padLeft(2,'0')}/'
                    '${achat.dateAchat.month.toString().padLeft(2,'0')}/'
                    '${achat.dateAchat.year}'),
                ],
              ),

              // Remarques
              if (achat.remarques != null && achat.remarques!.isNotEmpty)
                _Section(
                  title: 'Remarques',
                  icon: Icons.notes_outlined,
                  children: [
                    Text(achat.remarques!, style: AppTextStyles.body),
                  ],
                ),

              const SizedBox(height: 16),

              // Changer le statut
              Text('Changer le statut', style: AppTextStyles.heading3),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AchatStatut.values
                  .where((s) => s != achat.statut)
                  .map((s) {
                    final c = _colorFromStatut(s);
                    return ActionChip(
                      label: Text(s.label),
                      backgroundColor: c.withValues(alpha: 0.1),
                      labelStyle: TextStyle(color: c, fontWeight: FontWeight.w600),
                      onPressed: _loading ? null : () => _changerStatut(achat, s),
                    );
                  }).toList(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Future<void> _changerStatut(Achat achat, AchatStatut newStatut) async {
    setState(() => _loading = true);
    try {
      await AchatsRepository().updateAchatStatut(achat.id, newStatut);
      ref.invalidate(achatsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Statut mis à jour : ${newStatut.label}'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.retard));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(title, style: AppTextStyles.heading3),
      ]),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
      const SizedBox(height: 14),
    ],
  );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _Row(this.label, this.value, {this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySecondary),
        Text(value, style: TextStyle(
          fontSize: bold ? 15 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: valueColor ?? AppColors.textPrimary,
        )),
      ],
    ),
  );
}
