import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/quiz_result.dart';
import 'package:cognispark/models/category.dart';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/models/test_session.dart';
import 'package:cognispark/services/super_admin_test_manager.dart';
import 'package:cognispark/services/regular_user_test_interface.dart';
import 'package:cognispark/services/admin_dashboard_service.dart';

class StorageService {
  static const String _quizzesKey = 'quizzes';
  static const String _resultsKey = 'quiz_results';
  static const String _categoriesKey = 'categories';
  static const String _usersKey = 'users';
  static const String _testSessionsKey = 'test_sessions';
  static const String _quizTemplatesKey = 'quiz_templates';
  static const String _studyPlansKey = 'study_plans';
  static const String _achievementsKey = 'achievements';
  static const String _alertsKey = 'alerts';
  static const String _adminLogsKey = 'admin_logs';
  static const String _systemSettingsKey = 'system_settings';
  static const String _currentUserKey = 'current_user';
  static const String _currentUserSessionKey = 'current_user_session';
  static const String _userCredentialsKey = 'user_credentials';

  static Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  // Quiz CRUD operations
  static Future<List<Quiz>> getQuizzes() async {
    final prefs = await _prefs;
    final String? quizzesJson = prefs.getString(_quizzesKey);
    if (quizzesJson == null) return [];
    
    final List<dynamic> quizzesList = json.decode(quizzesJson);
    return quizzesList.map((quiz) => Quiz.fromJson(quiz)).toList();
  }

  static Future<void> saveQuiz(Quiz quiz) async {
    final quizzes = await getQuizzes();
    final existingIndex = quizzes.indexWhere((q) => q.id == quiz.id);
    
    if (existingIndex != -1) {
      quizzes[existingIndex] = quiz;
    } else {
      quizzes.add(quiz);
    }
    
    await _saveQuizzes(quizzes);
  }

  static Future<void> deleteQuiz(String quizId) async {
    final quizzes = await getQuizzes();
    quizzes.removeWhere((quiz) => quiz.id == quizId);
    await _saveQuizzes(quizzes);
  }

  static Future<Quiz?> getQuizById(String quizId) async {
    final quizzes = await getQuizzes();
    try {
      return quizzes.firstWhere((quiz) => quiz.id == quizId);
    } catch (e) {
      return null;
    }
  }

  static Future<Quiz?> getQuiz(String quizId) async {
    return await getQuizById(quizId);
  }

  static Future<void> _saveQuizzes(List<Quiz> quizzes) async {
    final prefs = await _prefs;
    final String quizzesJson = json.encode(
      quizzes.map((quiz) => quiz.toJson()).toList(),
    );
    await prefs.setString(_quizzesKey, quizzesJson);
  }

  // Quiz Results CRUD operations
  static Future<List<QuizResult>> getQuizResults() async {
    final prefs = await _prefs;
    final String? resultsJson = prefs.getString(_resultsKey);
    if (resultsJson == null) return [];
    
    final List<dynamic> resultsList = json.decode(resultsJson);
    return resultsList.map((result) => QuizResult.fromJson(result)).toList();
  }

  static Future<void> saveQuizResult(QuizResult result) async {
    final results = await getQuizResults();
    results.add(result);
    
    final prefs = await _prefs;
    final String resultsJson = json.encode(
      results.map((result) => result.toJson()).toList(),
    );
    await prefs.setString(_resultsKey, resultsJson);
  }

  static Future<List<QuizResult>> getQuizResultsById(String quizId) async {
    final results = await getQuizResults();
    return results.where((result) => result.quizId == quizId).toList();
  }

  // Categories CRUD operations
  static Future<List<QuizCategory>> getCategories() async {
    final prefs = await _prefs;
    final String? categoriesJson = prefs.getString(_categoriesKey);
    
    if (categoriesJson == null) {
      final defaultCategories = QuizCategory.getDefaultCategories();
      await _saveCategories(defaultCategories);
      return defaultCategories;
    }
    
    final List<dynamic> categoriesList = json.decode(categoriesJson);
    return categoriesList.map((category) => QuizCategory.fromJson(category)).toList();
  }

  static Future<void> _saveCategories(List<QuizCategory> categories) async {
    final prefs = await _prefs;
    final String categoriesJson = json.encode(
      categories.map((category) => category.toJson()).toList(),
    );
    await prefs.setString(_categoriesKey, categoriesJson);
  }

  static Future<QuizCategory?> getCategoryById(String categoryId) async {
    final categories = await getCategories();
    try {
      return categories.firstWhere((category) => category.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  // Analytics helpers
  static Future<Map<String, dynamic>> getQuizStatistics() async {
    final results = await getQuizResults();
    
    if (results.isEmpty) {
      return {
        'totalQuizzes': 0,
        'averageScore': 0.0,
        'totalTimePlayed': Duration.zero,
        'bestScore': 0.0,
        'recentActivity': <QuizResult>[],
      };
    }
    
    final totalScore = results.fold(0.0, (sum, result) => sum + result.percentage);
    final totalTime = results.fold(Duration.zero, (sum, result) => sum + result.timeTaken);
    final bestScore = results.fold(0.0, (best, result) => 
        result.percentage > best ? result.percentage : best);
    
    final recentResults = results
      ..sort((a, b) => b.endTime.compareTo(a.endTime));
    
    return {
      'totalQuizzes': results.length,
      'averageScore': totalScore / results.length,
      'totalTimePlayed': totalTime,
      'bestScore': bestScore,
      'recentActivity': recentResults.take(5).toList(),
    };
  }

  // User CRUD operations
  static Future<List<User>> getAllUsers() async {
    final prefs = await _prefs;
    final String? usersJson = prefs.getString(_usersKey);
    if (usersJson == null) return [];
    
    final List<dynamic> usersList = json.decode(usersJson);
    return usersList.map((user) => User.fromJson(user)).toList();
  }

  static Future<void> saveUser(User user) async {
    final users = await getAllUsers();
    final existingIndex = users.indexWhere((u) => u.id == user.id);
    
    if (existingIndex != -1) {
      users[existingIndex] = user;
    } else {
      users.add(user);
    }
    
    await _saveUsers(users);
  }

  static Future<User?> getUser(String userId) async {
    final users = await getAllUsers();
    try {
      return users.firstWhere((user) => user.id == userId);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _saveUsers(List<User> users) async {
    final prefs = await _prefs;
    final String usersJson = json.encode(
      users.map((user) => user.toJson()).toList(),
    );
    await prefs.setString(_usersKey, usersJson);
  }

  // Current user session management
  static Future<void> setCurrentUser(User user) async {
    final prefs = await _prefs;
    await prefs.setString(_currentUserKey, json.encode(user.toJson()));
  }

  static Future<User?> getCurrentUser() async {
    final prefs = await _prefs;
    final String? userJson = prefs.getString(_currentUserKey);
    if (userJson == null) return null;
    
    return User.fromJson(json.decode(userJson));
  }

  static Future<void> clearCurrentUser() async {
    final prefs = await _prefs;
    await prefs.remove(_currentUserKey);
  }

  // Test Session CRUD operations
  static Future<List<TestSession>> getAllTestSessions() async {
    final prefs = await _prefs;
    final String? sessionsJson = prefs.getString(_testSessionsKey);
    if (sessionsJson == null) return [];
    
    final List<dynamic> sessionsList = json.decode(sessionsJson);
    return sessionsList.map((session) => TestSession.fromJson(session)).toList();
  }

  static Future<void> saveTestSession(TestSession session) async {
    final sessions = await getAllTestSessions();
    final existingIndex = sessions.indexWhere((s) => s.sessionId == session.sessionId);
    
    if (existingIndex != -1) {
      sessions[existingIndex] = session;
    } else {
      sessions.add(session);
    }
    
    await _saveTestSessions(sessions);
  }

  static Future<TestSession?> getTestSession(String sessionId) async {
    final sessions = await getAllTestSessions();
    try {
      return sessions.firstWhere((session) => session.sessionId == sessionId);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _saveTestSessions(List<TestSession> sessions) async {
    final prefs = await _prefs;
    final String sessionsJson = json.encode(
      sessions.map((session) => session.toJson()).toList(),
    );
    await prefs.setString(_testSessionsKey, sessionsJson);
  }

  // Quiz Template CRUD operations
  static Future<List<QuizTemplate>> getQuizTemplates() async {
    final prefs = await _prefs;
    final String? templatesJson = prefs.getString(_quizTemplatesKey);
    if (templatesJson == null) return [];
    
    final List<dynamic> templatesList = json.decode(templatesJson);
    return templatesList.map((template) => QuizTemplate.fromJson(template)).toList();
  }

  static Future<void> saveQuizTemplate(QuizTemplate template) async {
    final templates = await getQuizTemplates();
    final existingIndex = templates.indexWhere((t) => t.id == template.id);
    
    if (existingIndex != -1) {
      templates[existingIndex] = template;
    } else {
      templates.add(template);
    }
    
    await _saveQuizTemplates(templates);
  }

  static Future<void> _saveQuizTemplates(List<QuizTemplate> templates) async {
    final prefs = await _prefs;
    final String templatesJson = json.encode(
      templates.map((template) => template.toJson()).toList(),
    );
    await prefs.setString(_quizTemplatesKey, templatesJson);
  }

  // Study Plan CRUD operations
  static Future<List<StudyPlan>> getStudyPlans() async {
    final prefs = await _prefs;
    final String? plansJson = prefs.getString(_studyPlansKey);
    if (plansJson == null) return [];
    
    final List<dynamic> plansList = json.decode(plansJson);
    return plansList.map((plan) => StudyPlan.fromJson(plan)).toList();
  }

  static Future<void> saveStudyPlan(StudyPlan plan) async {
    final plans = await getStudyPlans();
    final existingIndex = plans.indexWhere((p) => p.id == plan.id);
    
    if (existingIndex != -1) {
      plans[existingIndex] = plan;
    } else {
      plans.add(plan);
    }
    
    await _saveStudyPlans(plans);
  }

  static Future<StudyPlan?> getStudyPlan(String planId) async {
    final plans = await getStudyPlans();
    try {
      return plans.firstWhere((plan) => plan.id == planId);
    } catch (e) {
      return null;
    }
  }

  static Future<void> _saveStudyPlans(List<StudyPlan> plans) async {
    final prefs = await _prefs;
    final String plansJson = json.encode(
      plans.map((plan) => plan.toJson()).toList(),
    );
    await prefs.setString(_studyPlansKey, plansJson);
  }

  // Achievement operations
  static Future<List<Achievement>> getUserAchievements(String userId) async {
    final prefs = await _prefs;
    final String? achievementsJson = prefs.getString('${_achievementsKey}_$userId');
    if (achievementsJson == null) return [];
    
    final List<dynamic> achievementsList = json.decode(achievementsJson);
    return achievementsList.map((achievement) => Achievement.fromJson(achievement)).toList();
  }

  static Future<void> saveUserAchievement(String userId, Achievement achievement) async {
    final achievements = await getUserAchievements(userId);
    if (!achievements.any((a) => a.id == achievement.id)) {
      achievements.add(achievement);
      await _saveUserAchievements(userId, achievements);
    }
  }

  static Future<void> _saveUserAchievements(String userId, List<Achievement> achievements) async {
    final prefs = await _prefs;
    final String achievementsJson = json.encode(
      achievements.map((achievement) => achievement.toJson()).toList(),
    );
    await prefs.setString('${_achievementsKey}_$userId', achievementsJson);
  }

  // Alert operations
  static Future<List<AlertInfo>> getActiveAlerts() async {
    final prefs = await _prefs;
    final String? alertsJson = prefs.getString(_alertsKey);
    if (alertsJson == null) return [];
    
    final List<dynamic> alertsList = json.decode(alertsJson);
    final alerts = alertsList.map((alert) => AlertInfo.fromJson(alert)).toList();
    
    // Return only unacknowledged alerts
    return alerts.where((alert) => !alert.acknowledged).toList();
  }

  static Future<void> saveAlert(AlertInfo alert) async {
    final prefs = await _prefs;
    final String? alertsJson = prefs.getString(_alertsKey);
    final List<AlertInfo> alerts;
    
    if (alertsJson == null) {
      alerts = [];
    } else {
      final List<dynamic> alertsList = json.decode(alertsJson);
      alerts = alertsList.map((a) => AlertInfo.fromJson(a)).toList();
    }
    
    final existingIndex = alerts.indexWhere((a) => a.id == alert.id);
    if (existingIndex != -1) {
      alerts[existingIndex] = alert;
    } else {
      alerts.add(alert);
    }
    
    final String updatedAlertsJson = json.encode(
      alerts.map((alert) => alert.toJson()).toList(),
    );
    await prefs.setString(_alertsKey, updatedAlertsJson);
  }

  static Future<AlertInfo?> getAlert(String alertId) async {
    final prefs = await _prefs;
    final String? alertsJson = prefs.getString(_alertsKey);
    if (alertsJson == null) return null;
    
    final List<dynamic> alertsList = json.decode(alertsJson);
    final alerts = alertsList.map((alert) => AlertInfo.fromJson(alert)).toList();
    
    try {
      return alerts.firstWhere((alert) => alert.id == alertId);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteAlert(String alertId) async {
    final prefs = await _prefs;
    final String? alertsJson = prefs.getString(_alertsKey);
    if (alertsJson == null) return;
    
    final List<dynamic> alertsList = json.decode(alertsJson);
    final alerts = alertsList.map((alert) => AlertInfo.fromJson(alert)).toList();
    
    alerts.removeWhere((alert) => alert.id == alertId);
    
    final String updatedAlertsJson = json.encode(
      alerts.map((alert) => alert.toJson()).toList(),
    );
    await prefs.setString(_alertsKey, updatedAlertsJson);
  }

  // Admin Log operations
  static Future<void> saveAdminLog(Map<String, dynamic> log) async {
    final prefs = await _prefs;
    final String? logsJson = prefs.getString(_adminLogsKey);
    final List<Map<String, dynamic>> logs;
    
    if (logsJson == null) {
      logs = [];
    } else {
      final List<dynamic> logsList = json.decode(logsJson);
      logs = logsList.cast<Map<String, dynamic>>();
    }
    
    logs.add(log);
    
    // Keep only last 1000 logs to prevent storage bloat
    if (logs.length > 1000) {
      logs.removeRange(0, logs.length - 1000);
    }
    
    final String updatedLogsJson = json.encode(logs);
    await prefs.setString(_adminLogsKey, updatedLogsJson);
  }

  static Future<List<Map<String, dynamic>>> getAdminLogs({int limit = 100}) async {
    final prefs = await _prefs;
    final String? logsJson = prefs.getString(_adminLogsKey);
    if (logsJson == null) return [];
    
    final List<dynamic> logsList = json.decode(logsJson);
    final logs = logsList.cast<Map<String, dynamic>>();
    
    // Return most recent logs first
    final sortedLogs = logs.reversed.take(limit).toList();
    return sortedLogs;
  }

  // System Settings operations
  static Future<SystemSettings> getSystemSettings() async {
    final prefs = await _prefs;
    final String? settingsJson = prefs.getString(_systemSettingsKey);
    
    if (settingsJson == null) {
      final defaultSettings = SystemSettings();
      await saveSystemSettings(defaultSettings);
      return defaultSettings;
    }
    
    return SystemSettings.fromJson(json.decode(settingsJson));
  }

  static Future<void> saveSystemSettings(SystemSettings settings) async {
    final prefs = await _prefs;
    final String settingsJson = json.encode(settings.toJson());
    await prefs.setString(_systemSettingsKey, settingsJson);
  }

  // Category operations (add to existing)
  static Future<void> saveCategory(QuizCategory category) async {
    final categories = await getCategories();
    final existingIndex = categories.indexWhere((c) => c.id == category.id);
    
    if (existingIndex != -1) {
      categories[existingIndex] = category;
    } else {
      categories.add(category);
    }
    
    await _saveCategories(categories);
  }

  // Initialize default data
  static Future<void> initializeDefaultData() async {
    final currentUser = await getCurrentUser();
    if (currentUser == null) {
      // Create default super admin user
      final defaultAdmin = User(
        id: 'admin_default',
        name: 'System Administrator',
        email: 'admin@cognispark.com',
        role: UserRole.superAdmin,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );
      
      await saveUser(defaultAdmin);
      await setCurrentUser(defaultAdmin);
    }

    // Initialize default categories if not present
    final categories = await getCategories();
    if (categories.isEmpty) {
      final defaultCategories = QuizCategory.getDefaultCategories();
      await _saveCategories(defaultCategories);
    }
  }

  // Authentication and User Session operations
  static Future<User?> getUserByEmail(String email) async {
    final users = await getAllUsers();
    try {
      return users.firstWhere((user) => user.email == email);
    } catch (e) {
      return null;
    }
  }

  static Future<User?> getUserById(String id) async {
    final users = await getAllUsers();
    try {
      return users.firstWhere((user) => user.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveUserCredentials(String email, String password) async {
    final prefs = await _prefs;
    final String? credentialsJson = prefs.getString(_userCredentialsKey);
    Map<String, String> credentials;
    
    if (credentialsJson == null) {
      credentials = {};
    } else {
      credentials = Map<String, String>.from(json.decode(credentialsJson));
    }
    
    credentials[email] = password;
    
    final String updatedCredentialsJson = json.encode(credentials);
    await prefs.setString(_userCredentialsKey, updatedCredentialsJson);
  }

  static Future<String?> getUserPassword(String email) async {
    final prefs = await _prefs;
    final String? credentialsJson = prefs.getString(_userCredentialsKey);
    if (credentialsJson == null) return null;
    
    final Map<String, String> credentials = Map<String, String>.from(json.decode(credentialsJson));
    return credentials[email];
  }

  static Future<void> saveCurrentUserSession(Map<String, dynamic> sessionData) async {
    final prefs = await _prefs;
    final String sessionJson = json.encode(sessionData);
    await prefs.setString(_currentUserSessionKey, sessionJson);
  }

  static Future<Map<String, dynamic>?> getCurrentUserSession() async {
    final prefs = await _prefs;
    final String? sessionJson = prefs.getString(_currentUserSessionKey);
    if (sessionJson == null) return null;
    
    return Map<String, dynamic>.from(json.decode(sessionJson));
  }

  static Future<void> clearCurrentUserSession() async {
    final prefs = await _prefs;
    await prefs.remove(_currentUserSessionKey);
  }

  // Clear all data (for testing/reset)
  static Future<void> clearAllData() async {
    final prefs = await _prefs;
    await prefs.remove(_quizzesKey);
    await prefs.remove(_resultsKey);
    await prefs.remove(_categoriesKey);
    await prefs.remove(_usersKey);
    await prefs.remove(_testSessionsKey);
    await prefs.remove(_quizTemplatesKey);
    await prefs.remove(_studyPlansKey);
    await prefs.remove(_alertsKey);
    await prefs.remove(_adminLogsKey);
    await prefs.remove(_systemSettingsKey);
    await prefs.remove(_currentUserKey);
    await prefs.remove(_currentUserSessionKey);
    await prefs.remove(_userCredentialsKey);
    
    // Clear user-specific achievements
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_achievementsKey)) {
        await prefs.remove(key);
      }
    }
  }
}