import 'package:flutter/material.dart';
import '../routes/app_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: Stack(
        children: [
          const Center(child: Text('환영합니다!',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700))),
          Positioned(
            left:16, right: 16, bottom: 24,
            child: FilledButton(
              onPressed: () => Navigator.pushReplacementNamed(context, Routes.login),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('시작하기', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}