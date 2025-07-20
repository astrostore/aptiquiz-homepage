import 'dart:async';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/quiz_result.dart';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/models/test_session.dart';
import 'package:cognispark/models/category.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/services/test_engine.dart';
import 'package:cognispark/services/test_analytics.dart';

class QuizRecommendation {
  final Quiz quiz;
  final double matchScore;
  final String reason;
  final Map<String, dynamic> metadata;

  QuizRecommendation({
    required this.quiz,
    required this.matchScore,
    required this.reason,
    this.metadata = const {},
  });
}

class UserProgress {
  final String userId;
  final int totalQuizzesCompleted;
  final int totalQuizzesAttempted;
  final double averageScore;
  final int currentStreak;
  final Map<String, int> categoryProgress;
  final List<QuizResult> recentResults;
  final DateTime lastActivity;

  UserProgress({
    required this.userId,
    required this.totalQuizzesCompleted,
    required this.totalQuizzesAttempted,
    required this.averageScore,
    required this.currentStreak,
    required this.categoryProgress,
    required this.recentResults,
    required this.lastActivity,
  });
}

class StudyPlan {
  final String id;
  final String userId;
  final String name;
  final List<String> quizIds;
  final DateTime createdAt;
  final DateTime? targetCompletionDate;
  final Map<String, dynamic> settings;
  final double progress;

  StudyPlan({
    required this.id,
    required this.userId,
    required this.name,
    required this.quizIds,
    required this.createdAt,
    this.targetCompletionDate,
    this.settings = const {},
    this.progress = 0.0,
  });

  factory StudyPlan.fromJson(Map<String, dynamic> json) => StudyPlan(
        id: json['id'],
        userId: json['userId'],
        name: json['name'],
        quizIds: List<String>.from(json['quizIds']),
        createdAt: DateTime.parse(json['createdAt']),
        targetCompletionDate: json['targetCompletionDate'] != null
            ? DateTime.parse(json['targetCompletionDate'])
            : null,
        settings: Map<String, dynamic>.from(json['settings'] ?? {}),
        progress: json['progress'] ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'quizIds': quizIds,
        'createdAt': createdAt.toIso8601String(),
        'targetCompletionDate': targetCompletionDate?.toIso8601String(),
        'settings': settings,
        'progress': progress,
      };
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String iconPath;
  final DateTime unlockedAt;
  final Map<String, dynamic> criteria;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.unlockedAt,
    this.criteria = const {},
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        iconPath: json['iconPath'],
        unlockedAt: DateTime.parse(json['unlockedAt']),
        criteria: Map<String, dynamic>.from(json['criteria'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'iconPath': iconPath,
        'unlockedAt': unlockedAt.toIso8601String(),
        'criteria': criteria,
      };
}

class RegularUserTestInterface {
  static final RegularUserTestInterface _instance = RegularUserTestInterface._internal();
  factory RegularUserTestInterface() => _instance;
  RegularUserTestInterface._internal();

  final TestEngine _testEngine = TestEngine();
  final TestAnalytics _analytics = TestAnalytics();

  // Quiz Discovery and Selection

  Future<List<Quiz>> getAvailableQuizzes({
    String? categoryId,
    String? searchQuery,
    String sortBy = 'title',
    bool sortAscending = true,
  }) async {
    final allQuizzes = await StorageService.getQuizzes();
    
    // Filter by category if specified
    List<Quiz> filteredQuizzes = categoryId != null
        ? allQuizzes.where((quiz) => quiz.categoryId == categoryId).toList()
        : allQuizzes;

    // Filter by search query if specified
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filteredQuizzes = filteredQuizzes.where((quiz) =>
          quiz.title.toLowerCase().contains(query) ||
          quiz.description.toLowerCase().contains(query)
      ).toList();
    }

    // Sort quizzes
    filteredQuizzes.sort((a, b) {
      int comparison;
      switch (sortBy) {
        case 'title':
          comparison = a.title.compareTo(b.title);
          break;
        case 'createdAt':
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case 'questionCount':
          comparison = a.questionCount.compareTo(b.questionCount);
          break;
        case 'timeLimit':
          comparison = a.timeLimit.compareTo(b.timeLimit);
          break;
        default:
          comparison = a.title.compareTo(b.title);
      }
      return sortAscending ? comparison : -comparison;
    });

    return filteredQuizzes;
  }

  Future<List<QuizRecommendation>> getRecommendedQuizzes(User user, {int limit = 5}) async {
    final allQuizzes = await StorageService.getQuizzes();
    final userAnalytics = await _analytics.getUserAnalytics(user.id);
    final recommendations = <QuizRecommendation>[];

    for (final quiz in allQuizzes) {
      final score = await _calculateRecommendationScore(quiz, user, userAnalytics);
      final reason = _getRecommendationReason(quiz, user, userAnalytics, score);
      
      recommendations.add(QuizRecommendation(
        quiz: quiz,
        matchScore: score,
        reason: reason,
      ));
    }

    // Sort by match score and return top recommendations
    recommendations.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return recommendations.take(limit).toList();
  }

  Future<List<QuizCategory>> getCategories() async {
    return await StorageService.getCategories();
  }

  // Test Session Management

  Future<TestSession> startNewQuiz(User user, Quiz quiz) async {
    // Check if user has any incomplete sessions for this quiz
    final existingSessions = await _testEngine.getActiveSessions(userId: user.id);
    for (final session in existingSessions) {
      if (session.quizId == quiz.id && session.isActive) {
        // Return existing session if found
        return session;
      }
    }

    // Create and start new session
    final session = await _testEngine.createSession(
      user: user,
      quiz: quiz,
      config: const TestEngineConfig(
        allowPause: true,
        allowReview: false, // Regular users can't review during test
        showProgressBar: true,
        autoSave: true,
      ),
    );

    return await _testEngine.startSession(session.sessionId);
  }

  Future<TestSession> resumeQuiz(User user, String sessionId) async {
    final session = await _testEngine.getSession(sessionId);
    if (session == null) {
      throw Exception('Session not found');
    }

    if (session.userId != user.id) {
      throw Exception('Access denied');
    }

    return await _testEngine.resumeSession(sessionId);
  }

  Future<TestSession> pauseQuiz(String sessionId) async {
    return await _testEngine.pauseSession(sessionId);
  }

  Future<TestSession> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answer,
  }) async {
    return await _testEngine.submitAnswer(
      sessionId: sessionId,
      questionId: questionId,
      answer: answer,
    );
  }

  Future<TestSession> nextQuestion(String sessionId) async {
    return await _testEngine.nextQuestion(sessionId);
  }

  Future<TestSession> previousQuestion(String sessionId) async {
    return await _testEngine.previousQuestion(sessionId);
  }

  Future<QuizResult> completeQuiz(String sessionId) async {
    return await _testEngine.completeSession(sessionId);
  }

  Stream<TestSession> getSessionUpdates(String sessionId) {
    return _testEngine.getSessionStream(sessionId);
  }

  // Progress Tracking

  Future<UserProgress> getUserProgress(User user) async {
    final sessions = await StorageService.getAllTestSessions();
    final results = await StorageService.getQuizResults();
    final userAnalytics = await _analytics.getUserAnalytics(user.id);

    // Get user's sessions and results
    final userSessions = sessions.where((s) => s.userId == user.id).toList();
    final completedSessions = userSessions.where((s) => s.isCompleted).toList();

    // Get recent results (last 10)
    final recentResults = results
        .where((r) => userSessions.any((s) => s.quizId == r.quizId))
        .take(10)
        .toList();

    return UserProgress(
      userId: user.id,
      totalQuizzesCompleted: userAnalytics.totalQuizzesCompleted,
      totalQuizzesAttempted: userAnalytics.totalQuizzesTaken,
      averageScore: userAnalytics.averageScore,
      currentStreak: userAnalytics.streakDays,
      categoryProgress: userAnalytics.categoryPerformance,
      recentResults: recentResults,
      lastActivity: userSessions.isNotEmpty 
          ? userSessions.map((s) => s.lastActivity ?? s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b)
          : DateTime.now(),
    );
  }

  Future<List<TestSession>> getActiveQuizzes(User user) async {
    return await _testEngine.getActiveSessions(userId: user.id);
  }

  Future<List<QuizResult>> getQuizHistory(User user, {int limit = 20}) async {
    final sessions = await StorageService.getAllTestSessions();
    final results = await StorageService.getQuizResults();

    // Get user's quiz results
    final userSessions = sessions.where((s) => s.userId == user.id).toList();
    final userResults = results
        .where((r) => userSessions.any((s) => s.quizId == r.quizId))
        .toList();

    // Sort by completion time (most recent first)
    userResults.sort((a, b) => b.endTime.compareTo(a.endTime));

    return userResults.take(limit).toList();
  }

  // Study Plans

  Future<StudyPlan> createStudyPlan({
    required User user,
    required String name,
    required List<String> quizIds,
    DateTime? targetCompletionDate,
    Map<String, dynamic> settings = const {},
  }) async {
    final studyPlan = StudyPlan(
      id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      name: name,
      quizIds: quizIds,
      createdAt: DateTime.now(),
      targetCompletionDate: targetCompletionDate,
      settings: settings,
    );

    await StorageService.saveStudyPlan(studyPlan);
    return studyPlan;
  }

  Future<List<StudyPlan>> getUserStudyPlans(User user) async {
    final allPlans = await StorageService.getStudyPlans();
    return allPlans.where((plan) => plan.userId == user.id).toList();
  }

  Future<StudyPlan> updateStudyPlanProgress(String planId, double progress) async {
    final plan = await StorageService.getStudyPlan(planId);
    if (plan == null) {
      throw Exception('Study plan not found');
    }

    final updatedPlan = StudyPlan(
      id: plan.id,
      userId: plan.userId,
      name: plan.name,
      quizIds: plan.quizIds,
      createdAt: plan.createdAt,
      targetCompletionDate: plan.targetCompletionDate,
      settings: plan.settings,
      progress: progress.clamp(0.0, 100.0),
    );

    await StorageService.saveStudyPlan(updatedPlan);
    return updatedPlan;
  }

  // Achievements

  Future<List<Achievement>> getUserAchievements(User user) async {
    final achievements = await StorageService.getUserAchievements(user.id);
    return achievements;
  }

  Future<List<Achievement>> checkForNewAchievements(User user) async {
    final userProgress = await getUserProgress(user);
    final existingAchievements = await getUserAchievements(user);
    final existingIds = existingAchievements.map((a) => a.id).toSet();
    
    final newAchievements = <Achievement>[];

    // Check for various achievements
    if (!existingIds.contains('first_quiz') && userProgress.totalQuizzesCompleted >= 1) {
      newAchievements.add(_createAchievement('first_quiz', 'First Quiz Completed', 'Completed your first quiz!'));
    }

    if (!existingIds.contains('quiz_master') && userProgress.totalQuizzesCompleted >= 10) {
      newAchievements.add(_createAchievement('quiz_master', 'Quiz Master', 'Completed 10 quizzes!'));
    }

    if (!existingIds.contains('high_scorer') && userProgress.averageScore >= 90) {
      newAchievements.add(_createAchievement('high_scorer', 'High Scorer', 'Achieved 90% average score!'));
    }

    if (!existingIds.contains('streak_5') && userProgress.currentStreak >= 5) {
      newAchievements.add(_createAchievement('streak_5', 'Five Day Streak', 'Completed quizzes for 5 consecutive days!'));
    }

    // Save new achievements
    for (final achievement in newAchievements) {
      await StorageService.saveUserAchievement(user.id, achievement);
    }

    return newAchievements;
  }

  // Leaderboards

  Future<List<UserAnalytics>> getLeaderboard({
    String? categoryId,
    String sortBy = 'averageScore',
    int limit = 10,
  }) async {
    return await _analytics.getLeaderboard(
      categoryId: categoryId,
      sortBy: sortBy,
      limit: limit,
    );
  }

  Future<int> getUserRank(User user, {String? categoryId}) async {
    final leaderboard = await getLeaderboard(
      categoryId: categoryId,
      limit: 1000, // Get large list for accurate ranking
    );
    
    for (int i = 0; i < leaderboard.length; i++) {
      if (leaderboard[i].userId == user.id) {
        return i + 1; // 1-based ranking
      }
    }
    
    return -1; // Not found in leaderboard
  }

  // Private helper methods

  Future<double> _calculateRecommendationScore(Quiz quiz, User user, UserAnalytics userAnalytics) async {
    double score = 0.0;

    // Category preference (based on user's category performance)
    final categoryPerformance = userAnalytics.categoryPerformance[quiz.categoryId] ?? 0;
    score += (categoryPerformance / userAnalytics.totalQuizzesCompleted) * 30;

    // Difficulty match (based on user's average score)
    if (userAnalytics.averageScore >= 80) {
      // Advanced user - prefer harder quizzes
      score += quiz.questionCount > 10 ? 20 : 10;
    } else if (userAnalytics.averageScore >= 60) {
      // Intermediate user - prefer medium quizzes
      score += quiz.questionCount >= 5 && quiz.questionCount <= 15 ? 20 : 10;
    } else {
      // Beginner user - prefer easier quizzes
      score += quiz.questionCount <= 10 ? 20 : 10;
    }

    // Time preference (based on average completion time)
    if (userAnalytics.averageCompletionTime > 0) {
      final timePreference = userAnalytics.averageCompletionTime;
      if (quiz.timeLimit > 0) {
        final timeDiff = (quiz.timeLimit - timePreference).abs();
        score += (20 - timeDiff).clamp(0, 20);
      } else {
        score += 15; // No time limit might be preferred
      }
    }

    // Recency factor (newer quizzes get slight boost)
    final daysSinceCreated = DateTime.now().difference(quiz.createdAt).inDays;
    if (daysSinceCreated <= 7) score += 10;
    else if (daysSinceCreated <= 30) score += 5;

    // Avoid recently completed quizzes
    final recentResults = await StorageService.getQuizResults();
    final recentQuizIds = recentResults
        .where((r) => DateTime.now().difference(r.endTime).inDays <= 7)
        .map((r) => r.quizId)
        .toSet();
    
    if (recentQuizIds.contains(quiz.id)) {
      score -= 15;
    }

    return score.clamp(0, 100);
  }

  String _getRecommendationReason(Quiz quiz, User user, UserAnalytics userAnalytics, double score) {
    if (score >= 80) return 'Perfect match for your interests and skill level';
    if (score >= 60) return 'Good fit based on your quiz history';
    if (score >= 40) return 'You might enjoy this topic';
    if (score >= 20) return 'Try something new';
    return 'Explore a different category';
  }

  Achievement _createAchievement(String id, String name, String description) {
    return Achievement(
      id: id,
      name: name,
      description: description,
      iconPath: 'assets/achievements/$id.png',
      unlockedAt: DateTime.now(),
    );
  }
}