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
// ── Imports pour le badge des demandes web ──
import '../../web_demandes/presentation/web_demandes_providers.dart';
import '../../web_demandes/domain/web_demande_model.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

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
    
    // Écouter les requêtes du site web pour le badge d'alerte
    final webDemandesAsync = ref.watch(webDemandesListProvider);

    return profileAsync.when(
      loading: () => Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text(context.l10n.erreurAvecDetail(err.toString())))),
      data: (profile) {
        if (profile == null) {
          return Scaffold(body: Center(child: Text(context.l10n.profilIntrouvable)));
        }

        // Récupérer le nombre de demandes en attente de traitement
        final int nbEnAttente = webDemandesAsync.maybeWhen(
          data: (list) => list.where((d) => d.statut == DemandeWebStatut.enAttente).length,
          orElse: () => 0,
        );

        return Scaffold(
          appBar: CustomAppBar(
            title: context.l10n.monProfil,
            showHomeButton: true,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- 1. En-tête : Avatar et Identité ---
              _buildProfileHeader(profile),
              SizedBox(height: 24),

              // --- 2. Carte Rôle & Description ---
              _RoleCard(
                title: context.l10n.votreRole,
                description: profile.roleDescription,
                icon: profile.roleIcon,
                color: profile.color,
              ),
              SizedBox(height: 24),

              // --- 3. Informations de Contact (Table profiles) ---
              _SectionTitle(title: context.l10n.informationsDeContact),
              SizedBox(height: 8),
              _buildInfoTile(Icons.phone, 'Téléphone', profile.telephone ?? 'Non renseigné'),
              _buildInfoTile(Icons.email, 'Compte', 'Connecté via Supabase'),
              SizedBox(height: 24),

              // --- 4. Informations Showroom (Table showroom_settings) ---
              showroomAsync.when(
                data: (settings) => _buildShowroomSection(context, settings),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              SizedBox(height: 24),

              // --- 5. Permissions ---
              _SectionTitle(title: context.l10n.vosPermissionsAcces),
              SizedBox(height: 8),
              ..._buildPermissionsList(profile),
              SizedBox(height: 24),

              // --- 6. Administration (Gérant uniquement) ---
              if (profile.isGerant) ...[
                _SectionTitle(title: context.l10n.administrationShowroom),
                SizedBox(height: 8),
                
                // ✅ Nouveau bouton d'accès au module Web branché sur votre route
                _ActionTile(
                  icon: Icons.cloud_download_outlined,
                  title: context.l10n.demandesWebLeads,
                  subtitle: context.l10n.reservationsAchatsEtEchangesDuSite,
                  color: Colors.orange,
                  badgeCount: nbEnAttente > 0 ? nbEnAttente : null,
                  onTap: () => context.push('/admin/web-demandes'),
                ),
                
                _ActionTile(
                  icon: Icons.people_alt_outlined,
                  title: context.l10n.gererLEquipe,
                  subtitle: context.l10n.comptesGerantsAssociesEtProprietaires,
                  color: AppColors.primary,
                  onTap: () => context.push('/admin/users'),
                ),
                _ActionTile(
                  icon: Icons.settings_suggest_outlined,
                  title: context.l10n.parametresSysteme,
                  subtitle: context.l10n.clesApiGeminiFlespiEtCoordonnees,
                  color: AppColors.primary,
                  onTap: () => context.push('/admin/settings'),
                ),
                SizedBox(height: 24),
              ],

              // --- 7. Bouton Déconnexion ---
              _buildLogoutButton(context, ref),
              SizedBox(height: 32),
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
          SizedBox(height: 16),
          Text(profile.fullName, style: AppTextStyles.heading2),
          SizedBox(height: 6),
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
                SizedBox(width: 6),
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

  Widget _buildShowroomSection(BuildContext context, Map<String, dynamic>? settings) {
    if (settings == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: context.l10n.showroomRattache),
        SizedBox(height: 8),
        Card(
          color: AppColors.secondary.withValues(alpha: 0.05),
          child: ListTile(
            leading: Icon(Icons.business, color: AppColors.secondary),
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
      if (profile.isExterne)
        const _PermissionTile('Suivi de mes parts et revenus', true),
    ];
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () => _showLogoutDialog(context, ref),
      icon: Icon(Icons.logout, color: AppColors.retard),
      label: Text(context.l10n.seDeconnecter, 
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
        title: Text(context.l10n.deconnexion),
        content: Text(context.l10n.voulezVousVraimentFermerVotreSession),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.btnAnnuler)),
          ElevatedButton(
            onPressed: () async {
              await ref.read(supabaseClientProvider).auth.signOut();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.retard),
            child: Text(ctx.l10n.btnConfirmer),
          ),
        ],
      ),
    );
  }
}

// --- Widgets de support ---

class _SectionTitle extends StatelessWidget {
  final String title;
  _SectionTitle({required this.title});
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
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.heading3),
              SizedBox(height: 4),
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
        SizedBox(width: 10),
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
  final int? badgeCount; // ✅ Ajout du paramètre optionnel pour les notifications

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.1),
        child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: AppTextStyles.heading3),
      subtitle: Text(subtitle, style: AppTextStyles.bodySecondary),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeCount != null) // ✅ Affichage dynamique de la pastille rouge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.retard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          SizedBox(width: 4),
          Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    ),
  );
}