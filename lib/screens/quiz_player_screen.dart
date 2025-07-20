import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/question.dart';
import 'package:cognispark/models/quiz_result.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/screens/results_screen.dart';
import 'package:cognispark/widgets/question_widgets/mcq_widget.dart';
import 'package:cognispark/widgets/question_widgets/true_false_widget.dart';
import 'package:cognispark/widgets/question_widgets/fill_blank_widget.dart';
import 'package:cognispark/widgets/question_widgets/short_answer_widget.dart';

class QuizPlayerScreen extends StatefulWidget {
  final Quiz quiz;

  const QuizPlayerScreen({super.key, required this.quiz});

  @override
  State<QuizPlayerScreen> createState() => _QuizPlayerScreenState();
}

class _QuizPlayerScreenState extends State<QuizPlayerScreen> with TickerProviderStateMixin {
  late List<Question> questions;
  int currentQuestionIndex = 0;
  Map<String, String> userAnswers = {};
  Timer? timer;
  Duration remainingTime = Duration.zero;
  DateTime? startTime;
  bool isQuizCompleted = false;
  late AnimationController _progressController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    questions = widget.quiz.shuffleQuestions ? 
        (List.from(widget.quiz.questions)..shuffle()) : 
        widget.quiz.questions;
    startTime = DateTime.now();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _initializeTimer();
    _updateProgress();
    _slideController.forward();
  }

  @override
  void dispose() {
    timer?.cancel();
    _progressController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initializeTimer() {
    if (widget.quiz.timeLimit > 0) {
      remainingTime = Duration(minutes: widget.quiz.timeLimit);
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (remainingTime.inSeconds > 0) {
            remainingTime = remainingTime - const Duration(seconds: 1);
          } else {
            _completeQuiz();
          }
        });
      });
    }
  }

  void _updateProgress() {
    final progress = (currentQuestionIndex + 1) / questions.length;
    _progressController.animateTo(progress);
  }

  void _answerQuestion(String answer) {
    setState(() {
      userAnswers[questions[currentQuestionIndex].id] = answer;
    });
  }

  void _nextQuestion() {
    if (currentQuestionIndex < questions.length - 1) {
      setState(() {
        currentQuestionIndex++;
      });
      _updateProgress();
      _slideController.reset();
      _slideController.forward();
    } else {
      _completeQuiz();
    }
  }

  void _previousQuestion() {
    if (currentQuestionIndex > 0) {
      setState(() {
        currentQuestionIndex--;
      });
      _updateProgress();
      _slideController.reset();
      _slideController.forward();
    }
  }

  Future<void> _completeQuiz() async {
    if (isQuizCompleted) return;
    
    timer?.cancel();
    
    final endTime = DateTime.now();
    final timeTaken = endTime.difference(startTime!);
    
    // Calculate results
    final List<UserAnswer> answers = [];
    int totalScore = 0;
    
    for (final question in questions) {
      final userAnswer = userAnswers[question.id] ?? '';
      final isCorrect = question.checkAnswer(userAnswer);
      final pointsEarned = isCorrect ? question.points : 0;
      totalScore += pointsEarned;
      
      answers.add(UserAnswer(
        questionId: question.id,
        userAnswer: userAnswer,
        isCorrect: isCorrect,
        pointsEarned: pointsEarned,
        answeredAt: DateTime.now(),
      ));
    }
    
    final result = QuizResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      quizId: widget.quiz.id,
      quizTitle: widget.quiz.title,
      answers: answers,
      totalScore: totalScore,
      maxScore: widget.quiz.totalPoints,
      startTime: startTime!,
      endTime: endTime,
      timeTaken: timeTaken,
    );
    
    await StorageService.saveQuizResult(result);
    
    setState(() {
      isQuizCompleted = true;
    });
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            result: result,
            quiz: widget.quiz,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = questions[currentQuestionIndex];
    final hasAnswer = userAnswers.containsKey(question.id) && 
                     userAnswers[question.id]!.isNotEmpty;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          final shouldExit = await _showExitDialog();
          if (shouldExit == true && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          leading: IconButton(
            onPressed: () async {
              final shouldExit = await _showExitDialog();
              if (shouldExit == true && mounted) {
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.close),
          ),
          actions: [
            if (widget.quiz.timeLimit > 0)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: remainingTime.inMinutes < 2 
                          ? theme.colorScheme.errorContainer
                          : theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer,
                          size: 16,
                          color: remainingTime.inMinutes < 2 
                              ? theme.colorScheme.onErrorContainer
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(remainingTime),
                          style: TextStyle(
                            color: remainingTime.inMinutes < 2 
                                ? theme.colorScheme.onErrorContainer
                                : theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Progress indicator
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${currentQuestionIndex + 1} of ${questions.length}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        '${question.points} ${question.points == 1 ? 'point' : 'points'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: _progressController.value,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Question content
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildQuestionWidget(question),
              ),
            ),
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (currentQuestionIndex > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousQuestion,
                        child: Text('Previous', style: TextStyle(color: theme.colorScheme.primary)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: theme.colorScheme.primary),
                        ),
                      ),
                    ),
                  if (currentQuestionIndex > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: currentQuestionIndex == 0 ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: hasAnswer ? _nextQuestion : null,
                      child: Text(
                        currentQuestionIndex == questions.length - 1 ? 'Finish Quiz' : 'Next',
                        style: TextStyle(color: theme.colorScheme.onPrimary),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionWidget(Question question) {
    final currentAnswer = userAnswers[question.id];
    
    switch (question.type) {
      case QuestionType.multipleChoice:
        return MCQWidget(
          question: question as MultipleChoiceQuestion,
          selectedAnswer: currentAnswer,
          onAnswerSelected: _answerQuestion,
        );
      case QuestionType.trueFalse:
        return TrueFalseWidget(
          question: question as TrueFalseQuestion,
          selectedAnswer: currentAnswer,
          onAnswerSelected: _answerQuestion,
        );
      case QuestionType.fillInBlank:
        return FillBlankWidget(
          question: question as FillInBlankQuestion,
          answer: currentAnswer ?? '',
          onAnswerChanged: _answerQuestion,
        );
      case QuestionType.shortAnswer:
        return ShortAnswerWidget(
          question: question as ShortAnswerQuestion,
          answer: currentAnswer ?? '',
          onAnswerChanged: _answerQuestion,
        );
    }
  }

  String _formatTime(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Exit Quiz?'),
          content: const Text('Your progress will be lost if you exit now.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exit'),
            ),
          ],
        );
      },
    );
  }
}