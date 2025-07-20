import 'package:flutter/material.dart';
import 'package:cognispark/theme.dart';
import 'package:cognispark/screens/home_screen.dart';
import 'package:cognispark/screens/landing_screen.dart';
import 'package:cognispark/services/storage_service.dart';
import 'package:cognispark/services/quiz_service.dart';
import 'package:cognispark/services/admin_dashboard_service.dart';
import 'package:cognispark/services/auth_service.dart';
import 'package:cognispark/models/user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage and default data
  await StorageService.initializeDefaultData();
  
  // Initialize authentication service
  await AuthService.instance.initialize();
  
  // Initialize sample quiz data if needed
  await QuizService.initializeSampleData();
  
  // Initialize admin dashboard services
  AdminDashboardService().initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CogniSpark',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserSession?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final session = snapshot.data;
        if (session != null && !session.isExpired) {
          return const HomePage();
        } else {
          return const LandingScreen();
        }
      },
    );
  }
}
