import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const StardylogApp());
}

class StardylogApp extends StatelessWidget {
  const StardylogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'stardylog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: Routes.welcome,
    );
  }
}