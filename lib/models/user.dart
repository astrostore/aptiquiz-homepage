enum UserRole {
  regularUser,
  admin,
  superAdmin,
}

class User {
  final String id;
  final String name;
  final String email;
  final String? mobile;
  final UserRole role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic> permissions;
  final bool isActive;
  final bool isEmailVerified;
  final String? profileImageUrl;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.mobile,
    required this.role,
    required this.createdAt,
    this.lastLoginAt,
    this.permissions = const {},
    this.isActive = true,
    this.isEmailVerified = false,
    this.profileImageUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        mobile: json['mobile'],
        role: UserRole.values[json['role']],
        createdAt: DateTime.parse(json['createdAt']),
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.parse(json['lastLoginAt'])
            : null,
        permissions: Map<String, dynamic>.from(json['permissions'] ?? {}),
        isActive: json['isActive'] ?? true,
        isEmailVerified: json['isEmailVerified'] ?? false,
        profileImageUrl: json['profileImageUrl'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'mobile': mobile,
        'role': role.index,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'permissions': permissions,
        'isActive': isActive,
        'isEmailVerified': isEmailVerified,
        'profileImageUrl': profileImageUrl,
      };

  String get roleDisplayName {
    switch (role) {
      case UserRole.regularUser:
        return 'User';
      case UserRole.admin:
        return 'Administrator';
      case UserRole.superAdmin:
        return 'Super Administrator';
    }
  }

  bool get canCreateQuizzes => role == UserRole.admin || role == UserRole.superAdmin;
  bool get canManageUsers => role == UserRole.superAdmin;
  bool get canViewAnalytics => role == UserRole.admin || role == UserRole.superAdmin;
  bool get canManageSystem => role == UserRole.superAdmin;
  bool get canDeleteQuizzes => role == UserRole.admin || role == UserRole.superAdmin;
  bool get canModifyQuizSettings => role == UserRole.superAdmin;

  bool hasPermission(String permission) {
    if (role == UserRole.superAdmin) return true;
    return permissions[permission] == true;
  }

  User copyWith({
    String? name,
    String? email,
    String? mobile,
    UserRole? role,
    DateTime? lastLoginAt,
    Map<String, dynamic>? permissions,
    bool? isActive,
    bool? isEmailVerified,
    String? profileImageUrl,
  }) => User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        mobile: mobile ?? this.mobile,
        role: role ?? this.role,
        createdAt: createdAt,
        lastLoginAt: lastLoginAt ?? this.lastLoginAt,
        permissions: permissions ?? this.permissions,
        isActive: isActive ?? this.isActive,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      );
}

class UserSession {
  final String sessionId;
  final User user;
  final DateTime loginTime;
  final DateTime? lastActivity;
  final Map<String, dynamic> sessionData;

  UserSession({
    required this.sessionId,
    required this.user,
    required this.loginTime,
    this.lastActivity,
    this.sessionData = const {},
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        sessionId: json['sessionId'],
        user: User.fromJson(json['user']),
        loginTime: DateTime.parse(json['loginTime']),
        lastActivity: json['lastActivity'] != null
            ? DateTime.parse(json['lastActivity'])
            : null,
        sessionData: Map<String, dynamic>.from(json['sessionData'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'user': user.toJson(),
        'loginTime': loginTime.toIso8601String(),
        'lastActivity': lastActivity?.toIso8601String(),
        'sessionData': sessionData,
      };

  bool get isExpired {
    if (lastActivity == null) return false;
    final now = DateTime.now();
    final difference = now.difference(lastActivity!);
    return difference.inHours > 24; // 24-hour session timeout
  }

  UserSession updateActivity() => UserSession(
        sessionId: sessionId,
        user: user,
        loginTime: loginTime,
        lastActivity: DateTime.now(),
        sessionData: sessionData,
      );
}