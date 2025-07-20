class UserAnswer {
  final String questionId;
  final String userAnswer;
  final bool isCorrect;
  final int pointsEarned;
  final DateTime answeredAt;

  UserAnswer({
    required this.questionId,
    required this.userAnswer,
    required this.isCorrect,
    required this.pointsEarned,
    required this.answeredAt,
  });

  factory UserAnswer.fromJson(Map<String, dynamic> json) => UserAnswer(
        questionId: json['questionId'],
        userAnswer: json['userAnswer'],
        isCorrect: json['isCorrect'],
        pointsEarned: json['pointsEarned'],
        answeredAt: DateTime.parse(json['answeredAt']),
      );

  Map<String, dynamic> toJson() => {
        'questionId': questionId,
        'userAnswer': userAnswer,
        'isCorrect': isCorrect,
        'pointsEarned': pointsEarned,
        'answeredAt': answeredAt.toIso8601String(),
      };
}

class QuizResult {
  final String id;
  final String quizId;
  final String quizTitle;
  final List<UserAnswer> answers;
  final int totalScore;
  final int maxScore;
  final DateTime startTime;
  final DateTime endTime;
  final Duration timeTaken;

  QuizResult({
    required this.id,
    required this.quizId,
    required this.quizTitle,
    required this.answers,
    required this.totalScore,
    required this.maxScore,
    required this.startTime,
    required this.endTime,
    required this.timeTaken,
  });

  factory QuizResult.fromJson(Map<String, dynamic> json) => QuizResult(
        id: json['id'],
        quizId: json['quizId'],
        quizTitle: json['quizTitle'],
        answers: (json['answers'] as List)
            .map((a) => UserAnswer.fromJson(a))
            .toList(),
        totalScore: json['totalScore'],
        maxScore: json['maxScore'],
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        timeTaken: Duration(milliseconds: json['timeTakenMs']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'quizId': quizId,
        'quizTitle': quizTitle,
        'answers': answers.map((a) => a.toJson()).toList(),
        'totalScore': totalScore,
        'maxScore': maxScore,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'timeTakenMs': timeTaken.inMilliseconds,
      };

  double get percentage => maxScore > 0 ? (totalScore / maxScore) * 100 : 0;
  int get correctAnswers => answers.where((a) => a.isCorrect).length;
  int get totalQuestions => answers.length;

  String get formattedTime {
    final minutes = timeTaken.inMinutes;
    final seconds = timeTaken.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  String get grade {
    if (percentage >= 90) return 'A+';
    if (percentage >= 80) return 'A';
    if (percentage >= 70) return 'B';
    if (percentage >= 60) return 'C';
    if (percentage >= 50) return 'D';
    return 'F';
  }
}