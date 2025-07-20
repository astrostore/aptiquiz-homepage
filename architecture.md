# CogniSpark - Quiz Generation & Management System Architecture

## Overview
CogniSpark is a comprehensive quiz/test generation and management system that allows users to create, manage, take, and analyze quizzes with an intuitive Flutter interface.

## Core Features (MVP)

### 1. Quiz Creation & Management
- Create custom quizzes with various question types
- Edit existing quizzes
- Delete unwanted quizzes
- Organize quizzes by categories/subjects

### 2. Question Types Support
- Multiple Choice Questions (MCQ)
- True/False Questions
- Fill-in-the-blank Questions
- Short Answer Questions

### 3. Quiz Taking Experience
- Interactive quiz interface
- Progress tracking
- Timer functionality
- Immediate feedback option

### 4. Results & Analytics
- Score calculation and display
- Performance history tracking
- Detailed results breakdown
- Statistics dashboard

### 5. Local Storage
- Store quizzes locally using SharedPreferences
- Offline functionality
- Data persistence

## Technical Architecture

### Data Models
1. **Quiz Model**: Contains quiz metadata (title, description, category, etc.)
2. **Question Model**: Base class for different question types
3. **Answer Model**: Stores user responses and correct answers
4. **Result Model**: Quiz attempt results with scoring
5. **Category Model**: Quiz categorization

### Core Services
1. **Quiz Service**: CRUD operations for quizzes
2. **Question Service**: Question management
3. **Storage Service**: Local data persistence
4. **Analytics Service**: Performance tracking and statistics

### UI Structure
1. **Home Screen**: Dashboard with quiz overview and navigation
2. **Quiz Library**: Browse and manage all quizzes
3. **Quiz Creator**: Step-by-step quiz creation wizard
4. **Quiz Player**: Interactive quiz taking interface
5. **Results Screen**: Detailed results and analytics
6. **Statistics Dashboard**: Performance insights

### File Structure
```
lib/
├── main.dart
├── theme.dart
├── models/
│   ├── quiz.dart
│   ├── question.dart
│   ├── answer.dart
│   ├── result.dart
│   └── category.dart
├── services/
│   ├── quiz_service.dart
│   ├── storage_service.dart
│   └── analytics_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── quiz_library_screen.dart
│   ├── quiz_creator_screen.dart
│   ├── quiz_player_screen.dart
│   ├── results_screen.dart
│   └── statistics_screen.dart
└── widgets/
    ├── quiz_card.dart
    ├── question_widgets/
    │   ├── mcq_widget.dart
    │   ├── true_false_widget.dart
    │   ├── fill_blank_widget.dart
    │   └── short_answer_widget.dart
    └── common/
        ├── custom_button.dart
        ├── progress_indicator.dart
        └── stat_card.dart
```

## Implementation Strategy

### Phase 1: Foundation
1. Set up data models and local storage
2. Create basic UI structure and navigation
3. Implement quiz creation functionality

### Phase 2: Core Features
1. Build quiz taking interface with timer
2. Implement result calculation and display
3. Add quiz management features

### Phase 3: Enhancement
1. Analytics and statistics dashboard
2. UI polish with animations
3. Performance optimizations

## Sample Data
The app will include realistic sample quizzes across various subjects:
- General Knowledge
- Science & Technology
- History & Geography
- Mathematics
- Literature & Arts

## Design Principles
- Modern, clean UI with Material Design 3
- Intuitive navigation and user flow
- Responsive design for various screen sizes
- Accessibility-first approach
- Consistent theming and color palette