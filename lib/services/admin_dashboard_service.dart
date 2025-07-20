import 'dart:async';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/category.dart';
import 'package:cognispark/models/quiz_result.dart';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/models/test_session.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/services/test_engine.dart';
import 'package:cognispark/services/test_analytics.dart';

class DashboardMetrics {
  final int totalActiveUsers;
  final int totalQuizzes;
  final int activeSessions;
  final int completedSessionsToday;
  final double averageCompletionRate;
  final double systemPerformanceScore;
  final List<CategoryStats> topCategories;
  final List<QuizStats> topQuizzes;
  final Map<String, int> hourlyActivity;

  DashboardMetrics({
    required this.totalActiveUsers,
    required this.totalQuizzes,
    required this.activeSessions,
    required this.completedSessionsToday,
    required this.averageCompletionRate,
    required this.systemPerformanceScore,
    required this.topCategories,
    required this.topQuizzes,
    required this.hourlyActivity,
  });
}

class CategoryStats {
  final String categoryId;
  final String categoryName;
  final int totalQuizzes;
  final int totalAttempts;
  final double averageScore;
  final double completionRate;

  CategoryStats({
    required this.categoryId,
    required this.categoryName,
    required this.totalQuizzes,
    required this.totalAttempts,
    required this.averageScore,
    required this.completionRate,
  });
}

class QuizStats {
  final String quizId;
  final String quizTitle;
  final int totalAttempts;
  final int completedAttempts;
  final double averageScore;
  final double averageTime;
  final double difficultyRating;

  QuizStats({
    required this.quizId,
    required this.quizTitle,
    required this.totalAttempts,
    required this.completedAttempts,
    required this.averageScore,
    required this.averageTime,
    required this.difficultyRating,
  });
}

class UserActivitySummary {
  final String userId;
  final String userName;
  final DateTime lastActive;
  final int totalSessions;
  final int completedSessions;
  final double averageScore;
  final List<String> recentQuizzes;
  final bool isOnline;

  UserActivitySummary({
    required this.userId,
    required this.userName,
    required this.lastActive,
    required this.totalSessions,
    required this.completedSessions,
    required this.averageScore,
    required this.recentQuizzes,
    this.isOnline = false,
  });
}

class AlertInfo {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final AlertSeverity severity;
  final Map<String, dynamic> metadata;
  final bool acknowledged;

  AlertInfo({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.severity,
    this.metadata = const {},
    this.acknowledged = false,
  });

  factory AlertInfo.fromJson(Map<String, dynamic> json) => AlertInfo(
        id: json['id'],
        type: AlertType.values[json['type']],
        title: json['title'],
        message: json['message'],
        createdAt: DateTime.parse(json['createdAt']),
        severity: AlertSeverity.values[json['severity']],
        metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
        acknowledged: json['acknowledged'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'title': title,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'severity': severity.index,
        'metadata': metadata,
        'acknowledged': acknowledged,
      };
}

enum AlertType {
  systemPerformance,
  suspiciousActivity,
  highFailureRate,
  userInactivity,
  storageLimit,
  sessionTimeout,
  maintenance,
}

enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

class AdminDashboardService {
  static final AdminDashboardService _instance = AdminDashboardService._internal();
  factory AdminDashboardService() => _instance;
  AdminDashboardService._internal();

  final TestEngine _testEngine = TestEngine();
  final TestAnalytics _analytics = TestAnalytics();
  final StreamController<DashboardMetrics> _metricsController = StreamController.broadcast();
  final StreamController<List<AlertInfo>> _alertsController = StreamController.broadcast();

  Timer? _metricsUpdateTimer;
  Timer? _alertCheckTimer;

  // Initialize dashboard services
  void initialize() {
    _startMetricsUpdater();
    _startAlertMonitoring();
  }

  // Get real-time dashboard metrics
  Future<DashboardMetrics> getDashboardMetrics(User admin) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view dashboard metrics');
    }

    final systemAnalytics = await _analytics.getSystemAnalytics();
    final sessions = await StorageService.getAllTestSessions();
    final quizzes = await StorageService.getQuizzes();
    final results = await StorageService.getQuizResults();
    final categories = await StorageService.getCategories();

    // Calculate active sessions
    final activeSessions = sessions.where((s) => s.isActive).length;

    // Calculate sessions completed today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final completedToday = sessions
        .where((s) => s.isCompleted && 
                     s.completedAt != null && 
                     s.completedAt!.isAfter(startOfDay))
        .length;

    // Calculate completion rate
    final totalSessions = sessions.length;
    final completedSessions = sessions.where((s) => s.isCompleted).length;
    final completionRate = totalSessions > 0 ? (completedSessions / totalSessions) * 100.0 : 0.0;

    // Generate category stats
    final topCategories = await _generateCategoryStats(categories, quizzes, sessions, results);

    // Generate quiz stats
    final topQuizzes = await _generateQuizStats(quizzes, sessions, results);

    // Generate hourly activity
    final hourlyActivity = _generateHourlyActivity(sessions);

    // Calculate system performance score (simplified)
    final performanceScore = _calculateSystemPerformanceScore(
      completionRate,
      systemAnalytics.totalUsers,
      systemAnalytics.activeUsers,
    );

    final metrics = DashboardMetrics(
      totalActiveUsers: systemAnalytics.activeUsers,
      totalQuizzes: systemAnalytics.totalQuizzes,
      activeSessions: activeSessions,
      completedSessionsToday: completedToday,
      averageCompletionRate: completionRate,
      systemPerformanceScore: performanceScore,
      topCategories: topCategories,
      topQuizzes: topQuizzes,
      hourlyActivity: hourlyActivity,
    );

    _metricsController.add(metrics);
    return metrics;
  }

  // Get real-time metrics stream
  Stream<DashboardMetrics> getMetricsStream(User admin) {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view metrics stream');
    }
    return _metricsController.stream;
  }

  // Get user activity summaries
  Future<List<UserActivitySummary>> getUserActivitySummaries(
    User admin, {
    int limit = 20,
    String? searchQuery,
  }) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view user activities');
    }

    final users = await StorageService.getAllUsers();
    final sessions = await StorageService.getAllTestSessions();
    final results = await StorageService.getQuizResults();

    final summaries = <UserActivitySummary>[];

    for (final user in users.take(limit)) {
      // Filter by search query if provided
      if (searchQuery != null && searchQuery.isNotEmpty) {
        if (!user.name.toLowerCase().contains(searchQuery.toLowerCase()) &&
            !user.email.toLowerCase().contains(searchQuery.toLowerCase())) {
          continue;
        }
      }

      final userSessions = sessions.where((s) => s.userId == user.id).toList();
      final completedSessions = userSessions.where((s) => s.isCompleted).toList();
      
      // Get recent quiz titles
      final recentQuizIds = userSessions
          .where((s) => s.completedAt != null &&
                       DateTime.now().difference(s.completedAt!).inDays <= 7)
          .map((s) => s.quizId)
          .take(3)
          .toList();

      final recentQuizTitles = <String>[];
      for (final quizId in recentQuizIds) {
        final quiz = await StorageService.getQuiz(quizId);
        if (quiz != null) {
          recentQuizTitles.add(quiz.title);
        }
      }

      // Calculate average score
      final userResults = results.where((r) => 
          userSessions.any((s) => s.quizId == r.quizId)).toList();
      final averageScore = userResults.isNotEmpty
          ? userResults.fold(0.0, (sum, r) => sum + r.percentage) / userResults.length
          : 0.0;

      // Check if user is online (simplified - within last 5 minutes)
      final isOnline = user.lastLoginAt != null &&
          DateTime.now().difference(user.lastLoginAt!).inMinutes <= 5;

      summaries.add(UserActivitySummary(
        userId: user.id,
        userName: user.name,
        lastActive: user.lastLoginAt ?? user.createdAt,
        totalSessions: userSessions.length,
        completedSessions: completedSessions.length,
        averageScore: averageScore,
        recentQuizzes: recentQuizTitles,
        isOnline: isOnline,
      ));
    }

    // Sort by last active (most recent first)
    summaries.sort((a, b) => b.lastActive.compareTo(a.lastActive));
    
    return summaries;
  }

  // Alert Management

  Future<List<AlertInfo>> getActiveAlerts(User admin) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view alerts');
    }

    return await StorageService.getActiveAlerts();
  }

  Stream<List<AlertInfo>> getAlertsStream(User admin) {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view alerts stream');
    }
    return _alertsController.stream;
  }

  Future<void> acknowledgeAlert(User admin, String alertId) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to acknowledge alerts');
    }

    final alert = await StorageService.getAlert(alertId);
    if (alert == null) {
      throw Exception('Alert not found');
    }

    final acknowledgedAlert = AlertInfo(
      id: alert.id,
      type: alert.type,
      title: alert.title,
      message: alert.message,
      createdAt: alert.createdAt,
      severity: alert.severity,
      metadata: alert.metadata,
      acknowledged: true,
    );

    await StorageService.saveAlert(acknowledgedAlert);
    await _logAdminAction(admin.id, 'ACKNOWLEDGE_ALERT', {'alertId': alertId});
  }

  Future<void> dismissAlert(User admin, String alertId) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to dismiss alerts');
    }

    await StorageService.deleteAlert(alertId);
    await _logAdminAction(admin.id, 'DISMISS_ALERT', {'alertId': alertId});
  }

  // Session Monitoring

  Future<List<TestSession>> getActiveSessions(User admin, {int limit = 50}) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view active sessions');
    }

    final allSessions = await StorageService.getAllTestSessions();
    final activeSessions = allSessions
        .where((s) => s.isActive)
        .take(limit)
        .toList();

    // Sort by last activity (most recent first)
    activeSessions.sort((a, b) => 
        (b.lastActivity ?? b.createdAt).compareTo(a.lastActivity ?? a.createdAt));

    return activeSessions;
  }

  Future<void> monitorSuspiciousActivity(User admin) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to monitor activity');
    }

    final sessions = await StorageService.getAllTestSessions();
    final now = DateTime.now();

    // Check for suspicious patterns
    final userSessionCounts = <String, int>{};
    final recentSessions = sessions.where((s) => 
        now.difference(s.createdAt).inHours <= 24).toList();

    for (final session in recentSessions) {
      userSessionCounts[session.userId] = 
          (userSessionCounts[session.userId] ?? 0) + 1;
    }

    // Alert for users with excessive sessions
    for (final entry in userSessionCounts.entries) {
      if (entry.value > 20) { // More than 20 sessions in 24 hours
        await _createAlert(
          AlertType.suspiciousActivity,
          'Excessive Session Activity',
          'User ${entry.key} has created ${entry.value} sessions in the last 24 hours',
          AlertSeverity.medium,
          {'userId': entry.key, 'sessionCount': entry.value},
        );
      }
    }
  }

  // Report Generation

  Future<Map<String, dynamic>> generateActivityReport(
    User admin, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to generate reports');
    }

    final sessions = await StorageService.getAllTestSessions();
    final results = await StorageService.getQuizResults();
    final users = await StorageService.getAllUsers();

    // Filter data by date range
    final periodSessions = sessions.where((s) =>
        s.createdAt.isAfter(startDate) && s.createdAt.isBefore(endDate)).toList();
    
    final periodResults = results.where((r) =>
        r.endTime.isAfter(startDate) && r.endTime.isBefore(endDate)).toList();

    // Calculate metrics
    final totalSessions = periodSessions.length;
    final completedSessions = periodSessions.where((s) => s.isCompleted).length;
    final abandonedSessions = periodSessions.where((s) => 
        s.status == TestSessionStatus.abandoned).length;

    final averageScore = periodResults.isNotEmpty
        ? periodResults.fold(0.0, (sum, r) => sum + r.percentage) / periodResults.length
        : 0.0;

    final uniqueUsers = periodSessions.map((s) => s.userId).toSet().length;

    return {
      'reportGenerated': DateTime.now().toIso8601String(),
      'period': {
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'days': endDate.difference(startDate).inDays,
      },
      'summary': {
        'totalSessions': totalSessions,
        'completedSessions': completedSessions,
        'abandonedSessions': abandonedSessions,
        'completionRate': totalSessions > 0 ? (completedSessions / totalSessions) * 100 : 0,
        'averageScore': averageScore,
        'uniqueUsers': uniqueUsers,
      },
      'dailyBreakdown': _generateDailyBreakdown(periodSessions, startDate, endDate),
    };
  }

  // Private helper methods

  void _startMetricsUpdater() {
    _metricsUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      // This would be called by a background service in a real implementation
      // For now, we'll update when explicitly requested
    });
  }

  void _startAlertMonitoring() {
    _alertCheckTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      // Check for various alert conditions
      await _checkSystemHealth();
      await _checkSessionTimeouts();
      await _checkHighFailureRates();
    });
  }

  Future<void> _checkSystemHealth() async {
    // Simplified health check
    final sessions = await StorageService.getAllTestSessions();
    final activeSessions = sessions.where((s) => s.isActive).length;
    
    if (activeSessions > 1000) { // Threshold for high load
      await _createAlert(
        AlertType.systemPerformance,
        'High System Load',
        'System has $activeSessions active sessions',
        AlertSeverity.medium,
        {'activeSessionCount': activeSessions},
      );
    }
  }

  Future<void> _checkSessionTimeouts() async {
    final sessions = await StorageService.getAllTestSessions();
    final now = DateTime.now();
    
    final expiredSessions = sessions.where((s) =>
        s.isActive && 
        s.lastActivity != null &&
        now.difference(s.lastActivity!).inHours > 2).length;

    if (expiredSessions > 0) {
      await _createAlert(
        AlertType.sessionTimeout,
        'Expired Sessions Detected',
        '$expiredSessions sessions have been inactive for over 2 hours',
        AlertSeverity.low,
        {'expiredSessionCount': expiredSessions},
      );
    }
  }

  Future<void> _checkHighFailureRates() async {
    final sessions = await StorageService.getAllTestSessions();
    final recentSessions = sessions.where((s) =>
        DateTime.now().difference(s.createdAt).inHours <= 24).toList();

    if (recentSessions.isNotEmpty) {
      final abandonedCount = recentSessions.where((s) => 
          s.status == TestSessionStatus.abandoned).length;
      final failureRate = (abandonedCount / recentSessions.length) * 100;

      if (failureRate > 25) { // More than 25% failure rate
        await _createAlert(
          AlertType.highFailureRate,
          'High Quiz Failure Rate',
          'Quiz failure rate is ${failureRate.toStringAsFixed(1)}% in the last 24 hours',
          AlertSeverity.high,
          {'failureRate': failureRate, 'abandonedCount': abandonedCount},
        );
      }
    }
  }

  Future<void> _createAlert(
    AlertType type,
    String title,
    String message,
    AlertSeverity severity,
    Map<String, dynamic> metadata,
  ) async {
    final alert = AlertInfo(
      id: 'alert_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      title: title,
      message: message,
      createdAt: DateTime.now(),
      severity: severity,
      metadata: metadata,
    );

    await StorageService.saveAlert(alert);
    
    // Update alerts stream
    final activeAlerts = await StorageService.getActiveAlerts();
    _alertsController.add(activeAlerts);
  }

  Future<List<CategoryStats>> _generateCategoryStats(
    List<QuizCategory> categories,
    List<Quiz> quizzes,
    List<TestSession> sessions,
    List<QuizResult> results,
  ) async {
    final categoryStats = <CategoryStats>[];

    for (final category in categories.take(5)) {
      final categoryQuizzes = quizzes.where((q) => q.categoryId == category.id).toList();
      final categoryQuizIds = categoryQuizzes.map((q) => q.id).toSet();
      
      final categorySessions = sessions.where((s) => categoryQuizIds.contains(s.quizId)).toList();
      final categoryResults = results.where((r) => categoryQuizIds.contains(r.quizId)).toList();
      
      final completedSessions = categorySessions.where((s) => s.isCompleted).length;
      final completionRate = categorySessions.isNotEmpty 
          ? (completedSessions / categorySessions.length) * 100 
          : 0.0;
      
      final averageScore = categoryResults.isNotEmpty
          ? categoryResults.fold(0.0, (sum, r) => sum + r.percentage) / categoryResults.length
          : 0.0;

      categoryStats.add(CategoryStats(
        categoryId: category.id,
        categoryName: category.name,
        totalQuizzes: categoryQuizzes.length,
        totalAttempts: categorySessions.length,
        averageScore: averageScore,
        completionRate: completionRate,
      ));
    }

    // Sort by total attempts (descending)
    categoryStats.sort((a, b) => b.totalAttempts.compareTo(a.totalAttempts));
    return categoryStats;
  }

  Future<List<QuizStats>> _generateQuizStats(
    List<Quiz> quizzes,
    List<TestSession> sessions,
    List<QuizResult> results,
  ) async {
    final quizStats = <QuizStats>[];

    for (final quiz in quizzes.take(5)) {
      final quizSessions = sessions.where((s) => s.quizId == quiz.id).toList();
      final quizResults = results.where((r) => r.quizId == quiz.id).toList();
      
      final completedAttempts = quizSessions.where((s) => s.isCompleted).length;
      final averageScore = quizResults.isNotEmpty
          ? quizResults.fold(0.0, (sum, r) => sum + r.percentage) / quizResults.length
          : 0.0;
      
      final averageTime = quizResults.isNotEmpty
          ? quizResults.fold(0.0, (sum, r) => sum + r.timeTaken.inMinutes) / quizResults.length
          : 0.0;

      // Calculate difficulty rating based on average score (inverted)
      final difficultyRating = averageScore > 0 ? (100 - averageScore) : 50.0;

      quizStats.add(QuizStats(
        quizId: quiz.id,
        quizTitle: quiz.title,
        totalAttempts: quizSessions.length,
        completedAttempts: completedAttempts,
        averageScore: averageScore,
        averageTime: averageTime,
        difficultyRating: difficultyRating,
      ));
    }

    // Sort by total attempts (descending)
    quizStats.sort((a, b) => b.totalAttempts.compareTo(a.totalAttempts));
    return quizStats;
  }

  Map<String, int> _generateHourlyActivity(List<TestSession> sessions) {
    final hourlyActivity = <String, int>{};
    
    for (int hour = 0; hour < 24; hour++) {
      hourlyActivity[hour.toString().padLeft(2, '0')] = 0;
    }

    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    final todaySessions = sessions.where((s) =>
        s.createdAt.isAfter(startOfDay)).toList();

    for (final session in todaySessions) {
      final hour = session.createdAt.hour.toString().padLeft(2, '0');
      hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + 1;
    }

    return hourlyActivity;
  }

  double _calculateSystemPerformanceScore(
    double completionRate,
    int totalUsers,
    int activeUsers,
  ) {
    // Simplified performance score calculation
    double score = 0.0;
    
    // Completion rate factor (0-40 points)
    score += (completionRate / 100) * 40;
    
    // User engagement factor (0-30 points)
    final engagementRate = totalUsers > 0 ? (activeUsers / totalUsers) * 100.0 : 0.0;
    score += (engagementRate / 100) * 30;
    
    // System stability factor (0-30 points) - simplified
    score += 25; // Assume good stability for now
    
    return score.clamp(0, 100);
  }

  List<Map<String, dynamic>> _generateDailyBreakdown(
    List<TestSession> sessions,
    DateTime startDate,
    DateTime endDate,
  ) {
    final dailyData = <Map<String, dynamic>>[];
    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      final nextDay = current.add(const Duration(days: 1));
      
      final daySessions = sessions.where((s) =>
          s.createdAt.isAfter(current) && s.createdAt.isBefore(nextDay)).toList();
      
      final completed = daySessions.where((s) => s.isCompleted).length;
      final abandoned = daySessions.where((s) => 
          s.status == TestSessionStatus.abandoned).length;
      
      dailyData.add({
        'date': current.toIso8601String().split('T')[0],
        'totalSessions': daySessions.length,
        'completedSessions': completed,
        'abandonedSessions': abandoned,
        'uniqueUsers': daySessions.map((s) => s.userId).toSet().length,
      });
      
      current = current.add(const Duration(days: 1));
    }

    return dailyData;
  }

  Future<void> _logAdminAction(String adminId, String action, Map<String, dynamic> details) async {
    final log = {
      'adminId': adminId,
      'action': action,
      'details': details,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await StorageService.saveAdminLog(log);
  }

  // Cleanup resources
  void dispose() {
    _metricsUpdateTimer?.cancel();
    _alertCheckTimer?.cancel();
    _metricsController.close();
    _alertsController.close();
  }
}