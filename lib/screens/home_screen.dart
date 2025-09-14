import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../routes/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context){
    final auth = AuthService();
    final user = auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text("홈"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context, Routes.login, (_) => false);
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Text(
          '로그인 성공!\n${user?.displayName ?? user?.email ?? user?.uid}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}