import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_spacing.dart';
import '../../auth/presentation/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ModernMenuScreen — "Command Center" redesign
//  Direction : dashboard industriel-premium, dark-tinted, accents vifs,
//              animations décalées (staggered), layout asymétrique
// ─────────────────────────────────────────────────────────────────────────────

class ModernMenuScreen extends ConsumerStatefulWidget {
  const ModernMenuScreen({super.key});

  @override
  ConsumerState<ModernMenuScreen> createState() => _ModernMenuScreenState();
}

class _ModernMenuScreenState extends ConsumerState<ModernMenuScreen>
    with TickerProviderStateMixin {
  late AnimationController _masterController;
  late AnimationController _searchController;
  final TextEditingController _searchTextController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _searchQuery = '';
  bool _searchExpanded = false;

  // ── Palette "Command Center" ──────────────────────────────────────────────
  static const Color _bg        = Color(0xFF0F1117);
  static const Color _surface   = Color(0xFF181C27);
  static const Color _surface2  = Color(0xFF1E2233);
  static const Color _border    = Color(0xFF2A2F45);
  static const Color _textPri   = Color(0xFFEDF0FF);
  static const Color _textSec   = Color(0xFF8892B0);
  static const Color _textHint  = Color(0xFF4A5270);

  // Accents vifs par catégorie
  static const Color _accentBlue   = Color(0xFF4F8EF7);
  static const Color _accentGreen  = Color(0xFF34D399);
  static const Color _accentOrange = Color(0xFFF59E0B);
  static const Color _accentPurple = Color(0xFFA78BFA);
  static const Color _accentRed    = Color(0xFFEF4444);
  static const Color _accentTeal   = Color(0xFF2DD4BF);
  static const Color _accentPink   = Color(0xFFF472B6);

  // ── Données menu ──────────────────────────────────────────────────────────
  late final List<_MenuCategory> _categories = [
    _MenuCategory(
      title: 'Accès rapide',
      icon: Icons.bolt_rounded,
      accent: _accentOrange,
      items: [
        _MenuItem(label: 'Ventes',       icon: Icons.sell_rounded,                 accent: _accentGreen,  route: '/ventes',  badge: 3),
        _MenuItem(label: 'Caisse',       icon: Icons.account_balance_wallet_rounded, accent: _accentBlue,   route: '/caisse'),
        _MenuItem(label: 'Assistant IA', icon: Icons.auto_awesome_rounded,         accent: _accentPurple, route: '/ai-chat', isNew: true),
      ],
    ),
    _MenuCategory(
      title: 'Transactions',
      icon: Icons.swap_horiz_rounded,
      accent: _accentGreen,
      items: [
        _MenuItem(label: 'Ventes',   icon: Icons.sell_rounded,          accent: _accentGreen,  route: '/ventes'),
        _MenuItem(label: 'Achats',   icon: Icons.shopping_cart_rounded, accent: _accentOrange, route: '/achats'),
        _MenuItem(label: 'Échanges', icon: Icons.swap_horiz_rounded,    accent: _accentBlue,   route: '/echanges'),
      ],
    ),
    _MenuCategory(
      title: 'Opérations',
      icon: Icons.build_rounded,
      accent: _accentBlue,
      items: [
        _MenuItem(label: 'Caisse',      icon: Icons.account_balance_wallet_rounded, accent: _accentBlue,  route: '/caisse'),
        _MenuItem(label: 'Réparations', icon: Icons.build_rounded,                 accent: _accentRed,   route: '/reparations'),
        _MenuItem(label: 'Entretien',   icon: Icons.calendar_today_rounded,        accent: _accentTeal,  route: '/entretien'),
        _MenuItem(label: 'Relevé',      icon: Icons.bar_chart_rounded,             accent: _accentPurple, route: '/releve'),
      ],
    ),
    _MenuCategory(
      title: 'GPS & Suivi',
      icon: Icons.location_on_rounded,
      accent: _accentTeal,
      items: [
        _MenuItem(label: 'Carte Live',  icon: Icons.map_rounded,           accent: _accentTeal, route: '/gps'),
        _MenuItem(label: 'Alertes GPS', icon: Icons.notifications_rounded, accent: _accentRed,  route: '/gps/alertes', badge: 2),
      ],
    ),
    _MenuCategory(
      title: 'Administration',
      icon: Icons.admin_panel_settings_rounded,
      accent: _accentPink,
      items: [
        _MenuItem(label: 'Utilisateurs', icon: Icons.manage_accounts_rounded, accent: _accentBlue,   route: '/admin/users'),
        _MenuItem(label: 'Paramètres',   icon: Icons.settings_rounded,        accent: _accentPink,   route: '/admin/settings'),
        _MenuItem(label: 'Contrats',     icon: Icons.description_rounded,     accent: _accentOrange, route: '/contrats'),
        _MenuItem(label: 'Mon profil',   icon: Icons.person_rounded,          accent: _accentPurple, route: '/profil'),
      ],
    ),
  ];

  List<_MenuItem> get _filteredItems {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return _categories.expand((c) => c.items).where((i) => i.label.toLowerCase().contains(q)).toList();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus && _searchQuery.isEmpty) {
        setState(() => _searchExpanded = false);
        _searchController.reverse();
      }
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    _searchController.dispose();
    _searchTextController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searchExpanded = true);
    _searchController.forward();
    _searchFocus.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _closeSearch() {
    setState(() {
      _searchExpanded = false;
      _searchQuery = '';
    });
    _searchTextController.clear();
    _searchController.reverse();
    _searchFocus.unfocus();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final prenom = profile?.prenom ?? 'vous';
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'Bonjour' : now.hour < 18 ? 'Bon après-midi' : 'Bonsoir';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _bg,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeader(greeting, prenom),
            _buildSearchSliver(),
            if (_searchQuery.isNotEmpty)
              _buildSearchResults()
            else ...[
              _buildQuickStats(),
              ..._buildAllCategories(),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(String greeting, String prenom) {
    return SliverAppBar(
      expandedHeight: 160,
      collapsedHeight: 70,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _bg,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _buildHeaderBackground(greeting, prenom),
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16, right: 20),
        title: LayoutBuilder(
          builder: (context, constraints) {
            // Collapsed title
            final isCollapsed = constraints.maxHeight <= 90;
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isCollapsed ? 1.0 : 0.0,
              child: Row(
                children: [
                  _PulseDot(color: _accentGreen),
                  const SizedBox(width: 10),
                  Text(
                    'Menu',
                    style: TextStyle(
                      color: _textPri,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _SearchIconButton(onTap: _openSearch, color: _textSec),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderBackground(String greeting, String prenom) {
    return Container(
      decoration: const BoxDecoration(color: _bg),
      child: Stack(
        children: [
          // Fond décoratif : grille de points subtile
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter(color: _border)),
          ),
          // Accent arc de cercle en haut à droite
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentBlue.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: _buildHeaderContent(greeting, prenom),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderContent(String greeting, String prenom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ligne haute : status + bouton recherche
        Row(
          children: [
            _PulseDot(color: _accentGreen),
            const SizedBox(width: 8),
            Text(
              'Système actif',
              style: TextStyle(
                color: _accentGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            _SearchIconButton(onTap: _openSearch, color: _textSec),
          ],
        ),
        const SizedBox(height: 16),
        // Salutation
        _AnimatedFadeSlide(
          controller: _masterController,
          delay: 0.0,
          child: Text(
            '$greeting,',
            style: TextStyle(
              color: _textSec,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 2),
        _AnimatedFadeSlide(
          controller: _masterController,
          delay: 0.08,
          child: Text(
            prenom,
            style: const TextStyle(
              color: _textPri,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  // ── Barre de recherche ─────────────────────────────────────────────────────

  Widget _buildSearchSliver() {
    return SliverToBoxAdapter(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        height: _searchExpanded ? 52 : 0,
        child: _searchExpanded
            ? Container(
                decoration: BoxDecoration(
                  color: _surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _accentBlue.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    Icon(Icons.search_rounded, color: _accentBlue, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchTextController,
                        focusNode: _searchFocus,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: TextStyle(color: _textPri, fontSize: 14),
                        cursorColor: _accentBlue,
                        decoration: InputDecoration(
                          hintText: 'Rechercher une fonction...',
                          hintStyle: TextStyle(color: _textHint, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: _textSec, size: 18),
                      onPressed: _closeSearch,
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ── Stats rapides ──────────────────────────────────────────────────────────

  Widget _buildQuickStats() {
    return SliverToBoxAdapter(
      child: _AnimatedFadeSlide(
        controller: _masterController,
        delay: 0.15,
        child: SizedBox(
          height: 88,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            scrollDirection: Axis.horizontal,
            children: [
              _StatChip(label: 'Contrats actifs', value: '12', icon: Icons.description_rounded, color: _accentBlue),
              const SizedBox(width: 10),
              _StatChip(label: 'En retard', value: '3', icon: Icons.warning_rounded, color: _accentRed),
              const SizedBox(width: 10),
              _StatChip(label: 'Revenus / jour', value: '84k', icon: Icons.trending_up_rounded, color: _accentGreen),
              const SizedBox(width: 10),
              _StatChip(label: 'Véhicules dispo', value: '7', icon: Icons.directions_car_rounded, color: _accentTeal),
            ],
          ),
        ),
      ),
    );
  }

  // ── Résultats de recherche ─────────────────────────────────────────────────

  Widget _buildSearchResults() {
    final items = _filteredItems;
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: _textHint),
              const SizedBox(height: 12),
              Text('Aucun résultat', style: TextStyle(color: _textSec, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (ctx, i) => _AnimatedFadeSlide(
            controller: _masterController,
            delay: i * 0.05,
            child: _buildMenuCard(items[i]),
          ),
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
        ),
      ),
    );
  }

  // ── Catégories ─────────────────────────────────────────────────────────────

  List<Widget> _buildAllCategories() {
    return _categories.asMap().entries.map((e) {
      return SliverToBoxAdapter(
        child: _AnimatedFadeSlide(
          controller: _masterController,
          delay: 0.15 + e.key * 0.08,
          child: _buildCategoryBlock(e.value),
        ),
      );
    }).toList();
  }

  Widget _buildCategoryBlock(_MenuCategory cat) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre de catégorie avec pill accent
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cat.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cat.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(cat.icon, size: 13, color: cat.accent),
                    const SizedBox(width: 6),
                    Text(
                      cat.title.toUpperCase(),
                      style: TextStyle(
                        color: cat.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cat.accent.withValues(alpha: 0.3), Colors.transparent],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${cat.items.length}',
                style: TextStyle(color: _textHint, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Grille de cartes
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cat.items.length == 2 ? 2 : cat.items.length == 3 ? 3 : 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: cat.items.length == 3 ? 1.0 : 1.45,
            ),
            itemCount: cat.items.length,
            itemBuilder: (_, i) => _buildMenuCard(cat.items[i]),
          ),
        ],
      ),
    );
  }

  // ── Carte menu ─────────────────────────────────────────────────────────────

  Widget _buildMenuCard(_MenuItem item) {
    return _MenuCard(
      item: item,
      onTap: () {
        HapticFeedback.lightImpact();
        context.go(item.route);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SOUS-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Carte de menu avec effet de pression (scale)
class _MenuCard extends StatefulWidget {
  final _MenuItem item;
  final VoidCallback onTap;
  const _MenuCard({required this.item, required this.onTap});

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  static const Color _surface  = Color(0xFF181C27);
  static const Color _surface2 = Color(0xFF1E2233);
  static const Color _textPri  = Color(0xFFEDF0FF);
  static const Color _textSec  = Color(0xFF8892B0);

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.accent.withValues(alpha: 0.18), width: 1),
            boxShadow: [
              BoxShadow(
                color: item.accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Accent bar en haut
              Positioned(
                top: 0, left: 16, right: 16,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        item.accent.withValues(alpha: 0.0),
                        item.accent,
                        item.accent.withValues(alpha: 0.0),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(2)),
                  ),
                ),
              ),
              // Fond glow subtil en bas à droite
              Positioned(
                bottom: -10, right: -10,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        item.accent.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Contenu
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icône
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.accent.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(item.icon, size: 20, color: item.accent),
                        ),
                        if (item.badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${item.badge}',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          )
                        else if (item.isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA78BFA).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFA78BFA).withValues(alpha: 0.5)),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(color: Color(0xFFA78BFA), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                            ),
                          ),
                      ],
                    ),
                    // Label
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: _textPri,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1.5,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [item.accent.withValues(alpha: 0.5), Colors.transparent],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de stat compact (barre horizontale)
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  static const Color _surface2 = Color(0xFF1E2233);
  static const Color _textPri  = Color(0xFFEDF0FF);
  static const Color _textSec  = Color(0xFF8892B0);

  const _StatChip({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(color: _textPri, fontSize: 16, fontWeight: FontWeight.w800, height: 1)),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(color: _textSec, fontSize: 10, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton icône recherche
class _SearchIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;

  static const Color _surface2 = Color(0xFF1E2233);
  static const Color _border   = Color(0xFF2A2F45);

  const _SearchIconButton({required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _border),
        ),
        child: Icon(Icons.search_rounded, color: color, size: 20),
      ),
    );
  }
}

/// Point pulsant (status indicator)
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: _anim.value * 0.5), blurRadius: 4)],
        ),
      ),
    );
  }
}

/// Wrapper d'animation fade + slide décalé
class _AnimatedFadeSlide extends StatelessWidget {
  final AnimationController controller;
  final double delay; // 0.0 → 1.0
  final Widget child;

  const _AnimatedFadeSlide({required this.controller, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    final start = delay.clamp(0.0, 0.9);
    final end   = (delay + 0.3).clamp(0.0, 1.0);

    final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeOut)),
    );
    final slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: controller, curve: Interval(start, end, curve: Curves.easeOut)),
    );

    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) => FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

/// Grille de points discrets pour le fond du header
class _DotGridPainter extends CustomPainter {
  final Color color;
  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    const spacing = 22.0;
    const radius  = 1.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  MODÈLES
// ─────────────────────────────────────────────────────────────────────────────

class _MenuCategory {
  final String title;
  final IconData icon;
  final Color accent;
  final List<_MenuItem> items;

  const _MenuCategory({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
  });
}

class _MenuItem {
  final String label;
  final IconData icon;
  final Color accent;
  final String route;
  final int? badge;
  final bool isNew;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.accent,
    required this.route,
    this.badge,
    this.isNew = false,
  });
}