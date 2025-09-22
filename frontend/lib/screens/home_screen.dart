import 'package:flutter/material.dart';
import 'package:stardylog/services/api_service.dart';
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '로그인 성공!\n${user?.displayName ?? user?.email ?? user?.uid}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            FutureBuilder<String?>(
              future: user?.getIdToken(true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                if (snapshot.hasError) {
                  return Text("토큰 에러: ${snapshot.error}");
                }
                if (!snapshot.hasData) {
                  return const Text("토큰 없음");
                }
                final idToken = snapshot.data!;
                debugPrint("ID_TOKEN: $idToken");

                return Text(
                  "ID Token:\n$idToken",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                await ApiService.testBackend();
              },
              child: const Text("백엔드 연결 테스트"),
            ),
          ],
        ),
      ),
    );
  }
}