import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../main.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../domain/profile_model.dart';
import 'auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    if (profile == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Profil'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Mon Profil',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar et nom
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: profile.color.withValues(alpha: 0.15),
                  child: Text(
                    profile.initials,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: profile.color,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.fullName,
                  style: AppTextStyles.heading2,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: profile.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: profile.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        profile.roleIcon,
                        size: 14,
                        color: profile.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        profile.roleLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: profile.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Description du rôle
          _RoleCard(
            title: 'Votre rôle',
            description: profile.roleDescription,
            icon: profile.roleIcon,
            color: profile.color,
          ),
          const SizedBox(height: 16),

          // Permissions
          _SectionTitle(title: 'Vos permissions'),
          const SizedBox(height: 8),
          ..._buildPermissionsList(profile),
          const SizedBox(height: 24),

          // Actions
          if (profile.isGerant) ...[
            _SectionTitle(title: 'Administration'),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.people,
              title: 'Gérer les utilisateurs',
              subtitle: 'Ajouter, modifier les comptes',
              color: AppColors.primary,
              onTap: () => context.push('/admin/users'),
            ),
            _ActionTile(
              icon: Icons.settings,
              title: 'Paramètres du showroom',
              subtitle: 'Configuration générale',
              color: AppColors.primary,
              onTap: () => context.push('/admin/settings'),
            ),
            const SizedBox(height: 16),
          ],

          // Déconnexion
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, ref),
              icon: const Icon(Icons.logout, color: AppColors.retard),
              label: const Text(
                'Se déconnecter',
                style: TextStyle(color: AppColors.retard),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.retard),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPermissionsList(Profile profile) {
    final permissions = [
      if (profile.canManageVehicules)
        _PermissionTile('Gestion véhicules', profile.canManageVehicules),
      if (profile.isGerant) ...[
        _PermissionTile('Créer locations', true),
        _PermissionTile('Créer ventes', true),
        _PermissionTile('Créer échanges', true),
        _PermissionTile('Gestion caisse', true),
        _PermissionTile('Gestion réparations', true),
      ],
      if (profile.canViewFullFinance)
        _PermissionTile('Rapports financiers', true),
      if (profile.isProprietaire)
        _PermissionTile('Voir mes véhicules', true),
      if (profile.isProprietaire)
        _PermissionTile('Voir mes revenus', true),
    ];

    return permissions;
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Directly sign out from Supabase for reliability
              await supabase.auth.signOut();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                // Force navigation to login
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.retard,
            ),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppTextStyles.heading3.copyWith(
      color: AppColors.textSecondary,
    ),
  );
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

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
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.heading3,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.bodySecondary,
              ),
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
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(
          granted ? Icons.check_circle : Icons.cancel,
          size: 18,
          color: granted ? AppColors.secondary : AppColors.border,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.body.copyWith(
            color: granted ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: AppTextStyles.heading3),
      subtitle: Text(subtitle, style: AppTextStyles.bodySecondary),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
    ),
  );
}