import 'dart:async';
import 'dart:math';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/question.dart';
import 'package:cognispark/models/quiz_result.dart';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/models/test_session.dart';
import 'package:cognispark/services/storage_service.dart';

class TestEngineConfig {
  final bool allowPause;
  final bool allowReview;
  final bool shuffleQuestions;
  final bool shuffleOptions;
  final bool showProgressBar;
  final bool autoSave;
  final Duration autoSaveInterval;
  final bool strictTimeLimit;
  final bool showCorrectAnswersInReview;

  const TestEngineConfig({
    this.allowPause = true,
    this.allowReview = true,
    this.shuffleQuestions = false,
    this.shuffleOptions = false,
    this.showProgressBar = true,
    this.autoSave = true,
    this.autoSaveInterval = const Duration(seconds: 30),
    this.strictTimeLimit = false,
    this.showCorrectAnswersInReview = true,
  });
}

class TestEngine {
  static final TestEngine _instance = TestEngine._internal();
  factory TestEngine() => _instance;
  TestEngine._internal();

  final Map<String, TestSession> _activeSessions = {};
  final Map<String, Timer> _autoSaveTimers = {};
  final Map<String, StreamController<TestSession>> _sessionControllers = {};

  // Create a new test session
  Future<TestSession> createSession({
    required User user,
    required Quiz quiz,
    TestEngineConfig config = const TestEngineConfig(),
  }) async {
    final sessionId = _generateSessionId();
    
    // Check if user already has an active session for this quiz
    final existingSessions = await getActiveSessions(userId: user.id);
    for (final session in existingSessions) {
      if (session.quizId == quiz.id && session.isActive) {
        return session; // Return existing session
      }
    }

    // Create new session
    final session = TestSession(
      sessionId: sessionId,
      userId: user.id,
      quizId: quiz.id,
      createdAt: DateTime.now(),
      sessionMetadata: {
        'quizTitle': quiz.title,
        'totalQuestions': quiz.questions.length,
        'maxScore': quiz.totalPoints,
        'timeLimit': quiz.timeLimit,
        'config': {
          'allowPause': config.allowPause,
          'allowReview': config.allowReview,
          'shuffleQuestions': config.shuffleQuestions,
          'shuffleOptions': config.shuffleOptions,
          'showProgressBar': config.showProgressBar,
          'strictTimeLimit': config.strictTimeLimit,
        },
      },
    );

    _activeSessions[sessionId] = session;
    _createSessionController(sessionId);
    await _saveSession(session);

    return session;
  }

  // Start a test session
  Future<TestSession> startSession(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    if (session.status != TestSessionStatus.notStarted && 
        session.status != TestSessionStatus.paused) {
      throw Exception('Session cannot be started from current status: ${session.status}');
    }

    final quiz = await StorageService.getQuiz(session.quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    final updatedSession = session.start().copyWith(
      remainingTime: quiz.timeLimit > 0 ? Duration(minutes: quiz.timeLimit) : null,
    );

    _activeSessions[sessionId] = updatedSession;
    _sessionControllers[sessionId]?.add(updatedSession);
    
    // Start auto-save if enabled
    final config = _getSessionConfig(updatedSession);
    if (config.autoSave) {
      _startAutoSave(sessionId, config.autoSaveInterval);
    }

    // Start time tracking if quiz has time limit
    if (quiz.timeLimit > 0) {
      _startTimeTracking(sessionId, Duration(minutes: quiz.timeLimit));
    }

    await _saveSession(updatedSession);
    return updatedSession;
  }

  // Pause a test session
  Future<TestSession> pauseSession(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    final config = _getSessionConfig(session);
    if (!config.allowPause) {
      throw Exception('Pausing is not allowed for this test');
    }

    final updatedSession = session.pause();
    _activeSessions[sessionId] = updatedSession;
    _sessionControllers[sessionId]?.add(updatedSession);

    // Stop auto-save timer
    _autoSaveTimers[sessionId]?.cancel();
    _autoSaveTimers.remove(sessionId);

    await _saveSession(updatedSession);
    return updatedSession;
  }

  // Resume a test session
  Future<TestSession> resumeSession(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    if (!session.canResume) {
      throw Exception('Session cannot be resumed');
    }

    final updatedSession = session.resume();
    _activeSessions[sessionId] = updatedSession;
    _sessionControllers[sessionId]?.add(updatedSession);

    // Restart auto-save
    final config = _getSessionConfig(updatedSession);
    if (config.autoSave) {
      _startAutoSave(sessionId, config.autoSaveInterval);
    }

    await _saveSession(updatedSession);
    return updatedSession;
  }

  // Submit an answer for a question
  Future<TestSession> submitAnswer({
    required String sessionId,
    required String questionId,
    required String answer,
  }) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    if (session.status != TestSessionStatus.inProgress) {
      throw Exception('Session is not active');
    }

    final updatedSession = session.answerQuestion(questionId, answer);
    _activeSessions[sessionId] = updatedSession;
    _sessionControllers[sessionId]?.add(updatedSession);

    await _saveSession(updatedSession);
    return updatedSession;
  }

  // Navigate to next question
  Future<TestSession> nextQuestion(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    final quiz = await StorageService.getQuiz(session.quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    final updatedSession = session.moveToNextQuestion();
    _activeSessions[sessionId] = updatedSession;
    _sessionControllers[sessionId]?.add(updatedSession);

    await _saveSession(updatedSession);
    return updatedSession;
  }

  // Navigate to previous question
  Future<TestSession> previousQuestion(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    final updatedSession = session.moveToPreviousQuestion();
    _activeSessions[sessionId] = updatedSession;
    _sessionControllers[sessionId]?.add(updatedSession);

    await _saveSession(updatedSession);
    return updatedSession;
  }

  // Complete and grade a test session
  Future<QuizResult> completeSession(String sessionId) async {
    final session = _activeSessions[sessionId];
    if (session == null) {
      throw Exception('Session not found');
    }

    final quiz = await StorageService.getQuiz(session.quizId);
    if (quiz == null) {
      throw Exception('Quiz not found');
    }

    // Stop timers
    _autoSaveTimers[sessionId]?.cancel();
    _autoSaveTimers.remove(sessionId);

    // Mark session as completed
    final completedSession = session.complete();
    _activeSessions[sessionId] = completedSession;

    // Grade the test
    final result = await _gradeTest(completedSession, quiz);
    
    // Save result
    await StorageService.saveQuizResult(result);
    await _saveSession(completedSession);

    // Notify listeners
    _sessionControllers[sessionId]?.add(completedSession);

    return result;
  }

  // Get session by ID
  Future<TestSession?> getSession(String sessionId) async {
    if (_activeSessions.containsKey(sessionId)) {
      return _activeSessions[sessionId];
    }

    // Try to load from storage
    final sessions = await StorageService.getAllTestSessions();
    final session = sessions.firstWhere(
      (s) => s.sessionId == sessionId,
      orElse: () => throw Exception('Session not found'),
    );

    if (session.isActive) {
      _activeSessions[sessionId] = session;
      _createSessionController(sessionId);
    }

    return session;
  }

  // Get all active sessions for a user
  Future<List<TestSession>> getActiveSessions({String? userId}) async {
    final allSessions = await StorageService.getAllTestSessions();
    return allSessions.where((session) {
      final isActive = session.isActive;
      final matchesUser = userId == null || session.userId == userId;
      return isActive && matchesUser;
    }).toList();
  }

  // Get session stream for real-time updates
  Stream<TestSession> getSessionStream(String sessionId) {
    if (!_sessionControllers.containsKey(sessionId)) {
      _createSessionController(sessionId);
    }
    return _sessionControllers[sessionId]!.stream;
  }

  // Expire sessions based on time limits or inactivity
  Future<void> expireInactiveSessions() async {
    final allSessions = await StorageService.getAllTestSessions();
    final now = DateTime.now();

    for (final session in allSessions) {
      if (!session.isActive) continue;

      bool shouldExpire = false;

      // Check time limit expiration
      if (session.remainingTime != null && session.startedAt != null) {
        final elapsed = now.difference(session.startedAt!);
        if (elapsed >= session.remainingTime!) {
          shouldExpire = true;
        }
      }

      // Check inactivity expiration (24 hours)
      if (session.lastActivity != null) {
        final inactiveTime = now.difference(session.lastActivity!);
        if (inactiveTime.inHours >= 24) {
          shouldExpire = true;
        }
      }

      if (shouldExpire) {
        final expiredSession = session.expire();
        await _saveSession(expiredSession);
        _activeSessions.remove(session.sessionId);
        _sessionControllers[session.sessionId]?.add(expiredSession);
      }
    }
  }

  // Private helper methods

  String _generateSessionId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return 'session_${List.generate(12, (index) => chars[random.nextInt(chars.length)]).join()}';
  }

  void _createSessionController(String sessionId) {
    _sessionControllers[sessionId] = StreamController<TestSession>.broadcast();
  }

  TestEngineConfig _getSessionConfig(TestSession session) {
    final config = session.sessionMetadata['config'] as Map<String, dynamic>? ?? {};
    return TestEngineConfig(
      allowPause: config['allowPause'] ?? true,
      allowReview: config['allowReview'] ?? true,
      shuffleQuestions: config['shuffleQuestions'] ?? false,
      shuffleOptions: config['shuffleOptions'] ?? false,
      showProgressBar: config['showProgressBar'] ?? true,
      strictTimeLimit: config['strictTimeLimit'] ?? false,
    );
  }

  void _startAutoSave(String sessionId, Duration interval) {
    _autoSaveTimers[sessionId] = Timer.periodic(interval, (timer) async {
      final session = _activeSessions[sessionId];
      if (session != null && session.isActive) {
        await _saveSession(session);
      } else {
        timer.cancel();
        _autoSaveTimers.remove(sessionId);
      }
    });
  }

  void _startTimeTracking(String sessionId, Duration totalTime) {
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      final session = _activeSessions[sessionId];
      if (session == null || !session.isActive || session.startedAt == null) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(session.startedAt!);
      final remaining = totalTime - elapsed;

      if (remaining.isNegative) {
        // Time expired
        timer.cancel();
        final expiredSession = session.expire();
        _activeSessions[sessionId] = expiredSession;
        _sessionControllers[sessionId]?.add(expiredSession);
        await _saveSession(expiredSession);
      } else {
        // Update remaining time
        final updatedSession = session.copyWith(remainingTime: remaining);
        _activeSessions[sessionId] = updatedSession;
        _sessionControllers[sessionId]?.add(updatedSession);
      }
    });
  }

  Future<QuizResult> _gradeTest(TestSession session, Quiz quiz) async {
    final answers = <UserAnswer>[];
    int totalScore = 0;

    for (final question in quiz.questions) {
      final userAnswer = session.currentAnswers[question.id] ?? '';
      final isCorrect = question.checkAnswer(userAnswer);
      final pointsEarned = isCorrect ? question.points : 0;
      totalScore += pointsEarned;

      answers.add(UserAnswer(
        questionId: question.id,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        pointsEarned: pointsEarned,
        answeredAt: session.completedAt ?? DateTime.now(),
      ));
    }

    return QuizResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      quizId: quiz.id,
      quizTitle: quiz.title,
      answers: answers,
      totalScore: totalScore,
      maxScore: quiz.totalPoints,
      startTime: session.startedAt ?? session.createdAt,
      endTime: session.completedAt ?? DateTime.now(),
      timeTaken: session.elapsedTime ?? Duration.zero,
    );
  }

  Future<void> _saveSession(TestSession session) async {
    await StorageService.saveTestSession(session);
  }

  // Cleanup resources
  void dispose() {
    for (final timer in _autoSaveTimers.values) {
      timer.cancel();
    }
    _autoSaveTimers.clear();

    for (final controller in _sessionControllers.values) {
      controller.close();
    }
    _sessionControllers.clear();

    _activeSessions.clear();
  }
}