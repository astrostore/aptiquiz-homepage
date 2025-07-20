import 'package:flutter/material.dart';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/category.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/widgets/quiz_card.dart';
import 'package:cognispark/screens/quiz_creator_screen.dart';

class QuizLibraryScreen extends StatefulWidget {
  final String? categoryFilter;

  const QuizLibraryScreen({super.key, this.categoryFilter});

  @override
  State<QuizLibraryScreen> createState() => _QuizLibraryScreenState();
}

class _QuizLibraryScreenState extends State<QuizLibraryScreen> {
  List<Quiz> allQuizzes = [];
  List<Quiz> filteredQuizzes = [];
  List<QuizCategory> categories = [];
  String? selectedCategoryId;
  String searchQuery = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    selectedCategoryId = widget.categoryFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    final quizzes = await StorageService.getQuizzes();
    final categoriesData = await StorageService.getCategories();
    
    setState(() {
      allQuizzes = quizzes;
      categories = categoriesData;
      isLoading = false;
    });
    
    _filterQuizzes();
  }

  void _filterQuizzes() {
    setState(() {
      filteredQuizzes = allQuizzes.where((quiz) {
        final matchesCategory = selectedCategoryId == null || 
                               quiz.categoryId == selectedCategoryId;
        final matchesSearch = searchQuery.isEmpty ||
                             quiz.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
                             quiz.description.toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  Future<void> _deleteQuiz(Quiz quiz) async {
    await StorageService.deleteQuiz(quiz.id);
    await _loadData();
  }

  void _editQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizCreatorScreen(editQuiz: quiz),
      ),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Library'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QuizCreatorScreen()),
            ).then((_) => _loadData()),
            icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(theme),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildQuizList(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: (value) {
              searchQuery = value;
              _filterQuizzes();
            },
            decoration: InputDecoration(
              hintText: 'Search quizzes...',
              prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
          const SizedBox(height: 16),
          // Category filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: selectedCategoryId == null,
                  onSelected: (selected) {
                    setState(() {
                      selectedCategoryId = selected ? null : selectedCategoryId;
                    });
                    _filterQuizzes();
                  },
                  backgroundColor: theme.colorScheme.surface,
                  selectedColor: theme.colorScheme.primaryContainer,
                  checkmarkColor: theme.colorScheme.onPrimaryContainer,
                  labelStyle: TextStyle(
                    color: selectedCategoryId == null
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 8),
                ...categories.map((category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(category.icon),
                        const SizedBox(width: 4),
                        Text(category.name),
                      ],
                    ),
                    selected: selectedCategoryId == category.id,
                    onSelected: (selected) {
                      setState(() {
                        selectedCategoryId = selected ? category.id : null;
                      });
                      _filterQuizzes();
                    },
                    backgroundColor: theme.colorScheme.surface,
                    selectedColor: theme.colorScheme.primaryContainer,
                    checkmarkColor: theme.colorScheme.onPrimaryContainer,
                    labelStyle: TextStyle(
                      color: selectedCategoryId == category.id
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizList(ThemeData theme) {
    if (filteredQuizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              searchQuery.isNotEmpty || selectedCategoryId != null
                  ? Icons.search_off
                  : Icons.quiz_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty || selectedCategoryId != null
                  ? 'No quizzes found'
                  : 'No quizzes yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searchQuery.isNotEmpty || selectedCategoryId != null
                  ? 'Try adjusting your search or filters'
                  : 'Create your first quiz to get started!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            if (searchQuery.isEmpty && selectedCategoryId == null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const QuizCreatorScreen()),
                  ).then((_) => _loadData()),
                  icon: Icon(Icons.add, color: theme.colorScheme.onPrimary),
                  label: Text('Create Quiz', style: TextStyle(color: theme.colorScheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredQuizzes.length,
      itemBuilder: (context, index) {
        final quiz = filteredQuizzes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: QuizCard(
            quiz: quiz,
            onDelete: () => _deleteQuiz(quiz),
            onEdit: () => _editQuiz(quiz),
          ),
        );
      },
    );
  }
}