// lib/features/clients/presentation/client_detail_screen.dart
// Fiche client complète avec historique de locations, ventes, etc.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/client_model.dart';
import 'clients_provider.dart';

// Provider : historique locations d'un client
final clientLocationsProvider = FutureProvider.autoDispose.family<List<Map<String,dynamic>>, String>(
  (ref, clientId) async {
    final data = await ref.read(supabaseClientProvider)
      .from('locations')
      .select('*, vehicules(marque, modele)')
      .eq('client_id', clientId)
      .order('date_debut', ascending: false);
    return List<Map<String,dynamic>>.from(data);
  }
);

// Provider : ventes d'un client
final clientVentesProvider = FutureProvider.autoDispose.family<List<Map<String,dynamic>>, String>(
  (ref, clientId) async {
    final data = await ref.read(supabaseClientProvider)
      .from('ventes')
      .select('*, vehicules(marque, modele)')
      .eq('client_id', clientId)
      .order('date_vente', ascending: false);
    return List<Map<String,dynamic>>.from(data);
  }
);

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientDetailProvider(clientId));

    return clientAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur : $e'))),
      data: (client) => client == null
        ? const Scaffold(body: Center(child: Text('Client introuvable')))
        : _ClientDetailBody(client: client),
    );
  }
}

class _ClientDetailBody extends ConsumerWidget {
  final Client client;
  const _ClientDetailBody({required this.client});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locsAsync   = ref.watch(clientLocationsProvider(client.id));
    final ventesAsync = ref.watch(clientVentesProvider(client.id));

    return Scaffold(
      body: CustomScrollView(slivers: [
        // ── App Bar ────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        child: Text(client.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      Text(client.fullName,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold)),
                      _StatutBadge(client.statut),
                    ],
                  ),
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () => context.push('/clients/${client.id}/edit'),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Coordonnées ────────────────────────────────
                _Section(
                  title: 'Coordonnées',
                  icon: Icons.contact_page_outlined,
                  children: [
                    _InfoTile(Icons.phone, client.telephone,
                      onTap: () {}),
                    if (client.email != null && client.email!.isNotEmpty)
                      _InfoTile(Icons.email_outlined, client.email!),
                    if (client.adresse != null && client.adresse!.isNotEmpty)
                      _InfoTile(Icons.location_on_outlined, client.adresse!),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Documents ──────────────────────────────────
                if (client.numCni != null || client.numPermis != null)
                  _Section(
                    title: 'Documents',
                    icon: Icons.badge_outlined,
                    children: [
                      if (client.numCni != null)
                        _InfoTile(Icons.credit_card, 'CNI : ${client.numCni}'),
                      if (client.numPermis != null)
                        _InfoTile(Icons.drive_eta_outlined, 'Permis : ${client.numPermis}'),
                    ],
                  ),
                const SizedBox(height: 12),

                // ── Note interne ──────────────────────────────
                if (client.noteInterne != null && client.noteInterne!.isNotEmpty)
                  _Section(
                    title: 'Note interne',
                    icon: Icons.sticky_note_2_outlined,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(client.noteInterne!,
                          style: AppTextStyles.bodySecondary),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),

                // ── Historique locations ───────────────────────
                Text('Locations', style: AppTextStyles.heading2),
                const SizedBox(height: 8),
                locsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erreur : $e'),
                  data: (locs) => locs.isEmpty
                    ? const _EmptyHistory('Aucune location')
                    : Column(
                        children: locs.take(5).map((l) => _HistoryTile(
                          icon: Icons.car_rental,
                          title: "${l['vehicules']?['marque']} ${l['vehicules']?['modele']}",
                          subtitle: l['date_debut'] ?? '',
                          amount: "${(l['montant_brut'] as num?)?.toInt() ?? 0} DA",
                          color: AppColors.secondary,
                        )).toList(),
                      ),
                ),
                const SizedBox(height: 12),

                // ── Historique ventes ──────────────────────────
                Text('Achats / Ventes', style: AppTextStyles.heading2),
                const SizedBox(height: 8),
                ventesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Erreur : $e'),
                  data: (ventes) => ventes.isEmpty
                    ? const _EmptyHistory('Aucun achat')
                    : Column(
                        children: ventes.take(5).map((v) => _HistoryTile(
                          icon: Icons.sell_outlined,
                          title: "${v['vehicules']?['marque']} ${v['vehicules']?['modele']}",
                          subtitle: v['date_vente'] ?? '',
                          amount: "${(v['prix_vente'] as num?)?.toInt() ?? 0} DA",
                          color: AppColors.primary,
                        )).toList(),
                      ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ]),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/locations/new?clientId=${client.id}'),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle location'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ── Widgets helpers ──────────────────────────────────────────────────

class _StatutBadge extends StatelessWidget {
  final ClientStatut statut;
  const _StatutBadge(this.statut);

  @override
  Widget build(BuildContext context) {
    if (statut == ClientStatut.normal) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(statut.label,
        style: const TextStyle(color: Colors.white, fontSize: 11,
          fontWeight: FontWeight.w600)),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _Section({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(title, style: AppTextStyles.heading3),
          ]),
        ),
        const Divider(height: 1),
        ...children,
      ],
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _InfoTile(this.icon, this.text, {this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Icon(icon, size: 18, color: AppColors.textSecondary),
    title: Text(text, style: const TextStyle(fontSize: 13)),
    onTap: onTap,
  );
}

class _HistoryTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, amount;
  final Color color;
  const _HistoryTile({
    required this.icon, required this.title,
    required this.subtitle, required this.amount, required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      dense: true,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title, style: const TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
        style: const TextStyle(fontSize: 11)),
      trailing: Text(amount,
        style: TextStyle(color: color,
          fontWeight: FontWeight.bold, fontSize: 13)),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  final String message;
  const _EmptyHistory(this.message);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(message,
      style: AppTextStyles.bodySecondary),
  );
}
