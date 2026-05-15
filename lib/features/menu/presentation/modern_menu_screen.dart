// lib/features/menu/presentation/modern_menu_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../../../core/theme/app_colors.dart';

class ModernMenuScreen extends ConsumerWidget {
  const ModernMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Karossa Showroom'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppColors.error),
            tooltip: 'Déconnexion',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Se déconnecter'),
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
                    Text(
                      'Bienvenue dans votre gestionnaire de showroom',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                  const _MenuListRow(
                    label: 'Ventes',
                    icon: Icons.monetization_on_outlined,
                    color: AppColors.primary,
                    route: '/ventes',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Locations',
                    icon: Icons.vpn_key_outlined,
                    color: Colors.orange,
                    route: '/locations',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Achats de véhicules',
                    icon: Icons.shopping_bag_outlined,
                    color: Colors.cyan,
                    route: '/achats',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Échanges',
                    icon: Icons.swap_horiz_rounded,
                    color: Colors.teal,
                    route: '/echanges',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Contrats PDF',
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
                  const _MenuListRow(
                    label: 'Suivi GPS & Balises',
                    icon: Icons.gps_fixed_outlined,
                    color: Colors.redAccent,
                    route: '/gps',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Parc Automobiles (Véhicules)',
                    icon: Icons.directions_car_filled_outlined,
                    color: Colors.blueGrey,
                    route: '/vehicules',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Gestion des Clients',
                    icon: Icons.people_alt_outlined,
                    color: Colors.indigo,
                    route: '/clients',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Réparations',
                    icon: Icons.build_outlined,
                    color: Colors.deepOrange,
                    route: '/reparations',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Entretien & Révisions',
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
                  const _MenuListRow(
                    label: 'Gestion de la Caisse',
                    icon: Icons.account_balance_wallet_outlined,
                    color: Colors.pink,
                    route: '/caisse',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Rapports & Relevés',
                    icon: Icons.bar_chart_rounded,
                    color: Colors.green,
                    route: '/releve',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Assistant Virtuel IA',
                    icon: Icons.psychology_outlined,
                    color: Colors.deepPurpleAccent,
                    route: '/ai-chat',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  // ✅ FIX : Le mot-clé const a été retiré ici pour autoriser l'accès à .shade700
                  _MenuListRow(
                    label: 'Notifications & Alertes',
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
                  const _MenuListRow(
                    label: 'Gestion des clauses (Articles)',
                    icon: Icons.gavel_outlined,
                    color: Colors.amber,
                    route: '/admin/contract-articles',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Gestion des Utilisateurs',
                    icon: Icons.manage_accounts_outlined,
                    color: Colors.blueGrey,
                    route: '/admin/users',
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  const _MenuListRow(
                    label: 'Configuration du Showroom',
                    icon: Icons.settings_outlined,
                    color: Colors.blue,
                    route: '/admin/settings',
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

  const _MenuListRow({
    required this.label,
    required this.icon,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
      onTap: () => context.push(route),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}