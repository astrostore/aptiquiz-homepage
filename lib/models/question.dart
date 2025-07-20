enum QuestionType {
  multipleChoice,
  trueFalse,
  fillInBlank,
  shortAnswer,
}

abstract class Question {
  final String id;
  final String text;
  final QuestionType type;
  final int points;

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.points = 1,
  });

  Map<String, dynamic> toJson();
  factory Question.fromJson(Map<String, dynamic> json) {
    switch (QuestionType.values[json['type']]) {
      case QuestionType.multipleChoice:
        return MultipleChoiceQuestion.fromJson(json);
      case QuestionType.trueFalse:
        return TrueFalseQuestion.fromJson(json);
      case QuestionType.fillInBlank:
        return FillInBlankQuestion.fromJson(json);
      case QuestionType.shortAnswer:
        return ShortAnswerQuestion.fromJson(json);
    }
  }

  bool checkAnswer(String userAnswer);
}

class MultipleChoiceQuestion extends Question {
  final List<String> options;
  final int correctAnswerIndex;

  MultipleChoiceQuestion({
    required super.id,
    required super.text,
    required this.options,
    required this.correctAnswerIndex,
    super.points,
  }) : super(type: QuestionType.multipleChoice);

  factory MultipleChoiceQuestion.fromJson(Map<String, dynamic> json) =>
      MultipleChoiceQuestion(
        id: json['id'],
        text: json['text'],
        options: List<String>.from(json['options']),
        correctAnswerIndex: json['correctAnswerIndex'],
        points: json['points'] ?? 1,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type.index,
        'options': options,
        'correctAnswerIndex': correctAnswerIndex,
        'points': points,
      };

  @override
  bool checkAnswer(String userAnswer) {
    final answerIndex = int.tryParse(userAnswer);
    return answerIndex == correctAnswerIndex;
  }

  String get correctAnswer => options[correctAnswerIndex];
}

class TrueFalseQuestion extends Question {
  final bool correctAnswer;

  TrueFalseQuestion({
    required super.id,
    required super.text,
    required this.correctAnswer,
    super.points,
  }) : super(type: QuestionType.trueFalse);

  factory TrueFalseQuestion.fromJson(Map<String, dynamic> json) =>
      TrueFalseQuestion(
        id: json['id'],
        text: json['text'],
        correctAnswer: json['correctAnswer'],
        points: json['points'] ?? 1,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type.index,
        'correctAnswer': correctAnswer,
        'points': points,
      };

  @override
  bool checkAnswer(String userAnswer) {
    return userAnswer.toLowerCase() == correctAnswer.toString().toLowerCase();
  }
}

class FillInBlankQuestion extends Question {
  final String correctAnswer;
  final bool caseSensitive;

  FillInBlankQuestion({
    required super.id,
    required super.text,
    required this.correctAnswer,
    this.caseSensitive = false,
    super.points,
  }) : super(type: QuestionType.fillInBlank);

  factory FillInBlankQuestion.fromJson(Map<String, dynamic> json) =>
      FillInBlankQuestion(
        id: json['id'],
        text: json['text'],
        correctAnswer: json['correctAnswer'],
        caseSensitive: json['caseSensitive'] ?? false,
        points: json['points'] ?? 1,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type.index,
        'correctAnswer': correctAnswer,
        'caseSensitive': caseSensitive,
        'points': points,
      };

  @override
  bool checkAnswer(String userAnswer) {
    if (caseSensitive) {
      return userAnswer.trim() == correctAnswer;
    }
    return userAnswer.trim().toLowerCase() == correctAnswer.toLowerCase();
  }
}

class ShortAnswerQuestion extends Question {
  final List<String> acceptableAnswers;
  final bool caseSensitive;

  ShortAnswerQuestion({
    required super.id,
    required super.text,
    required this.acceptableAnswers,
    this.caseSensitive = false,
    super.points,
  }) : super(type: QuestionType.shortAnswer);

  factory ShortAnswerQuestion.fromJson(Map<String, dynamic> json) =>
      ShortAnswerQuestion(
        id: json['id'],
        text: json['text'],
        acceptableAnswers: List<String>.from(json['acceptableAnswers']),
        caseSensitive: json['caseSensitive'] ?? false,
        points: json['points'] ?? 1,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type.index,
        'acceptableAnswers': acceptableAnswers,
        'caseSensitive': caseSensitive,
        'points': points,
      };

  @override
  bool checkAnswer(String userAnswer) {
    final answer = userAnswer.trim();
    return acceptableAnswers.any((acceptable) {
      if (caseSensitive) {
        return answer == acceptable;
      }
      return answer.toLowerCase() == acceptable.toLowerCase();
    });
  }
}