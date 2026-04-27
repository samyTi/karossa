// lib/features/admin/presentation/settings_screen.dart
// Paramètres du showroom — données stockées dans Supabase

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../contrats/presentation/contrats_provider.dart';
import '../../contrats/data/contrats_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(showroomSettingsProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Paramètres du showroom',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Erreur : \$e')),
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

  Future<void> _editField(String key, String label, String current) async {
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Modifier — \$label'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
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

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ContratsRepository().updateShowroomSettings(_settings);
      ref.invalidate(showroomSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres sauvegardés'),
              backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : \$e'),
              backgroundColor: AppColors.retard),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionTitle(title: 'Informations générales', icon: Icons.business),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.business,
              title: 'Nom du showroom',
              value: _settings['nom'] ?? '',
              onEdit: () => _editField('nom', 'Nom du showroom', _settings['nom'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.location_on,
              title: 'Adresse',
              value: _settings['adresse'] ?? '',
              onEdit: () => _editField('adresse', 'Adresse', _settings['adresse'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.phone,
              title: 'Téléphone',
              value: _settings['tel'] ?? '',
              onEdit: () => _editField('tel', 'Téléphone', _settings['tel'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.email,
              title: 'Email',
              value: _settings['email'] ?? '',
              onEdit: () => _editField('email', 'Email', _settings['email'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.gavel,
              title: 'Registre du commerce',
              value: _settings['rc'] ?? '',
              onEdit: () => _editField('rc', 'RC / Matricule', _settings['rc'] ?? ''),
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: 'GPS Traccar', icon: Icons.gps_fixed),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.dns,
              title: 'URL Traccar',
              value: _settings['traccar_url'] ?? 'Non configuré',
              onEdit: () => _editField('traccar_url', 'URL Traccar (ex: http://192.168.1.10:8082)',
                  _settings['traccar_url'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.person,
              title: 'Login Traccar',
              value: _settings['traccar_user'] ?? '',
              onEdit: () => _editField('traccar_user', 'Email Traccar',
                  _settings['traccar_user'] ?? ''),
            ),
            const SizedBox(height: 8),
            _InfoCard(
              icon: Icons.lock,
              title: 'Mot de passe Traccar',
              value: (_settings['traccar_password'] ?? '').isNotEmpty ? '••••••••' : '',
              onEdit: () => _editField('traccar_password', 'Mot de passe Traccar',
                  _settings['traccar_password'] ?? ''),
            ),

            const SizedBox(height: 24),
            _SectionTitle(title: 'Préférences', icon: Icons.settings),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.attach_money,
              title: 'Devise',
              subtitle: 'Dinar algérien (DZD)',
              trailing: const Text('DZD',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {},
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                "© ${DateTime.now().year} ${_settings['nom'] ?? 'Garage Auto'}",
                style: AppTextStyles.bodySecondary,
              ),
            ),
          ],
        ),
        if (_saving)
          const Positioned(
            top: 0, left: 0, right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

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
          style: AppTextStyles.heading3.copyWith(color: AppColors.textSecondary)),
    ],
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, value;
  final VoidCallback onEdit;
  const _InfoCard({required this.icon, required this.title,
      required this.value, required this.onEdit});

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

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget trailing;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.title,
      required this.subtitle, required this.trailing, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title, style: AppTextStyles.body),
      subtitle: Text(subtitle,
          style: AppTextStyles.bodySecondary.copyWith(fontSize: 11)),
      trailing: trailing,
      onTap: onTap,
    ),
  );
}
