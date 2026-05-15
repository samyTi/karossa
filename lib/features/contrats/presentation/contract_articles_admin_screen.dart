// lib/features/contrats/presentation/contract_articles_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_text_styles.dart';
import './contract_articles_provider.dart';
import '../domain/contract_article_model.dart';

class ContractArticlesAdminScreen extends ConsumerStatefulWidget {
  const ContractArticlesAdminScreen({super.key});

  @override
  ConsumerState<ContractArticlesAdminScreen> createState() =>
      _ContractArticlesAdminScreenState();
}

class _ContractArticlesAdminScreenState
    extends ConsumerState<ContractArticlesAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _types = ['location', 'vente', 'echange'];
  final _typesLabels = ['Location', 'Vente', 'Échange'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _types.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Articles des contrats'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _typesLabels.map((l) => Tab(text: l)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _types.map((type) => _ArticlesTab(contratType: type)).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ArticlesTab extends ConsumerWidget {
  const _ArticlesTab({required this.contratType});
  final String contratType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncArticles = ref.watch(contractArticlesNotifierProvider(contratType));

    return asyncArticles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (articles) => _ArticlesList(
        contratType: contratType,
        articles: articles,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ArticlesList extends ConsumerStatefulWidget {
  const _ArticlesList({required this.contratType, required this.articles});
  final String contratType;
  final List<ContractArticle> articles;

  @override
  ConsumerState<_ArticlesList> createState() => _ArticlesListState();
}

class _ArticlesListState extends ConsumerState<_ArticlesList> {
  void _onReorder(int oldIndex, int newIndex) {
    final list = List<ContractArticle>.from(widget.articles);
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    ref
        .read(contractArticlesNotifierProvider(widget.contratType).notifier)
        .reordonner(list);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.articles.isEmpty
          ? _EmptyState(contratType: widget.contratType)
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              itemCount: widget.articles.length,
              onReorder: _onReorder,
              itemBuilder: (_, i) => _ArticleCard(
                key: ValueKey(widget.articles[i].id),
                article: widget.articles[i],
                contratType: widget.contratType,
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel article'),
      ),
    );
  }

  void _showForm(BuildContext context, ContractArticle? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ArticleForm(
        contratType: widget.contratType,
        existing: existing,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ArticleCard extends ConsumerWidget {
  const _ArticleCard({super.key, required this.article, required this.contratType});
  final ContractArticle article;
  final String contratType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(contractArticlesNotifierProvider(contratType).notifier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.drag_handle),
        title: Row(
          children: [
            Expanded(
              child: Text(
                article.titre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            // Badge langue
            _LangueBadge(langue: article.langue),
          ],
        ),
        subtitle: Text(
          article.corps,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: article.actif,
              onChanged: (v) => notifier.toggleActif(article.id, v),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) =>
                    _ArticleForm(contratType: contratType, existing: article),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, notifier),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, dynamic notifier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Non')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Oui')),
        ],
      ),
    );
    if (ok == true) notifier.supprimer(article.id);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Badge compact affiché dans la card pour indiquer la langue de l'article
// ─────────────────────────────────────────────────────────────────────────────

class _LangueBadge extends StatelessWidget {
  const _LangueBadge({required this.langue});
  final ArticleLangue langue;

  @override
  Widget build(BuildContext context) {
    final isFr = langue == ArticleLangue.fr;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isFr ? Colors.blue.shade50 : Colors.green.shade50,
        border: Border.all(
          color: isFr ? Colors.blue.shade200 : Colors.green.shade300,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isFr ? 'FR' : 'AR',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isFr ? Colors.blue.shade700 : Colors.green.shade700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Formulaire de création / modification d'un article
// ─────────────────────────────────────────────────────────────────────────────

class _ArticleForm extends ConsumerStatefulWidget {
  const _ArticleForm({required this.contratType, this.existing});
  final String contratType;
  final ContractArticle? existing;

  @override
  ConsumerState<_ArticleForm> createState() => _ArticleFormState();
}

class _ArticleFormState extends ConsumerState<_ArticleForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titreCtrl;
  late TextEditingController _corpsCtrl;
  late ArticleLangue _langue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titreCtrl = TextEditingController(text: widget.existing?.titre ?? '');
    _corpsCtrl = TextEditingController(text: widget.existing?.corps ?? '');
    _langue = widget.existing?.langue ?? ArticleLangue.fr;
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _corpsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final notifier = ref.read(
          contractArticlesNotifierProvider(widget.contratType).notifier);

      if (widget.existing == null) {
        await notifier.creer(ContractArticle(
          id: '',
          contratType: widget.contratType,
          titre: _titreCtrl.text.trim(),
          corps: _corpsCtrl.text.trim(),
          ordre: 0,
          langue: _langue,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      } else {
        await notifier.modifier(widget.existing!.id, {
          'titre': _titreCtrl.text.trim(),
          'corps': _corpsCtrl.text.trim(),
          'langue': _langue.value,
        });
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
          bottom: bottomInset, left: 16, right: 16, top: 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── En-tête ──────────────────────────────────────────────────
            Text(
              widget.existing == null ? 'Nouvel article' : 'Modifier l\'article',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // ── Sélecteur de langue ──────────────────────────────────────
            const Text(
              'Langue du contrat',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            _LangueSelector(
              value: _langue,
              onChanged: (l) => setState(() => _langue = l),
            ),
            const SizedBox(height: 4),
            Text(
              _langue == ArticleLangue.fr
                  ? '→ Affiché dans la section française du PDF (gauche → droite)'
                  : '→ Affiché dans la section arabe du PDF (droite → gauche)',
              style: TextStyle(
                fontSize: 11,
                color: _langue == ArticleLangue.fr
                    ? Colors.blue.shade600
                    : Colors.green.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            // ── Titre ────────────────────────────────────────────────────
            TextFormField(
              controller: _titreCtrl,
              textDirection: _langue == ArticleLangue.ar
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'Titre',
                helperText: 'Ex : Article 1 — Responsabilités',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
            ),
            const SizedBox(height: 16),

            // ── Corps ────────────────────────────────────────────────────
            TextFormField(
              controller: _corpsCtrl,
              maxLines: 5,
              textDirection: _langue == ArticleLangue.ar
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'Corps',
                helperText:
                    'Utilisez {{variable}} pour les champs dynamiques',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Corps requis' : null,
            ),
            const SizedBox(height: 24),

            // ── Bouton ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Enregistrer'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Widget de sélection de langue (FR / AR) avec toggle visuel
// ─────────────────────────────────────────────────────────────────────────────

class _LangueSelector extends StatelessWidget {
  const _LangueSelector({required this.value, required this.onChanged});
  final ArticleLangue value;
  final ValueChanged<ArticleLangue> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ArticleLangue.values.map((lang) {
        final selected = value == lang;
        final isFr = lang == ArticleLangue.fr;
        final color = isFr ? Colors.blue : Colors.green;

        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: isFr ? 8 : 0),
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: selected ? color.shade100 : Colors.grey.shade100,
                border: Border.all(
                  color: selected ? color.shade400 : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isFr ? Icons.translate : Icons.language,
                    size: 18,
                    color: selected ? color.shade700 : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    lang.label,
                    style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: selected ? color.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.contratType});
  final String contratType;

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Aucun article trouvé.'));
}