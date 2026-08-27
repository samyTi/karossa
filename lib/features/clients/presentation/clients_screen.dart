import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/custom_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_loading.dart';
import '../domain/client_model.dart';
import 'clients_provider.dart';
import '../../../shared/widgets/search_bar_widget.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});
  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider);
    return Scaffold(
      appBar: CustomAppBar(
        title: context.l10n.titreClients,
        showBackButton: false,
        showHomeButton: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clients/new'),
        icon: const Icon(Icons.person_add),
        label: Text(context.l10n.nouveauClient),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
body: Column(children: [
  AppSearchBar(
    hint: context.l10n.rechercherUnClient,
    onChanged: (q) => setState(() => _search = q),
  ),
  Expanded(child: clients.when(
        loading: () => const ClientsListShimmer(),
        error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
data: (allList) {
  final list = _search.isEmpty ? allList
    : allList.where((c) =>
        c.fullName.toLowerCase().contains(_search.toLowerCase()) ||
        c.telephone.contains(_search)).toList();
  return list.isEmpty
          ? EmptyState(
              icon: Icons.people_outline,
              message: context.l10n.aucunClientEnregistre)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: list.length,
              itemBuilder: (_, i) => _ClientTile(client: list[i]),
            );
        },
      )),
    ]),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Client client;
  const _ClientTile({required this.client});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(client.initials,
          style: const TextStyle(color: AppColors.primary,
            fontWeight: FontWeight.w600, fontSize: 13)),
      ),
      title: Row(children: [
        Text(client.fullName, style: AppTextStyles.heading3),
        if (client.statut != ClientStatut.normal) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: client.statut.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
            child: Text(client.statut.label,
              style: TextStyle(fontSize: 10,
                color: client.statut.color,
                fontWeight: FontWeight.w600)),
          ),
        ],
      ]),
      subtitle: Text(client.telephone,
        style: AppTextStyles.bodySecondary),
      trailing: const Icon(Icons.chevron_right,
        color: AppColors.textSecondary),
      onTap: () => context.push('/clients/${client.id}'),
    ),
  );
}
