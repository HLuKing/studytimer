import 'package:flutter/material.dart';
import '../routes/app_router.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _loading = false; String? _error;

  Future<void> _run(Future f) async {
    setState(() { _loading = true; _error = null;});
    try { await f; if (mounted) Navigator.pushReplacementNamed(context, Routes.home);}
    catch (e) {setState(() => _error = '$e');}
    finally {if(mounted) setState(() => _loading = false);}
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('안녕하세요', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: Colors.red)), const SizedBox(height: 12),
                      ],
                      FilledButton.icon(
                        onPressed: _loading ? null : () => _run(_auth.signInWithGoogle()),
                        icon: const Icon(Icons.login), label: const Text('구글로 로그인하기'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : () => _run(_auth.signInWithKakaoOIDC()),
                          icon: const Icon(Icons.chat_bubble_outline), label: const Text('카카오로 로그인하기'),
                        ),
                        if (_loading) ...[const SizedBox(height: 20), const CircularProgressIndicator()],
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}