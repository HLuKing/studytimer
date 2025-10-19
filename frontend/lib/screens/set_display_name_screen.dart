import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart'; // 아이콘을 위해 import
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class SetDisplayNameScreen extends StatefulWidget {
  const SetDisplayNameScreen({super.key});

  @override
  State<SetDisplayNameScreen> createState() => _SetDisplayNameScreenState();
}

class _SetDisplayNameScreenState extends State<SetDisplayNameScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isLoading = false;
  String? _apiError; // 서버에서 받은 에러 메시지

  Future<void> _submit() async {
    // 폼 유효성 검사
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _apiError = null; // 에러 초기화
    });

    try {
      // 1. API Service를 통해 닉네임 설정 시도
      await ApiService.setDisplayName(_controller.text.trim());
      
      if (mounted) {
        // 2. 성공 시, AuthProvider의 유저 정보 갱신 요청
        // (이 함수가 AuthWrapper를 재빌드하여 HomeScreen으로 이동시킴)
        await Provider.of<AuthProvider>(context, listen: false).refreshUserDetails();
      }
    } catch (e) {
      // 3. 실패 시 (닉네임 중복 등) 에러 메시지 표시
      if (mounted) {
        setState(() {
          _apiError = e.toString().replaceFirst("Exception: ", ""); // "Exception: " 부분 제거
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 1. 로그인 화면과 동일한 배경색
      backgroundColor: Colors.grey[100], 
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 2. 로그인 화면과 동일한 카드 스타일 적용
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 5,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 3. 적절한 아이콘과 텍스트로 변경
                      const Icon(LucideIcons.userCheck, size: 60, color: Colors.black54),
                      const SizedBox(height: 16),
                      const Text(
                        '환영합니다!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '사용하실 닉네임을 입력해주세요.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 40),
                      
                      // 4. TextFormField 스타일링
                      TextFormField(
                        controller: _controller,
                        decoration: InputDecoration(
                          labelText: '닉네임',
                          hintText: '2~20자, 한글/영문/숫자/밑줄',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          // 서버 에러 메시지가 있으면 표시
                          errorText: _apiError,
                        ),
                        // 5. 닉네임 유효성 검사 (서버 규칙과 동일하게)
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '닉네임을 입력해주세요.';
                          }
                          if (value.trim().length < 2 || value.trim().length > 20) {
                            return '닉네임은 2자에서 20자 사이여야 합니다.';
                          }
                          // 정규식 검사 (서버 DTO와 동일)
                          final RegExp regex = RegExp(r"^[a-zA-Z0-9가-힣_]+$");
                          if (!regex.hasMatch(value.trim())) {
                             return '한글/영문/숫자/밑줄만 사용 가능합니다.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // 6. 버튼 스타일링 및 로딩 처리
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton( // <-- OutlinedButton으로 변경
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 50),
                                // 버튼 배경색 (파란색 계열)
                                backgroundColor: Colors.black87, 
                                // 그림자 색상
                                foregroundColor: Colors.white,
                                // 그림자 추가 (elevation)
                                elevation: 4,
                                shadowColor: Colors.black.withOpacity(0.2), 

                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                '시작하기', 
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
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
      ),
    );
  }
}