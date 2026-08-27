// lib/features/admin/presentation/settings_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/showroom_settings_model.dart';
import 'showroom_settings_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';
import '../../../core/providers/locale_provider.dart'; // ⚠️ adapte le chemin si besoin

const _kGeminiModels = [
  {'id': 'gemini-2.5-flash',       'label': 'gemini-2.5-flash',          'desc': 'Rapide, recommandé ✅'},
  {'id': 'gemini-2.5-flash-lite',  'label': 'gemini-2.5-flash-lite',     'desc': 'Rapide, recommandé ✅'},
  {'id': 'gemini-2.0-flash',       'label': 'Gemini 2.0 Flash ✅',       'desc': 'Rapide, recommandé'},
  {'id': 'gemini-2.0-flash-lite',  'label': 'Gemini 2.0 Flash Lite',     'desc': 'Ultra rapide, léger'},
  {'id': 'gemini-1.5-flash-latest','label': 'Gemini 1.5 Flash (latest)', 'desc': 'Stable, bon équilibre'},
  {'id': 'gemini-1.5-pro-latest',  'label': 'Gemini 1.5 Pro (latest)',   'desc': 'Plus puissant, plus lent'},
];
const _kDefaultGeminiModel = 'gemini-2.0-flash';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(showroomSettingsTypedProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.parametresDuShowroom,
        showHomeButton: true,
      ),
      body: settingsAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
        data:    (settings) => _SettingsBody(settings: settings),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SettingsBody extends ConsumerStatefulWidget {
  final ShowroomSettings settings;
  const _SettingsBody({required this.settings});

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  // On travaille sur une Map mutable pour les éditions locales,
  // initialisée depuis le ShowroomSettings typé.
  late Map<String, dynamic> _data;
  bool _saving = false;
  bool _uploadingLogo = false;

  @override
  void initState() {
    super.initState();
    _data = widget.settings.toJson();
    // toJson() n'inclut pas 'id' si null — on le force depuis le model
    if (widget.settings.id != null) _data['id'] = widget.settings.id;
  }

  // ── Sauvegarde directe via Supabase ──────────────────────────────────────
  // On lit currentShowroomIdProvider ici : il est toujours disponible
  // puisque l'utilisateur est connecté et que son profil est chargé
  // (sinon il ne serait pas sur cet écran).
  Future<void> _save() async {
    final showroomId = ref.read(currentShowroomIdProvider);
    if (showroomId == null || showroomId.isEmpty) {
      _showError('Showroom introuvable. Veuillez vous reconnecter.');
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = Map<String, dynamic>.from(_data)..remove('id');
      await ref.read(supabaseClientProvider)
          .from('showrooms')
          .update(payload)
          .eq('id', showroomId);

      // Invalide les deux providers qui lisent les settings
      ref.invalidate(showroomSettingsTypedProvider);
      ref.invalidate(showroomSettingsNotifierProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.l10n.parametresSauvegardes),
          backgroundColor: AppColors.secondary,
        ));
      }
    } catch (e) {
      _showError('Erreur lors de la sauvegarde : $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
    ));
  }

  // ── Dialogue édition champ texte ─────────────────────────────────────────
  Future<void> _editField(String key, String label, String current,
      {bool isSecret = false}) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.modifierLabel(label)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: isSecret,
          decoration: InputDecoration(
            labelText: label,
            hintText: isSecret ? 'Entrez la clé ou le token' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.btnAnnuler),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: Text(context.l10n.sauvegarder),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => _data[key] = result);
    await _save();
  }

  // ── Upload du logo vers Supabase Storage (bucket public "logos") ────────
  //
  // Remplace la simple saisie manuelle d'URL : l'utilisateur choisit une
  // image depuis sa galerie, elle est uploadée dans le bucket "logos" et
  // l'URL publique retournée par Supabase est enregistrée dans logo_url.
  // ⚠️ Le bucket "logos" doit exister et être configuré en public dans le
  // dashboard Supabase (Storage → New bucket → cocher "Public bucket").
  Future<void> _pickAndUploadLogo() async {
    final showroomId = ref.read(currentShowroomIdProvider);
    if (showroomId == null || showroomId.isEmpty) {
      _showError('Showroom introuvable. Veuillez vous reconnecter.');
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _uploadingLogo = true);
    try {
      final supabase = ref.read(supabaseClientProvider);
      final ext = (image.name.contains('.') ? image.name.split('.').last : 'jpg')
          .toLowerCase();
      // On fixe un nom de fichier stable par showroom : un nouvel upload
      // écrase l'ancien logo (upsert: true) plutôt que d'accumuler des
      // fichiers orphelins dans le bucket.
      final path = '$showroomId/logo.$ext';

      final Uint8List fileBytes = await image.readAsBytes();

      await supabase.storage.from('logos').uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(
              contentType: image.mimeType ?? 'image/jpeg',
              upsert: true,
            ),
          );

      // On ajoute un cache-buster car getPublicUrl() retourne toujours la
      // même URL pour un même path : sans ça, l'ancien logo resterait
      // affiché en cache (dans l'app comme dans les PDF déjà mis en cache).
      final publicUrl =
          '${supabase.storage.from('logos').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';

      setState(() => _data['logo_url'] = publicUrl);
      await _save();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Logo mis à jour avec succès'),
          backgroundColor: AppColors.secondary,
        ));
      }
    } catch (e) {
      _showError('Échec de l\'upload du logo : $e');
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  // ── Dialogue sélection modèle Gemini ─────────────────────────────────────
  Future<void> _selectGeminiModel() async {
    final current = (_data['gemini_model'] as String?)?.isNotEmpty == true
        ? _data['gemini_model'] as String
        : _kDefaultGeminiModel;
    final validCurrent = _kGeminiModels.any((m) => m['id'] == current)
        ? current
        : _kDefaultGeminiModel;
    String? selected = validCurrent;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(children: [
            Icon(Icons.smart_toy_outlined, size: 22),
            SizedBox(width: 8),
            Text(context.l10n.modeleGemini),
          ]),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _kGeminiModels.map((model) => RadioListTile<String>(
                value: model['id']!,
                groupValue: selected,
                title: Text(model['label']!,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(model['desc']!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                activeColor: AppColors.primary,
                selected: selected == model['id'],
                onChanged: (v) => setLocal(() => selected = v),
              )).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.btnAnnuler)),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, selected),
              child: Text(context.l10n.btnConfirmer),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    setState(() => _data['gemini_model'] = result);
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final currentModelId = (_data['gemini_model'] as String?)?.isNotEmpty == true
        ? _data['gemini_model'] as String
        : _kDefaultGeminiModel;
    final currentModelLabel = _kGeminiModels.firstWhere(
      (m) => m['id'] == currentModelId,
      orElse: () => _kGeminiModels.first,
    )['label'] ?? currentModelId;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── 1. Informations générales ────────────────────────────────────
            _SectionTitle(title: context.l10n.informationsGenerales, icon: Icons.business),
            SizedBox(height: 12),
            _InfoCard(icon: Icons.business,     title: context.l10n.nomDuShowroom,           value: _data['nom']      ?? '', onEdit: () => _editField('nom',      'Nom du showroom',          _data['nom']      ?? '')),
            SizedBox(height: 8),
            _InfoCard(icon: Icons.location_on,  title: context.l10n.champAdresse,                   value: _data['adresse']  ?? '', onEdit: () => _editField('adresse',  'Adresse',                  _data['adresse']  ?? '')),
            SizedBox(height: 8),
            _InfoCard(icon: Icons.phone,        title: context.l10n.telephone,                 value: _data['tel']      ?? '', onEdit: () => _editField('tel',      'Téléphone',                _data['tel']      ?? '')),
            SizedBox(height: 8),
            _InfoCard(icon: Icons.email,        title: context.l10n.champEmail,                     value: _data['email']    ?? '', onEdit: () => _editField('email',    'Email',                    _data['email']    ?? '')),
            SizedBox(height: 8),
            _InfoCard(icon: Icons.gavel,        title: context.l10n.registreDuCommerceRc, value: _data['rc']       ?? '', onEdit: () => _editField('rc',       'RC / Matricule',           _data['rc']       ?? '')),
            SizedBox(height: 8),
            _LogoCard(
              logoUrl: _data['logo_url'] as String?,
              uploading: _uploadingLogo,
              onUpload: _pickAndUploadLogo,
              // Option de secours : coller manuellement une URL externe
              // (doit pointer directement vers le fichier image, pas vers
              // une page web qui l'affiche).
              onEditUrlManually: () => _editField(
                  'logo_url', 'URL publique du logo (avancé)', _data['logo_url'] ?? ''),
            ),

            // ── 2. GPS Flespi ────────────────────────────────────────────────
            SizedBox(height: 24),
            _SectionTitle(title: context.l10n.gpsPasserelleFlespi, icon: Icons.gps_fixed),
            SizedBox(height: 12),
            _InfoCard(icon: Icons.dns,    title: context.l10n.urlFlespi,          value: _data['flespi_url']  ?? '', onEdit: () => _editField('flespi_url',  'URL Flespi',                  _data['flespi_url']  ?? '')),
            SizedBox(height: 8),
            _InfoCard(icon: Icons.person, title: context.l10n.utilisateurFlespi,  value: _data['flespi_user'] ?? '', onEdit: () => _editField('flespi_user', 'Email ou utilisateur Flespi', _data['flespi_user'] ?? '')),
            SizedBox(height: 8),
            _InfoCard(icon: Icons.lock,   title: context.l10n.motDePasseFlespi,
              value: (_data['flespi_password'] ?? '').isNotEmpty ? '••••••••' : '',
              onEdit: () => _editField('flespi_password', 'Mot de passe Flespi', _data['flespi_password'] ?? '', isSecret: true),
            ),
            SizedBox(height: 8),
            _InfoCard(icon: Icons.key_outlined, title: context.l10n.tokenFlespi,
              value: (_data['flespi_token'] ?? '').isNotEmpty ? '••••••••••••••••' : '',
              onEdit: () => _editField('flespi_token', 'Token Flespi (Master/Standard)', _data['flespi_token'] ?? '', isSecret: true),
            ),

            // ── 3. Intelligence Artificielle ─────────────────────────────────
            SizedBox(height: 24),
            _SectionTitle(title: context.l10n.intelligenceArtificielle, icon: Icons.psychology),
            SizedBox(height: 12),
            _InfoCard(icon: Icons.api, title: context.l10n.cleApiGemini,
              value: (_data['gemini_api_key'] ?? '').isNotEmpty ? '••••••••••••••••' : '',
              onEdit: () => _editField('gemini_api_key', 'Clé Secrète API Google Gemini', _data['gemini_api_key'] ?? '', isSecret: true),
            ),
            SizedBox(height: 8),
            _ModelCard(currentLabel: currentModelLabel, onSelect: _selectGeminiModel),

            // ── 4. Préférences système ───────────────────────────────────────
            SizedBox(height: 24),
            _SectionTitle(title: context.l10n.preferencesSysteme, icon: Icons.settings),
            SizedBox(height: 12),
            Card(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const DarkModeSwitch(),
            )),
            SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.attach_money,
              title: context.l10n.devisePrincipale,
              subtitle: context.l10n.dinarAlgerienFixeDzd,
              trailing: Text(context.l10n.dzdDa, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              onTap: () {},
            ),
            SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.language, color: AppColors.textSecondary, size: 20),
                    SizedBox(width: 12),
                    Text(context.l10n.langue, style: AppTextStyles.body),
                    const Spacer(),
                    _LangButton(label: 'FR', locale: const Locale('fr')),
                    SizedBox(width: 8),
                    _LangButton(label: 'AR', locale: const Locale('ar')),
                    SizedBox(width: 8),
                    _LangButton(label: 'EN', locale: const Locale('en')),
                  ],
                ),
              ),
            ),

            // ── 5. Commissions ───────────────────────────────────────────────
            SizedBox(height: 24),
            _SectionTitle(title: context.l10n.commissionsDuGerant, icon: Icons.percent),
            SizedBox(height: 4),
            Text(context.l10n.definissezLeTauxParDefautPre, style: AppTextStyles.bodySecondary.copyWith(fontSize: 11)),
            SizedBox(height: 12),
            _CommissionCard(label: 'Vente',           icon: Icons.sell_outlined,           typeKey: 'commission_vente_type',     valeurKey: 'commission_vente_valeur',     settings: _data, onChanged: (u) async { setState(() => _data = u); await _save(); }),
            SizedBox(height: 8),
            _CommissionCard(label: context.l10n.echangeReprise, icon: Icons.swap_horiz,            typeKey: 'commission_echange_type',   valeurKey: 'commission_echange_valeur',   settings: _data, onChanged: (u) async { setState(() => _data = u); await _save(); }),
            SizedBox(height: 8),
            _CommissionCard(label: 'Location',        icon: Icons.car_rental,              typeKey: 'commission_location_type',  valeurKey: 'commission_location_valeur',  settings: _data, onChanged: (u) async { setState(() => _data = u); await _save(); }),
            SizedBox(height: 8),
            _CommissionCard(label: 'Achat',           icon: Icons.shopping_cart_outlined,  typeKey: 'commission_achat_type',     valeurKey: 'commission_achat_valeur',     settings: _data, onChanged: (u) async { setState(() => _data = u); await _save(); }),

            // ── 6. Documents & Contrats ──────────────────────────────────────
            SizedBox(height: 24),
            _SectionTitle(title: context.l10n.gestionDesDocuments, icon: Icons.description_outlined),
            SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.article_outlined,
              title: context.l10n.clausesArticlesDesContrats,
              subtitle: context.l10n.configurerLesMentionsLegalesLocationVente,
              trailing: Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/contract-articles'),
            ),

            SizedBox(height: 40),
            Center(child: Text(
              "© ${DateTime.now().year} ${_data['nom'] ?? 'Garage Auto'} — Gestion Showroom",
              style: AppTextStyles.bodySecondary,
            )),
            SizedBox(height: 24),
          ],
        ),

        // Barre de progression sauvegarde
        if (_saving)
          const Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionTitle({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 20, color: AppColors.textSecondary),
    SizedBox(width: 8),
    Text(title, style: AppTextStyles.heading3.copyWith(color: AppColors.textSecondary)),
  ]);
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final VoidCallback onEdit;
  const _InfoCard({required this.icon, required this.title, required this.value, required this.onEdit});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
      subtitle: Text(
        value.isEmpty ? 'Non défini' : value,
        style: AppTextStyles.heading3.copyWith(
          color: value.isEmpty ? AppColors.textHint : null,
          fontSize: 14,
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.edit, size: 18),
        onPressed: onEdit,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

class _ModelCard extends StatelessWidget {
  final String currentLabel;
  final VoidCallback onSelect;
  const _ModelCard({required this.currentLabel, required this.onSelect});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 20),
      ),
      title: Text(context.l10n.modeleIaGemini,
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
      subtitle: Text(currentLabel,
          style: AppTextStyles.heading3.copyWith(fontSize: 14)),
      trailing: IconButton(
        icon: Icon(Icons.tune, size: 18),
        onPressed: onSelect,
        color: AppColors.textSecondary,
      ),
      onTap: onSelect,
    ),
  );
}

// ── Carte Logo (aperçu + upload) ─────────────────────────────────────────────

class _LogoCard extends StatelessWidget {
  final String? logoUrl;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onEditUrlManually;
  const _LogoCard({
    required this.logoUrl,
    required this.uploading,
    required this.onUpload,
    required this.onEditUrlManually,
  });

  bool get _hasLogo => logoUrl != null && logoUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: uploading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _hasLogo
                      ? Image.network(
                          logoUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.textSecondary),
                        )
                      : const Icon(Icons.image_outlined,
                          color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.urlDuLogo, style: AppTextStyles.body),
                  const SizedBox(height: 2),
                  Text(
                    _hasLogo
                        ? 'Logo configuré'
                        : 'Aucun logo — les contrats PDF s\'afficheront sans logo',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (v) {
                if (v == 'upload') onUpload();
                if (v == 'manual') onEditUrlManually();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'upload',
                  child: Row(children: [
                    Icon(Icons.upload_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Choisir une image'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'manual',
                  child: Row(children: [
                    Icon(Icons.link, size: 18),
                    SizedBox(width: 8),
                    Text('Coller une URL (avancé)'),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.title, required this.subtitle, required this.trailing, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
      title: Text(title, style: AppTextStyles.body),
      subtitle: Text(subtitle, style: AppTextStyles.bodySecondary.copyWith(fontSize: 11)),
      trailing: trailing,
      onTap: onTap,
    ),
  );
}

// ── Commission Card ──────────────────────────────────────────────────────────

class _CommissionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String typeKey, valeurKey;
  final Map<String, dynamic> settings;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const _CommissionCard({required this.label, required this.icon, required this.typeKey, required this.valeurKey, required this.settings, required this.onChanged});

  CommissionType get _type   => CommissionTypeExt.fromDb(settings[typeKey] as String?);
  double         get _valeur => (settings[valeurKey] as num?)?.toDouble() ?? 0;

  Future<void> _edit(BuildContext context) async {
    CommissionType selectedType = _type;
    final ctrl = TextEditingController(
        text: _valeur.toStringAsFixed(_valeur == _valeur.truncate() ? 0 : 2));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            SizedBox(width: 8),
            Text(ctx.l10n.commissionLabel(label)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.typeDeCommission, style: AppTextStyles.label),
              SizedBox(height: 8),
              Row(children: [
                Expanded(child: _TypeChip(label: context.l10n.pourcentage,  selected: selectedType == CommissionType.pct,  onTap: () => setLocal(() => selectedType = CommissionType.pct))),
                SizedBox(width: 8),
                Expanded(child: _TypeChip(label: context.l10n.montantFixeDa, selected: selectedType == CommissionType.fixe, onTap: () => setLocal(() => selectedType = CommissionType.fixe))),
              ]),
              SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: ctx.l10n.champValeur,
                  suffixText: selectedType == CommissionType.pct ? '%' : 'DA',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.btnAnnuler)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true),  child: Text(context.l10n.sauvegarder)),
          ],
        ),
      ),
    );
    if (result != true) return;
    final newVal = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? _valeur;
    onChanged(Map<String, dynamic>.from(settings)
      ..[typeKey]   = selectedType.dbValue
      ..[valeurKey] = newVal);
  }

  @override
  Widget build(BuildContext context) {
    final isPct = _type == CommissionType.pct;
    final valStr = isPct
        ? '${_valeur.toStringAsFixed(_valeur == _valeur.truncate() ? 0 : 1)} %'
        : '${_valeur.toStringAsFixed(0)} DA fixe';

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.gerant.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.gerant, size: 20),
        ),
        title: Text(label, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
        subtitle: Row(children: [
          Text(valStr, style: AppTextStyles.heading3.copyWith(fontSize: 14, color: AppColors.gerant)),
          SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isPct ? AppColors.primary : AppColors.accent).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isPct ? 'PCT' : 'FIXE',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: isPct ? AppColors.primary : AppColors.accent),
            ),
          ),
        ]),
        trailing: IconButton(
          icon: Icon(Icons.edit, size: 18),
          onPressed: () => _edit(context),
          color: AppColors.textSecondary,
        ),
        onTap: () => _edit(context),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    ),
  );
}

class DarkModeSwitch extends ConsumerWidget {
  const DarkModeSwitch({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode   = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    return SwitchListTile(
      title: Text(context.l10n.modeSombre),
      subtitle: Text(isDark ? 'Activé' : 'Désactivé'),
      secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
          color: isDark ? AppColors.primary : AppColors.accent),
      value: isDark,
      activeThumbColor: AppColors.primary,
      onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}

// ── Sélecteur de langue ──────────────────────────────────────────────────────

class _LangButton extends ConsumerWidget {
  final String label;
  final Locale locale;
  const _LangButton({required this.label, required this.locale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final selected = current.languageCode == locale.languageCode;
    return GestureDetector(
      onTap: () => ref.read(localeProvider.notifier).setLocale(locale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}