import 'package:cognispark/models/user.dart';
import 'package:cognispark/services/storage_service.dart';

enum Permission {
  // Quiz permissions
  createQuiz,
  editQuiz,
  deleteQuiz,
  viewAllQuizzes,
  publishQuiz,
  unpublishQuiz,
  
  // User permissions
  viewUsers,
  createUser,
  editUser,
  deleteUser,
  manageUserRoles,
  viewUserActivity,
  
  // Session permissions
  viewAllSessions,
  manageSessions,
  forceCompleteSession,
  cancelSession,
  
  // Analytics permissions
  viewBasicAnalytics,
  viewAdvancedAnalytics,
  viewSystemAnalytics,
  exportData,
  
  // System permissions
  manageSystem,
  viewSystemSettings,
  editSystemSettings,
  viewLogs,
  manageMaintenance,
  
  // Content permissions
  manageCategories,
  manageTemplates,
  bulkOperations,
  
  // Security permissions
  viewSecurityLogs,
  manageAlerts,
  moderateContent,
}

class PermissionGroup {
  final String name;
  final String description;
  final List<Permission> permissions;

  const PermissionGroup({
    required this.name,
    required this.description,
    required this.permissions,
  });

  static const List<PermissionGroup> defaultGroups = [
    PermissionGroup(
      name: 'Quiz Management',
      description: 'Create, edit, and manage quizzes',
      permissions: [
        Permission.createQuiz,
        Permission.editQuiz,
        Permission.deleteQuiz,
        Permission.viewAllQuizzes,
        Permission.publishQuiz,
        Permission.unpublishQuiz,
      ],
    ),
    PermissionGroup(
      name: 'User Management',
      description: 'Manage users and their permissions',
      permissions: [
        Permission.viewUsers,
        Permission.createUser,
        Permission.editUser,
        Permission.deleteUser,
        Permission.manageUserRoles,
        Permission.viewUserActivity,
      ],
    ),
    PermissionGroup(
      name: 'Analytics & Reporting',
      description: 'View analytics and generate reports',
      permissions: [
        Permission.viewBasicAnalytics,
        Permission.viewAdvancedAnalytics,
        Permission.viewSystemAnalytics,
        Permission.exportData,
      ],
    ),
    PermissionGroup(
      name: 'System Administration',
      description: 'System-level controls and settings',
      permissions: [
        Permission.manageSystem,
        Permission.viewSystemSettings,
        Permission.editSystemSettings,
        Permission.viewLogs,
        Permission.manageMaintenance,
      ],
    ),
  ];
}

class AccessControlService {
  static final AccessControlService _instance = AccessControlService._internal();
  factory AccessControlService() => _instance;
  AccessControlService._internal();

  // Define role-based default permissions
  static const Map<UserRole, Set<Permission>> _defaultRolePermissions = {
    UserRole.regularUser: {
      // Regular users have minimal permissions
      Permission.viewBasicAnalytics,
    },
    
    UserRole.admin: {
      // Admin users have extensive permissions
      Permission.createQuiz,
      Permission.editQuiz,
      Permission.deleteQuiz,
      Permission.viewAllQuizzes,
      Permission.publishQuiz,
      Permission.unpublishQuiz,
      Permission.viewUsers,
      Permission.viewUserActivity,
      Permission.viewAllSessions,
      Permission.manageSessions,
      Permission.viewBasicAnalytics,
      Permission.viewAdvancedAnalytics,
      Permission.exportData,
      Permission.manageCategories,
      Permission.manageTemplates,
      Permission.manageAlerts,
      Permission.moderateContent,
    },
    
    UserRole.superAdmin: {
      // Super admins have all permissions
      ...Permission.values,
    },
  };

  // Check if user has a specific permission
  Future<bool> hasPermission(User user, Permission permission) async {
    // Super admin always has all permissions
    if (user.role == UserRole.superAdmin) {
      return true;
    }

    // Check role-based permissions first
    final rolePermissions = _defaultRolePermissions[user.role] ?? <Permission>{};
    if (rolePermissions.contains(permission)) {
      return true;
    }

    // Check user-specific permissions
    final permissionKey = permission.toString().split('.').last;
    return user.hasPermission(permissionKey);
  }

  // Check if user has all specified permissions
  Future<bool> hasAllPermissions(User user, List<Permission> permissions) async {
    for (final permission in permissions) {
      if (!(await hasPermission(user, permission))) {
        return false;
      }
    }
    return true;
  }

  // Check if user has any of the specified permissions
  Future<bool> hasAnyPermission(User user, List<Permission> permissions) async {
    for (final permission in permissions) {
      if (await hasPermission(user, permission)) {
        return true;
      }
    }
    return false;
  }

  // Grant permission to user
  Future<void> grantPermission(
    User grantor,
    String userId,
    Permission permission,
  ) async {
    if (!(await hasPermission(grantor, Permission.manageUserRoles))) {
      throw Exception('Insufficient permissions to grant permissions');
    }

    final targetUser = await StorageService.getUser(userId);
    if (targetUser == null) {
      throw Exception('User not found');
    }

    // Cannot modify super admin permissions
    if (targetUser.role == UserRole.superAdmin && grantor.role != UserRole.superAdmin) {
      throw Exception('Cannot modify super admin permissions');
    }

    final permissionKey = permission.toString().split('.').last;
    final updatedPermissions = Map<String, dynamic>.from(targetUser.permissions);
    updatedPermissions[permissionKey] = true;

    final updatedUser = targetUser.copyWith(permissions: updatedPermissions);
    await StorageService.saveUser(updatedUser);
  }

  // Revoke permission from user
  Future<void> revokePermission(
    User revoker,
    String userId,
    Permission permission,
  ) async {
    if (!(await hasPermission(revoker, Permission.manageUserRoles))) {
      throw Exception('Insufficient permissions to revoke permissions');
    }

    final targetUser = await StorageService.getUser(userId);
    if (targetUser == null) {
      throw Exception('User not found');
    }

    // Cannot modify super admin permissions
    if (targetUser.role == UserRole.superAdmin && revoker.role != UserRole.superAdmin) {
      throw Exception('Cannot modify super admin permissions');
    }

    final permissionKey = permission.toString().split('.').last;
    final updatedPermissions = Map<String, dynamic>.from(targetUser.permissions);
    updatedPermissions[permissionKey] = false;

    final updatedUser = targetUser.copyWith(permissions: updatedPermissions);
    await StorageService.saveUser(updatedUser);
  }

  // Get all permissions for a user
  Future<Set<Permission>> getUserPermissions(User user) async {
    final permissions = <Permission>{};

    // Add role-based permissions
    final rolePermissions = _defaultRolePermissions[user.role] ?? <Permission>{};
    permissions.addAll(rolePermissions);

    // Add user-specific permissions
    for (final permission in Permission.values) {
      final permissionKey = permission.toString().split('.').last;
      if (user.hasPermission(permissionKey)) {
        permissions.add(permission);
      }
    }

    return permissions;
  }

  // Get permissions grouped by category
  Future<Map<String, List<Permission>>> getGroupedUserPermissions(User user) async {
    final allPermissions = await getUserPermissions(user);
    final grouped = <String, List<Permission>>{};

    for (final group in PermissionGroup.defaultGroups) {
      final groupPermissions = group.permissions
          .where((permission) => allPermissions.contains(permission))
          .toList();
      
      if (groupPermissions.isNotEmpty) {
        grouped[group.name] = groupPermissions;
      }
    }

    return grouped;
  }

  // Validate action with detailed error message
  Future<void> validateAction(User user, Permission permission, {String? context}) async {
    if (!(await hasPermission(user, permission))) {
      final contextMessage = context != null ? ' ($context)' : '';
      throw PermissionException(
        'Access denied: ${_getPermissionDescription(permission)}$contextMessage',
        permission,
        user.role,
      );
    }
  }

  // Validate multiple permissions for complex operations
  Future<void> validateComplexAction(
    User user,
    List<Permission> requiredPermissions,
    {String? context,
    bool requireAll = true}
  ) async {
    if (requireAll) {
      for (final permission in requiredPermissions) {
        if (!(await hasPermission(user, permission))) {
          final contextMessage = context != null ? ' ($context)' : '';
          throw PermissionException(
            'Access denied: ${_getPermissionDescription(permission)}$contextMessage',
            permission,
            user.role,
          );
        }
      }
    } else {
      if (!(await hasAnyPermission(user, requiredPermissions))) {
        final contextMessage = context != null ? ' ($context)' : '';
        final permissionDescriptions = requiredPermissions
            .map((p) => _getPermissionDescription(p))
            .join(' or ');
        throw PermissionException(
          'Access denied: Requires $permissionDescriptions$contextMessage',
          requiredPermissions.first,
          user.role,
        );
      }
    }
  }

  // Check if user can access resource based on ownership and permissions
  Future<bool> canAccessResource(
    User user,
    String resourceOwnerId,
    Permission requiredPermission,
  ) async {
    // Users can always access their own resources
    if (user.id == resourceOwnerId) {
      return true;
    }

    // Otherwise check if they have the required permission
    return await hasPermission(user, requiredPermission);
  }

  // Get filtered permissions based on role hierarchy
  List<Permission> getAvailablePermissions(UserRole granterRole) {
    switch (granterRole) {
      case UserRole.superAdmin:
        return Permission.values;
      case UserRole.admin:
        return Permission.values
            .where((p) => !_isSuperAdminOnlyPermission(p))
            .toList();
      case UserRole.regularUser:
        return []; // Regular users cannot grant permissions
    }
  }

  // Helper methods

  bool _isSuperAdminOnlyPermission(Permission permission) {
    const superAdminOnlyPermissions = [
      Permission.manageSystem,
      Permission.editSystemSettings,
      Permission.manageUserRoles,
      Permission.deleteUser,
      Permission.manageMaintenance,
    ];
    return superAdminOnlyPermissions.contains(permission);
  }

  String _getPermissionDescription(Permission permission) {
    switch (permission) {
      case Permission.createQuiz:
        return 'Create quizzes';
      case Permission.editQuiz:
        return 'Edit quizzes';
      case Permission.deleteQuiz:
        return 'Delete quizzes';
      case Permission.viewAllQuizzes:
        return 'View all quizzes';
      case Permission.publishQuiz:
        return 'Publish quizzes';
      case Permission.unpublishQuiz:
        return 'Unpublish quizzes';
      case Permission.viewUsers:
        return 'View users';
      case Permission.createUser:
        return 'Create users';
      case Permission.editUser:
        return 'Edit users';
      case Permission.deleteUser:
        return 'Delete users';
      case Permission.manageUserRoles:
        return 'Manage user roles';
      case Permission.viewUserActivity:
        return 'View user activity';
      case Permission.viewAllSessions:
        return 'View all sessions';
      case Permission.manageSessions:
        return 'Manage sessions';
      case Permission.forceCompleteSession:
        return 'Force complete sessions';
      case Permission.cancelSession:
        return 'Cancel sessions';
      case Permission.viewBasicAnalytics:
        return 'View basic analytics';
      case Permission.viewAdvancedAnalytics:
        return 'View advanced analytics';
      case Permission.viewSystemAnalytics:
        return 'View system analytics';
      case Permission.exportData:
        return 'Export data';
      case Permission.manageSystem:
        return 'Manage system';
      case Permission.viewSystemSettings:
        return 'View system settings';
      case Permission.editSystemSettings:
        return 'Edit system settings';
      case Permission.viewLogs:
        return 'View logs';
      case Permission.manageMaintenance:
        return 'Manage maintenance';
      case Permission.manageCategories:
        return 'Manage categories';
      case Permission.manageTemplates:
        return 'Manage templates';
      case Permission.bulkOperations:
        return 'Perform bulk operations';
      case Permission.viewSecurityLogs:
        return 'View security logs';
      case Permission.manageAlerts:
        return 'Manage alerts';
      case Permission.moderateContent:
        return 'Moderate content';
    }
  }
}

class PermissionException implements Exception {
  final String message;
  final Permission permission;
  final UserRole userRole;

  PermissionException(this.message, this.permission, this.userRole);

  @override
  String toString() => 'PermissionException: $message';
}