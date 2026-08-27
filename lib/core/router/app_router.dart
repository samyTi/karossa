// lib/core/router/app_router.dart
// Routeur principal — routes imbriquées correctement dans les branches

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/contrats/presentation/contrats_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/domain/profile_model.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_screen.dart'; // 💡 Chemin ajusté vers features/profile
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
import '../../features/locations/presentation/location_edit_screen.dart';
import '../../features/clients/presentation/clients_screen.dart';
import '../../features/clients/presentation/client_form_screen.dart';
import '../../features/clients/presentation/client_detail_screen.dart';
import '../../features/caisse/presentation/caisse_screen.dart';
import '../../features/echanges/presentation/echanges_screen.dart';
import '../../features/echanges/presentation/echange_form_screen.dart';
import '../../features/reparations/presentation/reparations_screen.dart';
import '../../features/reparations/presentation/reparation_form_screen.dart';
import '../../features/reparations/domain/reparation_model.dart';
import '../../features/entretien/presentation/entretien_screen.dart';
import '../../features/entretien/presentation/entretien_form_screen.dart';
import '../../features/finance/presentation/releve_screen.dart';
import '../../features/ventes/presentation/vente_form_screen.dart';
import '../../features/ventes/presentation/vente_detail_screen.dart';
import '../../features/ventes/presentation/ventes_screen.dart';
import '../../features/admin/presentation/users_screen.dart';
import '../../features/admin/presentation/edit_user_screen.dart';
import '../../features/admin/presentation/add_user_screen.dart';
import '../../features/admin/presentation/settings_screen.dart';
import '../../features/admin/presentation/role_permissions_screen.dart';
import '../../features/achats/presentation/achats_screen.dart';
import '../../features/achats/presentation/achat_form_screen.dart';
import '../../features/achats/presentation/achat_detail_screen.dart';
import '../../features/gps/presentation/gps_fleet_map_screen.dart';
import '../../features/gps/presentation/gps_alerts_screen.dart';
import '../../features/gps/presentation/gps_screen.dart';
import '../../features/gps/presentation/gps_dashboard_screen.dart';
import '../../features/gps/presentation/gps_playback_screen.dart';
import '../../features/gps/presentation/gps_alerts_center_screen.dart';
import '../../features/gps/presentation/gps_geofences_screen.dart';
import '../../features/gps/presentation/gps_heatmap_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/presentation/notifications_provider.dart';
import '../../features/audit/presentation/audit_log_screen.dart';
import '../../features/locations/presentation/location_calendar_screen.dart';
import '../../features/ai/presentation/ai_chat_screen.dart';
import '../../features/contrats/presentation/contract_articles_admin_screen.dart';
import '../../features/web_demandes/presentation/web_demandes_screen.dart';
import '../../features/finance/presentation/proprietaire_finance_screen.dart';
import '../../features/finance/presentation/gerant_commission_screen.dart';

// Import indispensable pour mapper la clé d'Overlay globale
import '../../shared/services/notification_service.dart';
import 'package:garage_auto/core/extensions/l10n_extension.dart';

// ── RBAC : permission requise pour accéder à un préfixe de route ────────────
// Basé sur le système Permission/RolePermissions déjà défini dans
// profile_model.dart — on ne fait ici que l'APPLIQUER au niveau navigation.
// Avant cette modif, un `associe` pouvait taper une URL /admin/... ou /caisse
// directement (deep link, barre d'adresse) et atteindre l'écran, car aucune
// route ne vérifiait réellement hasPermission().
final Map<String, String> _routePermissions = {
  '/admin/role-permissions': Permission.permissionsManage,
  '/admin': Permission.usersManage,
  '/caisse': Permission.caisseView,
  '/releve': Permission.financeView,
};

String? _missingPermissionRedirect(Profile? profile, String location) {
  if (profile == null) return null;

  // Cas spécial : un "externe" peut toujours consulter SON PROPRE récap
  // financier (lien ajouté au menu), même sans la permission 'usersManage'
  // qui protège normalement tout /admin/... — on vérifie juste que l'id
  // dans l'URL correspond bien à son propre profil.
  if (location.startsWith('/admin/proprietaire/')) {
    final id = location.substring('/admin/proprietaire/'.length).split('?').first;
    if (id == profile.id && profile.hasPermission(Permission.financeViewOwn)) {
      return null;
    }
  }

  // Trie par longueur de préfixe décroissante : la route la PLUS SPÉCIFIQUE
  // gagne (ex. '/admin/role-permissions' avant '/admin'). Sans ça, le
  // préfixe générique '/admin' pouvait bloquer un rôle ayant seulement
  // 'permissionsManage' mais pas 'usersManage'.
  final sortedEntries = _routePermissions.entries.toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  for (final entry in sortedEntries) {
    if (location.startsWith(entry.key)) {
      return profile.hasPermission(entry.value) ? null : '/dashboard';
    }
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    
    // 🌐 AJOUT MAJEUR : Liaison de la clé globale pour corriger le bug de l'Overlay indéfinie
    navigatorKey: NotificationService.navigatorKey,

    redirect: (context, state) {
      // Évite les sauts de redirection si Supabase charge encore l'état de session
      if (authState.isLoading) return null;

      final isLoggedIn   = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';
      
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn  && isLoginRoute)  return '/dashboard';

      // Garde RBAC : bloque l'accès direct par URL à un module non autorisé.
      if (isLoggedIn) {
        final profile = ref.read(currentProfileProvider).valueOrNull;
        final blocked = _missingPermissionRedirect(profile, state.matchedLocation);
        if (blocked != null && blocked != state.matchedLocation) return blocked;
      }
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
                    // ★ NOUVEAU — lien "Créer une réparation" depuis une alerte GPS
                    // (gps_alerts_center_screen.dart → onAction createRepair)
                    // ⚠️ TODO : ReparationFormScreen n'a pas encore de paramètre
                    //    `vehiculeId` pour préremplir le véhicule. En attendant,
                    //    on ouvre le formulaire vide (l'utilisateur sélectionne
                    //    le véhicule manuellement). Voir message suivant pour
                    //    ajouter le préremplissage proprement.
                    GoRoute(
                      path: 'reparations/new',
                      builder: (_, s) => const ReparationFormScreen(),
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
                  path: 'calendrier',
                  builder: (_, __) => const LocationCalendarScreen(),
                ),
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
                GoRoute(
                  path: ':id/edit',
                  builder: (_, s) => LocationEditScreen(
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
                  builder: (_, s) => ClientDetailScreen(
                    clientId: s.pathParameters['id']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, s) => ClientFormScreen(
                        clientId: s.pathParameters['id'],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ]),

          // ── Plus (menu secondaire) ───────────────────────────────────────
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              builder: (_, __) => const ModernMenuScreen(),
              routes: [
                GoRoute(
                  path: 'web-demandes',
                  builder: (_, __) => const WebDemandesScreen(),
                ),
              ],
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
          GoRoute(
            path: ':id',
            builder: (_, s) => VenteDetailScreen(
              venteId: s.pathParameters['id']!,
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
          GoRoute(
            path: ':id/edit',
            builder: (_, s) => ReparationFormScreen(
              existing: s.extra as Reparation?,
            ),
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
        builder: (_, __) => const GpsDashboardScreen(), // ★ Mission Control = nouvel écran d'entrée
        routes: [
          GoRoute(
            path: 'map',
            builder: (_, __) => const GpsFleetMapScreen(),
          ),
          GoRoute(
            path: 'alertes',
            builder: (_, __) => const GpsAlertsScreen(),
          ),

          // Ancien écran (liste simple par véhicule) — conservé au cas où
          // il serait encore utile, déplacé pour ne pas entrer en conflit
          // avec le nouveau Mission Control sur '/gps'.
          GoRoute(
            path: 'legacy',
            builder: (_, __) => const GpsScreen(),
          ),

          // Alias — certains écrans (ex. GpsFleetHomeWidget) poussent encore
          // vers '/gps/dashboard' explicitement ; garde les deux chemins valides.
          GoRoute(
            path: 'dashboard',
            builder: (_, __) => const GpsDashboardScreen(),
          ),

          // Lecture de trajet animée (playback)
          // Appelé avec extra: {'vehiculeId': id, 'nom': 'BMW 320d'}
          GoRoute(
            path: 'playback',
            builder: (_, s) {
              final extra = s.extra as Map<String, dynamic>?;
              return GpsPlaybackScreen(
                vehiculeId:  extra?['vehiculeId'] as String? ?? '',
                vehiculeNom: extra?['nom'] as String? ?? 'Véhicule',
              );
            },
          ),

          // Centre d'alertes unifié (GPS + entretien)
          GoRoute(
            path: 'alerts-center',
            builder: (_, __) => const GpsAlertsCenterScreen(),
          ),

          // Geofencing (tracé + gestion des zones)
          GoRoute(
            path: 'geofences',
            builder: (_, __) => const GpsGeofencesScreen(),
          ),

          // Heat map (zones de circulation)
          GoRoute(
            path: 'heatmap',
            builder: (_, __) => const GpsHeatmapScreen(),
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
        path: '/admin/users/edit',
        builder: (_, s) => EditUserScreen(user: s.extra as Profile),
      ),
      GoRoute(
        path: '/admin/users/add',
        builder: (_, __) => const AddUserScreen(),
      ),
      GoRoute(
        path: '/admin/proprietaire/:id',
        builder: (_, s) => ProprietaireFinanceScreen(
          proprietaireId: s.pathParameters['id']!,
          proprietaireNom: s.uri.queryParameters['nom'] ?? 'Propriétaire',
        ),
      ),
      GoRoute(
        path: '/admin/gerant/:id',
        builder: (_, s) => GerantCommissionScreen(
          gerantId: s.pathParameters['id']!,
          gerantNom: s.uri.queryParameters['nom'] ?? 'Gérant',
        ),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/admin/role-permissions',
        builder: (_, __) => const RolePermissionsScreen(),
      ),
      GoRoute(
        path: '/admin/contract-articles',
        builder: (_, __) => const ContractArticlesAdminScreen(),
      ),
      GoRoute(
        path: '/admin/audit-log',
        builder: (_, __) => const AuditLogScreen(),
      ),
    ],
  );
});

// ── Scaffold principal avec BottomNavigationBar ───────────────────────────────
class _MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const _MainScaffold({required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Active l'écoute Realtime (nouvelles alertes GPS, retards, demandes web...)
    // une seule fois pour toute la navigation principale.
    ref.watch(notificationsRealtimeProvider);
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) => Scaffold(
    body: shell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: shell.currentIndex,
      onDestinationSelected: shell.goBranch,
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: context.l10n.navAccueil,
        ),
        NavigationDestination(
          icon: Icon(Icons.directions_car_outlined),
          selectedIcon: Icon(Icons.directions_car),
          label: context.l10n.vehicules,
        ),
        NavigationDestination(
          icon: Icon(Icons.car_rental_outlined),
          selectedIcon: Icon(Icons.car_rental),
          label: context.l10n.titreLocations,
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outlined),
          selectedIcon: Icon(Icons.people),
          label: context.l10n.titreClients,
        ),
        NavigationDestination(
          icon: Icon(Icons.apps_outlined),
          selectedIcon: Icon(Icons.apps),
          label: context.l10n.navPlus,
        ),
      ],
    ),
  );
}