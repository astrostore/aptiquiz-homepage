class QuizCategory {
  final String id;
  final String name;
  final String icon;
  final String description;

  QuizCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });

  factory QuizCategory.fromJson(Map<String, dynamic> json) => QuizCategory(
        id: json['id'],
        name: json['name'],
        icon: json['icon'],
        description: json['description'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'description': description,
      };

  static List<QuizCategory> getDefaultCategories() => [
        QuizCategory(
          id: 'general',
          name: 'General Knowledge',
          icon: '🧠',
          description: 'Test your general knowledge across various topics',
        ),
        QuizCategory(
          id: 'science',
          name: 'Science & Technology',
          icon: '🔬',
          description: 'Explore the world of science and technology',
        ),
        QuizCategory(
          id: 'history',
          name: 'History & Geography',
          icon: '🏛️',
          description: 'Journey through history and explore geography',
        ),
        QuizCategory(
          id: 'math',
          name: 'Mathematics',
          icon: '🔢',
          description: 'Challenge your mathematical abilities',
        ),
        QuizCategory(
          id: 'literature',
          name: 'Literature & Arts',
          icon: '📚',
          description: 'Dive into literature and artistic knowledge',
        ),
      ];
}