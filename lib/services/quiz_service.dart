import 'dart:math';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/question.dart';
import 'package:cognispark/services/storage_service.dart';

class QuizService {
  static Future<void> initializeSampleData() async {
    final existingQuizzes = await StorageService.getQuizzes();
    if (existingQuizzes.isNotEmpty) return; // Sample data already exists
    
    final sampleQuizzes = _generateSampleQuizzes();
    for (final quiz in sampleQuizzes) {
      await StorageService.saveQuiz(quiz);
    }
  }

  static List<Quiz> _generateSampleQuizzes() => [
    Quiz(
      id: 'quiz_1',
      title: 'World Geography Basics',
      description: 'Test your knowledge of world geography, countries, and capitals.',
      categoryId: 'history',
      timeLimit: 10,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      questions: [
        MultipleChoiceQuestion(
          id: 'geo_1',
          text: 'Which is the largest continent by area?',
          options: ['Africa', 'Asia', 'North America', 'Europe'],
          correctAnswerIndex: 1,
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: 'geo_2',
          text: 'What is the capital of Australia?',
          options: ['Sydney', 'Melbourne', 'Canberra', 'Perth'],
          correctAnswerIndex: 2,
          points: 1,
        ),
        TrueFalseQuestion(
          id: 'geo_3',
          text: 'The Nile River is the longest river in the world.',
          correctAnswer: true,
          points: 1,
        ),
        FillInBlankQuestion(
          id: 'geo_4',
          text: 'The highest mountain peak in the world is Mount _____.',
          correctAnswer: 'Everest',
          points: 2,
        ),
        ShortAnswerQuestion(
          id: 'geo_5',
          text: 'Name the ocean between Africa and Australia.',
          acceptableAnswers: ['Indian Ocean', 'Indian'],
          points: 1,
        ),
      ],
    ),
    
    Quiz(
      id: 'quiz_2',
      title: 'Science Fundamentals',
      description: 'Basic concepts in physics, chemistry, and biology.',
      categoryId: 'science',
      timeLimit: 15,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      questions: [
        MultipleChoiceQuestion(
          id: 'sci_1',
          text: 'What is the chemical symbol for gold?',
          options: ['Go', 'Gd', 'Au', 'Ag'],
          correctAnswerIndex: 2,
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: 'sci_2',
          text: 'Which planet is closest to the Sun?',
          options: ['Venus', 'Mercury', 'Earth', 'Mars'],
          correctAnswerIndex: 1,
          points: 1,
        ),
        TrueFalseQuestion(
          id: 'sci_3',
          text: 'Sound travels faster in water than in air.',
          correctAnswer: true,
          points: 1,
        ),
        FillInBlankQuestion(
          id: 'sci_4',
          text: 'The process by which plants make food is called _____.',
          correctAnswer: 'Photosynthesis',
          points: 2,
        ),
        MultipleChoiceQuestion(
          id: 'sci_5',
          text: 'How many bones are there in an adult human body?',
          options: ['196', '206', '216', '226'],
          correctAnswerIndex: 1,
          points: 1,
        ),
        ShortAnswerQuestion(
          id: 'sci_6',
          text: 'What gas do plants absorb from the atmosphere during photosynthesis?',
          acceptableAnswers: ['Carbon Dioxide', 'CO2', 'Carbon dioxide'],
          points: 1,
        ),
      ],
    ),
    
    Quiz(
      id: 'quiz_3',
      title: 'Mathematics Quick Test',
      description: 'Basic arithmetic and algebra problems.',
      categoryId: 'math',
      timeLimit: 8,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      questions: [
        MultipleChoiceQuestion(
          id: 'math_1',
          text: 'What is 15% of 200?',
          options: ['25', '30', '35', '40'],
          correctAnswerIndex: 1,
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: 'math_2',
          text: 'If x + 5 = 12, what is the value of x?',
          options: ['5', '6', '7', '8'],
          correctAnswerIndex: 2,
          points: 1,
        ),
        TrueFalseQuestion(
          id: 'math_3',
          text: 'The square root of 144 is 12.',
          correctAnswer: true,
          points: 1,
        ),
        FillInBlankQuestion(
          id: 'math_4',
          text: 'The result of 8 × 7 is _____.',
          correctAnswer: '56',
          points: 1,
        ),
      ],
    ),

    Quiz(
      id: 'quiz_4',
      title: 'Classic Literature',
      description: 'Test your knowledge of famous books and authors.',
      categoryId: 'literature',
      timeLimit: 12,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      questions: [
        MultipleChoiceQuestion(
          id: 'lit_1',
          text: 'Who wrote "Pride and Prejudice"?',
          options: ['Charlotte Brontë', 'Jane Austen', 'Emily Dickinson', 'Virginia Woolf'],
          correctAnswerIndex: 1,
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: 'lit_2',
          text: 'In which Shakespeare play does the character Hamlet appear?',
          options: ['Macbeth', 'Romeo and Juliet', 'Hamlet', 'Othello'],
          correctAnswerIndex: 2,
          points: 1,
        ),
        TrueFalseQuestion(
          id: 'lit_3',
          text: '"To Kill a Mockingbird" was written by Harper Lee.',
          correctAnswer: true,
          points: 1,
        ),
        FillInBlankQuestion(
          id: 'lit_4',
          text: 'The famous opening line "It was the best of times, it was the worst of times" is from _____ by Charles Dickens.',
          correctAnswer: 'A Tale of Two Cities',
          points: 2,
        ),
        ShortAnswerQuestion(
          id: 'lit_5',
          text: 'Who is the author of "1984"?',
          acceptableAnswers: ['George Orwell', 'Orwell'],
          points: 1,
        ),
      ],
    ),

    Quiz(
      id: 'quiz_5',
      title: 'General Knowledge Mix',
      description: 'A variety of questions from different topics.',
      categoryId: 'general',
      timeLimit: 20,
      createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      questions: [
        MultipleChoiceQuestion(
          id: 'gen_1',
          text: 'Which country hosted the 2020 Summer Olympics?',
          options: ['China', 'Japan', 'Brazil', 'Russia'],
          correctAnswerIndex: 1,
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: 'gen_2',
          text: 'What is the currency of the United Kingdom?',
          options: ['Euro', 'Dollar', 'Pound Sterling', 'Franc'],
          correctAnswerIndex: 2,
          points: 1,
        ),
        TrueFalseQuestion(
          id: 'gen_3',
          text: 'The Great Wall of China is visible from space.',
          correctAnswer: false,
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: 'gen_4',
          text: 'Which company created the iPhone?',
          options: ['Samsung', 'Apple', 'Google', 'Microsoft'],
          correctAnswerIndex: 1,
          points: 1,
        ),
        FillInBlankQuestion(
          id: 'gen_5',
          text: 'The largest ocean on Earth is the _____ Ocean.',
          correctAnswer: 'Pacific',
          points: 1,
        ),
        ShortAnswerQuestion(
          id: 'gen_6',
          text: 'What does WWW stand for?',
          acceptableAnswers: ['World Wide Web'],
          points: 1,
        ),
        MultipleChoiceQuestion(
          id: 'gen_7',
          text: 'How many days are there in a leap year?',
          options: ['364', '365', '366', '367'],
          correctAnswerIndex: 2,
          points: 1,
        ),
      ],
    ),
  ];

  static String generateQuizId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
  }

  static String generateQuestionId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return 'q_${List.generate(6, (index) => chars[random.nextInt(chars.length)]).join()}';
  }
}