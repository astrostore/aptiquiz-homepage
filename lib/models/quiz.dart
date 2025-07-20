import 'package:cognispark/models/question.dart';

class Quiz {
  final String id;
  final String title;
  final String description;
  final String categoryId;
  final List<Question> questions;
  final int timeLimit; // in minutes, 0 means no time limit
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool shuffleQuestions;
  final bool showCorrectAnswers;

  Quiz({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.questions,
    this.timeLimit = 0,
    required this.createdAt,
    this.updatedAt,
    this.shuffleQuestions = false,
    this.showCorrectAnswers = true,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) => Quiz(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        categoryId: json['categoryId'],
        questions: (json['questions'] as List)
            .map((q) => Question.fromJson(q))
            .toList(),
        timeLimit: json['timeLimit'] ?? 0,
        createdAt: DateTime.parse(json['createdAt']),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : null,
        shuffleQuestions: json['shuffleQuestions'] ?? false,
        showCorrectAnswers: json['showCorrectAnswers'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'questions': questions.map((q) => q.toJson()).toList(),
        'timeLimit': timeLimit,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'shuffleQuestions': shuffleQuestions,
        'showCorrectAnswers': showCorrectAnswers,
      };

  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);
  int get questionCount => questions.length;
  
  String get formattedTimeLimit {
    if (timeLimit == 0) return 'No limit';
    if (timeLimit < 60) return '${timeLimit}m';
    final hours = timeLimit ~/ 60;
    final minutes = timeLimit % 60;
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  Quiz copyWith({
    String? title,
    String? description,
    String? categoryId,
    List<Question>? questions,
    int? timeLimit,
    DateTime? updatedAt,
    bool? shuffleQuestions,
    bool? showCorrectAnswers,
  }) => Quiz(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        categoryId: categoryId ?? this.categoryId,
        questions: questions ?? this.questions,
        timeLimit: timeLimit ?? this.timeLimit,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
        showCorrectAnswers: showCorrectAnswers ?? this.showCorrectAnswers,
      );
}