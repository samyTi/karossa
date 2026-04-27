import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../../auth/domain/profile_model.dart';
import 'users_provider.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Gérer les utilisateurs',
        showBackButton: true,
        showHomeButton: true,
      ),
      body: usersAsync.when(
        loading: () => const ClientsListShimmer(itemCount: 5), // Réutilise le shimmer des clients
        error: (e, _) => Center(child: Text('Erreur: $e')),
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
                    label: 'Actifs',
                    value: '${users.length}', // Tous les utilisateurs sont actifs par défaut
                    icon: Icons.check_circle,
                    color: AppColors.secondary,
                  ),
                  _StatItem(
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
                          Text(
                            'Aucun utilisateur trouvé',
                            style: AppTextStyles.bodySecondary,
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
        onPressed: () {
          // TODO: Show add user dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ajouter un utilisateur...')),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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

            // Actions
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Édition utilisateur...')),
                  );
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
