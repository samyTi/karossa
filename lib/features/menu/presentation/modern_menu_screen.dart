// lib/features/menu/presentation/modern_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/profile_model.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class ModernMenuScreen extends ConsumerWidget {
  const ModernMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(context.l10n.karossaShowroom),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppColors.error),
            tooltip: context.l10n.deconnexion,
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(context.l10n.deconnexion),
                  content: Text(context.l10n.etesVousSurDeVouloirVous),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.l10n.btnAnnuler),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: Text(context.l10n.seDeconnecter),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(supabaseClientProvider).auth.signOut();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête Utilisateur ──────────────────────────────────────────
            userAsync.when(
              data: (user) => Padding(
                padding: const EdgeInsets.only(bottom: 24.0, left: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour, ${user?.email?.split('@').first ?? 'Utilisateur'} 👋',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(context.l10n.bienvenueDansVotreGestionnaireDeShowroom, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              loading: () => const SizedBox(height: 60),
              error: (_, __) => const SizedBox(height: 60),
            ),

            // ── SECTION 1 : ACTIVITÉ COMMERCIALE ─────────────────────────────
            _buildSectionTitle(context, 'Activité Commerciale'),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MenuListRow(
                    label: context.l10n.titreVentes,
                    icon: Icons.monetization_on_outlined,
                    color: AppColors.primary,
                    route: '/ventes',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.titreLocations,
                    icon: Icons.vpn_key_outlined,
                    color: Colors.orange,
                    route: '/locations',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.achatsDeVehicules,
                    icon: Icons.shopping_bag_outlined,
                    color: Colors.cyan,
                    route: '/achats',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.titreEchanges,
                    icon: Icons.swap_horiz_rounded,
                    color: Colors.teal,
                    route: '/echanges',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  // ✅ BRANCHEMENT : Demandes Web & Leads ajoutées ici
                  _MenuListRow(
                    label: context.l10n.demandesWebLeads,
                    icon: Icons.cloud_download_outlined,
                    color: AppColors.secondary,
                    route: '/more/web-demandes', // ✅ Doit correspondre exactement à /more/web-demandes
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.contratsPdf,
                    icon: Icons.description_outlined,
                    color: Colors.purple,
                    route: '/contrats',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── SECTION 2 : FLOTTE, LOGISTIQUE & ATELIER ─────────────────────
            _buildSectionTitle(context, 'Flotte & Atelier'),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MenuListRow(
                    label: context.l10n.suiviGpsBalises,
                    icon: Icons.gps_fixed_outlined,
                    color: Colors.redAccent,
                    route: '/gps',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.parcAutomobilesVehicules,
                    icon: Icons.directions_car_filled_outlined,
                    color: Colors.blueGrey,
                    route: '/vehicules',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.gestionDesClients,
                    icon: Icons.people_alt_outlined,
                    color: Colors.indigo,
                    route: '/clients',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.reparations,
                    icon: Icons.build_outlined,
                    color: Colors.deepOrange,
                    route: '/reparations',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.entretienRevisions,
                    icon: Icons.car_repair_outlined,
                    color: Colors.brown,
                    route: '/entretien',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── SECTION 3 : COMPTABILITÉ & COMMUNICATION ──────────────────────
            _buildSectionTitle(context, 'Finance & Communication'),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  if (profile?.isExterne == true) ...[
                    _MenuListRow(
                      label: 'Mon résumé financier',
                      icon: Icons.account_balance_wallet_outlined,
                      color: Colors.green,
                      route: '/admin/proprietaire/${profile!.id}'
                          '?nom=${Uri.encodeComponent(profile.fullName)}',
                    ),
                    Divider(height: 1, color: Colors.grey.shade100),
                  ],
                  _MenuListRow(
                    label: context.l10n.gestionDeLaCaisse,
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.pink,
                    route: '/caisse',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.rapportsReleves,
                    icon: Icons.bar_chart_rounded,
                    color: Colors.green,
                    route: '/releve',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.assistantVirtuelIa,
                    icon: Icons.psychology_outlined,
                    color: Colors.deepPurpleAccent,
                    route: '/ai-chat',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.notificationsAlertes,
                    icon: Icons.notifications_none_outlined,
                    color: Colors.amber.shade700,
                    route: '/notifications',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── SECTION 4 : CONFIGURATION & ADMINISTRATION ──────────────────
            _buildSectionTitle(context, 'Configuration & Système'),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              child: ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MenuListRow(
                    label: context.l10n.gestionDesClausesArticles,
                    icon: Icons.gavel_outlined,
                    color: Colors.amber,
                    route: '/admin/contract-articles',
                    enabled: ref.watch(currentProfileProvider).valueOrNull
                            ?.hasPermission(Permission.usersManage) ==
                        true,
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.gestionDesUtilisateurs,
                    icon: Icons.manage_accounts_outlined,
                    color: Colors.blueGrey,
                    route: '/admin/users',
                    enabled: ref.watch(currentProfileProvider).valueOrNull
                            ?.hasPermission(Permission.usersManage) ==
                        true,
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: context.l10n.configurationDuShowroom,
                    icon: Icons.settings_outlined,
                    color: Colors.blue,
                    route: '/admin/settings',
                    enabled: ref.watch(currentProfileProvider).valueOrNull
                            ?.hasPermission(Permission.usersManage) ==
                        true,
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: 'Permissions par rôle',
                    icon: Icons.admin_panel_settings_outlined,
                    color: Colors.indigo,
                    route: '/admin/role-permissions',
                    enabled: ref.watch(currentProfileProvider).valueOrNull
                            ?.hasPermission(Permission.permissionsManage) ==
                        true,
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  _MenuListRow(
                    label: "Journal d'audit",
                    icon: Icons.history_toggle_off_outlined,
                    color: Colors.black87,
                    route: '/admin/audit-log',
                    enabled: ref.watch(currentProfileProvider).valueOrNull
                            ?.hasPermission(Permission.usersManage) ==
                        true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Composant Ligne (List)
// ─────────────────────────────────────────────────────────────────────────────
class _MenuListRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  final bool enabled;

  const _MenuListRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final row = ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: enabled ? color.withValues(alpha: 0.1) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: enabled ? color : Colors.grey.shade400, size: 20),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: enabled ? AppColors.textPrimary : Colors.grey.shade400,
            ),
      ),
      trailing: Icon(
        enabled ? Icons.chevron_right : Icons.lock_outline,
        color: Colors.grey.shade400,
        size: 20,
      ),
      onTap: enabled
          ? () => context.push(route)
          : () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Vous n'avez pas les droits nécessaires pour accéder à cette section."),
                ),
              ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );

    if (enabled) return row;

    return Tooltip(
      message: "Vous n'avez pas les droits nécessaires pour accéder à cette section",
      child: row,
    );
  }
}