import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:stardylog/screens/login_screen.dart';
import 'package:stardylog/screens/set_display_name_screen.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/goals_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/study_provider.dart';
import 'screens/home_screen.dart'; // HomeScreen은 이제 메인 탭 화면이 됩니다.

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('ko_KR', null);

  // ### Provider 초기화 로직 추가 ###
  final authProvider = AuthProvider();
  await authProvider.initialize(); // Firebase 유저 상태를 확인하는 초기화

  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  final studyProvider = StudyProvider();
  await studyProvider.loadData();
  
  final goalsProvider = GoalsProvider();
  await goalsProvider.loadGoals();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: studyProvider),
        ChangeNotifierProvider.value(value: goalsProvider),
      ],
      child: const StardylogApp(),
    ),
  );
}

class StardylogApp extends StatelessWidget {
  const StardylogApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ### 테마 적용 로직 추가 ###
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return MaterialApp(
          title: 'stardylog',
          debugShowCheckedModeBanner: false,
          theme: settings.isDarkMode ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true),
          // ### 로그인 상태에 따라 첫 화면 결정 ###
          home: const AuthWrapper(),
          onGenerateRoute: AppRouter.onGenerateRoute,
        );
      },
    );
  }
}

// ### 로그인 상태 확인 위젯 추가 ###
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        switch (auth.status) {
          case AuthStatus.uninitialized:
          case AuthStatus.authenticating:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          
          case AuthStatus.unauthenticated:
            return const LoginScreen();
            
          case AuthStatus.needsProfile:
            return const SetDisplayNameScreen();
            
          case AuthStatus.authenticated:
            return const HomeScreen();
        }
      },
    );
  }
}