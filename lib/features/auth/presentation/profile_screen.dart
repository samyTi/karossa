// lib/features/profile/presentation/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../domain/profile_model.dart';
import 'auth_provider.dart';

/// Provider pour charger les informations du showroom depuis la base de données
final showroomSettingsProvider = FutureProvider((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  return await supabase.from('showroom_settings').select().maybeSingle();
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final showroomAsync = ref.watch(showroomSettingsProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Erreur : $err'))),
      data: (profile) {
        if (profile == null) {
          return const Scaffold(body: Center(child: Text('Profil introuvable')));
        }

        return Scaffold(
          appBar: const CustomAppBar(
            title: 'Mon Profil',
            showHomeButton: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- 1. En-tête : Avatar et Identité ---
              _buildProfileHeader(profile),
              const SizedBox(height: 24),

              // --- 2. Carte Rôle & Description ---
              _RoleCard(
                title: 'Votre rôle',
                description: profile.roleDescription,
                icon: profile.roleIcon,
                color: profile.color,
              ),
              const SizedBox(height: 24),

              // --- 3. Informations de Contact (Table profiles) ---
              const _SectionTitle(title: 'Informations de contact'),
              const SizedBox(height: 8),
              _buildInfoTile(Icons.phone, 'Téléphone', profile.telephone ?? 'Non renseigné'),
              _buildInfoTile(Icons.email, 'Compte', 'Connecté via Supabase'),
              const SizedBox(height: 24),

              // --- 4. Informations Showroom (Table showroom_settings) ---
              showroomAsync.when(
                data: (settings) => _buildShowroomSection(settings),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // --- 5. Permissions ---
              const _SectionTitle(title: 'Vos permissions accès'),
              const SizedBox(height: 8),
              ..._buildPermissionsList(profile),
              const SizedBox(height: 24),

              // --- 6. Administration (Gérant uniquement) ---
              if (profile.isGerant) ...[
                const _SectionTitle(title: 'Administration Showroom'),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.people_alt_outlined,
                  title: 'Gérer l\'équipe',
                  subtitle: 'Comptes gérants, associés et propriétaires',
                  color: AppColors.primary,
                  onTap: () => context.push('/admin/users'),
                ),
                _ActionTile(
                  icon: Icons.settings_suggest_outlined,
                  title: 'Paramètres système',
                  subtitle: 'Clés API Gemini, Flespi et coordonnées',
                  color: AppColors.primary,
                  onTap: () => context.push('/admin/settings'),
                ),
                const SizedBox(height: 24),
              ],

              // --- 7. Bouton Déconnexion ---
              _buildLogoutButton(context, ref),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(Profile profile) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 45,
            backgroundColor: profile.color.withValues(alpha: 0.15),
            child: Text(
              profile.initials,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: profile.color),
            ),
          ),
          const SizedBox(height: 16),
          Text(profile.fullName, style: AppTextStyles.heading2),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: profile.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: profile.color.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(profile.roleIcon, size: 14, color: profile.color),
                const SizedBox(width: 6),
                Text(
                  profile.roleLabel.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: profile.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary, size: 20),
        title: Text(label, style: AppTextStyles.bodySecondary),
        subtitle: Text(value, style: AppTextStyles.heading3),
      ),
    );
  }

  Widget _buildShowroomSection(Map<String, dynamic>? settings) {
    if (settings == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Showroom rattaché'),
        const SizedBox(height: 8),
        Card(
          color: AppColors.secondary.withValues(alpha: 0.05),
          child: ListTile(
            leading: const Icon(Icons.business, color: AppColors.secondary),
            title: Text(settings['nom'] ?? 'Karossa Showroom', style: AppTextStyles.heading3),
            subtitle: Text(settings['adresse'] ?? 'Algérie', style: AppTextStyles.bodySecondary),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPermissionsList(Profile profile) {
    return [
      _PermissionTile('Gestion du stock véhicules', profile.canManageVehicules),
      _PermissionTile('Accès aux rapports financiers', profile.canViewFullFinance || profile.isGerant),
      _PermissionTile('Gestion de la caisse showroom', profile.isGerant),
      if (profile.isProprietaire)
        const _PermissionTile('Suivi de mes parts et revenus', true),
    ];
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _showLogoutDialog(context, ref),
      icon: const Icon(Icons.logout, color: AppColors.retard),
      label: const Text('Se déconnecter', 
        style: TextStyle(color: AppColors.retard, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.retard),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment fermer votre session Karossa ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.retard),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }
}

// --- Widgets de support ---

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) => Text(title, 
    style: AppTextStyles.heading3.copyWith(color: AppColors.textSecondary));
}

class _RoleCard extends StatelessWidget {
  final String title, description;
  final IconData icon;
  final Color color;
  const _RoleCard({required this.title, required this.description, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading3),
              const SizedBox(height: 4),
              Text(description, style: AppTextStyles.bodySecondary),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PermissionTile extends StatelessWidget {
  final String label;
  final bool granted;
  const _PermissionTile(this.label, this.granted);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(granted ? Icons.check_circle : Icons.lock_outline, 
          size: 18, color: granted ? AppColors.secondary : Colors.grey),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: granted ? AppColors.textPrimary : Colors.grey)),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: AppTextStyles.heading3),
      subtitle: Text(subtitle, style: AppTextStyles.bodySecondary),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}