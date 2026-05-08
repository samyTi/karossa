// lib/features/more/presentation/more_screen.dart
//
// Page "Plus" — design premium showroom automobile

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/domain/profile_model.dart';
import '../../auth/presentation/auth_provider.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile  = ref.watch(currentProfileProvider).valueOrNull;
    final isGerant = profile?.isGerant ?? false;
    final isAdmin  = profile?.isAdmin  ?? false;
    final canAdmin = isGerant || isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  profile: profile,
                  onTap: () => context.push('/profil'),
                ),
              ),
              SliverToBoxAdapter(
                child: _QuickActionsSection(canAdmin: canAdmin),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _PremiumNavSection(
                      title: 'Finances',
                      icon: Icons.account_balance_outlined,
                      accent: AppColors.secondary,
                      items: [
                        _PremiumNavItem(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Caisse',
                          subtitle: 'Entrées & sorties',
                          color: AppColors.secondary,
                          onTap: () => context.push('/caisse'),
                        ),
                        _PremiumNavItem(
                          icon: Icons.analytics_outlined,
                          label: 'Relevé financier',
                          subtitle: 'Bilans & statistiques',
                          color: AppColors.primary,
                          onTap: () => context.push('/releve'),
                        ),
                      ],
                    ),
                    _PremiumNavSection(
                      title: 'Transactions',
                      icon: Icons.receipt_long_outlined,
                      accent: AppColors.reserve,
                      items: [
                        _PremiumNavItem(
                          icon: Icons.sell_outlined,
                          label: 'Ventes',
                          subtitle: 'Historique des ventes',
                          color: AppColors.secondary,
                          onTap: () => context.push('/ventes'),
                        ),
                        _PremiumNavItem(
                          icon: Icons.shopping_cart_outlined,
                          label: 'Achats',
                          subtitle: 'Véhicules achetés',
                          color: AppColors.accent,
                          onTap: () => context.push('/achats'),
                        ),
                        _PremiumNavItem(
                          icon: Icons.swap_horiz,
                          label: 'Échanges',
                          subtitle: 'Reprises & échanges',
                          color: AppColors.reserve,
                          onTap: () => context.push('/echanges'),
                        ),
                      ],
                    ),
                    _PremiumNavSection(
                      title: 'Maintenance',
                      icon: Icons.build_outlined,
                      accent: AppColors.reparation,
                      items: [
                        _PremiumNavItem(
                          icon: Icons.build_circle_outlined,
                          label: 'Réparations',
                          subtitle: 'Suivi des réparations',
                          color: AppColors.reparation,
                          onTap: () => context.push('/reparations'),
                        ),
                        _PremiumNavItem(
                          icon: Icons.notification_important_outlined,
                          label: 'Alertes entretien',
                          subtitle: 'Vidanges, CT, assurances',
                          color: AppColors.accent,
                          onTap: () => context.push('/entretien'),
                        ),
                      ],
                    ),
                    _PremiumNavSection(
                      title: 'GPS & Sécurité',
                      icon: Icons.gps_fixed,
                      accent: AppColors.primary,
                      items: [
                        _PremiumNavItem(
                          icon: Icons.map_outlined,
                          label: 'Carte GPS',
                          subtitle: 'Position en temps réel',
                          color: AppColors.primary,
                          onTap: () => context.push('/gps/map'),
                        ),
                        _PremiumNavItem(
                          icon: Icons.warning_amber_outlined,
                          label: 'Alertes GPS',
                          subtitle: 'Notifications boîtiers',
                          color: AppColors.retard,
                          onTap: () => context.push('/gps/alertes'),
                        ),
                      ],
                    ),
                    _PremiumNavSection(
                      title: 'Documents',
                      icon: Icons.description_outlined,
                      accent: AppColors.primary,
                      items: [
                        _PremiumNavItem(
                          icon: Icons.folder_open_outlined,
                          label: 'Contrats',
                          subtitle: 'Locations, ventes, échanges',
                          color: AppColors.primary,
                          onTap: () => context.push('/contrats'),
                        ),
                      ],
                    ),
                    if (canAdmin)
                      _PremiumNavSection(
                        title: 'Administration',
                        icon: Icons.admin_panel_settings_outlined,
                        accent: AppColors.gerant,
                        items: [
                          _PremiumNavItem(
                            icon: Icons.people_outlined,
                            label: 'Utilisateurs',
                            subtitle: 'Gérer les accès',
                            color: AppColors.gerant,
                            onTap: () => context.push('/admin/users'),
                          ),
                          _PremiumNavItem(
                            icon: Icons.settings_outlined,
                            label: 'Paramètres',
                            subtitle: 'Configuration du showroom',
                            color: AppColors.textSecondary,
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 28),
                    _LogoutTile(onTap: () => _confirmLogout(context, ref)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 32, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.error.withValues(alpha: 0.15),
                      AppColors.error.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3), width: 1.5),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppColors.error, size: 26),
              ),
              const SizedBox(height: 20),
              const Text('Se déconnecter ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text("Vous serez redirigé vers l'écran de connexion.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    height: 1.5)),
              const SizedBox(height: 28),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text('Déconnecter',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (confirm == true && context.mounted) {
      await ref.read(authProvider).signOut();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFILE HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final Profile? profile;
  final VoidCallback onTap;
  const _ProfileHeader({required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final roleColor = profile?.role.color ?? AppColors.primary;
    final fullName  = profile?.fullName   ?? '—';
    final initials  = profile?.initials   ?? '?';
    final roleLabel = profile?.role.label ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Container(
          height: 140,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: roleColor.withValues(alpha: 0.25),
                blurRadius: 24, offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        roleColor.withValues(alpha: 0.95),
                        roleColor.withValues(alpha: 0.65),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              Positioned(right: -20, top: -20,
                child: _GeoCircle(size: 140, opacity: 0.10)),
              Positioned(right: 80, bottom: -50,
                child: _GeoCircle(size: 120, opacity: 0.07)),
              Positioned(left: -10, bottom: -30,
                child: _GeoCircle(size: 90, opacity: 0.08)),
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CustomPaint(painter: _StripePainter()),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: Row(children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.30),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                      ),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.50), width: 2),
                    ),
                    child: Center(
                      child: Text(initials,
                        style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: -0.5,
                        )),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('MON PROFIL',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w700, letterSpacing: 1.2,
                          )),
                        const SizedBox(height: 4),
                        Text(fullName,
                          style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w800,
                            color: Colors.white, letterSpacing: -0.5, height: 1.1,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.30), width: 1),
                          ),
                          child: Text(roleLabel,
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: 0.3,
                            )),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25), width: 1),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white, size: 14),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeoCircle extends StatelessWidget {
  final double size, opacity;
  const _GeoCircle({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    const stripeWidth = 30.0;
    const gap = 22.0;
    for (double x = -size.height; x < size.width + size.height; x += stripeWidth + gap) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + stripeWidth, 0)
        ..lineTo(x + stripeWidth + size.height, size.height)
        ..lineTo(x + size.height, size.height)
        ..close();
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  final bool canAdmin;
  const _QuickActionsSection({required this.canAdmin});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4, height: 14,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text('ACCÈS RAPIDE',
              style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                letterSpacing: 1.2,
              )),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _QuickPill(icon: Icons.account_balance_wallet_outlined,
                label: 'Caisse', color: AppColors.secondary,
                onTap: () => context.push('/caisse')),
            const SizedBox(width: 8),
            _QuickPill(icon: Icons.sell_outlined,
                label: 'Ventes', color: AppColors.primary,
                onTap: () => context.push('/ventes')),
            const SizedBox(width: 8),
            _QuickPill(icon: Icons.build_circle_outlined,
                label: 'Réparations', color: AppColors.reparation,
                onTap: () => context.push('/reparations')),
            const SizedBox(width: 8),
            _QuickPill(icon: Icons.folder_open_outlined,
                label: 'Contrats', color: AppColors.reserve,
                onTap: () => context.push('/contrats')),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _QuickPill(icon: Icons.map_outlined,
                label: 'GPS', color: AppColors.info,
                onTap: () => context.push('/gps/map')),
            const SizedBox(width: 8),
            _QuickPill(icon: Icons.shopping_cart_outlined,
                label: 'Achats', color: AppColors.accent,
                onTap: () => context.push('/achats')),
            const SizedBox(width: 8),
            _QuickPill(icon: Icons.swap_horiz,
                label: 'Échanges', color: AppColors.reserve,
                onTap: () => context.push('/echanges')),
            const SizedBox(width: 8),
            _QuickPill(icon: Icons.notifications_outlined,
                label: 'Alertes', color: AppColors.retard,
                onTap: () => context.push('/notifications')),
          ]),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuickPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickPill({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  State<_QuickPill> createState() => _QuickPillState();
}

class _QuickPillState extends State<_QuickPill> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _pressed
                  ? widget.color.withValues(alpha: 0.12)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _pressed
                    ? widget.color.withValues(alpha: 0.4)
                    : AppColors.border,
                width: 1.5,
              ),
              boxShadow: _pressed ? [] : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8, offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 19),
                ),
                const SizedBox(height: 6),
                Text(widget.label,
                  style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary, letterSpacing: 0.1,
                  ),
                  textAlign: TextAlign.center, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV SECTION + ITEMS
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumNavSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final List<_PremiumNavItem> items;
  const _PremiumNavSection({
    required this.title, required this.icon,
    required this.accent, required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4, height: 14,
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 8),
            Icon(icon, size: 12, color: accent.withValues(alpha: 0.8)),
            const SizedBox(width: 5),
            Text(title.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
                letterSpacing: 1.2,
              )),
          ]),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isLast = i == items.length - 1;
                  return Column(children: [
                    item._buildTile(context),
                    if (!isLast)
                      Divider(
                        height: 1, indent: 62, endIndent: 16,
                        color: AppColors.border.withValues(alpha: 0.7),
                      ),
                  ]);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumNavItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PremiumNavItem({
    required this.icon, required this.label,
    required this.subtitle, required this.color, required this.onTap,
  });

  Widget _buildTile(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.08),
        highlightColor: color.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.07),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.20), width: 1),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                    style: const TextStyle(
                      fontSize: 14.5, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary, letterSpacing: -0.1,
                    )),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w400,
                    )),
                ],
              ),
            ),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: AppColors.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHint, size: 18),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGOUT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutTile extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutTile({required this.onTap});
  @override
  State<_LogoutTile> createState() => _LogoutTileState();
}

class _LogoutTileState extends State<_LogoutTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _pressed
                ? [AppColors.error.withValues(alpha: 0.15), AppColors.error.withValues(alpha: 0.08)]
                : [AppColors.error.withValues(alpha: 0.08), AppColors.error.withValues(alpha: 0.04)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _pressed
                ? AppColors.error.withValues(alpha: 0.5)
                : AppColors.error.withValues(alpha: 0.25),
            width: 1.5,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 17),
          ),
          const SizedBox(width: 12),
          const Text('Se déconnecter',
            style: TextStyle(
              fontSize: 14.5, fontWeight: FontWeight.w700,
              color: AppColors.error, letterSpacing: 0.1,
            )),
        ]),
      ),
    );
  }
}