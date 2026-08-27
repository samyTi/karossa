//lib/features/admin/presentation/users_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/domain/profile_model.dart';
import 'users_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.gererLesUtilisateurs,
        showHomeButton: true,
      ),
      body: usersAsync.when(
        loading: () => const ClientsListShimmer(), // Réutilise le shimmer des clients
        error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
        data: (users) => Column(
          children: [
            // Stats bar
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Total',
                    value: '${users.length}',
                    icon: Icons.people,
                    color: AppColors.primary,
                  ),
                  _StatItem(
                    label: context.l10n.tabActifs,
                    value: '${users.length}', // Tous les utilisateurs sont actifs par défaut
                    icon: Icons.check_circle,
                    color: AppColors.secondary,
                  ),
                  const _StatItem(
                    label: 'Inactifs',
                    value: '0',
                    icon: Icons.cancel,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),

            // Users list
            Expanded(
              child: users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: AppColors.textHint),
                          const SizedBox(height: 16),
                          Text(context.l10n.aucunUtilisateurTrouve, style: AppTextStyles.bodySecondary,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _UserCard(user: user);
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/users/add'),
        icon: const Icon(Icons.person_add),
        label: Text(context.l10n.btnAjouter),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: AppTextStyles.label.copyWith(color: color),
      ),
    ],
  );
}

class _UserCard extends StatelessWidget {
  final Profile user;

  const _UserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final roleColor = user.role.color;
    final roleLabel = user.role.label;
    // Tous les rôles ont désormais un résumé financier consultable :
    // propriétaire/associé → parts de copropriété, gérant → commissions (écran dédié).
    final isGerant = user.role == UserRole.gerant;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push(
          isGerant
              ? '/admin/gerant/${user.id}?nom=${Uri.encodeComponent(user.fullName)}'
              : '/admin/proprietaire/${user.id}?nom=${Uri.encodeComponent(user.fullName)}',
        ),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: roleColor.withValues(alpha: 0.15),
              child: Text(
                user.initials,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.telephone ?? '',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: roleColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      roleLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: roleColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Icon(Icons.account_balance_wallet_outlined,
                  color: AppColors.textHint, size: 18),
            ),

            // Actions
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/admin/users/edit', extra: user);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text(context.l10n.btnModifier),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}