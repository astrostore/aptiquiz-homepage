import 'dart:math';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/question.dart';
import 'package:cognispark/models/quiz_result.dart';
import 'package:cognispark/models/test_session.dart';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/services/storage_service.dart';

class QuizAnalytics {
  final String quizId;
  final String quizTitle;
  final int totalAttempts;
  final int completedAttempts;
  final int abandonedAttempts;
  final double averageScore;
  final double averageCompletionTime;
  final double passingRate;
  final Map<String, QuestionAnalytics> questionAnalytics;
  final List<ScoreDistribution> scoreDistribution;
  final Map<String, int> attemptsByUser;

  QuizAnalytics({
    required this.quizId,
    required this.quizTitle,
    required this.totalAttempts,
    required this.completedAttempts,
    required this.abandonedAttempts,
    required this.averageScore,
    required this.averageCompletionTime,
    required this.passingRate,
    required this.questionAnalytics,
    required this.scoreDistribution,
    required this.attemptsByUser,
  });
}

class QuestionAnalytics {
  final String questionId;
  final String questionText;
  final int totalAttempts;
  final int correctAttempts;
  final double accuracy;
  final double averageTimeSpent;
  final Map<String, int> answerDistribution;
  final int skippedCount;

  QuestionAnalytics({
    required this.questionId,
    required this.questionText,
    required this.totalAttempts,
    required this.correctAttempts,
    required this.accuracy,
    required this.averageTimeSpent,
    required this.answerDistribution,
    required this.skippedCount,
  });
}

class ScoreDistribution {
  final String range;
  final int count;
  final double percentage;

  ScoreDistribution({
    required this.range,
    required this.count,
    required this.percentage,
  });
}

class UserAnalytics {
  final String userId;
  final String userName;
  final int totalQuizzesTaken;
  final int totalQuizzesCompleted;
  final double averageScore;
  final double averageCompletionTime;
  final int streakDays;
  final Map<String, int> categoryPerformance;
  final List<PerformanceTrend> performanceTrends;

  UserAnalytics({
    required this.userId,
    required this.userName,
    required this.totalQuizzesTaken,
    required this.totalQuizzesCompleted,
    required this.averageScore,
    required this.averageCompletionTime,
    required this.streakDays,
    required this.categoryPerformance,
    required this.performanceTrends,
  });
}

class PerformanceTrend {
  final DateTime date;
  final double score;
  final int quizzesCompleted;

  PerformanceTrend({
    required this.date,
    required this.score,
    required this.quizzesCompleted,
  });
}

class SystemAnalytics {
  final int totalUsers;
  final int activeUsers;
  final int totalQuizzes;
  final int totalSessions;
  final int completedSessions;
  final double systemUptime;
  final Map<String, int> userRoleDistribution;
  final Map<String, int> quizCategoryDistribution;
  final List<DailyUsageStats> dailyStats;

  SystemAnalytics({
    required this.totalUsers,
    required this.activeUsers,
    required this.totalQuizzes,
    required this.totalSessions,
    required this.completedSessions,
    required this.systemUptime,
    required this.userRoleDistribution,
    required this.quizCategoryDistribution,
    required this.dailyStats,
  });
}

class DailyUsageStats {
  final DateTime date;
  final int activeUsers;
  final int sessionsStarted;
  final int sessionsCompleted;
  final int quizzesCreated;

  DailyUsageStats({
    required this.date,
    required this.activeUsers,
    required this.sessionsStarted,
    required this.sessionsCompleted,
    required this.quizzesCreated,
  });
}

class TestAnalytics {
  static final TestAnalytics _instance = TestAnalytics._internal();
  factory TestAnalytics() => _instance;
  TestAnalytics._internal();

  // Get comprehensive quiz analytics
  Future<QuizAnalytics> getQuizAnalytics(String quizId) async {
    final quiz = await StorageService.getQuiz(quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    final sessions = await StorageService.getAllTestSessions();
    final results = await StorageService.getQuizResults();

    // Filter data for this quiz
    final quizSessions = sessions.where((s) => s.quizId == quizId).toList();
    final quizResults = results.where((r) => r.quizId == quizId).toList();

    // Calculate basic metrics
    final totalAttempts = quizSessions.length;
    final completedAttempts = quizSessions.where((s) => s.isCompleted).length;
    final abandonedAttempts = quizSessions.where((s) => s.status == TestSessionStatus.abandoned).length;

    // Calculate average score
    double averageScore = 0;
    if (quizResults.isNotEmpty) {
      final totalScore = quizResults.fold(0.0, (sum, result) => sum + result.percentage);
      averageScore = totalScore / quizResults.length;
    }

    // Calculate average completion time
    double averageCompletionTime = 0;
    final completedResults = quizResults.where((r) => r.timeTaken.inMinutes > 0).toList();
    if (completedResults.isNotEmpty) {
      final totalTime = completedResults.fold(0, (sum, result) => sum + result.timeTaken.inMinutes);
      averageCompletionTime = totalTime / completedResults.length;
    }

    // Calculate passing rate (assuming 70% is passing)
    final passingResults = quizResults.where((r) => r.percentage >= 70).length;
    final passingRate = quizResults.isNotEmpty ? (passingResults / quizResults.length) * 100 : 0;

    // Generate question analytics
    final questionAnalytics = <String, QuestionAnalytics>{};
    for (final question in quiz.questions) {
      questionAnalytics[question.id] = await _generateQuestionAnalytics(question, quizResults);
    }

    // Generate score distribution
    final scoreDistribution = _generateScoreDistribution(quizResults);

    // Count attempts by user
    final attemptsByUser = <String, int>{};
    for (final session in quizSessions) {
      attemptsByUser[session.userId] = (attemptsByUser[session.userId] ?? 0) + 1;
    }

    return QuizAnalytics(
      quizId: quizId,
      quizTitle: quiz.title,
      totalAttempts: totalAttempts,
      completedAttempts: completedAttempts,
      abandonedAttempts: abandonedAttempts,
      averageScore: averageScore,
      averageCompletionTime: averageCompletionTime,
      passingRate: passingRate.toDouble(),
      questionAnalytics: questionAnalytics,
      scoreDistribution: scoreDistribution,
      attemptsByUser: attemptsByUser,
    );
  }

  // Get user performance analytics
  Future<UserAnalytics> getUserAnalytics(String userId) async {
    final sessions = await StorageService.getAllTestSessions();
    final results = await StorageService.getQuizResults();
    final quizzes = await StorageService.getQuizzes();

    // Filter data for this user
    final userSessions = sessions.where((s) => s.userId == userId).toList();
    final userResults = results.where((r) {
      // Match results to user through sessions
      return userSessions.any((s) => s.quizId == r.quizId);
    }).toList();

    // Calculate basic metrics
    final totalQuizzesTaken = userSessions.length;
    final totalQuizzesCompleted = userSessions.where((s) => s.isCompleted).length;

    // Calculate average score
    double averageScore = 0;
    if (userResults.isNotEmpty) {
      final totalScore = userResults.fold(0.0, (sum, result) => sum + result.percentage);
      averageScore = totalScore / userResults.length;
    }

    // Calculate average completion time
    double averageCompletionTime = 0;
    final completedResults = userResults.where((r) => r.timeTaken.inMinutes > 0).toList();
    if (completedResults.isNotEmpty) {
      final totalTime = completedResults.fold(0, (sum, result) => sum + result.timeTaken.inMinutes);
      averageCompletionTime = totalTime / completedResults.length;
    }

    // Calculate category performance
    final categoryPerformance = <String, int>{};
    for (final result in userResults) {
      final quiz = quizzes.firstWhere((q) => q.id == result.quizId, orElse: () => throw Exception('Quiz not found'));
      categoryPerformance[quiz.categoryId] = (categoryPerformance[quiz.categoryId] ?? 0) + 1;
    }

    // Generate performance trends (last 30 days)
    final performanceTrends = _generatePerformanceTrends(userResults);

    // Calculate streak days (simplified - consecutive days with completed quizzes)
    final streakDays = _calculateStreakDays(userSessions);

    return UserAnalytics(
      userId: userId,
      userName: 'User $userId', // Would come from user service
      totalQuizzesTaken: totalQuizzesTaken,
      totalQuizzesCompleted: totalQuizzesCompleted,
      averageScore: averageScore,
      averageCompletionTime: averageCompletionTime,
      streakDays: streakDays,
      categoryPerformance: categoryPerformance,
      performanceTrends: performanceTrends,
    );
  }

  // Get system-wide analytics
  Future<SystemAnalytics> getSystemAnalytics() async {
    final sessions = await StorageService.getAllTestSessions();
    final quizzes = await StorageService.getQuizzes();
    final users = await StorageService.getAllUsers();

    // Calculate basic metrics
    final totalUsers = users.length;
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final activeUsers = users.where((u) => u.lastLoginAt?.isAfter(last30Days) ?? false).length;

    final totalQuizzes = quizzes.length;
    final totalSessions = sessions.length;
    final completedSessions = sessions.where((s) => s.isCompleted).length;

    // User role distribution
    final userRoleDistribution = <String, int>{};
    for (final user in users) {
      final roleName = user.roleDisplayName;
      userRoleDistribution[roleName] = (userRoleDistribution[roleName] ?? 0) + 1;
    }

    // Quiz category distribution
    final quizCategoryDistribution = <String, int>{};
    for (final quiz in quizzes) {
      quizCategoryDistribution[quiz.categoryId] = (quizCategoryDistribution[quiz.categoryId] ?? 0) + 1;
    }

    // Generate daily stats for last 30 days
    final dailyStats = _generateDailyUsageStats(sessions, quizzes, users);

    return SystemAnalytics(
      totalUsers: totalUsers,
      activeUsers: activeUsers,
      totalQuizzes: totalQuizzes,
      totalSessions: totalSessions,
      completedSessions: completedSessions,
      systemUptime: 99.9, // Would come from system monitoring
      userRoleDistribution: userRoleDistribution,
      quizCategoryDistribution: quizCategoryDistribution,
      dailyStats: dailyStats,
    );
  }

  // Get leaderboard data
  Future<List<UserAnalytics>> getLeaderboard({
    String? categoryId,
    int limit = 10,
    String sortBy = 'averageScore',
  }) async {
    final results = await StorageService.getQuizResults();
    final quizzes = await StorageService.getQuizzes();
    final sessions = await StorageService.getAllTestSessions();

    // Group results by user
    final userResults = <String, List<QuizResult>>{};
    for (final result in results) {
      final quiz = quizzes.firstWhere((q) => q.id == result.quizId, orElse: () => throw Exception('Quiz not found'));
      
      // Filter by category if specified
      if (categoryId != null && quiz.categoryId != categoryId) continue;
      
      userResults.putIfAbsent(result.id, () => []).add(result);
    }

    // Generate analytics for each user
    final userAnalyticsList = <UserAnalytics>[];
    for (final userId in userResults.keys) {
      try {
        final analytics = await getUserAnalytics(userId);
        userAnalyticsList.add(analytics);
      } catch (e) {
        // Skip users with invalid data
        continue;
      }
    }

    // Sort by specified criteria
    userAnalyticsList.sort((a, b) {
      switch (sortBy) {
        case 'averageScore':
          return b.averageScore.compareTo(a.averageScore);
        case 'totalCompleted':
          return b.totalQuizzesCompleted.compareTo(a.totalQuizzesCompleted);
        case 'streakDays':
          return b.streakDays.compareTo(a.streakDays);
        default:
          return b.averageScore.compareTo(a.averageScore);
      }
    });

    return userAnalyticsList.take(limit).toList();
  }

  // Private helper methods

  Future<QuestionAnalytics> _generateQuestionAnalytics(Question question, List<QuizResult> results) async {
    final questionAnswers = <String>[];
    int correctCount = 0;

    for (final result in results) {
      final answer = result.answers.firstWhere(
        (a) => a.questionId == question.id,
        orElse: () => throw Exception('Answer not found'),
      );
      
      questionAnswers.add(answer.userAnswer);
      if (answer.isCorrect) correctCount++;
    }

    final accuracy = questionAnswers.isNotEmpty ? (correctCount / questionAnswers.length) * 100 : 0;

    // Calculate answer distribution
    final answerDistribution = <String, int>{};
    for (final answer in questionAnswers) {
      if (answer.isNotEmpty) {
        answerDistribution[answer] = (answerDistribution[answer] ?? 0) + 1;
      }
    }

    return QuestionAnalytics(
      questionId: question.id,
      questionText: question.text,
      totalAttempts: questionAnswers.length,
      correctAttempts: correctCount,
      accuracy: accuracy.toDouble(),
      averageTimeSpent: 0, // Would need session timing data
      answerDistribution: answerDistribution,
      skippedCount: results.length - questionAnswers.where((a) => a.isNotEmpty).length,
    );
  }

  List<ScoreDistribution> _generateScoreDistribution(List<QuizResult> results) {
    if (results.isEmpty) return [];

    final ranges = ['0-20%', '21-40%', '41-60%', '61-80%', '81-100%'];
    final distribution = <String, int>{};

    for (final result in results) {
      final percentage = result.percentage;
      String range;
      
      if (percentage <= 20) range = '0-20%';
      else if (percentage <= 40) range = '21-40%';
      else if (percentage <= 60) range = '41-60%';
      else if (percentage <= 80) range = '61-80%';
      else range = '81-100%';

      distribution[range] = (distribution[range] ?? 0) + 1;
    }

    return ranges.map((range) {
      final count = distribution[range] ?? 0;
      final percentage = (count / results.length) * 100;
      return ScoreDistribution(
        range: range,
        count: count,
        percentage: percentage,
      );
    }).toList();
  }

  List<PerformanceTrend> _generatePerformanceTrends(List<QuizResult> results) {
    if (results.isEmpty) return [];

    // Group results by date
    final dailyResults = <DateTime, List<QuizResult>>{};
    for (final result in results) {
      final date = DateTime(result.endTime.year, result.endTime.month, result.endTime.day);
      dailyResults.putIfAbsent(date, () => []).add(result);
    }

    // Generate trends for last 30 days
    final trends = <PerformanceTrend>[];
    final now = DateTime.now();
    for (int i = 29; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayResults = dailyResults[date] ?? [];
      
      double averageScore = 0;
      if (dayResults.isNotEmpty) {
        final totalScore = dayResults.fold(0.0, (sum, result) => sum + result.percentage);
        averageScore = totalScore / dayResults.length;
      }

      trends.add(PerformanceTrend(
        date: date,
        score: averageScore,
        quizzesCompleted: dayResults.length,
      ));
    }

    return trends;
  }

  int _calculateStreakDays(List<TestSession> sessions) {
    if (sessions.isEmpty) return 0;

    // Sort sessions by completion date
    final completedSessions = sessions
        .where((s) => s.isCompleted && s.completedAt != null)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    if (completedSessions.isEmpty) return 0;

    // Calculate consecutive days
    int streak = 0;
    DateTime? previousDate;

    for (final session in completedSessions) {
      final currentDate = DateTime(
        session.completedAt!.year,
        session.completedAt!.month,
        session.completedAt!.day,
      );

      if (previousDate == null) {
        streak = 1;
        previousDate = currentDate;
      } else {
        final difference = previousDate.difference(currentDate).inDays;
        if (difference == 1) {
          streak++;
          previousDate = currentDate;
        } else {
          break; // Streak broken
        }
      }
    }

    return streak;
  }

  List<DailyUsageStats> _generateDailyUsageStats(
    List<TestSession> sessions,
    List<Quiz> quizzes,
    List<User> users,
  ) {
    final stats = <DailyUsageStats>[];
    final now = DateTime.now();

    for (int i = 29; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final nextDay = date.add(const Duration(days: 1));

      // Count sessions for this day
      final daySessions = sessions.where((s) =>
          s.createdAt.isAfter(date) && s.createdAt.isBefore(nextDay)).toList();
      
      final sessionsStarted = daySessions.length;
      final sessionsCompleted = daySessions.where((s) => s.isCompleted).length;

      // Count active users (users who had sessions this day)
      final activeUserIds = daySessions.map((s) => s.userId).toSet();
      final activeUsers = activeUserIds.length;

      // Count quizzes created this day
      final quizzesCreated = quizzes.where((q) =>
          q.createdAt.isAfter(date) && q.createdAt.isBefore(nextDay)).length;

      stats.add(DailyUsageStats(
        date: date,
        activeUsers: activeUsers,
        sessionsStarted: sessionsStarted,
        sessionsCompleted: sessionsCompleted,
        quizzesCreated: quizzesCreated,
      ));
    }

    return stats;
  }
}