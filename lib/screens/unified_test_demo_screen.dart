import 'package:flutter/material.dart';
import 'package:cognispark/models/user.dart';
import 'package:cognispark/models/quiz.dart';
import 'package:cognispark/models/test_session.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/services/test_engine.dart';
import 'package:cognispark/services/regular_user_test_interface.dart';
import 'package:cognispark/services/super_admin_test_manager.dart';
import 'package:cognispark/services/admin_dashboard_service.dart';
import 'package:cognispark/services/access_control_service.dart';

class UnifiedTestDemoScreen extends StatefulWidget {
  const UnifiedTestDemoScreen({super.key});

  @override
  State<UnifiedTestDemoScreen> createState() => _UnifiedTestDemoScreenState();
}

class _UnifiedTestDemoScreenState extends State<UnifiedTestDemoScreen> {
  User? currentUser;
  List<Quiz> availableQuizzes = [];
  List<TestSession> activeSessions = [];
  bool isLoading = true;
  String statusMessage = '';

  final TestEngine _testEngine = TestEngine();
  final RegularUserTestInterface _userInterface = RegularUserTestInterface();
  final SuperAdminTestManager _adminManager = SuperAdminTestManager();
  final AdminDashboardService _dashboardService = AdminDashboardService();
  final AccessControlService _accessControl = AccessControlService();

  @override
  void initState() {
    super.initState();
    _initializeDemo();
  }

  Future<void> _initializeDemo() async {
    try {
      // Get current user (should be the default admin created in main.dart)
      currentUser = await StorageService.getCurrentUser();
      
      if (currentUser != null) {
        // Load available quizzes for the user
        availableQuizzes = await _userInterface.getAvailableQuizzes();
        
        // Load active sessions for the user
        activeSessions = await _userInterface.getActiveQuizzes(currentUser!);
        
        setState(() {
          statusMessage = 'Demo initialized successfully';
          isLoading = false;
        });
      } else {
        setState(() {
          statusMessage = 'No user found - please check initialization';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Error initializing demo: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _startQuizDemo(Quiz quiz) async {
    if (currentUser == null) return;
    
    try {
      setState(() {
        statusMessage = 'Starting quiz: ${quiz.title}...';
      });
      
      // Use the unified test engine to start a quiz
      final session = await _userInterface.startNewQuiz(currentUser!, quiz);
      
      setState(() {
        statusMessage = 'Quiz started! Session ID: ${session.sessionId}';
        activeSessions.add(session);
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error starting quiz: $e';
      });
    }
  }

  Future<void> _demonstratePermissions() async {
    if (currentUser == null) return;
    
    try {
      // Test various permission checks
      final canCreateQuiz = await _accessControl.hasPermission(
        currentUser!, 
        Permission.createQuiz
      );
      
      final canManageUsers = await _accessControl.hasPermission(
        currentUser!, 
        Permission.manageUserRoles
      );
      
      final canViewAnalytics = await _accessControl.hasPermission(
        currentUser!, 
        Permission.viewSystemAnalytics
      );
      
      setState(() {
        statusMessage = '''
Permission Check Results:
• Create Quiz: ${canCreateQuiz ? '✅' : '❌'}
• Manage Users: ${canManageUsers ? '✅' : '❌'}  
• View Analytics: ${canViewAnalytics ? '✅' : '❌'}
User Role: ${currentUser!.roleDisplayName}
        ''';
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error checking permissions: $e';
      });
    }
  }

  Future<void> _demonstrateAdminFeatures() async {
    if (currentUser == null) return;
    
    try {
      setState(() {
        statusMessage = 'Fetching dashboard metrics...';
      });
      
      // Get system analytics (admin feature)
      final systemAnalytics = await _adminManager.getSystemAnalytics(currentUser!);
      
      setState(() {
        statusMessage = '''
System Analytics:
• Total Users: ${systemAnalytics.totalUsers}
• Active Users: ${systemAnalytics.activeUsers}
• Total Quizzes: ${systemAnalytics.totalQuizzes}
• Total Sessions: ${systemAnalytics.totalSessions}
• Completed Sessions: ${systemAnalytics.completedSessions}
        ''';
      });
    } catch (e) {
      setState(() {
        statusMessage = 'Error fetching admin data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unified Test Engine Demo'),
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current User',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          if (currentUser != null) ...[
                            Text('Name: ${currentUser!.name}'),
                            Text('Email: ${currentUser!.email}'),
                            Text('Role: ${currentUser!.roleDisplayName}'),
                            Text('ID: ${currentUser!.id}'),
                          ] else
                            const Text('No user logged in'),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Demo Actions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Demo Actions',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          
                          // Permission Demo Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _demonstratePermissions,
                              icon: const Icon(Icons.security),
                              label: const Text('Test Permissions'),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Admin Features Demo Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _demonstrateAdminFeatures,
                              icon: const Icon(Icons.admin_panel_settings),
                              label: const Text('Demo Admin Features'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Available Quizzes
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available Quizzes (${availableQuizzes.length})',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (availableQuizzes.isEmpty)
                            const Text('No quizzes available')
                          else
                            ...availableQuizzes.take(3).map((quiz) => 
                              ListTile(
                                title: Text(quiz.title),
                                subtitle: Text(quiz.description),
                                trailing: ElevatedButton(
                                  onPressed: () => _startQuizDemo(quiz),
                                  child: const Text('Start'),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Active Sessions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Sessions (${activeSessions.length})',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          if (activeSessions.isEmpty)
                            const Text('No active sessions')
                          else
                            ...activeSessions.map((session) => 
                              ListTile(
                                title: Text('Session: ${session.sessionId}'),
                                subtitle: Text('Status: ${session.statusDisplayName}'),
                                trailing: Text('Progress: ${session.progressPercentage.toStringAsFixed(1)}%'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Status Messages
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceVariant,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusMessage.isEmpty ? 'Ready' : statusMessage,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _testEngine.dispose();
    super.dispose();
  }
}