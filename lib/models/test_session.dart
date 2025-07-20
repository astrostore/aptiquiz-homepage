import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/models/quiz_result.dart';

enum TestSessionStatus {
  notStarted,
  inProgress,
  paused,
  completed,
  expired,
  abandoned,
}

class TestSession {
  final String sessionId;
  final String userId;
  final String quizId;
  final TestSessionStatus status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? lastActivity;
  final Map<String, String> currentAnswers;
  final int currentQuestionIndex;
  final Duration? remainingTime;
  final Map<String, dynamic> sessionMetadata;
  final List<String> visitedQuestions;
  final int attemptNumber;

  TestSession({
    required this.sessionId,
    required this.userId,
    required this.quizId,
    this.status = TestSessionStatus.notStarted,
    required this.createdAt,
    this.startedAt,
    this.completedAt,
    this.lastActivity,
    this.currentAnswers = const {},
    this.currentQuestionIndex = 0,
    this.remainingTime,
    this.sessionMetadata = const {},
    this.visitedQuestions = const [],
    this.attemptNumber = 1,
  });

  factory TestSession.fromJson(Map<String, dynamic> json) => TestSession(
        sessionId: json['sessionId'],
        userId: json['userId'],
        quizId: json['quizId'],
        status: TestSessionStatus.values[json['status']],
        createdAt: DateTime.parse(json['createdAt']),
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'])
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'])
            : null,
        lastActivity: json['lastActivity'] != null
            ? DateTime.parse(json['lastActivity'])
            : null,
        currentAnswers: Map<String, String>.from(json['currentAnswers'] ?? {}),
        currentQuestionIndex: json['currentQuestionIndex'] ?? 0,
        remainingTime: json['remainingTimeMs'] != null
            ? Duration(milliseconds: json['remainingTimeMs'])
            : null,
        sessionMetadata: Map<String, dynamic>.from(json['sessionMetadata'] ?? {}),
        visitedQuestions: List<String>.from(json['visitedQuestions'] ?? []),
        attemptNumber: json['attemptNumber'] ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'userId': userId,
        'quizId': quizId,
        'status': status.index,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'lastActivity': lastActivity?.toIso8601String(),
        'currentAnswers': currentAnswers,
        'currentQuestionIndex': currentQuestionIndex,
        'remainingTimeMs': remainingTime?.inMilliseconds,
        'sessionMetadata': sessionMetadata,
        'visitedQuestions': visitedQuestions,
        'attemptNumber': attemptNumber,
      };

  String get statusDisplayName {
    switch (status) {
      case TestSessionStatus.notStarted:
        return 'Not Started';
      case TestSessionStatus.inProgress:
        return 'In Progress';
      case TestSessionStatus.paused:
        return 'Paused';
      case TestSessionStatus.completed:
        return 'Completed';
      case TestSessionStatus.expired:
        return 'Expired';
      case TestSessionStatus.abandoned:
        return 'Abandoned';
    }
  }

  Duration? get elapsedTime {
    if (startedAt == null) return null;
    final endTime = completedAt ?? DateTime.now();
    return endTime.difference(startedAt!);
  }

  double get progressPercentage {
    final totalQuestions = sessionMetadata['totalQuestions'] as int? ?? 1;
    return (currentQuestionIndex / totalQuestions * 100).clamp(0.0, 100.0);
  }

  bool get isActive => status == TestSessionStatus.inProgress || status == TestSessionStatus.paused;
  bool get isCompleted => status == TestSessionStatus.completed;
  bool get canResume => status == TestSessionStatus.paused;
  bool get hasExpired => status == TestSessionStatus.expired;

  TestSession copyWith({
    TestSessionStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? lastActivity,
    Map<String, String>? currentAnswers,
    int? currentQuestionIndex,
    Duration? remainingTime,
    Map<String, dynamic>? sessionMetadata,
    List<String>? visitedQuestions,
  }) => TestSession(
        sessionId: sessionId,
        userId: userId,
        quizId: quizId,
        status: status ?? this.status,
        createdAt: createdAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        lastActivity: lastActivity ?? this.lastActivity,
        currentAnswers: currentAnswers ?? this.currentAnswers,
        currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
        remainingTime: remainingTime ?? this.remainingTime,
        sessionMetadata: sessionMetadata ?? this.sessionMetadata,
        visitedQuestions: visitedQuestions ?? this.visitedQuestions,
        attemptNumber: attemptNumber,
      );

  TestSession updateActivity() => copyWith(lastActivity: DateTime.now());

  TestSession answerQuestion(String questionId, String answer) {
    final updatedAnswers = Map<String, String>.from(currentAnswers);
    updatedAnswers[questionId] = answer;
    
    final updatedVisited = List<String>.from(visitedQuestions);
    if (!updatedVisited.contains(questionId)) {
      updatedVisited.add(questionId);
    }

    return copyWith(
      currentAnswers: updatedAnswers,
      visitedQuestions: updatedVisited,
      lastActivity: DateTime.now(),
    );
  }

  TestSession moveToNextQuestion() => copyWith(
        currentQuestionIndex: currentQuestionIndex + 1,
        lastActivity: DateTime.now(),
      );

  TestSession moveToPreviousQuestion() => copyWith(
        currentQuestionIndex: (currentQuestionIndex - 1).clamp(0, currentQuestionIndex),
        lastActivity: DateTime.now(),
      );

  TestSession start() => copyWith(
        status: TestSessionStatus.inProgress,
        startedAt: DateTime.now(),
        lastActivity: DateTime.now(),
      );

  TestSession pause() => copyWith(
        status: TestSessionStatus.paused,
        lastActivity: DateTime.now(),
      );

  TestSession resume() => copyWith(
        status: TestSessionStatus.inProgress,
        lastActivity: DateTime.now(),
      );

  TestSession complete() => copyWith(
        status: TestSessionStatus.completed,
        completedAt: DateTime.now(),
        lastActivity: DateTime.now(),
      );

  TestSession expire() => copyWith(
        status: TestSessionStatus.expired,
        lastActivity: DateTime.now(),
      );

  TestSession abandon() => copyWith(
        status: TestSessionStatus.abandoned,
        lastActivity: DateTime.now(),
      );
}