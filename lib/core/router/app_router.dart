// lib/core/router/app_router.dart
// Routeur principal — sans doublons, avec module GPS

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/vehicules/presentation/catalogue_screen.dart';
import '../../features/vehicules/presentation/vehicule_form_screen.dart';
import '../../features/vehicules/presentation/vehicule_detail_screen.dart';
import '../../features/vehicules/presentation/vehicule_history_screen.dart';
import '../../features/locations/presentation/locations_screen.dart';
import '../../features/locations/presentation/location_form_screen.dart';
import '../../features/locations/presentation/location_retour_screen.dart';
import '../../features/clients/presentation/clients_screen.dart';
import '../../features/clients/presentation/client_form_screen.dart';
import '../../features/caisse/presentation/caisse_screen.dart';
import '../../features/echanges/presentation/echanges_screen.dart';
import '../../features/echanges/presentation/echange_form_screen.dart';
import '../../features/reparations/presentation/reparations_screen.dart';
import '../../features/reparations/presentation/reparation_form_screen.dart';
import '../../features/entretien/presentation/entretien_screen.dart';
import '../../features/entretien/presentation/entretien_form_screen.dart';
import '../../features/finance/presentation/releve_screen.dart';
import '../../features/ventes/presentation/vente_form_screen.dart';
import '../../features/ventes/presentation/ventes_screen.dart';
import '../../features/admin/presentation/users_screen.dart';
import '../../features/admin/presentation/settings_screen.dart';
import '../../features/achats/presentation/achats_screen.dart';
import '../../features/achats/presentation/achat_form_screen.dart';
import '../../features/achats/presentation/achat_detail_screen.dart';
import '../../features/gps/presentation/gps_map_screen.dart';
import '../../features/gps/presentation/gps_alerts_screen.dart';
import '../../features/contrats/presentation/contrats_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn   = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn  && isLoginRoute)  return '/dashboard';
      return null;
    },
    routes: [

      // ── Auth ──────────────────────────────────────────────
      GoRoute(path: '/login',
        builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/profil',
        builder: (_, __) => const ProfileScreen()),

      // ── Navigation principale avec BottomNav ──────────────
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => _MainScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/dashboard',
              builder: (_, __) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/vehicules',
              builder: (_, __) => const CatalogueScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (_, s) => VehiculeDetailScreen(
                    id: s.pathParameters['id']!)),
              ]),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/locations',
              builder: (_, __) => const LocationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/clients',
              builder: (_, __) => const ClientsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/more',
              builder: (_, __) => const _MoreScreen()),
          ]),
        ],
      ),

      // ── Véhicules ─────────────────────────────────────────
      GoRoute(path: '/vehicules/new',
        builder: (_, __) => const VehiculeFormScreen()),
      GoRoute(path: '/vehicules/:id/edit',
        builder: (_, s) => VehiculeFormScreen(
          vehiculeId: s.pathParameters['id'])),
      GoRoute(path: '/vehicules/:id/history',
        builder: (_, s) => VehiculeHistoryScreen(
          vehiculeId: s.pathParameters['id']!)),

      // ── Locations ─────────────────────────────────────────
      GoRoute(path: '/locations/new',
        builder: (_, s) => LocationFormScreen(
          vehiculeId: s.uri.queryParameters['vehiculeId'])),
      GoRoute(path: '/locations/:id/retour',
        builder: (_, s) => LocationRetourScreen(
          locationId: s.pathParameters['id']!)),

      // ── Clients ───────────────────────────────────────────
      GoRoute(path: '/clients/new',
        builder: (_, __) => const ClientFormScreen()),
      GoRoute(path: '/clients/:id',
        builder: (_, s) => ClientFormScreen(
          clientId: s.pathParameters['id'])),

      // ── Ventes ────────────────────────────────────────────
      GoRoute(path: '/ventes',
        builder: (_, __) => const VentesScreen()),
      GoRoute(path: '/ventes/new',
        builder: (_, s) => VenteFormScreen(
          vehiculeId: s.uri.queryParameters['vehiculeId'])),

      // ── Achats ────────────────────────────────────────────
      GoRoute(path: '/achats',
        builder: (_, __) => const AchatsScreen()),
      GoRoute(path: '/achats/new',
        builder: (_, __) => const AchatFormScreen()),
      GoRoute(path: '/achats/:id',
        builder: (_, s) => AchatDetailScreen(
          achatId: s.pathParameters['id']!)),

      // ── Autres modules ────────────────────────────────────
      GoRoute(path: '/caisse',
        builder: (_, __) => const CaisseScreen()),
      GoRoute(path: '/echanges',
        builder: (_, __) => const EchangesScreen()),
      GoRoute(path: '/echanges/new',
        builder: (_, __) => const EchangeFormScreen()),
      GoRoute(path: '/reparations',
        builder: (_, __) => const ReparationsScreen()),
      GoRoute(path: '/reparations/new',
        builder: (_, __) => const ReparationFormScreen()),
      GoRoute(path: '/entretien',
        builder: (_, __) => const EntretienScreen()),
      GoRoute(path: '/entretien/new',
        builder: (_, __) => const EntretienFormScreen()),
      GoRoute(path: '/releve',
        builder: (_, __) => const ReleveScreen()),

      // ── Administration ────────────────────────────────────
      GoRoute(path: '/admin/users',
        builder: (_, __) => const UsersScreen()),
      GoRoute(path: '/admin/settings',
        builder: (_, __) => const SettingsScreen()),

      // ── GPS (NOUVEAU) ─────────────────────────────────────
      GoRoute(path: '/contrats',
        builder: (_, __) => const ContratsScreen()),

      // ── GPS (NOUVEAU) ─────────────────────────────────────
      GoRoute(path: '/gps',
        builder: (_, __) => const GpsMapScreen()),
      GoRoute(path: '/gps/alertes',
        builder: (_, __) => const GpsAlertsScreen()),
    ],
  );
});

// ── Scaffold principal avec BottomNavigationBar ───────────────────────
class _MainScaffold extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _MainScaffold({required this.shell});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: 'Accueil'),
        NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car),
          label: 'Véhicules'),
        NavigationDestination(
          icon: Icon(Icons.car_rental_outlined),
          selectedIcon: Icon(Icons.car_rental),
          label: 'Locations'),
        NavigationDestination(
          icon: Icon(Icons.people_outlined),
          selectedIcon: Icon(Icons.people),
          label: 'Clients'),
        NavigationDestination(
          icon: Icon(Icons.apps_outlined),
          selectedIcon: Icon(Icons.apps),
          label: 'Plus'),
      ],
    ),
  );
}

// ── Écran "Plus" — menu de tous les autres modules ─────────────────────
class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MenuCategory(title: 'Transactions', items: [
            _MI('Ventes',    Icons.sell,         AppColors.secondary, '/ventes'),
            _MI('Achats',    Icons.shopping_cart, AppColors.accent,    '/achats'),
            _MI('Échanges',  Icons.swap_horiz,   AppColors.primary,   '/echanges'),
          ]),
          _MenuCategory(title: 'Opérations', items: [
            _MI('Caisse',    Icons.account_balance_wallet, AppColors.secondary, '/caisse'),
            _MI('Réparations', Icons.build,              AppColors.reparation, '/reparations'),
            _MI('Entretien', Icons.calendar_today,        AppColors.accent,    '/entretien'),
            _MI('Relevé',    Icons.bar_chart,             AppColors.primary,   '/releve'),
          ]),
          _MenuCategory(title: 'GPS & Suivi', items: [
            _MI('Carte Live',  Icons.map,              AppColors.secondary, '/gps'),
            _MI('Alertes GPS', Icons.notifications,    AppColors.retard,    '/gps/alertes'),
          ]),
          _MenuCategory(title: 'Administration', items: [
            _MI('Utilisateurs', Icons.manage_accounts, AppColors.primary, '/admin/users'),
            _MI('Paramètres',   Icons.settings,        AppColors.textSecondary, '/admin/settings'),
            _MI('Contrats',     Icons.description,     AppColors.accent,  '/contrats'),
            _MI('Mon profil',   Icons.person,          AppColors.primary, '/profil'),
          ]),
        ],
      ),
    );
  }
}

class _MenuCategory extends StatelessWidget {
  final String title;
  final List<_MI> items;
  const _MenuCategory({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.textSecondary)),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5),
        itemCount: items.length,
        itemBuilder: (_, i) => _MenuItemCard(item: items[i]),
      ),
      const SizedBox(height: 8),
    ],
  );
}

class _MI {
  final String label;
  final IconData icon;
  final Color color;
  final String route;
  const _MI(this.label, this.icon, this.color, this.route);
}

class _MenuItemCard extends StatelessWidget {
  final _MI item;
  const _MenuItemCard({required this.item});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go(item.route),
    borderRadius: BorderRadius.circular(12),
    child: Container(
      decoration: BoxDecoration(
        color: item.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 28, color: item.color),
          const SizedBox(height: 8),
          Text(item.label,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: item.color,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}
