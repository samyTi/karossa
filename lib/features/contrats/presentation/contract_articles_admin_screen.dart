// lib/features/contrats/presentation/contract_articles_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_text_styles.dart';
import './contract_articles_provider.dart';
import '../domain/contract_article_model.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

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
        title: Text(context.l10n.articlesDesContrats),
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
      loading: () => Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(context.l10n.erreurAvecDetail(e.toString()))),
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
  @override
  Widget build(BuildContext context) {
    final articlesFr =
        widget.articles.where((a) => a.langue == ArticleLangue.fr).toList();
    final articlesAr =
        widget.articles.where((a) => a.langue == ArticleLangue.ar).toList();

    return Scaffold(
      body: widget.articles.isEmpty
          ? _EmptyState(contratType: widget.contratType)
          : ListView(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              children: [
                if (articlesFr.isNotEmpty) ...[
                  _LangueSectionHeader(langue: ArticleLangue.fr, count: articlesFr.length),
                  ...List.generate(articlesFr.length, (i) => _ArticleCard(
                        key: ValueKey(articlesFr[i].id),
                        article: articlesFr[i],
                        contratType: widget.contratType,
                        position: i + 1,
                        total: articlesFr.length,
                      )),
                ],
                if (articlesAr.isNotEmpty) ...[
                  _LangueSectionHeader(langue: ArticleLangue.ar, count: articlesAr.length),
                  ...List.generate(articlesAr.length, (i) => _ArticleCard(
                        key: ValueKey(articlesAr[i].id),
                        article: articlesAr[i],
                        contratType: widget.contratType,
                        position: i + 1,
                        total: articlesAr.length,
                      )),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(context, null),
        icon: Icon(Icons.add),
        label: Text(context.l10n.nouvelArticle),
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
//  En-tête de section séparant les clauses FR des clauses AR
// ─────────────────────────────────────────────────────────────────────────────

class _LangueSectionHeader extends StatelessWidget {
  const _LangueSectionHeader({required this.langue, required this.count});
  final ArticleLangue langue;
  final int count;

  @override
  Widget build(BuildContext context) {
    final isFr = langue == ArticleLangue.fr;
    final color = isFr ? Colors.blue : Colors.green;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(isFr ? Icons.translate : Icons.language, size: 16, color: color.shade700),
          const SizedBox(width: 6),
          Text(
            '${langue.label} ($count)',
            style: TextStyle(fontWeight: FontWeight.bold, color: color.shade700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ArticleCard extends ConsumerWidget {
  const _ArticleCard({
    super.key,
    required this.article,
    required this.contratType,
    required this.position,
    required this.total,
  });
  final ContractArticle article;
  final String contratType;
  final int position;
  final int total;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier =
        ref.read(contractArticlesNotifierProvider(contratType).notifier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        // 🔢 La position n'est plus modifiable ici : elle se règle dans le
        // formulaire de modification de la clause (bouton crayon), là où
        // l'utilisateur peut saisir directement le numéro d'ordre voulu.
        leading: CircleAvatar(
          radius: 16,
          child: Text('$position', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                article.titre,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 8),
            // Badge langue
            _LangueBadge(langue: article.langue),
          ],
        ),
        subtitle: Text(
          article.corps,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _openForm(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: article.actif,
              onChanged: (v) => notifier.toggleActif(article.id, v),
            ),
            IconButton(
              icon: Icon(Icons.edit_outlined),
              onPressed: () => _openForm(context),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, notifier),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ArticleForm(
          contratType: contratType,
          existing: article,
          currentPosition: position,
          currentTotal: total,
        ),
      );

  Future<void> _confirmDelete(BuildContext context, dynamic notifier) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.supprimer),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.non)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.l10n.oui)),
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
  const _ArticleForm({
    required this.contratType,
    this.existing,
    this.currentPosition,
    this.currentTotal,
  });
  final String contratType;
  final ContractArticle? existing;
  /// Position actuelle (1-based) de la clause dans SA langue, et nombre total
  /// de clauses de cette langue — utilisés pour pré-remplir et borner le
  /// champ « Position ». Non fournis lors d'une création.
  final int? currentPosition;
  final int? currentTotal;

  @override
  ConsumerState<_ArticleForm> createState() => _ArticleFormState();
}

class _ArticleFormState extends ConsumerState<_ArticleForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titreCtrl;
  late TextEditingController _corpsCtrl;
  late TextEditingController _positionCtrl;
  late ArticleLangue _langue;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titreCtrl = TextEditingController(text: widget.existing?.titre ?? '');
    _corpsCtrl = TextEditingController(text: widget.existing?.corps ?? '');
    _langue = widget.existing?.langue ?? ArticleLangue.fr;

    // Position par défaut : celle actuelle si on modifie une clause
    // existante, sinon la dernière place de la langue sélectionnée
    // (nouvelle clause ajoutée en fin de liste par défaut).
    final defaultPosition = widget.currentPosition ?? _langueCount(_langue) + 1;
    _positionCtrl = TextEditingController(text: '$defaultPosition');
  }

  /// Nombre de clauses déjà existantes pour une langue donnée (utilisé pour
  /// borner et pré-remplir le champ Position).
  int _langueCount(ArticleLangue langue) {
    final all = ref.read(contractArticlesNotifierProvider(widget.contratType))
            .valueOrNull ??
        const [];
    return all.where((a) => a.langue == langue).length;
  }

  @override
  void dispose() {
    _titreCtrl.dispose();
    _corpsCtrl.dispose();
    _positionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final repo = ref.read(contractArticlesRepositoryProvider);
      final isCreation = widget.existing == null;

      String? savedId;

      if (isCreation) {
        // Créée provisoirement en fin de liste de sa langue ; la position
        // exacte demandée est appliquée juste après via reordonner().
        final sameLangueCount = _langueCount(_langue);
        final created = await repo.creer(ContractArticle(
          id: '',
          contratType: ContratArticleType.fromString(widget.contratType),
          titre: _titreCtrl.text.trim(),
          corps: _corpsCtrl.text.trim(),
          ordre: sameLangueCount, // fin de liste, provisoire
          langue: _langue,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
        savedId = created?.id;
      } else {
        await repo.modifier(widget.existing!.id, {
          'titre': _titreCtrl.text.trim(),
          'corps': _corpsCtrl.text.trim(),
          'langue': _langue.value,
        });
        savedId = widget.existing!.id;
      }

      // ── Application du numéro d'ordre saisi ────────────────────────────
      // On relit la liste fraîche depuis le serveur (plutôt que l'état du
      // notifier, qui peut ne pas encore avoir fini de se rafraîchir à ce
      // stade) pour être sûr de repositionner la clause par rapport à un
      // classement à jour, notamment juste après une création.
      final desiredPosition = int.tryParse(_positionCtrl.text.trim());
      if (savedId != null && desiredPosition != null) {
        final all = await repo.getTous(widget.contratType);
        final langueList = all.where((a) => a.langue == _langue).toList();
        final currentIndex = langueList.indexWhere((a) => a.id == savedId);

        if (currentIndex != -1) {
          final targetIndex =
              (desiredPosition - 1).clamp(0, langueList.length - 1);
          if (targetIndex != currentIndex) {
            final item = langueList.removeAt(currentIndex);
            langueList.insert(targetIndex, item);
            await repo.reordonner(langueList);
          }
        }
      }

      ref.invalidate(contractArticlesNotifierProvider(widget.contratType));

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.erreurAvecDetail(e.toString())), backgroundColor: Colors.red),
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
            SizedBox(height: 16),

            // ── Sélecteur de langue ──────────────────────────────────────
            Text(context.l10n.langueDuContrat, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 6),
            _LangueSelector(
              value: _langue,
              onChanged: (l) => setState(() => _langue = l),
            ),
            SizedBox(height: 4),
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
            SizedBox(height: 16),

            // ── Position (numéro d'ordre) ──────────────────────────────────
            Builder(builder: (context) {
              final maxPos = widget.existing == null
                  ? _langueCount(_langue) + 1
                  : _langueCount(_langue);
              return TextFormField(
                controller: _positionCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Position (ordre d\'affichage)',
                  helperText:
                      'Numéro de 1 à $maxPos parmi les clauses ${_langue.label.toLowerCase()}',
                  prefixIcon: const Icon(Icons.format_list_numbered),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 1) return 'Numéro invalide';
                  return null;
                },
              );
            }),
            SizedBox(height: 16),

            // ── Titre ────────────────────────────────────────────────────
            TextFormField(
              controller: _titreCtrl,
              textDirection: _langue == ArticleLangue.ar
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.champTitre,
                helperText: context.l10n.exArticle1Responsabilites,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Titre requis' : null,
            ),
            SizedBox(height: 16),

            // ── Corps ────────────────────────────────────────────────────
            TextFormField(
              controller: _corpsCtrl,
              maxLines: 5,
              textDirection: _langue == ArticleLangue.ar
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              decoration: InputDecoration(
                labelText: context.l10n.champCorps,
                helperText:
                    context.l10n.utilisezVariablePourLesChampsDynamiques('{{variable}}'),
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Corps requis' : null,
            ),
            SizedBox(height: 24),

            // ── Bouton ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(context.l10n.enregistrer),
              ),
            ),
            SizedBox(height: 16),
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
                  SizedBox(width: 6),
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
      Center(child: Text(context.l10n.aucunArticleTrouve));
}