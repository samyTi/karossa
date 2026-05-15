// lib/core/router/app_router.dart
// Routeur principal — routes imbriquées correctement dans les branches

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/contrats/presentation/contrats_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/dashboard/presentation/modern_dashboard.dart';
import '../../features/menu/presentation/modern_menu_screen.dart';
import '../../features/vehicules/presentation/vehicule_contracts_screen.dart';
import '../../features/vehicules/presentation/catalogue_screen.dart';
import '../../features/vehicules/presentation/vehicule_form_screen.dart';
import '../../features/vehicules/presentation/vehicule_detail_screen.dart';
import '../../features/vehicules/presentation/vehicule_history_screen.dart';
import '../../features/vehicules/presentation/vehicule_financials_screen.dart';
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
// ✅ gps_map_screen renommé en gps_fleet_map_screen
import '../../features/gps/presentation/gps_fleet_map_screen.dart';
import '../../features/gps/presentation/gps_alerts_screen.dart';
// ✅ gps_screen déplacé de screens/ vers presentation/
import '../../features/gps/presentation/gps_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/ai/presentation/ai_chat_screen.dart';
import '../../features/contrats/presentation/contract_articles_admin_screen.dart';


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

      // ── Auth ──────────────────────────────────────────────────────────────
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/profil',
        builder: (_, __) => const ProfileScreen(),
      ),

      // ── Navigation principale avec BottomNav ──────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (ctx, state, shell) => _MainScaffold(shell: shell),
        branches: [

          // ── Dashboard ───────────────────────────────────────────────────
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, __) => const ModernDashboard(),
            ),
          ]),

          // ── Véhicules ───────────────────────────────────────────────────
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/vehicules',
              builder: (_, __) => const CatalogueScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, __) => const VehiculeFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, s) => VehiculeDetailScreen(
                    id: s.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, s) => VehiculeFormScreen(
                        vehiculeId: s.pathParameters['id'],
                      ),
                    ),
                    GoRoute(
                      path: 'history',
                      builder: (_, s) => VehiculeHistoryScreen(
                        vehiculeId: s.pathParameters['id']!,
                      ),
                    ),
                    GoRoute(
                      path: 'financials',
                      builder: (_, s) => VehiculeFinancialsScreen(
                        vehiculeId: s.pathParameters['id']!,
                        vehiculeNom: s.uri.queryParameters['nom'] ?? 'Véhicule',
                      ),
                    ),
                    GoRoute(
                      path: 'contracts',
                      builder: (_, s) => VehiculeContractsScreen(
                        vehiculeId: s.pathParameters['id']!,
                        vehiculeNom: s.uri.queryParameters['nom'] ?? 'Véhicule',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),

          // ── Locations ───────────────────────────────────────────────────
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/locations',
              builder: (_, __) => const LocationsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, s) => LocationFormScreen(
                    vehiculeId: s.uri.queryParameters['vehiculeId'],
                  ),
                ),
                GoRoute(
                  path: ':id/retour',
                  builder: (_, s) => LocationRetourScreen(
                    locationId: s.pathParameters['id']!,
                  ),
                ),
              ],
            ),
          ]),

          // ── Clients ─────────────────────────────────────────────────────
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/clients',
              builder: (_, __) => const ClientsScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (_, __) => const ClientFormScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (_, s) => ClientFormScreen(
                    clientId: s.pathParameters['id'],
                  ),
                ),
              ],
            ),
          ]),

          // ── Plus (menu secondaire) ───────────────────────────────────────
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              builder: (_, __) => const ModernMenuScreen(),
            ),
          ]),
        ],
      ),

      // ── Ventes ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/ventes',
        builder: (_, __) => const VentesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, s) => VenteFormScreen(
              vehiculeId: s.uri.queryParameters['vehiculeId'],
            ),
          ),
        ],
      ),

      // ── Achats ────────────────────────────────────────────────────────────
      GoRoute(
        path: '/achats',
        builder: (_, __) => const AchatsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => const AchatFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (_, s) => AchatDetailScreen(
              achatId: s.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // ── Échanges ──────────────────────────────────────────────────────────
      GoRoute(
        path: '/echanges',
        builder: (_, __) => const EchangesScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => const EchangeFormScreen(),
          ),
        ],
      ),

      // ── Réparations ───────────────────────────────────────────────────────
      GoRoute(
        path: '/reparations',
        builder: (_, __) => const ReparationsScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => const ReparationFormScreen(),
          ),
        ],
      ),

      // ── Entretien ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/entretien',
        builder: (_, __) => const EntretienScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (_, __) => const EntretienFormScreen(),
          ),
        ],
      ),

      // ── Autres modules ────────────────────────────────────────────────────
      GoRoute(
        path: '/caisse',
        builder: (_, __) => const CaisseScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/releve',
        builder: (_, __) => const ReleveScreen(),
      ),
      GoRoute(
        path: '/contrats',
        builder: (_, __) => const ContratsScreen(),
      ),

      // ── GPS ───────────────────────────────────────────────────────────────
      GoRoute(
        path: '/gps',
        builder: (_, __) => const GpsScreen(),      // ✅ liste véhicules GPS
        routes: [
          GoRoute(
            path: 'map',
            builder: (_, __) => const GpsFleetMapScreen(), // ✅ carte flotte
          ),
          GoRoute(
            path: 'alertes',
            builder: (_, __) => const GpsAlertsScreen(),
          ),
        ],
      ),

      // ── IA Chat ───────────────────────────────────────────────────────────
      GoRoute(
        path: '/ai-chat',
        builder: (_, s) {
          final extra = s.extra as Map<String, dynamic>?;
          return AiChatScreen(
            vehiculeContext: extra?['vehiculeContext'],
            vehiculeNom:     extra?['vehiculeNom'],
          );
        },
      ),

      // ── Administration ────────────────────────────────────────────────────
      GoRoute(
        path: '/admin/users',
        builder: (_, __) => const UsersScreen(),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin/contract-articles',
        builder: (_, __) => const ContractArticlesAdminScreen(),
      ),
    ],
  );
});

// ── Scaffold principal avec BottomNavigationBar ───────────────────────────────
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
          label: 'Accueil',
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car),
          label: 'Véhicules',
        ),
        NavigationDestination(
          icon: Icon(Icons.car_rental_outlined),
          selectedIcon: Icon(Icons.car_rental),
          label: 'Locations',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outlined),
          selectedIcon: Icon(Icons.people),
          label: 'Clients',
        ),
        NavigationDestination(
          icon: Icon(Icons.apps_outlined),
          selectedIcon: Icon(Icons.apps),
          label: 'Plus',
        ),
      ],
    ),
  );
}