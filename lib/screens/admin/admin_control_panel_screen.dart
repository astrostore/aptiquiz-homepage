import 'package:flutter/material.dart';
import 'package:cognispark/services/auth_service.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/models/user.dart';

class AdminControlPanelScreen extends StatefulWidget {
  const AdminControlPanelScreen({super.key});

  @override
  State<AdminControlPanelScreen> createState() => _AdminControlPanelScreenState();
}

class _AdminControlPanelScreenState extends State<AdminControlPanelScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<User> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await StorageService.getAllUsers();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = AuthService.instance.currentUser;

    if (currentUser?.role != UserRole.superAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Access Denied'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.block,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only super administrators can access this panel.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control Panel'),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.admin_panel_settings), text: 'Roles'),
            Tab(icon: Icon(Icons.settings), text: 'System'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersTab(theme),
          _buildRolesTab(theme),
          _buildSystemTab(theme),
        ],
      ),
    );
  }

  Widget _buildUsersTab(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_allUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allUsers.length,
      itemBuilder: (context, index) {
        final user = _allUsers[index];
        return _buildUserCard(theme, user);
      },
    );
  }

  Widget _buildUserCard(ThemeData theme, User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getUserRoleColor(user.role, theme),
                ),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      user.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getUserRoleColor(user.role, theme),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  user.roleDisplayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // User details
          Row(
            children: [
              _buildInfoChip(
                theme,
                icon: user.isEmailVerified ? Icons.verified : Icons.warning,
                label: user.isEmailVerified ? 'Verified' : 'Not Verified',
                color: user.isEmailVerified ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                theme,
                icon: user.isActive ? Icons.check_circle : Icons.cancel,
                label: user.isActive ? 'Active' : 'Inactive',
                color: user.isActive ? Colors.green : Colors.red,
              ),
              if (user.mobile != null) ...[
                const SizedBox(width: 8),
                _buildInfoChip(
                  theme,
                  icon: Icons.phone,
                  label: 'Mobile',
                  color: theme.colorScheme.primary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          
          // Action buttons (only for other users)
          if (user.id != AuthService.instance.currentUser?.id)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRoleChangeDialog(user),
                    icon: const Icon(Icons.admin_panel_settings, size: 16),
                    label: const Text('Change Role'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: user.isActive 
                      ? () => _toggleUserStatus(user, false)
                      : () => _toggleUserStatus(user, true),
                  icon: Icon(
                    user.isActive ? Icons.block : Icons.check_circle,
                    size: 16,
                    color: user.isActive ? Colors.red : Colors.green,
                  ),
                  label: Text(user.isActive ? 'Deactivate' : 'Activate'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    foregroundColor: user.isActive ? Colors.red : Colors.green,
                    side: BorderSide(
                      color: user.isActive ? Colors.red : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesTab(ThemeData theme) {
    final roleCounts = <UserRole, int>{};
    for (final role in UserRole.values) {
      roleCounts[role] = _allUsers.where((user) => user.role == role).length;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Role Distribution',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          ...UserRole.values.map((role) {
            final count = roleCounts[role] ?? 0;
            final users = _allUsers.where((user) => user.role == role).toList();
            
            return _buildRoleSection(theme, role, count, users);
          }),
        ],
      ),
    );
  }

  Widget _buildRoleSection(ThemeData theme, UserRole role, int count, List<User> users) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getUserRoleColor(role, theme),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getRoleIcon(role),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getRoleDisplayName(role),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '$count ${count == 1 ? 'user' : 'users'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (users.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...users.map((user) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${user.name} (${user.email})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemTab(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildSystemCard(
            theme,
            icon: Icons.people,
            title: 'Total Users',
            value: '${_allUsers.length}',
            color: theme.colorScheme.primary,
          ),
          _buildSystemCard(
            theme,
            icon: Icons.verified_user,
            title: 'Verified Users',
            value: '${_allUsers.where((user) => user.isEmailVerified).length}',
            color: Colors.green,
          ),
          _buildSystemCard(
            theme,
            icon: Icons.admin_panel_settings,
            title: 'Administrators',
            value: '${_allUsers.where((user) => user.role == UserRole.admin || user.role == UserRole.superAdmin).length}',
            color: Colors.orange,
          ),
          _buildSystemCard(
            theme,
            icon: Icons.block,
            title: 'Inactive Users',
            value: '${_allUsers.where((user) => !user.isActive).length}',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemCard(ThemeData theme, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getUserRoleColor(UserRole role, ThemeData theme) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.red;
      case UserRole.admin:
        return Colors.orange;
      case UserRole.regularUser:
        return theme.colorScheme.primary;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Icons.supervisor_account;
      case UserRole.admin:
        return Icons.admin_panel_settings;
      case UserRole.regularUser:
        return Icons.person;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Administrator';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.regularUser:
        return 'Regular User';
    }
  }

  void _showRoleChangeDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Role for ${user.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.values.map((role) {
            return RadioListTile<UserRole>(
              title: Text(_getRoleDisplayName(role)),
              value: role,
              groupValue: user.role,
              onChanged: (newRole) {
                Navigator.of(context).pop();
                if (newRole != null && newRole != user.role) {
                  _changeUserRole(user, newRole);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeUserRole(User user, UserRole newRole) async {
    try {
      final result = await AuthService.instance.updateUserRole(
        userId: user.id,
        newRole: newRole,
      );

      if (result.success) {
        _showSuccessSnackBar('Role updated successfully');
        _loadUsers(); // Refresh the users list
      } else {
        _showErrorSnackBar(result.error ?? 'Failed to update role');
      }
    } catch (e) {
      _showErrorSnackBar('Error updating role: $e');
    }
  }

  Future<void> _toggleUserStatus(User user, bool activate) async {
    try {
      final updatedUser = user.copyWith(isActive: activate);
      await StorageService.saveUser(updatedUser);
      
      _showSuccessSnackBar(
        activate ? 'User activated successfully' : 'User deactivated successfully'
      );
      _loadUsers(); // Refresh the users list
    } catch (e) {
      _showErrorSnackBar('Error updating user status: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}