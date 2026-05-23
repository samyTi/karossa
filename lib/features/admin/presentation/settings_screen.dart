// lib/features/admin/presentation/settings_screen.dart
// Paramètres du showroom — données stockées dans Supabase

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../contrats/presentation/contrats_provider.dart';
import '../domain/showroom_settings_model.dart';
import 'showroom_settings_provider.dart';

// Modèles Gemini disponibles (synchronisé avec ai_repository.dart)
const _kGeminiModels = [
  {'id': 'gemini-2.0-flash',      'label': 'Gemini 2.0 Flash ✅',       'desc': 'Rapide, recommandé'},
  {'id': 'gemini-2.0-flash-lite', 'label': 'Gemini 2.0 Flash Lite',    'desc': 'Ultra rapide, léger'},
  {'id': 'gemini-1.5-flash-latest','label': 'Gemini 1.5 Flash (latest)','desc': 'Stable, bon équilibre'},
  {'id': 'gemini-1.5-pro-latest', 'label': 'Gemini 1.5 Pro (latest)',  'desc': 'Plus puissant, plus lent'},
];
const _kDefaultGeminiModel = 'gemini-2.0-flash';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(showroomSettingsProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Paramètres du showroom',
        showHomeButton: true,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur : $e')),
        data: (settings) => _SettingsBody(settings: settings),
      ),
    );
  }
}

class _SettingsBody extends ConsumerStatefulWidget {
  final Map<String, dynamic> settings;
  const _SettingsBody({required this.settings});

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  late Map<String, dynamic> _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = Map<String, dynamic>.from(widget.settings);
  }

  Future<void> _editField(String key, String label, String current,
      {bool isSecret = false}) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier — $label'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: isSecret,
          decoration: InputDecoration(
            labelText: label,
            hintText:
                isSecret ? 'Entrez la clé ou le token masqué' : null,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('Sauvegarder')),
        ],
      ),
    );
    if (result == null) return;
    setState(() => _settings[key] = result);
    await _save();
  }

  /// Dialogue de sélection du modèle Gemini
  Future<void> _selectGeminiModel() async {
    final current = (_settings['gemini_model'] as String?)?.isNotEmpty == true
        ? _settings['gemini_model'] as String
        : _kDefaultGeminiModel;

    // S'assurer que la valeur courante est dans la liste
    final validCurrent = _kGeminiModels.any((m) => m['id'] == current)
        ? current
        : _kDefaultGeminiModel;

    String? selected = validCurrent;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 22),
              SizedBox(width: 8),
              Text('Modèle Gemini'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _kGeminiModels.map((model) {
                final isSelected = selected == model['id'];
                return RadioListTile<String>(
                  value: model['id']!,
                  groupValue: selected,
                  title: Text(
                    model['label']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  subtitle: Text(model['desc']!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[600])),
                  activeColor: AppColors.primary,
                  selected: isSelected,
                  onChanged: (v) => setLocal(() => selected = v),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, selected),
                child: const Text('Confirmer')),
          ],
        ),
      ),
    );

    if (result == null) return;
    setState(() => _settings['gemini_model'] = result);
    await _save();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(contratsRepositoryProvider)
          .updateShowroomSettings(_settings);
      ref.invalidate(showroomSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres sauvegardés avec succès'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sauvegarde : $e'),
            backgroundColor: AppColors.retard,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Modèle affiché (avec fallback sur le défaut)
    final currentModelId =
        (_settings['gemini_model'] as String?)?.isNotEmpty == true
            ? _settings['gemini_model'] as String
            : _kDefaultGeminiModel;
    final currentModelLabel = _kGeminiModels
            .firstWhere((m) => m['id'] == currentModelId,
                orElse: () => _kGeminiModels.first)['label'] ??
        currentModelId;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Section 1 : Général ──────────────────────────────────────────
            const _SectionTitle(
                title: 'Informations générales', icon: Icons.business),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.business,
              title: 'Nom du showroom',
              value: _settings['nom'] ?? '',
              onEdit: () => _editField(
                  'nom', 'Nom du showroom', _settings['nom'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.location_on,
              title: 'Adresse',
              value: _settings['adresse'] ?? '',
              onEdit: () => _editField(
                  'adresse', 'Adresse', _settings['adresse'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.phone,
              title: 'Téléphone',
              value: _settings['tel'] ?? '',
              onEdit: () =>
                  _editField('tel', 'Téléphone', _settings['tel'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.email,
              title: 'Email',
              value: _settings['email'] ?? '',
              onEdit: () =>
                  _editField('email', 'Email', _settings['email'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.gavel,
              title: 'Registre du commerce (RC)',
              value: _settings['rc'] ?? '',
              onEdit: () =>
                  _editField('rc', 'RC / Matricule', _settings['rc'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.link,
              title: 'URL du Logo',
              value: _settings['logo_url'] ?? '',
              onEdit: () => _editField('logo_url', 'URL publique du logo',
                  _settings['logo_url'] ?? ''),
            ),

            // ── Section 2 : GPS Flespi ───────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionTitle(
                title: 'GPS & Passerelle Flespi', icon: Icons.gps_fixed),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.dns,
              title: 'URL Flespi',
              value: _settings['flespi_url'] ?? '',
              onEdit: () => _editField(
                  'flespi_url', 'URL Flespi', _settings['flespi_url'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.person,
              title: 'Identifiant / Utilisateur Flespi',
              value: _settings['flespi_user'] ?? '',
              onEdit: () => _editField('flespi_user',
                  'Email ou utilisateur Flespi', _settings['flespi_user'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.lock,
              title: 'Mot de passe Flespi',
              value: (_settings['flespi_password'] ?? '').isNotEmpty
                  ? '••••••••'
                  : '',
              onEdit: () => _editField('flespi_password',
                  'Mot de passe Flespi', _settings['flespi_password'] ?? '',
                  isSecret: true),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.key_outlined,
              title: 'Token d\'accès Flespi (flespi_token)',
              value: (_settings['flespi_token'] ?? '').isNotEmpty
                  ? '••••••••••••••••'
                  : '',
              onEdit: () => _editField('flespi_token',
                  'Token Flespi (Master/Standard)',
                  _settings['flespi_token'] ?? '',
                  isSecret: true),
            ),

            // ── Section 3 : Intelligence Artificielle ────────────────────────
            const SizedBox(height: 24),
            const _SectionTitle(
                title: 'Intelligence Artificielle', icon: Icons.psychology),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.api,
              title: 'Clé API Gemini (gemini_api_key)',
              value: (_settings['gemini_api_key'] ?? '').isNotEmpty
                  ? '••••••••••••••••'
                  : '',
              onEdit: () => _editField('gemini_api_key',
                  'Clé Secrète API Google Gemini',
                  _settings['gemini_api_key'] ?? '',
                  isSecret: true),
            ),
            const SizedBox(height: 8),
            // ── Sélecteur de modèle Gemini ───────────────────────────────────
            _ModelCard(
              currentLabel: currentModelLabel,
              onSelect: _selectGeminiModel,
            ),

            // ── Section 4 : Préférences & Système ───────────────────────────
            const SizedBox(height: 24),
            const _SectionTitle(
                title: 'Préférences & Système', icon: Icons.settings),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const DarkModeSwitch(),
              ),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.attach_money,
              title: 'Devise principale',
              subtitle: 'Dinar algérien fixe (DZD)',
              trailing: const Text(
                'DZD (DA)',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              onTap: () {},
            ),

            // ── Section 5 : Commissions ──────────────────────────────────────
            const SizedBox(height: 24),
            const _SectionTitle(
                title: 'Commissions du gérant', icon: Icons.percent),
            const SizedBox(height: 4),
            Text(
              'Définissez le taux par défaut pré-rempli dans chaque formulaire.',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 12),
            _CommissionCard(
              label: 'Vente',
              icon: Icons.sell_outlined,
              typeKey: 'commission_vente_type',
              valeurKey: 'commission_vente_valeur',
              settings: _settings,
              onChanged: (updated) async {
                setState(() => _settings = updated);
                await _save();
              },
            ),
            const SizedBox(height: 8),
            _CommissionCard(
              label: 'Échange / Reprise',
              icon: Icons.swap_horiz,
              typeKey: 'commission_echange_type',
              valeurKey: 'commission_echange_valeur',
              settings: _settings,
              onChanged: (updated) async {
                setState(() => _settings = updated);
                await _save();
              },
            ),
            const SizedBox(height: 8),
            _CommissionCard(
              label: 'Location',
              icon: Icons.car_rental,
              typeKey: 'commission_location_type',
              valeurKey: 'commission_location_valeur',
              settings: _settings,
              onChanged: (updated) async {
                setState(() => _settings = updated);
                await _save();
              },
            ),
            const SizedBox(height: 8),
            _CommissionCard(
              label: 'Achat',
              icon: Icons.shopping_cart_outlined,
              typeKey: 'commission_achat_type',
              valeurKey: 'commission_achat_valeur',
              settings: _settings,
              onChanged: (updated) async {
                setState(() => _settings = updated);
                await _save();
              },
            ),

            // ── Section 6 : Contrats Clauses ─────────────────────────────────
            const SizedBox(height: 24),
            const _SectionTitle(
                title: 'Gestion des Documents',
                icon: Icons.description_outlined),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.article_outlined,
              title: 'Clauses & Articles des contrats',
              subtitle:
                  'Configurer les mentions légales par type (location, vente, échange)',
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/admin/contract-articles'),
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                "© ${DateTime.now().year} ${_settings['nom'] ?? 'Garage Auto'} — Gestion Showroom",
                style: AppTextStyles.bodySecondary,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        if (_saving)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
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
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(title,
              style: AppTextStyles.heading3
                  .copyWith(color: AppColors.textSecondary)),
        ],
      );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final VoidCallback onEdit;
  const _InfoCard(
      {required this.icon,
      required this.title,
      required this.value,
      required this.onEdit});

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
          title: Text(title,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
          subtitle: Text(
            value.isEmpty ? 'Non défini' : value,
            style: AppTextStyles.heading3.copyWith(
              color: value.isEmpty ? AppColors.textHint : null,
              fontSize: 14,
            ),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.edit, size: 18),
            onPressed: onEdit,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

/// Carte spéciale pour le sélecteur de modèle Gemini (ouvre un dialogue Radio)
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
            child:
                Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 20),
          ),
          title: Text('Modèle IA (gemini_model)',
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
          subtitle: Text(
            currentLabel,
            style: AppTextStyles.heading3.copyWith(fontSize: 14),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.tune, size: 18),
            onPressed: onSelect,
            color: AppColors.textSecondary,
          ),
          onTap: onSelect,
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  const _SettingsTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.trailing,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: AppColors.textSecondary, size: 20),
          ),
          title: Text(title, style: AppTextStyles.body),
          subtitle: Text(subtitle,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 11)),
          trailing: trailing,
          onTap: onTap,
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget Commission Card
// ─────────────────────────────────────────────────────────────────────────────

class _CommissionCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String typeKey;
  final String valeurKey;
  final Map<String, dynamic> settings;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _CommissionCard({
    required this.label,
    required this.icon,
    required this.typeKey,
    required this.valeurKey,
    required this.settings,
    required this.onChanged,
  });

  CommissionType get _type =>
      CommissionTypeExt.fromDb(settings[typeKey] as String?);
  double get _valeur =>
      (settings[valeurKey] as num?)?.toDouble() ?? 0;

  Future<void> _edit(BuildContext context) async {
    CommissionType selectedType = _type;
    final ctrl = TextEditingController(text: _valeur.toStringAsFixed(
        _valeur == _valeur.truncate() ? 0 : 2));

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Commission — $label'),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type de commission', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _TypeChip(
                    label: 'Pourcentage (%)',
                    selected: selectedType == CommissionType.pct,
                    onTap: () => setLocal(() =>
                        selectedType = CommissionType.pct),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeChip(
                    label: 'Montant fixe (DA)',
                    selected: selectedType == CommissionType.fixe,
                    onTap: () => setLocal(() =>
                        selectedType = CommissionType.fixe),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Valeur',
                  suffixText: selectedType == CommissionType.pct ? '%' : 'DA',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sauvegarder'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final newVal = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? _valeur;
    final updated = Map<String, dynamic>.from(settings)
      ..[typeKey]   = selectedType.dbValue
      ..[valeurKey] = newVal;
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isPct = _type == CommissionType.pct;
    final valStr = isPct
        ? '${_valeur.toStringAsFixed(_valeur == _valeur.truncate() ? 0 : 1)} %'
        : '${_valeur.toStringAsFixed(_valeur == _valeur.truncate() ? 0 : 0)} DA fixe';

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
        title: Text(label,
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 12)),
        subtitle: Row(children: [
          Text(
            valStr,
            style: AppTextStyles.heading3.copyWith(
              fontSize: 14,
              color: AppColors.gerant,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (isPct ? AppColors.primary : AppColors.accent)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isPct ? 'PCT' : 'FIXE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isPct ? AppColors.primary : AppColors.accent,
              ),
            ),
          ),
        ]),
        trailing: IconButton(
          icon: const Icon(Icons.edit, size: 18),
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
  const _TypeChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.inputFill,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
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

// Widget switch dark mode synchronisé
class DarkModeSwitch extends ConsumerWidget {
  const DarkModeSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = mode == ThemeMode.dark;
    return SwitchListTile(
      title: const Text('Mode sombre'),
      subtitle: Text(isDark ? 'Activé' : 'Désactivé'),
      secondary: Icon(
        isDark ? Icons.dark_mode : Icons.light_mode,
        color: isDark ? AppColors.primary : AppColors.accent,
      ),
      value: isDark,
      activeThumbColor: AppColors.primary,
      onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
    );
  }
}