import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Rôles utilisateur dans l'application
/// - admin: Super administrateur qui gère les permissions
/// - gerant: Gère tout le showroom
/// - proprietaire_showroom: Propriétaire principal du showroom
/// - proprietaire_vehicule: Propriétaire de véhicules uniquement
enum UserRole { 
  admin,                 // Super admin - Gère les permissions
  gerant,                // Gérant - Gestion complète
  // ignore: constant_identifier_names
  proprietaire_showroom, // Propriétaire du showroom + véhicules
  // ignore: constant_identifier_names
  proprietaire_vehicule  // Propriétaire de véhicules seulement
}

extension UserRoleExtension on UserRole {
  String get label {
    switch (this) {
      case UserRole.admin: return 'Administrateur';
      case UserRole.gerant: return 'Gérant';
      case UserRole.proprietaire_showroom: return 'Propriétaire Showroom';
      case UserRole.proprietaire_vehicule: return 'Propriétaire Véhicule';
    }
  }

  String get description {
    switch (this) {
      case UserRole.admin: 
        return 'Administrateur principal - Gère les utilisateurs et permissions';
      case UserRole.gerant: 
        return 'Gestion complète du showroom';
      case UserRole.proprietaire_showroom: 
        return 'Propriétaire du showroom et des véhicules';
      case UserRole.proprietaire_vehicule: 
        return 'Propriétaire de véhicules en location/vente';
    }
  }

  IconData get icon {
    switch (this) {
      case UserRole.admin: return Icons.security;
      case UserRole.gerant: return Icons.admin_panel_settings;
      case UserRole.proprietaire_showroom: return Icons.business;
      case UserRole.proprietaire_vehicule: return Icons.directions_car;
    }
  }

  Color get color {
    // Couleur basée sur le RÔLE, pas le prénom - plus professionnel
    switch (this) {
      case UserRole.admin: return AppColors.admin;
      case UserRole.gerant: return AppColors.gerant;
      case UserRole.proprietaire_showroom: return AppColors.proprietaireShowroom;
      case UserRole.proprietaire_vehicule: return AppColors.proprietaireVehicule;
    }
  }

  int get level {
    // Niveau hiérarchique pour les comparaisons
    switch (this) {
      case UserRole.admin: return 4;
      case UserRole.gerant: return 3;
      case UserRole.proprietaire_showroom: return 2;
      case UserRole.proprietaire_vehicule: return 1;
    }
  }
}

/// Permissions disponibles dans l'application
class Permission {
  // Véhicules
  static const vehiculesCreate = 'vehicules_create';
  static const vehiculesEdit = 'vehicules_edit';
  static const vehiculesDelete = 'vehicules_delete';
  static const vehiculesViewOwn = 'vehicules_view_own';
  
  // Locations
  static const locationsCreate = 'locations_create';
  static const locationsEdit = 'locations_edit';
  static const locationsReturn = 'locations_return';
  static const locationsView = 'locations_view';
  static const locationsViewOwn = 'locations_view_own';
  
  // Ventes
  static const ventesCreate = 'ventes_create';
  static const ventesEdit = 'ventes_edit';
  static const ventesView = 'ventes_view';
  
  // Échanges
  static const echangesCreate = 'echanges_create';
  static const echangesEdit = 'echanges_edit';
  static const echangesView = 'echanges_view';
  
  // Clients
  static const clientsCreate = 'clients_create';
  static const clientsEdit = 'clients_edit';
  static const clientsView = 'clients_view';
  
  // Caisse
  static const caisseView = 'caisse_view';
  static const caisseEdit = 'caisse_edit';
  
  // Réparations
  static const reparationsCreate = 'reparations_create';
  static const reparationsEdit = 'reparations_edit';
  static const reparationsView = 'reparations_view';
  
  // Entretien
  static const entretienView = 'entretien_view';
  
  // Finance
  static const financeView = 'finance_view';
  static const financeViewOwn = 'finance_view_own';
  
  // Rapports
  static const rapportsView = 'rapports_view';
  static const rapportsViewOwn = 'rapports_view_own';
  
  // Administration
  static const usersManage = 'users_manage';
  static const rolesManage = 'roles_manage';
  static const permissionsManage = 'permissions_manage';
}

/// Permissions par rôle
class RolePermissions {
  static Set<String> getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return {
          // Tous les permissions + gestion des utilisateurs
          ...RolePermissions._getAllPermissions(),
          Permission.usersManage,
          Permission.rolesManage,
          Permission.permissionsManage,
        };

      case UserRole.gerant:
        return {
          Permission.vehiculesCreate,
          Permission.vehiculesEdit,
          Permission.vehiculesDelete,
          Permission.locationsCreate,
          Permission.locationsEdit,
          Permission.locationsReturn,
          Permission.ventesCreate,
          Permission.ventesEdit,
          Permission.echangesCreate,
          Permission.echangesEdit,
          Permission.clientsCreate,
          Permission.clientsEdit,
          Permission.caisseView,
          Permission.caisseEdit,
          Permission.reparationsCreate,
          Permission.reparationsEdit,
          Permission.entretienView,
          Permission.financeView,
          Permission.rapportsView,
        };

      case UserRole.proprietaire_showroom:
        return {
          Permission.vehiculesCreate,
          Permission.vehiculesEdit,
          Permission.vehiculesDelete,
          Permission.locationsView,
          Permission.ventesView,
          Permission.echangesView,
          Permission.clientsView,
          Permission.caisseView,
          Permission.reparationsView,
          Permission.entretienView,
          Permission.financeView,
          Permission.rapportsView,
        };

      case UserRole.proprietaire_vehicule:
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
  final DateTime? dateCreation;
  final Set<String>? customPermissions; // Permissions personnalisées (admin only)

  const Profile({
    required this.id, 
    required this.nom, 
    required this.prenom,
    required this.role, 
    this.telephone, 
    this.avatarUrl,
    this.dateCreation,
    this.customPermissions,
  });

  String get fullName => '$prenom $nom';

  String get initials =>
    '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'.toUpperCase();

  Color get color {
    // Couleur basée sur le RÔLE, pas le prénom - plus professionnel et réutilisable
    return role.color;
  }

  /// Obtient toutes les permissions de l'utilisateur
  Set<String> getPermissions() {
    if (customPermissions != null && customPermissions!.isNotEmpty) {
      return customPermissions!;
    }
    return RolePermissions.getDefaultPermissions(role);
  }

  /// Vérifie si l'utilisateur a une permission spécifique
  bool hasPermission(String permission) {
    return getPermissions().contains(permission);
  }

  /// Vérifie si l'utilisateur peut gérer la caisse
  bool get canManageCaisse => hasPermission(Permission.caisseEdit);

  /// Vérifie si l'utilisateur peut créer/modifier des véhicules
  bool get canManageVehicules => 
    hasPermission(Permission.vehiculesCreate) && 
    hasPermission(Permission.vehiculesEdit);

  /// Vérifie si l'utilisateur est un admin
  bool get isAdmin => role == UserRole.admin;

  /// Vérifie si l'utilisateur est un gérant
  bool get isGerant => role == UserRole.gerant;

  /// Vérifie si l'utilisateur est propriétaire (showroom ou véhicule)
  bool get isProprietaire => 
    role == UserRole.proprietaire_showroom || role == UserRole.proprietaire_vehicule;

  /// Vérifie si l'utilisateur peut voir les rapports financiers complets
  bool get canViewFullFinance => hasPermission(Permission.financeView);

  /// Vérifie si l'utilisateur peut gérer les autres utilisateurs
  bool get canManageUsers => hasPermission(Permission.usersManage);

  /// Vérifie si l'utilisateur peut modifier les rôles
  bool get canManageRoles => hasPermission(Permission.rolesManage);

  /// Vérifie si l'utilisateur peut créer des véhicules
  bool get canCreateVehicule => hasPermission(Permission.vehiculesCreate);

  /// Vérifie si l'utilisateur peut supprimer des véhicules
  bool get canDeleteVehicule => hasPermission(Permission.vehiculesDelete);

  /// Vérifie si l'utilisateur peut créer des clients
  bool get canCreateClient => hasPermission(Permission.clientsCreate);

  /// Vérifie si l'utilisateur peut créer des réparations
  bool get canCreateReparation => hasPermission(Permission.reparationsCreate);

  /// Vérifie si l'utilisateur peut créer des échanges
  bool get canCreateEchange => hasPermission(Permission.echangesCreate);

  /// Vérifie si l'utilisateur peut créer des ventes
  bool get canCreateVente => hasPermission(Permission.ventesCreate);

  /// Vérifie si l'utilisateur est en mode 'lecture seule' (proprietaire_vehicule)
  bool get isViewOnly => role == UserRole.proprietaire_vehicule;

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id:        json['id'],
    nom:       json['nom'],
    prenom:    json['prenom'],
    role:      UserRole.values.firstWhere(
      (r) => r.name == json['role'],
      orElse: () => UserRole.proprietaire_vehicule
    ),
    telephone: json['telephone'],
    avatarUrl: json['avatar_url'],
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
    'created_at': dateCreation?.toIso8601String(),
    if (customPermissions != null)
      'custom_permissions': customPermissions!.toList(),
  };

  @override
  String toString() => 'Profile($fullName, ${role.label})';

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is Profile && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Extension pour afficher les informations de rôle dans l'UI
extension ProfileUI on Profile {
  String get roleLabel => role.label;
  String get roleDescription => role.description;
  IconData get roleIcon => role.icon;
  Color get roleColor => role.color;
  
  /// Retourne true si ce profil peut accéder au menu Caisse
  bool get canAccessCaisse => hasPermission(Permission.caisseView);
  
  /// Retourne true si ce profil peut accéder aux rapports financiers
  bool get canAccessFinance => hasPermission(Permission.financeView);
  
  /// Retourne true si ce profil peut créer des locations
  bool get canCreateLocation => hasPermission(Permission.locationsCreate);
  
  /// Retourne true si ce profil peut créer des ventes
  bool get canCreateVente => hasPermission(Permission.ventesCreate);
  
  /// Retourne true si ce profil peut créer des échanges
  bool get canCreateEchange => hasPermission(Permission.echangesCreate);
  
  /// Retourne true si ce profil peut gérer les réparations
  bool get canManageReparations => hasPermission(Permission.reparationsCreate);
  
  /// Retourne true si ce profil peut gérer les utilisateurs
  bool get canAccessAdmin => hasPermission(Permission.usersManage);
}