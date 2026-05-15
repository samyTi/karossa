import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/profile_model.dart';

class ReleveScreen extends ConsumerStatefulWidget {
  const ReleveScreen({super.key});
  @override
  ConsumerState<ReleveScreen> createState() => _State();
}

class _State extends ConsumerState<ReleveScreen> {
  int  _mois  = DateTime.now().month;
  int  _annee = DateTime.now().year;
  bool _loading = false;
  List<Map<String, dynamic>> _repartitions = [];
  double _totalBrut = 0;
  double _partNette = 0;
  String? _associeId;
  Profile? _profile;

  final _moisLabels = [
    'Jan','Fev','Mar','Avr','Mai','Jun',
    'Jul','Aou','Sep','Oct','Nov','Dec'
  ];

  @override
  void initState() {
    super.initState();
    _profile   = ref.read(currentProfileProvider).valueOrNull;
    _associeId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    _charger();
  }

  Future<void> _charger() async {
    if (_associeId == null) return;
    setState(() => _loading = true);
    try {
      final debut = DateTime(_annee, _mois).toIso8601String();
      final fin   = DateTime(_annee, _mois + 1, 0, 23, 59)
        .toIso8601String();
      final data  = await ref.read(supabaseClientProvider)
        .from('location_repartitions')
        .select(
          '*, locations('
          'vehicules(marque, modele), '
          'date_debut, montant_brut'
          ')')
        .eq('beneficiaire_id', _associeId!)
        .gte('created_at', debut)
        .lte('created_at', fin);

      double part = 0, brut = 0;
      for (final r in data) {
        part += (r['montant'] as num).toDouble();
        final mb = r['locations']?['montant_brut'];
        if (mb != null) brut += (mb as num).toDouble();
      }
      setState(() {
        _repartitions = List<Map<String, dynamic>>.from(data);
        _partNette = part;
        _totalBrut = brut;
        _loading   = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moisLabel = _moisLabels[_mois - 1];
    final titre     = '$moisLabel $_annee';

    return Scaffold(
      appBar: CustomAppBar(
        title: titre,
        showBackButton: false,
        showHomeButton: true,
        actions: !_loading && _repartitions.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  tooltip: 'Exporter PDF',
                  onPressed: _exportPdf),
              ]
            : null,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(child: DropdownButtonFormField<int>(
              initialValue: _mois,
              decoration: const InputDecoration(labelText: 'Mois'),
              items: List.generate(12, (i) => DropdownMenuItem<int>(
                value: i + 1,
                child: Text(_moisLabels[i]))).toList(),
              onChanged: (v) {
                setState(() => _mois = v!);
                _charger();
              },
            )),
            const SizedBox(width: 12),
            Expanded(child: DropdownButtonFormField<int>(
              initialValue: _annee,
              decoration: const InputDecoration(labelText: 'Annee'),
              items: [2024, 2025, 2026].map((y) =>
                DropdownMenuItem<int>(
                  value: y, child: Text('$y'))).toList(),
              onChanged: (v) {
                setState(() => _annee = v!);
                _charger();
              },
            )),
          ]),
        ),

        if (_loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator()))
        else if (_repartitions.isEmpty)
          const Expanded(
            child: Center(
              child: Text('Aucune transaction ce mois-ci')))
        else
          Expanded(child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: _SummaryCard(
                  'Brut genere',
                  '${_totalBrut.toInt()} DA',
                  AppColors.textSecondary)),
                const SizedBox(width: 12),
                Expanded(child: _SummaryCard(
                  'Votre part nette',
                  '${_partNette.toInt()} DA',
                  AppColors.secondary)),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: _repartitions.length,
              itemBuilder: (_, i) {
                final r   = _repartitions[i];
                final veh = r['locations']?['vehicules'];
                final nom = veh != null
                  ? '${veh['marque']} ${veh['modele']}' : '---';
                final mnt = (r['montant'] as num).toDouble();
                final pct = (r['pourcentage'] as num).toDouble();
                final pctStr = pct.toStringAsFixed(1);
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(nom, style: AppTextStyles.heading3),
                    subtitle: Text('$pctStr%',
                      style: AppTextStyles.label),
                    trailing: Text('${mnt.toInt()} DA',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.secondary,
                        fontSize: 14)),
                  ),
                );
              },
            )),
          ])),
      ]),
    );
  }

  Future<void> _exportPdf() async {
    final doc = pw.Document();
    final fmt = NumberFormat('#,###', 'fr');
    final moisLabel = _moisLabels[_mois - 1];
    final nomAssoc  = _profile?.fullName ?? '';

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Garage Auto - Releve mensuel',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold)),
          pw.Text('$moisLabel $_annee - $nomAssoc',
            style: const pw.TextStyle(
              fontSize: 13, color: PdfColors.grey600)),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: ['Vehicule', 'Part %', 'Montant DA'],
            data: _repartitions.map((r) {
              final veh = r['locations']?['vehicules'];
              final nom = veh != null
                ? '${veh['marque']} ${veh['modele']}' : '---';
              final pct = (r['pourcentage'] as num)
                .toStringAsFixed(1);
              final mnt = fmt.format(
                (r['montant'] as num).toInt());
              return [nom, '$pct%', '$mnt DA'];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                'PART NETTE : ${fmt.format(_partNette.toInt())} DA',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 14,
                  color: PdfColors.green800)),
            ]),
        ]),
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: 'releve_${_moisLabels[_mois - 1]}_$_annee.pdf',
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SummaryCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Column(children: [
      Text(label, style: AppTextStyles.label,
        textAlign: TextAlign.center),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w800,
        color: color)),
    ]),
  );
}
