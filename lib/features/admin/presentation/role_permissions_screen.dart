// lib/features/admin/presentation/role_permissions_screen.dart
//
// Permet à un administrateur de personnaliser, pour son showroom, les
// permissions accordées à chaque rôle (gerant, proprietaire, associe).
// Le rôle admin n'est pas éditable ici : il garde toujours l'accès complet
// pour éviter qu'un admin ne se retrouve bloqué hors de cet écran.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/modern_app_bar.dart';
import '../../auth/domain/profile_model.dart';
import '../../auth/presentation/auth_provider.dart';

final _editableRoles = [UserRole.gerant, UserRole.externe];

/// Charge les permissions actuelles (overrides existants ou valeurs par
/// défaut codées en dur) pour le showroom courant.
final _rolePermissionsDraftProvider =
    FutureProvider.autoDispose<Map<UserRole, Set<String>>>((ref) async {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  final result = <UserRole, Set<String>>{
    for (final r in _editableRoles) r: {...RolePermissions.getDefaultPermissions(r)},
  };
  if (profile?.showroomId == null) return result;

  final client = ref.watch(supabaseClientProvider);
  try {
    final rows = await client
        .from('role_permissions')
        .select()
        .eq('showroom_id', profile!.showroomId as Object);
    for (final row in (rows as List)) {
      final role = _editableRoles.where((r) => r.name == row['role']).cast<UserRole?>().firstWhere(
            (_) => true,
            orElse: () => null,
          );
      if (role == null) continue;
      result[role] = Set<String>.from(row['permissions'] ?? const []);
    }
  } catch (_) {
    // Table pas encore créée / erreur réseau → on garde les défauts.
  }
  return result;
});

class RolePermissionsScreen extends ConsumerStatefulWidget {
  const RolePermissionsScreen({super.key});

  @override
  ConsumerState<RolePermissionsScreen> createState() => _RolePermissionsScreenState();
}

class _RolePermissionsScreenState extends ConsumerState<RolePermissionsScreen> {
  Map<UserRole, Set<String>>? _draft;
  bool _saving = false;
  bool _dirty = false;

  void _ensureDraft(Map<UserRole, Set<String>> loaded) {
    _draft ??= {for (final e in loaded.entries) e.key: {...e.value}};
  }

  void _toggle(UserRole role, String permission, bool value) {
    setState(() {
      final set = _draft![role]!;
      if (value) {
        set.add(permission);
      } else {
        set.remove(permission);
      }
      _dirty = true;
    });
  }

  Future<void> _save() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile?.showroomId == null || _draft == null) return;

    setState(() => _saving = true);
    final client = ref.read(supabaseClientProvider);
    try {
      for (final role in _editableRoles) {
        await client.from('role_permissions').upsert({
          'showroom_id': profile!.showroomId,
          'role': role.name,
          'permissions': _draft![role]!.toList(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      RolePermissions.applyOverrides(_draft!);
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions enregistrées')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetRoleToDefault(UserRole role) {
    setState(() {
      _draft![role] = {...RolePermissions.getDefaultPermissions(role)};
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncDraft = ref.watch(_rolePermissionsDraftProvider);

    return Scaffold(
      appBar: const ModernAppBar(title: 'Permissions par rôle'),
      body: asyncDraft.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (loaded) {
          _ensureDraft(loaded);
          return DefaultTabController(
            length: _editableRoles.length,
            child: Column(
              children: [
                TabBar(
                  labelColor: AppColors.primary,
                  tabs: [for (final r in _editableRoles) Tab(text: r.label)],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final role in _editableRoles) _RolePermissionsTab(
                        role: role,
                        selected: _draft![role]!,
                        onToggle: (perm, v) => _toggle(role, perm, v),
                        onReset: () => _resetRoleToDefault(role),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: _dirty
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Enregistrement…' : 'Enregistrer'),
            )
          : null,
    );
  }
}

class _RolePermissionsTab extends StatelessWidget {
  final UserRole role;
  final Set<String> selected;
  final void Function(String permission, bool value) onToggle;
  final VoidCallback onReset;

  const _RolePermissionsTab({
    required this.role,
    required this.selected,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                role.description,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            TextButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Défaut'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final entry in Permission.catalog.entries.where((e) => e.key != 'Administration')) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(entry.key,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
          ),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                for (final perm in entry.value)
                  SwitchListTile(
                    dense: true,
                    title: Text(perm.value, style: const TextStyle(fontSize: 14)),
                    value: selected.contains(perm.key),
                    onChanged: (v) => onToggle(perm.key, v),
                    activeTrackColor: AppColors.primary,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
