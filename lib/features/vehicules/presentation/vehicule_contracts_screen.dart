// lib/features/vehicules/presentation/vehicule_contracts_screen.dart
// Écran pour afficher et télécharger les contrats PDF d'un véhicule

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/modern_app_bar.dart';
import '../../echanges/data/echanges_repository.dart';
import '../../echanges/presentation/echanges_provider.dart';
import '../../echanges/domain/echange_model.dart';

/// Provider pour récupérer les contrats d'un véhicule
final vehiculeContractsProvider = FutureProvider.autoDispose
    .family<List<Echange>, String>((ref, vehiculeId) {
  return ref.read(echangesRepositoryProvider).getByVehiculeId(vehiculeId);
});

class VehiculeContractsScreen extends ConsumerWidget {
  final String vehiculeId;
  final String vehiculeNom;

  const VehiculeContractsScreen({
    super.key,
    required this.vehiculeId,
    required this.vehiculeNom,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsAsync = ref.watch(vehiculeContractsProvider(vehiculeId));

    return Scaffold(
      appBar: const ModernAppBar(
        title: 'Contrats du véhicule',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: contractsAsync.when(
        loading: () => const Center(child: const CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Erreur lors du chargement des contrats',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 8),
              Text(e.toString(), style: AppTextStyles.label),
            ],
          ),
        ),
        data: (contracts) => _ContractsBody(
          vehiculeNom: vehiculeNom,
          contracts: contracts,
          vehiculeId: vehiculeId,
        ),
      ),
    );
  }
}

class _ContractsBody extends StatelessWidget {
  final String vehiculeNom;
  final List<Echange> contracts;
  final String vehiculeId;

  const _ContractsBody({
    required this.vehiculeNom,
    required this.contracts,
    required this.vehiculeId,
  });

  @override
  Widget build(BuildContext context) {
    if (contracts.isEmpty) {
      return EmptyState(
        icon: Icons.picture_as_pdf_outlined,
        message: 'Aucun contrat trouvé pour ce véhicule',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: contracts.length,
      itemBuilder: (context, index) {
        final contract = contracts[index];
        return _ContractCard(
          contract: contract,
          vehiculeNom: vehiculeNom,
          onOpen: () => _showContractOptions(context, contract, vehiculeNom),
        );
      },
    );
  }

  void _showContractOptions(
    BuildContext context,
    Echange contract,
    String vehiculeNom,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ContractOptionsSheet(
        contract: contract,
        vehiculeNom: vehiculeNom,
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final Echange contract;
  final String vehiculeNom;
  final VoidCallback? onOpen;

  const _ContractCard({
    required this.contract,
    required this.vehiculeNom,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec date et statut
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.swap_horiz,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contrat d\'échange',
                          style: AppTextStyles.heading3.copyWith(fontSize: 14),
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(contract.dateEchange),
                          style: AppTextStyles.label,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Détails du contrat
              _DetailRow(
                'Véhicule cédé',
                contract.vehiculeCedeNom ?? vehiculeNom,
              ),
              const SizedBox(height: 6),
              _DetailRow(
                'Véhicule repris',
                contract.vehiculeReprisNom,
              ),
              const SizedBox(height: 6),
              _DetailRow(
                'Client',
                contract.clientNom ?? '---',
              ),
              const SizedBox(height: 6),
              _DetailRow(
                'Valeur reprise',
                contract.valeurReprise.toDA(),
                valueColor: AppColors.primary,
              ),
              if (contract.complementClient > 0) ...[
                const SizedBox(height: 6),
                _DetailRow(
                  'Complément client',
                  contract.complementClient.toDA(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? get onTap => null;
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodySecondary),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _ContractOptionsSheet extends StatelessWidget {
  final Echange contract;
  final String vehiculeNom;

  const _ContractOptionsSheet({
    required this.contract,
    required this.vehiculeNom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Options du contrat',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 8),
          Text(
            'Contrat #${contract.id.substring(0, 8)}',
            style: AppTextStyles.bodySecondary,
          ),
          const SizedBox(height: 20),
          _OptionButton(
            icon: Icons.visibility,
            label: 'Aperçu du PDF',
            color: AppColors.primary,
            onTap: () {
              context.pop();
              _previewPdf(context);
            },
          ),
          const SizedBox(height: 8),
          _OptionButton(
            icon: Icons.download,
            label: 'Télécharger le PDF',
            color: AppColors.secondary,
            onTap: () {
              context.pop();
              _downloadPdf(context);
            },
          ),
          const SizedBox(height: 8),
          _OptionButton(
            icon: Icons.share,
            label: 'Partager le PDF',
            color: AppColors.accent,
            onTap: () {
              context.pop();
              _sharePdf(context);
            },
          ),
          const SizedBox(height: 8),
          _OptionButton(
            icon: Icons.print,
            label: 'Imprimer',
            color: AppColors.textSecondary,
            onTap: () {
              context.pop();
              _printPdf(context);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _previewPdf(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PdfPreviewScreen(contract: contract),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    // TODO: Implement PDF download using pdf and path_provider
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité de téléchargement à implémenter')),
    );
  }

  Future<void> _sharePdf(BuildContext context) async {
    // TODO: Implement PDF sharing using share_plus
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité de partage à implémenter')),
    );
  }

  Future<void> _printPdf(BuildContext context) async {
    // Generate PDF and use printing package
    final pdf = await _generatePdf(contract);
    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Contrat_${contract.id.substring(0, 8)}.pdf',
    );
  }

  Future<pw.Document> _generatePdf(Echange contract) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'CONTRAT D\'ÉCHANGE AUTOMOBILE',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Numéro de contrat: ${contract.id}',
              style: pw.TextStyle(fontSize: 12),
            ),
              pw.Text(
                'Date: ${DateFormat('dd/MM/yyyy').format(contract.dateEchange)}',
                style: pw.TextStyle(fontSize: 12),
              ),
            pw.SizedBox(height: 30),
            pw.Text(
              'DÉTAILS DE L\'ÉCHANGE',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Véhicule cédé: ${contract.vehiculeCedeNom ?? "---"}'),
            pw.Text('Véhicule repris: ${contract.vehiculeReprisNom}'),
            pw.Text('Client: ${contract.clientNom ?? "---"}'),
            pw.SizedBox(height: 10),
            pw.Text(
              'Valeur de reprise: ${contract.valeurReprise.toInt()} DA',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            if (contract.complementClient > 0)
              pw.Text(
                'Complément client: ${contract.complementClient.toInt()} DA',
              ),
            if (contract.commissionGerantMnt != null)
              pw.Text(
                'Commission gérant: ${contract.commissionGerantMnt!.toInt()} DA',
              ),
            pw.SizedBox(height: 30),
            if (contract.notes != null && contract.notes!.isNotEmpty) ...[
              pw.Text(
                'NOTES:',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(contract.notes!),
            ],
          ],
        ),
      ),
    );

    return pdf;
  }
}

class _OptionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }
}

class _PdfPreviewScreen extends StatelessWidget {
  final Echange contract;

  const _PdfPreviewScreen({required this.contract});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar(
        title: 'Aperçu du contrat',
        showBackButton: true,
      ),
      body: FutureBuilder(
        future: _generatePdf(contract),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: const CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          return PdfPreview(
            build: (format) => snapshot.data!.save(),
          );
        },
      ),
    );
  }

  Future<pw.Document> _generatePdf(Echange contract) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.blueGrey,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'CONTRAT D\'ÉCHANGE AUTOMOBILE',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Garage Auto - Document officiel',
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.white,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),
            // Contract info
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Numéro de contrat',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey,
                      ),
                    ),
                    pw.Text(
                      contract.id.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Date de signature',
                      style: pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey,
                      ),
                    ),
                    pw.Text(
              DateFormat('dd/MM/yyyy').format(contract.dateEchange),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            // Vehicle details
            pw.Text(
              'DÉTAILS DE L\'ÉCHANGE',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey,
              ),
            ),
            pw.SizedBox(height: 15),
            _buildInfoRow('Véhicule cédé (du garage)', contract.vehiculeCedeNom ?? '---'),
            _buildInfoRow('Véhicule repris (du client)', contract.vehiculeReprisNom),
            _buildInfoRow('Client acquéreur', contract.clientNom ?? '---'),
            pw.SizedBox(height: 20),
            // Financial details
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DETAILS FINANCIERS',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildMoneyRow('Valeur de reprise', contract.valeurReprise),
                  if (contract.complementClient > 0)
                    _buildMoneyRow('Complément client', contract.complementClient),
                  if (contract.commissionGerantMnt != null)
                    _buildMoneyRow('Commission gérant', contract.commissionGerantMnt!),
                ],
              ),
            ),
            pw.Spacer(),
            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SIGNATURES',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 150,
                            height: 1,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'Le Gérant',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                      pw.Column(
                        children: [
                          pw.Container(
                            width: 150,
                            height: 1,
                            color: PdfColors.black,
                          ),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            'Le Client',
                            style: pw.TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return pdf;
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey,
              ),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMoneyRow(String label, double value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 12)),
          pw.Text(
            '${value.toInt()} DA',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }
}