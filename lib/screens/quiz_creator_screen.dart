import 'package:flutter/material.dart';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/question.dart';
import 'package:cognispark/models/category.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/services/quiz_service.dart';

class QuizCreatorScreen extends StatefulWidget {
  final Quiz? editQuiz;

  const QuizCreatorScreen({super.key, this.editQuiz});

  @override
  State<QuizCreatorScreen> createState() => _QuizCreatorScreenState();
}

class _QuizCreatorScreenState extends State<QuizCreatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  List<QuizCategory> categories = [];
  String? selectedCategoryId;
  int timeLimit = 0;
  bool shuffleQuestions = false;
  bool showCorrectAnswers = true;
  List<Question> questions = [];
  
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final categoriesData = await StorageService.getCategories();
    setState(() {
      categories = categoriesData;
      selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
    });
    
    if (widget.editQuiz != null) {
      _loadExistingQuiz();
    }
    
    setState(() {
      isLoading = false;
    });
  }

  void _loadExistingQuiz() {
    final quiz = widget.editQuiz!;
    _titleController.text = quiz.title;
    _descriptionController.text = quiz.description;
    selectedCategoryId = quiz.categoryId;
    timeLimit = quiz.timeLimit;
    shuffleQuestions = quiz.shuffleQuestions;
    showCorrectAnswers = quiz.showCorrectAnswers;
    questions = List.from(quiz.questions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editQuiz != null ? 'Edit Quiz' : 'Create Quiz'),
        actions: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: questions.isNotEmpty ? _saveQuiz : null,
              child: Text(
                'Save',
                style: TextStyle(
                  color: questions.isNotEmpty 
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBasicInfoSection(theme),
              const SizedBox(height: 24),
              _buildSettingsSection(theme),
              const SizedBox(height: 24),
              _buildQuestionsSection(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Basic Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Quiz Title',
                hintText: 'Enter a catchy title for your quiz',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a quiz title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe what this quiz is about',
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
              ),
              items: categories.map((category) {
                return DropdownMenuItem(
                  value: category.id,
                  child: Row(
                    children: [
                      Text(category.icon, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Text(category.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategoryId = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select a category';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Quiz Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Time Limit (minutes)',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    initialValue: timeLimit.toString(),
                    decoration: const InputDecoration(
                      hintText: '0',
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      timeLimit = int.tryParse(value) ?? 0;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Set to 0 for no time limit',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Shuffle Questions'),
              subtitle: const Text('Present questions in random order'),
              value: shuffleQuestions,
              onChanged: (value) {
                setState(() {
                  shuffleQuestions = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              title: const Text('Show Correct Answers'),
              subtitle: const Text('Show correct answers in results'),
              value: showCorrectAnswers,
              onChanged: (value) {
                setState(() {
                  showCorrectAnswers = value;
                });
              },
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsSection(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.quiz, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Questions (${questions.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddQuestionDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (questions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No questions yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first question to get started',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                itemBuilder: (context, index) {
                  final question = questions[index];
                  return _buildQuestionItem(theme, question, index);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionItem(ThemeData theme, Question question, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '${index + 1}',
            style: TextStyle(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          question.text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(_getQuestionTypeText(question.type)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${question.points} pts',
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontSize: 12,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editQuestion(index);
                } else if (value == 'delete') {
                  _deleteQuestion(index);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getQuestionTypeText(QuestionType type) {
    switch (type) {
      case QuestionType.multipleChoice:
        return 'Multiple Choice';
      case QuestionType.trueFalse:
        return 'True/False';
      case QuestionType.fillInBlank:
        return 'Fill in the Blank';
      case QuestionType.shortAnswer:
        return 'Short Answer';
    }
  }

  void _showAddQuestionDialog() {
    showDialog(
      context: context,
      builder: (context) => _QuestionTypeDialog(
        onTypeSelected: (type) {
          Navigator.pop(context);
          _addQuestion(type);
        },
      ),
    );
  }

  void _addQuestion(QuestionType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QuestionEditorScreen(
          type: type,
          onQuestionSaved: (question) {
            setState(() {
              questions.add(question);
            });
          },
        ),
      ),
    );
  }

  void _editQuestion(int index) {
    final question = questions[index];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QuestionEditorScreen(
          type: question.type,
          editQuestion: question,
          onQuestionSaved: (updatedQuestion) {
            setState(() {
              questions[index] = updatedQuestion;
            });
          },
        ),
      ),
    );
  }

  void _deleteQuestion(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Question'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                questions.removeAt(index);
              });
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveQuiz() async {
    if (!_formKey.currentState!.validate() || questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields and add at least one question')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final quiz = Quiz(
        id: widget.editQuiz?.id ?? QuizService.generateQuizId(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        categoryId: selectedCategoryId!,
        questions: questions,
        timeLimit: timeLimit,
        createdAt: widget.editQuiz?.createdAt ?? DateTime.now(),
        updatedAt: widget.editQuiz != null ? DateTime.now() : null,
        shuffleQuestions: shuffleQuestions,
        showCorrectAnswers: showCorrectAnswers,
      );

      await StorageService.saveQuiz(quiz);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.editQuiz != null ? 'Quiz updated successfully!' : 'Quiz created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save quiz. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }
}

class _QuestionTypeDialog extends StatelessWidget {
  final Function(QuestionType) onTypeSelected;

  const _QuestionTypeDialog({required this.onTypeSelected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: const Text('Select Question Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypeOption(
            theme,
            'Multiple Choice',
            'Choose from several options',
            Icons.radio_button_checked,
            () => onTypeSelected(QuestionType.multipleChoice),
          ),
          _buildTypeOption(
            theme,
            'True/False',
            'Simple true or false question',
            Icons.check_box,
            () => onTypeSelected(QuestionType.trueFalse),
          ),
          _buildTypeOption(
            theme,
            'Fill in the Blank',
            'Complete the missing word',
            Icons.edit,
            () => onTypeSelected(QuestionType.fillInBlank),
          ),
          _buildTypeOption(
            theme,
            'Short Answer',
            'Type a brief answer',
            Icons.text_fields,
            () => onTypeSelected(QuestionType.shortAnswer),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption(ThemeData theme, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}

class _QuestionEditorScreen extends StatefulWidget {
  final QuestionType type;
  final Question? editQuestion;
  final Function(Question) onQuestionSaved;

  const _QuestionEditorScreen({
    required this.type,
    this.editQuestion,
    required this.onQuestionSaved,
  });

  @override
  State<_QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<_QuestionEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [];
  final _correctAnswerController = TextEditingController();
  
  int points = 1;
  int correctAnswerIndex = 0;
  bool correctAnswer = true;
  bool caseSensitive = false;
  List<String> acceptableAnswers = [''];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadExistingQuestion();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _correctAnswerController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeControllers() {
    if (widget.type == QuestionType.multipleChoice) {
      for (int i = 0; i < 4; i++) {
        _optionControllers.add(TextEditingController());
      }
    }
  }

  void _loadExistingQuestion() {
    if (widget.editQuestion == null) return;
    
    final question = widget.editQuestion!;
    _questionController.text = question.text;
    points = question.points;
    
    switch (widget.type) {
      case QuestionType.multipleChoice:
        final mcq = question as MultipleChoiceQuestion;
        for (int i = 0; i < mcq.options.length && i < _optionControllers.length; i++) {
          _optionControllers[i].text = mcq.options[i];
        }
        correctAnswerIndex = mcq.correctAnswerIndex;
        break;
      case QuestionType.trueFalse:
        final tf = question as TrueFalseQuestion;
        correctAnswer = tf.correctAnswer;
        break;
      case QuestionType.fillInBlank:
        final fib = question as FillInBlankQuestion;
        _correctAnswerController.text = fib.correctAnswer;
        caseSensitive = fib.caseSensitive;
        break;
      case QuestionType.shortAnswer:
        final sa = question as ShortAnswerQuestion;
        acceptableAnswers = List.from(sa.acceptableAnswers);
        caseSensitive = sa.caseSensitive;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.editQuestion != null ? 'Edit' : 'Add'} Question'),
        actions: [
          TextButton(
            onPressed: _saveQuestion,
            child: Text('Save', style: TextStyle(color: theme.colorScheme.primary)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  hintText: 'Enter your question here...',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a question';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Points: '),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: points.toString(),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        points = int.tryParse(value) ?? 1;
                      },
                      validator: (value) {
                        final intValue = int.tryParse(value ?? '');
                        if (intValue == null || intValue < 1) {
                          return 'Must be ≥ 1';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildTypeSpecificFields(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields(ThemeData theme) {
    switch (widget.type) {
      case QuestionType.multipleChoice:
        return _buildMCQFields(theme);
      case QuestionType.trueFalse:
        return _buildTrueFalseFields(theme);
      case QuestionType.fillInBlank:
        return _buildFillBlankFields(theme);
      case QuestionType.shortAnswer:
        return _buildShortAnswerFields(theme);
    }
  }

  Widget _buildMCQFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Answer Options',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...List.generate(_optionControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Radio<int>(
                  value: index,
                  groupValue: correctAnswerIndex,
                  onChanged: (value) {
                    setState(() {
                      correctAnswerIndex = value!;
                    });
                  },
                ),
                Expanded(
                  child: TextFormField(
                    controller: _optionControllers[index],
                    decoration: InputDecoration(
                      labelText: 'Option ${String.fromCharCode(65 + index)}',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter an option';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrueFalseFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Correct Answer',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        RadioListTile<bool>(
          title: const Text('True'),
          value: true,
          groupValue: correctAnswer,
          onChanged: (value) {
            setState(() {
              correctAnswer = value!;
            });
          },
        ),
        RadioListTile<bool>(
          title: const Text('False'),
          value: false,
          groupValue: correctAnswer,
          onChanged: (value) {
            setState(() {
              correctAnswer = value!;
            });
          },
        ),
      ],
    );
  }

  Widget _buildFillBlankFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Correct Answer',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Use _____ in your question to indicate where the blank should be.'),
        const SizedBox(height: 16),
        TextFormField(
          controller: _correctAnswerController,
          decoration: const InputDecoration(
            labelText: 'Correct Answer',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter the correct answer';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Case Sensitive'),
          value: caseSensitive,
          onChanged: (value) {
            setState(() {
              caseSensitive = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildShortAnswerFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acceptable Answers',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...List.generate(acceptableAnswers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: acceptableAnswers[index],
                    decoration: InputDecoration(
                      labelText: 'Answer ${index + 1}',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      acceptableAnswers[index] = value;
                    },
                    validator: (value) {
                      if (index == 0 && (value == null || value.trim().isEmpty)) {
                        return 'Please enter at least one answer';
                      }
                      return null;
                    },
                  ),
                ),
                if (index > 0)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        acceptableAnswers.removeAt(index);
                      });
                    },
                    icon: const Icon(Icons.remove_circle),
                  ),
              ],
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              acceptableAnswers.add('');
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Alternative Answer'),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Case Sensitive'),
          value: caseSensitive,
          onChanged: (value) {
            setState(() {
              caseSensitive = value;
            });
          },
        ),
      ],
    );
  }

  void _saveQuestion() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Question question;
    final id = widget.editQuestion?.id ?? QuizService.generateQuestionId();
    final questionText = _questionController.text.trim();

    switch (widget.type) {
      case QuestionType.multipleChoice:
        final options = _optionControllers.map((c) => c.text.trim()).toList();
        question = MultipleChoiceQuestion(
          id: id,
          text: questionText,
          options: options,
          correctAnswerIndex: correctAnswerIndex,
          points: points,
        );
        break;
      case QuestionType.trueFalse:
        question = TrueFalseQuestion(
          id: id,
          text: questionText,
          correctAnswer: correctAnswer,
          points: points,
        );
        break;
      case QuestionType.fillInBlank:
        question = FillInBlankQuestion(
          id: id,
          text: questionText,
          correctAnswer: _correctAnswerController.text.trim(),
          caseSensitive: caseSensitive,
          points: points,
        );
        break;
      case QuestionType.shortAnswer:
        final validAnswers = acceptableAnswers
            .where((answer) => answer.trim().isNotEmpty)
            .map((answer) => answer.trim())
            .toList();
        question = ShortAnswerQuestion(
          id: id,
          text: questionText,
          acceptableAnswers: validAnswers,
          caseSensitive: caseSensitive,
          points: points,
        );
        break;
    }

    widget.onQuestionSaved(question);
    Navigator.pop(context);
  }
}