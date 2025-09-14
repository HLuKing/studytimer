import 'package:flutter/material.dart';
import '../routes/app_router.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _run(Future fn) async {
    setState(() { _loading = true; _error = null; });
    try {
      await fn;
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.home);
      }
    } catch (e) {
      setState(() {_error = '$e'; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인 실패: $e')),
      );
    } finally {
      if(mounted) setState(() { _loading = false; });
    }
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
              const Text('안녕하세요',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 40),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null) ...[
                          Text(_error!, style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 12),
                        ],
                        FilledButton.icon(
                          onPressed: _loading 
                              ? null 
                              : () => _run(_auth.signInWithGoogle()),
                          icon: const Icon(Icons.login),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('구글로 로그인하기'),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await _auth.forceGoogleReauth();
                            await _run(_auth.signInWithGoogle());
                          },
                          child: const Text('다른 계정으로 로그인'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _run(_auth.signInWithKakaoOIDC()),
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('카카오로 로그인하기'),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () async {
                                await _auth.forceKakaoReauth();
                                await _run(_auth.signInWithKakaoOIDC());
                              },
                          icon: const Icon(Icons.refresh),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('카카오 계정 다시 로그인'),
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),

                        const SizedBox(height: 12),

                        ElevatedButton.icon(
                          onPressed: _loading ? null : () async {
                            await _auth.signOut();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('로그아웃 되었습니다.')),
                            );
                          },
                          icon: const Icon(Icons.logout),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('카카오톡 로그아웃'),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            backgroundColor: Colors.redAccent,
                          ),
                        ),
                        if (_loading) ...[
                          const SizedBox(height: 20),
                          const CircularProgressIndicator()
                        ],
                      ],
                    ),
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