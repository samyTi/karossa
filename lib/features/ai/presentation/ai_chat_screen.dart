//lib/features/ai/presentation/ai_chat_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../core/providers/supabase_provider.dart';
import '../../auth/presentation/auth_provider.dart';
import '../domain/chat_message.dart';
import '../data/ai_report_generator.dart';
import 'ai_chart_widget.dart';
import 'ai_alertes_provider.dart';
import 'ai_data_context_provider.dart';
import 'ai_provider.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? vehiculeContext;
  final String? vehiculeNom;

  const AiChatScreen({super.key, this.vehiculeContext, this.vehiculeNom});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _generatingReport = false;

  List<String> get _suggestions {
    if (widget.vehiculeContext != null) {
      return [
        '📊 Ce véhicule est-il rentable ?',
        '💰 Quel prix de location conseiller ?',
        '📈 Simuler une baisse de prix de 10%',
        '🔧 Plan d\'entretien recommandé',
      ];
    }
    return [
      '📊 Résumé de mon activité',
      '🚨 Détecter des anomalies ce mois-ci',
      '💰 Suggérer un prix de location',
      '📈 Optimiser ma rentabilité',
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatMessagesProvider.notifier).sendMessage(
          text,
          vehiculeContext: widget.vehiculeContext,
        );
    _scrollToBottom();
  }

  void _showDataPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => const _DataPickerSheet(),
    );
  }

  Future<void> _attachPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(context.l10n.prendrePhoto),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.choisirGalerie),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await ImagePicker().pickImage(source: source, imageQuality: 82, maxWidth: 1600);
    if (picked == null) return;

    final Uint8List bytes = await picked.readAsBytes();
    if (!mounted) return;
    ref.read(chatMessagesProvider.notifier).sendImage(bytes);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _genererRapportPdf() async {
    setState(() => _generatingReport = true);
    try {
      final repo = ref.read(aiRepositoryProvider);
      final data = await repo.genererRapportMensuel();

      final client = ref.read(supabaseClientProvider);
      final showroomId = ref.read(currentShowroomIdProvider);
      String nomShowroom = 'Showroom';
      if (showroomId != null) {
        final res = await client
            .from('showrooms')
            .select('nom')
            .eq('id', showroomId)
            .maybeSingle();
        nomShowroom = (res?['nom'] as String?) ?? nomShowroom;
      }

      await AiReportGenerator.generateAndShare(data, showroomNom: nomShowroom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.erreurGenerationRapport(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);

    ref.listen(chatMessagesProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.karossaAi,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(
                    widget.vehiculeNom != null
                        ? 'Fiche : ${widget.vehiculeNom}'
                        : 'Expert Métier Automobile',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _generatingReport
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: context.l10n.genererRapportPdfMois,
            onPressed: _generatingReport ? null : _genererRapportPdf,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.effacerHistorique,
            onPressed: () => notifier.clearChat(),
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: ref.watch(aiDataContextProvider) != null,
              child: const Icon(Icons.dataset_outlined),
            ),
            tooltip: context.l10n.injecterDesDonneesDeGestion,
            onPressed: _showDataPicker,
          ),
        ],
      ),
      body: Column(
        children: [
          const _AlertesBanner(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: messages.length,
              itemBuilder: (ctx, i) => _FadeInMessage(child: _MessageBubble(message: messages[i])),
            ),
          ),
          if (messages.length <= 1)
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ActionChip(
                  label: Text(_suggestions[i], style: const TextStyle(fontSize: 12)),
                  backgroundColor: Theme.of(context).cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  onPressed: () {
                    _controller.text = _suggestions[i];
                    _send();
                  },
                ),
              ),
            ),
          const SizedBox(height: 6),
          _InputBar(
            controller: _controller,
            isLoading: ref.watch(chatMessagesProvider.notifier).isLoading,
            onSend: _send,
            onAttachPhoto: _attachPhoto,
          ),
        ],
      ),
    );
  }
}

/// Bannière compacte affichant les alertes proactives non lues générées
/// par le job quotidien (ai-daily-digest). Tap sur une alerte → l'IA
/// développe le sujet dans le chat, et l'alerte est marquée comme lue.
class _AlertesBanner extends ConsumerWidget {
  const _AlertesBanner();

  Color _severiteColor(String s) {
    switch (s) {
      case 'urgent':
        return Colors.red;
      case 'attention':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _severiteIcon(String s) {
    switch (s) {
      case 'urgent':
        return Icons.warning_amber_rounded;
      case 'attention':
        return Icons.info_outline;
      default:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertesAsync = ref.watch(aiAlertesNonLuesProvider);

    return alertesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (alertes) {
        if (alertes.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
          ),
          child: SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: alertes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final a = alertes[i];
                final color = _severiteColor(a.severite);
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    ref.read(chatMessagesProvider.notifier).sendMessage(
                        'Explique-moi et détaille cette alerte : "${a.titre}" — ${a.message}');
                    ref.read(aiAlertesActionsProvider).marquerCommeLue(a.id);
                  },
                  child: Container(
                    width: 240,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(_severiteIcon(a.severite), color: color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.titre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              Text(a.message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DataPickerSheet extends ConsumerWidget {
  const _DataPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(18),
        children: [
          Text(context.l10n.contextualiserAssistant,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.analytics_outlined, color: Colors.blue),
            title: Text(context.l10n.selectionnerLes50DernieresLocations),
            subtitle: Text(context.l10n.analyseDesRendementsEtStatutsDe),
            onTap: () async {
              Navigator.pop(context);
              await _loadLocations(ref, context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_car_filled_outlined, color: Colors.green),
            title: Text(context.l10n.selectionnerLeCatalogueDeVehicules),
            subtitle: Text(context.l10n.aiAnalyseEtatGlobalParc),
            onTap: () async {
              Navigator.pop(context);
              await _loadVehicules(ref, context);
            },
          ),
          if (ref.watch(aiDataContextProvider) != null)
            ListTile(
              leading: const Icon(Icons.clear_all, color: Colors.red),
              title: Text(context.l10n.detacherLeContexteActuel),
              textColor: Colors.red,
              onTap: () {
                ref.read(aiDataContextProvider.notifier).state = null;
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _loadLocations(WidgetRef ref, BuildContext context) async {
    final client = ref.read(supabaseClientProvider);
    final showroomId = ref.read(currentShowroomIdProvider);

    try {
      final data = await client
          .from('locations')
          .select('date_debut, date_fin_prevue, km_depart, prix_jour, caution, statut, nb_jours, montant_brut')
          .eq('showroom_id', showroomId!)
          .order('created_at', ascending: false)
          .limit(50);

      ref.read(aiDataContextProvider.notifier).state = AiDataContext(
        label: context.l10n.aiNLocationsRecentes(data.length.toString()),
        data: List<Map<String, dynamic>>.from(data),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.aiContratsChargesContexte(data.length.toString()))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())))
        );
      }
    }
  }

  Future<void> _loadVehicules(WidgetRef ref, BuildContext context) async {
    final client = ref.read(supabaseClientProvider);
    final showroomId = ref.read(currentShowroomIdProvider);

    try {
      final data = await client
          .from('vehicules')
          .select('marque, modele, annee, carburant, boite, kilometrage, prix_vente, prix_location_jour, statut, date_entree')
          .eq('showroom_id', showroomId!)
          .limit(60);

      ref.read(aiDataContextProvider.notifier).state = AiDataContext(
        label: context.l10n.aiCatalogueNVehicules(data.length.toString()),
        data: List<Map<String, dynamic>>.from(data),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.aiVehiculesSynchronisesKarossa(data.length.toString()))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.erreurAvecDetail(e.toString())))
        );
      }
    }
  }
}

/// Fondu + léger glissement à l'apparition d'un nouveau message —
/// ne se rejoue pas lors des mises à jour de contenu (streaming) car
/// l'élément conserve son State tant que sa position dans la liste ne change pas.
class _FadeInMessage extends StatefulWidget {
  final Widget child;
  const _FadeInMessage({required this.child});

  @override
  State<_FadeInMessage> createState() => _FadeInMessageState();
}

class _FadeInMessageState extends State<_FadeInMessage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

/// Curseur clignotant affiché en fin de bulle pendant le streaming, pour
/// renforcer l'effet "machine à écrire".
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();
  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(width: 2, height: 14, margin: const EdgeInsets.only(left: 2), color: AppColors.primary),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  Widget _buildSegment(BuildContext context, AiContentSegment seg, bool isUser, ThemeData theme,
      {required bool addCursor}) {
    switch (seg.type) {
      case AiSegmentType.chart:
        return AiChartCard(chartData: seg.payload!);
      case AiSegmentType.action:
        return AiActionCard(actionData: seg.payload!);
      case AiSegmentType.damage:
        return AiDamageCard(damageData: seg.payload!);
      case AiSegmentType.text:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: MarkdownBody(
                data: seg.text ?? '',
                selectable: false,
                styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                  p: TextStyle(
                    color: isUser ? Colors.white : theme.textTheme.bodyLarge?.color,
                    fontSize: 14,
                    height: 1.45,
                  ),
                  listBullet: TextStyle(color: isUser ? Colors.white : AppColors.primary),
                  tableHead: const TextStyle(fontWeight: FontWeight.bold),
                  tableBody: const TextStyle(fontSize: 13),
                ),
              ),
            ),
            if (addCursor) const _BlinkingCursor(),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final theme = Theme.of(context);
    final segments = message.isLoading ? const <AiContentSegment>[] : parseAiContentSegments(message.content);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.6)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                color: isUser ? AppColors.primary : theme.cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [BoxShadow(blurRadius: 4, color: Colors.black.withValues(alpha: 0.05))],
              ),
              child: message.isLoading
                  ? _TypingIndicator(label: message.toolTrace)
                  : SelectionArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message.imageBytes != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(message.imageBytes!, height: 140, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 8),
                          ],
                          for (int i = 0; i < segments.length; i++)
                            _buildSegment(context, segments[i], isUser, theme,
                                addCursor: message.isStreaming && i == segments.length - 1),
                        ],
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final String? label;
  const _TypingIndicator({this.label});
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 400))..repeat(reverse: true),
    );
    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 140), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _controllers[i],
                builder: (_, __) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3 + _controllers[i].value * 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
          if (widget.label != null) ...[
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                widget.label!,
                key: ValueKey(widget.label),
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback? onAttachPhoto;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    this.onAttachPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withValues(alpha: 0.05))],
        ),
        child: Row(
          children: [
            if (onAttachPhoto != null)
              IconButton(
                icon: const Icon(Icons.add_a_photo_outlined),
                color: AppColors.primary,
                tooltip: context.l10n.joindrePhoto,
                onPressed: isLoading ? null : onAttachPhoto,
              ),
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: context.l10n.demanderAKarossaai,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'ai_send_msg',
              onPressed: isLoading ? null : onSend,
              backgroundColor: isLoading ? Colors.grey : AppColors.primary,
              elevation: 0,
              child: isLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}