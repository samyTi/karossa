// lib/features/admin/presentation/edit_user_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../auth/domain/profile_model.dart';
import 'users_provider.dart';

/// Écran de modification d'un utilisateur existant (nom, prénom,
/// téléphone, rôle). La création se fait toujours directement dans
/// Supabase — cet écran ne gère que l'édition.
class EditUserScreen extends ConsumerStatefulWidget {
  final Profile user;
  const EditUserScreen({super.key, required this.user});

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _prenomCtrl;
  late final TextEditingController _telephoneCtrl;
  late UserRole _role;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.user.nom);
    _prenomCtrl = TextEditingController(text: widget.user.prenom);
    _telephoneCtrl = TextEditingController(text: widget.user.telephone ?? '');
    _role = widget.user.role;
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _prenomCtrl.dispose();
    _telephoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(supabaseClientProvider).from('profiles').update({
        'nom': _nomCtrl.text.trim(),
        'prenom': _prenomCtrl.text.trim(),
        'telephone': _telephoneCtrl.text.trim().isEmpty
            ? null
            : _telephoneCtrl.text.trim(),
        'role': _role.name,
      }).eq('id', widget.user.id);

      ref.invalidate(usersProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Utilisateur modifié avec succès')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: 'Modifier ${widget.user.fullName}'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _prenomCtrl,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomCtrl,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Champ requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telephoneCtrl,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<UserRole>(
              value: _role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: UserRole.values
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(r.icon, size: 18, color: r.color),
                            const SizedBox(width: 8),
                            Text(r.label),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (r) => setState(() => _role = r ?? _role),
            ),
            const SizedBox(height: 4),
            Text(
              _role.description,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gerant,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
