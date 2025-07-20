import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/question.dart';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/models/test_session.dart';
import 'package:cognispark/models/category.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/services/test_engine.dart';
import 'package:cognispark/services/test_analytics.dart';
import 'package:cognispark/services/quiz_service.dart';

class QuizTemplate {
  final String id;
  final String name;
  final String description;
  final List<QuestionTemplate> questionTemplates;
  final Map<String, dynamic> defaultSettings;
  final DateTime createdAt;

  QuizTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.questionTemplates,
    required this.defaultSettings,
    required this.createdAt,
  });

  factory QuizTemplate.fromJson(Map<String, dynamic> json) => QuizTemplate(
        id: json['id'],
        name: json['name'],
        description: json['description'],
        questionTemplates: (json['questionTemplates'] as List)
            .map((q) => QuestionTemplate.fromJson(q))
            .toList(),
        defaultSettings: Map<String, dynamic>.from(json['defaultSettings']),
        createdAt: DateTime.parse(json['createdAt']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'questionTemplates': questionTemplates.map((q) => q.toJson()).toList(),
        'defaultSettings': defaultSettings,
        'createdAt': createdAt.toIso8601String(),
      };
}

class QuestionTemplate {
  final String id;
  final QuestionType type;
  final String textTemplate;
  final Map<String, dynamic> parameters;
  final int defaultPoints;

  QuestionTemplate({
    required this.id,
    required this.type,
    required this.textTemplate,
    required this.parameters,
    this.defaultPoints = 1,
  });

  factory QuestionTemplate.fromJson(Map<String, dynamic> json) => QuestionTemplate(
        id: json['id'],
        type: QuestionType.values[json['type']],
        textTemplate: json['textTemplate'],
        parameters: Map<String, dynamic>.from(json['parameters']),
        defaultPoints: json['defaultPoints'] ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'textTemplate': textTemplate,
        'parameters': parameters,
        'defaultPoints': defaultPoints,
      };
}

class SystemSettings {
  final int maxQuizDuration;
  final int defaultSessionTimeout;
  final bool allowPauseGlobally;
  final bool requireUserRegistration;
  final Map<String, dynamic> gradingSettings;
  final Map<String, dynamic> securitySettings;
  final Map<String, dynamic> notificationSettings;

  SystemSettings({
    this.maxQuizDuration = 180, // 3 hours max
    this.defaultSessionTimeout = 1440, // 24 hours
    this.allowPauseGlobally = true,
    this.requireUserRegistration = true,
    this.gradingSettings = const {},
    this.securitySettings = const {},
    this.notificationSettings = const {},
  });

  factory SystemSettings.fromJson(Map<String, dynamic> json) => SystemSettings(
        maxQuizDuration: json['maxQuizDuration'] ?? 180,
        defaultSessionTimeout: json['defaultSessionTimeout'] ?? 1440,
        allowPauseGlobally: json['allowPauseGlobally'] ?? true,
        requireUserRegistration: json['requireUserRegistration'] ?? true,
        gradingSettings: Map<String, dynamic>.from(json['gradingSettings'] ?? {}),
        securitySettings: Map<String, dynamic>.from(json['securitySettings'] ?? {}),
        notificationSettings: Map<String, dynamic>.from(json['notificationSettings'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'maxQuizDuration': maxQuizDuration,
        'defaultSessionTimeout': defaultSessionTimeout,
        'allowPauseGlobally': allowPauseGlobally,
        'requireUserRegistration': requireUserRegistration,
        'gradingSettings': gradingSettings,
        'securitySettings': securitySettings,
        'notificationSettings': notificationSettings,
      };
}

class SuperAdminTestManager {
  static final SuperAdminTestManager _instance = SuperAdminTestManager._internal();
  factory SuperAdminTestManager() => _instance;
  SuperAdminTestManager._internal();

  final TestEngine _testEngine = TestEngine();
  final TestAnalytics _analytics = TestAnalytics();

  // Quiz Management

  Future<Quiz> createAdvancedQuiz({
    required User admin,
    required String title,
    required String description,
    required String categoryId,
    required List<Question> questions,
    int timeLimit = 0,
    bool shuffleQuestions = false,
    bool showCorrectAnswers = true,
    Map<String, dynamic> advancedSettings = const {},
  }) async {
    if (!admin.canCreateQuizzes) {
      throw Exception('Insufficient permissions to create quizzes');
    }

    final quiz = Quiz(
      id: QuizService.generateQuizId(),
      title: title,
      description: description,
      categoryId: categoryId,
      questions: questions,
      timeLimit: timeLimit,
      createdAt: DateTime.now(),
      shuffleQuestions: shuffleQuestions,
      showCorrectAnswers: showCorrectAnswers,
    );

    await StorageService.saveQuiz(quiz);
    await _logAdminAction(admin.id, 'CREATE_QUIZ', {'quizId': quiz.id});
    
    return quiz;
  }

  Future<Quiz> bulkCreateQuestionsFromTemplate({
    required User admin,
    required String quizId,
    required QuizTemplate template,
    required Map<String, dynamic> templateData,
  }) async {
    if (!admin.canCreateQuizzes) {
      throw Exception('Insufficient permissions to modify quizzes');
    }

    final quiz = await StorageService.getQuiz(quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    final newQuestions = <Question>[];
    for (final questionTemplate in template.questionTemplates) {
      final question = _generateQuestionFromTemplate(questionTemplate, templateData);
      newQuestions.add(question);
    }

    final updatedQuiz = quiz.copyWith(
      questions: [...quiz.questions, ...newQuestions],
      updatedAt: DateTime.now(),
    );

    await StorageService.saveQuiz(updatedQuiz);
    await _logAdminAction(admin.id, 'BULK_ADD_QUESTIONS', {
      'quizId': quizId,
      'questionsAdded': newQuestions.length,
    });

    return updatedQuiz;
  }

  Future<void> duplicateQuiz({
    required User admin,
    required String sourceQuizId,
    required String newTitle,
    required String newCategoryId,
  }) async {
    if (!admin.canCreateQuizzes) {
      throw Exception('Insufficient permissions to duplicate quizzes');
    }

    final sourceQuiz = await StorageService.getQuiz(sourceQuizId);
    if (sourceQuiz == null) {
      throw Exception('Source quiz not found');
    }

    final duplicatedQuiz = Quiz(
      id: QuizService.generateQuizId(),
      title: newTitle,
      description: '${sourceQuiz.description} (Copy)',
      categoryId: newCategoryId,
      questions: sourceQuiz.questions.map((q) => _duplicateQuestion(q)).toList(),
      timeLimit: sourceQuiz.timeLimit,
      createdAt: DateTime.now(),
      shuffleQuestions: sourceQuiz.shuffleQuestions,
      showCorrectAnswers: sourceQuiz.showCorrectAnswers,
    );

    await StorageService.saveQuiz(duplicatedQuiz);
    await _logAdminAction(admin.id, 'DUPLICATE_QUIZ', {
      'sourceQuizId': sourceQuizId,
      'newQuizId': duplicatedQuiz.id,
    });
  }

  // User Management

  Future<void> createUser({
    required User admin,
    required String name,
    required String email,
    required UserRole role,
    Map<String, dynamic> permissions = const {},
  }) async {
    if (!admin.canManageUsers) {
      throw Exception('Insufficient permissions to create users');
    }

    final user = User(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      email: email,
      role: role,
      createdAt: DateTime.now(),
      permissions: permissions,
    );

    await StorageService.saveUser(user);
    await _logAdminAction(admin.id, 'CREATE_USER', {
      'userId': user.id,
      'role': role.name,
    });
  }

  Future<void> updateUserRole({
    required User admin,
    required String userId,
    required UserRole newRole,
    Map<String, dynamic>? newPermissions,
  }) async {
    if (!admin.canManageUsers) {
      throw Exception('Insufficient permissions to modify users');
    }

    final user = await StorageService.getUser(userId);
    if (user == null) {
      throw Exception('User not found');
    }

    final updatedUser = user.copyWith(
      role: newRole,
      permissions: newPermissions ?? user.permissions,
    );

    await StorageService.saveUser(updatedUser);
    await _logAdminAction(admin.id, 'UPDATE_USER_ROLE', {
      'userId': userId,
      'oldRole': user.role.name,
      'newRole': newRole.name,
    });
  }

  Future<void> deactivateUser({
    required User admin,
    required String userId,
    String? reason,
  }) async {
    if (!admin.canManageUsers) {
      throw Exception('Insufficient permissions to deactivate users');
    }

    final user = await StorageService.getUser(userId);
    if (user == null) {
      throw Exception('User not found');
    }

    final updatedUser = user.copyWith(isActive: false);
    await StorageService.saveUser(updatedUser);

    // Cancel all active sessions for this user
    await cancelAllUserSessions(admin, userId);

    await _logAdminAction(admin.id, 'DEACTIVATE_USER', {
      'userId': userId,
      'reason': reason,
    });
  }

  // Session Management

  Future<void> cancelAllUserSessions(User admin, String userId) async {
    if (!admin.canManageSystem) {
      throw Exception('Insufficient permissions to manage sessions');
    }

    final sessions = await _testEngine.getActiveSessions(userId: userId);
    
    for (final session in sessions) {
      final abandonedSession = session.abandon();
      await StorageService.saveTestSession(abandonedSession);
    }

    await _logAdminAction(admin.id, 'CANCEL_USER_SESSIONS', {
      'userId': userId,
      'sessionsCancelled': sessions.length,
    });
  }

  Future<void> forceCompleteSession({
    required User admin,
    required String sessionId,
    String? reason,
  }) async {
    if (!admin.canManageSystem) {
      throw Exception('Insufficient permissions to manage sessions');
    }

    final session = await _testEngine.getSession(sessionId);
    if (session == null) {
      throw Exception('Session not found');
    }

    if (session.isCompleted) {
      throw Exception('Session is already completed');
    }

    // Force complete the session
    await _testEngine.completeSession(sessionId);

    await _logAdminAction(admin.id, 'FORCE_COMPLETE_SESSION', {
      'sessionId': sessionId,
      'reason': reason,
    });
  }

  // Category Management

  Future<QuizCategory> createCategory({
    required User admin,
    required String name,
    required String icon,
    required String description,
    String? parentCategoryId,
  }) async {
    if (!admin.canManageSystem) {
      throw Exception('Insufficient permissions to create categories');
    }

    final category = QuizCategory(
      id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      icon: icon,
      description: description,
    );

    await StorageService.saveCategory(category);
    await _logAdminAction(admin.id, 'CREATE_CATEGORY', {
      'categoryId': category.id,
      'name': name,
    });

    return category;
  }

  // Template Management

  Future<QuizTemplate> createQuizTemplate({
    required User admin,
    required String name,
    required String description,
    required List<QuestionTemplate> questionTemplates,
    Map<String, dynamic> defaultSettings = const {},
  }) async {
    if (!admin.canManageSystem) {
      throw Exception('Insufficient permissions to create templates');
    }

    final template = QuizTemplate(
      id: 'template_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      questionTemplates: questionTemplates,
      defaultSettings: defaultSettings,
      createdAt: DateTime.now(),
    );

    await StorageService.saveQuizTemplate(template);
    await _logAdminAction(admin.id, 'CREATE_TEMPLATE', {
      'templateId': template.id,
      'name': name,
    });

    return template;
  }

  Future<List<QuizTemplate>> getQuizTemplates(User admin) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view templates');
    }

    return await StorageService.getQuizTemplates();
  }

  // System Settings

  Future<void> updateSystemSettings({
    required User admin,
    required SystemSettings settings,
  }) async {
    if (!admin.canManageSystem) {
      throw Exception('Insufficient permissions to update system settings');
    }

    await StorageService.saveSystemSettings(settings);
    await _logAdminAction(admin.id, 'UPDATE_SYSTEM_SETTINGS', {
      'maxQuizDuration': settings.maxQuizDuration,
      'defaultSessionTimeout': settings.defaultSessionTimeout,
    });
  }

  Future<SystemSettings> getSystemSettings(User admin) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view system settings');
    }

    return await StorageService.getSystemSettings();
  }

  // Analytics Access

  Future<SystemAnalytics> getSystemAnalytics(User admin) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view system analytics');
    }

    return await _analytics.getSystemAnalytics();
  }

  Future<List<UserAnalytics>> getAllUserAnalytics(User admin) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view user analytics');
    }

    final users = await StorageService.getAllUsers();
    final analyticsList = <UserAnalytics>[];

    for (final user in users) {
      try {
        final analytics = await _analytics.getUserAnalytics(user.id);
        analyticsList.add(analytics);
      } catch (e) {
        // Skip users with no data
        continue;
      }
    }

    return analyticsList;
  }

  // Maintenance Operations

  Future<void> cleanupExpiredSessions(User admin) async {
    if (!admin.canManageSystem) {
      throw Exception('Insufficient permissions to perform maintenance');
    }

    await _testEngine.expireInactiveSessions();
    await _logAdminAction(admin.id, 'CLEANUP_EXPIRED_SESSIONS', {});
  }

  Future<Map<String, dynamic>> getSystemHealth(User admin) async {
    if (!admin.canViewAnalytics) {
      throw Exception('Insufficient permissions to view system health');
    }

    final sessions = await StorageService.getAllTestSessions();
    final activeSessions = sessions.where((s) => s.isActive).length;
    final totalSessions = sessions.length;

    final quizzes = await StorageService.getQuizzes();
    final users = await StorageService.getAllUsers();
    final activeUsers = users.where((u) => u.isActive).length;

    return {
      'activeSessions': activeSessions,
      'totalSessions': totalSessions,
      'totalQuizzes': quizzes.length,
      'activeUsers': activeUsers,
      'totalUsers': users.length,
      'systemUptime': 99.9, // Would come from actual system monitoring
      'memoryUsage': 'Normal', // Would come from system monitoring
      'lastCleanup': DateTime.now().subtract(const Duration(hours: 2)),
    };
  }

  // Private helper methods

  Question _generateQuestionFromTemplate(QuestionTemplate template, Map<String, dynamic> data) {
    final questionId = QuizService.generateQuestionId();
    final questionText = _interpolateTemplate(template.textTemplate, data);

    switch (template.type) {
      case QuestionType.multipleChoice:
        final options = (template.parameters['options'] as List<String>)
            .map((option) => _interpolateTemplate(option, data))
            .toList();
        return MultipleChoiceQuestion(
          id: questionId,
          text: questionText,
          options: options,
          correctAnswerIndex: template.parameters['correctAnswerIndex'] ?? 0,
          points: template.defaultPoints,
        );

      case QuestionType.trueFalse:
        return TrueFalseQuestion(
          id: questionId,
          text: questionText,
          correctAnswer: template.parameters['correctAnswer'] ?? true,
          points: template.defaultPoints,
        );

      case QuestionType.fillInBlank:
        return FillInBlankQuestion(
          id: questionId,
          text: questionText,
          correctAnswer: _interpolateTemplate(template.parameters['correctAnswer'], data),
          caseSensitive: template.parameters['caseSensitive'] ?? false,
          points: template.defaultPoints,
        );

      case QuestionType.shortAnswer:
        final acceptableAnswers = (template.parameters['acceptableAnswers'] as List<String>)
            .map((answer) => _interpolateTemplate(answer, data))
            .toList();
        return ShortAnswerQuestion(
          id: questionId,
          text: questionText,
          acceptableAnswers: acceptableAnswers,
          caseSensitive: template.parameters['caseSensitive'] ?? false,
          points: template.defaultPoints,
        );
    }
  }

  String _interpolateTemplate(String template, Map<String, dynamic> data) {
    String result = template;
    data.forEach((key, value) {
      result = result.replaceAll('{{$key}}', value.toString());
    });
    return result;
  }

  Question _duplicateQuestion(Question original) {
    final newId = QuizService.generateQuestionId();
    
    switch (original.type) {
      case QuestionType.multipleChoice:
        final mcq = original as MultipleChoiceQuestion;
        return MultipleChoiceQuestion(
          id: newId,
          text: mcq.text,
          options: List.from(mcq.options),
          correctAnswerIndex: mcq.correctAnswerIndex,
          points: mcq.points,
        );

      case QuestionType.trueFalse:
        final tf = original as TrueFalseQuestion;
        return TrueFalseQuestion(
          id: newId,
          text: tf.text,
          correctAnswer: tf.correctAnswer,
          points: tf.points,
        );

      case QuestionType.fillInBlank:
        final fib = original as FillInBlankQuestion;
        return FillInBlankQuestion(
          id: newId,
          text: fib.text,
          correctAnswer: fib.correctAnswer,
          caseSensitive: fib.caseSensitive,
          points: fib.points,
        );

      case QuestionType.shortAnswer:
        final sa = original as ShortAnswerQuestion;
        return ShortAnswerQuestion(
          id: newId,
          text: sa.text,
          acceptableAnswers: List.from(sa.acceptableAnswers),
          caseSensitive: sa.caseSensitive,
          points: sa.points,
        );
    }
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
}