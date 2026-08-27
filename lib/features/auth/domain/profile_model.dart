// lib/features/auth/domain/profile_model.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Rôles utilisateur réalignés avec les contraintes CHECK de la base de données :
/// - gerant: Gère le showroom au quotidien (accès complet)
/// - externe: Propriétaire/associé — accès lecture seule à son propre portefeuille
///   (le statut précis "propriétaire" vs "associé" est désormais porté par véhicule,
///   voir vehicule_proprietes.type_participation, pas par le profil utilisateur)
enum UserRole { 
  gerant,       
  externe       
}

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.gerant: return 'Gérant';
      case UserRole.externe: return 'Externe';
    }
  }

  String get description {
    switch (this) {
      case UserRole.gerant: 
        return 'Gestion complète du showroom au quotidien';
      case UserRole.externe: 
        return 'Accès en lecture seule à ses véhicules et sa finance';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.gerant: return Icons.admin_panel_settings;
      case UserRole.externe: return Icons.people;
    }
  }

  Color get color {
    switch (this) {
      case UserRole.gerant: return AppColors.gerant;
      case UserRole.externe: return AppColors.proprietaireVehicule;
    }
  }

  int get level {
    switch (this) {
      case UserRole.gerant: return 2;
      case UserRole.externe: return 1;
    }
  }
}

/// Permissions disponibles dans l'application
class Permission {
  static const vehiculesCreate = 'vehicules_create';
  static const vehiculesEdit = 'vehicules_edit';
  static const vehiculesDelete = 'vehicules_delete';
  static const vehiculesViewOwn = 'vehicules_view_own';
  
  static const locationsCreate = 'locations_create';
  static const locationsEdit = 'locations_edit';
  static const locationsReturn = 'locations_return';
  static const locationsView = 'locations_view';
  static const locationsViewOwn = 'locations_view_own';
  
  static const ventesCreate = 'ventes_create';
  static const ventesEdit = 'ventes_edit';
  static const ventesView = 'ventes_view';
  
  static const echangesCreate = 'echanges_create';
  static const echangesEdit = 'echanges_edit';
  static const echangesView = 'echanges_view';
  
  static const clientsCreate = 'clients_create';
  static const clientsEdit = 'clients_edit';
  static const clientsView = 'clients_view';
  
  static const caisseView = 'caisse_view';
  static const caisseEdit = 'caisse_edit';
  
  static const reparationsCreate = 'reparations_create';
  static const reparationsEdit = 'reparations_edit';
  static const reparationsView = 'reparations_view';
  
  static const entretienView = 'entretien_view';
  
  static const financeView = 'finance_view';
  static const financeViewOwn = 'finance_view_own';
  
  static const rapportsView = 'rapports_view';
  static const rapportsViewOwn = 'rapports_view_own';
  
  static const usersManage = 'users_manage';
  static const rolesManage = 'roles_manage';
  static const permissionsManage = 'permissions_manage';

  /// Catalogue utilisé par l'écran d'administration des permissions
  /// (lib/features/admin/presentation/role_permissions_screen.dart).
  /// Regroupe chaque permission sous un module avec un libellé lisible.
  static const Map<String, List<MapEntry<String, String>>> catalog = {
    'Véhicules': [
      MapEntry(vehiculesCreate, 'Ajouter un véhicule'),
      MapEntry(vehiculesEdit, 'Modifier un véhicule'),
      MapEntry(vehiculesDelete, 'Supprimer un véhicule'),
      MapEntry(vehiculesViewOwn, 'Voir ses véhicules associés'),
    ],
    'Locations': [
      MapEntry(locationsCreate, 'Créer une location'),
      MapEntry(locationsEdit, 'Modifier une location'),
      MapEntry(locationsReturn, 'Enregistrer un retour'),
      MapEntry(locationsView, 'Voir toutes les locations'),
      MapEntry(locationsViewOwn, 'Voir ses locations'),
    ],
    'Ventes': [
      MapEntry(ventesCreate, 'Créer une vente'),
      MapEntry(ventesEdit, 'Modifier une vente'),
      MapEntry(ventesView, 'Voir les ventes'),
    ],
    'Échanges': [
      MapEntry(echangesCreate, 'Créer un échange'),
      MapEntry(echangesEdit, 'Modifier un échange'),
      MapEntry(echangesView, 'Voir les échanges'),
    ],
    'Clients': [
      MapEntry(clientsCreate, 'Ajouter un client'),
      MapEntry(clientsEdit, 'Modifier un client'),
      MapEntry(clientsView, 'Voir les clients'),
    ],
    'Caisse': [
      MapEntry(caisseView, 'Voir la caisse'),
      MapEntry(caisseEdit, 'Modifier la caisse'),
    ],
    'Réparations': [
      MapEntry(reparationsCreate, 'Créer une réparation'),
      MapEntry(reparationsEdit, 'Modifier une réparation'),
      MapEntry(reparationsView, 'Voir les réparations'),
    ],
    'Entretien': [
      MapEntry(entretienView, "Voir les alertes d'entretien"),
    ],
    'Finance': [
      MapEntry(financeView, 'Voir la finance globale'),
      MapEntry(financeViewOwn, 'Voir sa propre finance'),
    ],
    'Rapports': [
      MapEntry(rapportsView, 'Voir tous les rapports'),
      MapEntry(rapportsViewOwn, 'Voir ses rapports'),
    ],
    'Administration': [
      MapEntry(usersManage, 'Gérer les utilisateurs'),
      MapEntry(rolesManage, 'Gérer les rôles'),
      MapEntry(permissionsManage, 'Gérer les permissions'),
    ],
  };
}

/// Permissions par rôle
class RolePermissions {
  /// Overrides chargés depuis Supabase (table `role_permissions`) pour le
  /// showroom actif. `null` = pas encore chargé / erreur → fallback sur les
  /// permissions par défaut codées en dur ci-dessous.
  static Map<UserRole, Set<String>>? _overrides;

  /// Appelé une fois le profil chargé (voir auth_provider.dart).
  /// Remplace le cache d'overrides en mémoire pour le showroom courant.
  static void applyOverrides(Map<UserRole, Set<String>> overrides) {
    _overrides = overrides;
  }

  /// Réinitialise le cache (déconnexion, changement de showroom).
  static void clearOverrides() {
    _overrides = null;
  }

  static Set<String> getDefaultPermissions(UserRole role) {
    final override = _overrides?[role];
    if (override != null) {
      // Sécurité : un gérant garde toujours au moins la gestion des
      // utilisateurs, même si l'override a été mal configuré, pour éviter
      // de se verrouiller hors de l'écran qui permet de corriger ça.
      if (role == UserRole.gerant) {
        return {...override, Permission.usersManage};
      }
      return override;
    }
    return _defaultPermissions(role);
  }

  static Set<String> _defaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.gerant:
        return {
          ...RolePermissions._getAllPermissions(),
          Permission.usersManage,
          Permission.rolesManage,
          Permission.permissionsManage,
        };

      case UserRole.externe:
        return {
          Permission.vehiculesViewOwn,
          Permission.locationsViewOwn,
          Permission.financeViewOwn,
          Permission.rapportsViewOwn,
        };
    }
  }

  static Set<String> _getAllPermissions() {
    return {
      Permission.vehiculesCreate,
      Permission.vehiculesEdit,
      Permission.vehiculesDelete,
      Permission.vehiculesViewOwn,
      Permission.locationsCreate,
      Permission.locationsEdit,
      Permission.locationsReturn,
      Permission.locationsView,
      Permission.locationsViewOwn,
      Permission.ventesCreate,
      Permission.ventesEdit,
      Permission.ventesView,
      Permission.echangesCreate,
      Permission.echangesEdit,
      Permission.echangesView,
      Permission.clientsCreate,
      Permission.clientsEdit,
      Permission.clientsView,
      Permission.caisseView,
      Permission.caisseEdit,
      Permission.reparationsCreate,
      Permission.reparationsEdit,
      Permission.reparationsView,
      Permission.entretienView,
      Permission.financeView,
      Permission.financeViewOwn,
      Permission.rapportsView,
      Permission.rapportsViewOwn,
    };
  }

  static bool hasPermission(UserRole role, String permission) {
    return getDefaultPermissions(role).contains(permission);
  }
}

class Profile {
  final String id;
  final String nom;
  final String prenom;
  final UserRole role;
  final String? telephone;
  final String? avatarUrl;
  final String? showroomId; 
  final DateTime? dateCreation;
  final Set<String>? customPermissions; 

  const Profile({
    required this.id, 
    required this.nom, 
    required this.prenom,
    required this.role, 
    this.telephone, 
    this.avatarUrl,
    this.showroomId,
    this.dateCreation,
    this.customPermissions,
  });

  String get fullName => '$prenom $nom';

  String get initials =>
    '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'.toUpperCase();

  Color get color => role.color;

  /// Permissions effectives de cet utilisateur.
  /// `customPermissions`, si défini, s'AJOUTE aux permissions du rôle
  /// (union) — il ne les remplace plus intégralement. Ça évite qu'un champ
  /// oublié en base ne court-circuite silencieusement le système de
  /// permissions par rôle (lib/features/admin/presentation/role_permissions_screen.dart).
  Set<String> getPermissions() {
    final base = RolePermissions.getDefaultPermissions(role);
    if (customPermissions != null && customPermissions!.isNotEmpty) {
      return {...base, ...customPermissions!};
    }
    return base;
  }

  bool hasPermission(String permission) => getPermissions().contains(permission);

  bool get canManageCaisse => hasPermission(Permission.caisseEdit);
  bool get canManageVehicules => hasPermission(Permission.vehiculesCreate) && hasPermission(Permission.vehiculesEdit);
  bool get isGerant => role == UserRole.gerant;
  bool get isExterne => role == UserRole.externe;
  bool get canViewFullFinance => hasPermission(Permission.financeView);
  bool get canManageUsers => hasPermission(Permission.usersManage);
  bool get canManageRoles => hasPermission(Permission.rolesManage);
  bool get canCreateVehicule => hasPermission(Permission.vehiculesCreate);
  bool get canDeleteVehicule => hasPermission(Permission.vehiculesDelete);
  bool get canCreateClient => hasPermission(Permission.clientsCreate);
  bool get canCreateReparation => hasPermission(Permission.reparationsCreate);
  bool get canCreateEchange => hasPermission(Permission.echangesCreate);
  bool get canCreateVente => hasPermission(Permission.ventesCreate);
  bool get isViewOnly => role == UserRole.externe;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id:        json['id'],
    nom:       json['nom'] ?? 'Inconnu',
    prenom:    json['prenom'] ?? '',
    role:      UserRole.values.firstWhere(
      (r) => r.name == json['role'],
      orElse: () => UserRole.externe
    ),
    telephone: json['telephone'],
    avatarUrl: json['avatar_url'],
    showroomId: json['showroom_id'], 
    dateCreation: json['created_at'] != null 
      ? DateTime.tryParse(json['created_at']) 
      : null,
    customPermissions: json['custom_permissions'] != null
      ? Set<String>.from(json['custom_permissions'])
      : null,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'prenom': prenom,
    'role': role.name,
    'telephone': telephone,
    'avatar_url': avatarUrl,
    'showroom_id': showroomId, 
    'created_at': dateCreation?.toIso8601String(),
    if (customPermissions != null)
      'custom_permissions': customPermissions!.toList(),
  };

  @override
  String toString() => 'Profile($fullName, ${role.label}, Showroom: $showroomId)';

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Profile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

extension ProfileUI on Profile {
  String get roleLabel => role.label;
  String get roleDescription => role.description;
  IconData get roleIcon => role.icon;
  Color get roleColor => role.color;
  
  bool get canAccessCaisse => hasPermission(Permission.caisseView);
  bool get canAccessFinance => hasPermission(Permission.financeView);
  bool get canCreateLocation => hasPermission(Permission.locationsCreate);
  bool get canCreateVente => hasPermission(Permission.ventesCreate);
  bool get canCreateEchange => hasPermission(Permission.echangesCreate);
  bool get canManageReparations => hasPermission(Permission.reparationsCreate);
  bool get canAccessAdmin => hasPermission(Permission.usersManage);
}
