import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:google_sign_in/google_sign_in.dart';
import '../services/api_service.dart';

// ### 1. 인증 상태를 명확한 열거형(enum)으로 정의 ###
enum AuthStatus {
  uninitialized, // 초기화 전
  unauthenticated, // 비로그인
  authenticating, // 로그인 중
  authenticated, // 로그인 완료 (닉네임도 있음)
  needsProfile, // 로그인 완료 (닉네임 설정 필요)
}

class AuthProvider with ChangeNotifier {
  final _auth = firebase.FirebaseAuth.instance;
  
  // Firebase에서 제공하는 유저 정보
  firebase.User? _firebaseUser;
  firebase.User? get firebaseUser => _firebaseUser;

  // 우리 서버(DB)에 저장된 유저 상세 정보
  Map<String, dynamic>? _userDetails;
  Map<String, dynamic>? get userDetails => _userDetails;

  AuthStatus _status = AuthStatus.uninitialized;
  AuthStatus get status => _status;

  // 앱 시작 시 Firebase의 현재 로그인 상태를 확인하는 초기화 함수
  Future<void> initialize() async {
    // 잠시 지연을 주어 앱이 완전히 빌드될 시간을 줌
    await Future.delayed(const Duration(milliseconds: 50)); 
    _auth.authStateChanges().listen(_onAuthStateChanged);
    // ### 1. 현재 유저 정보를 명시적으로 확인하는 로직 추가 ###
    // 앱이 시작될 때 현재 로그인된 사용자가 있는지 즉시 확인합니다.
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      // 현재 로그인된 사용자가 없으면 비로그인 상태로 확정
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } else {
      // 로그인된 사용자가 있으면, 상태 변경 로직을 바로 실행
      await _onAuthStateChanged(currentUser);
    }
  }

  // Firebase 인증 상태가 변경될 때마다 호출됨
  Future<void> _onAuthStateChanged(firebase.User? user) async {
      // 로그아웃 상태이면 상세 정보도 초기화
    if (user == null) {
      _firebaseUser = null;
      _userDetails = null;
    } else {
      // 로그인 상태
      _firebaseUser = user;
      // 서버에서 사용자 정보 가져오기
      try {
        _userDetails = await ApiService.fetchMe();
        if (_userDetails?['displayName'] == null || (_userDetails!['displayName'] as String).isEmpty) {
          // 닉네임이 없으면 프로필 설정 필요 상태
          _status = AuthStatus.needsProfile;
        } else {
          // 닉네임이 있으면 완전히 로그인된 상태
          _status = AuthStatus.authenticated;
        }
      } catch (e) {
        // 서버 통신 실패 시, 일단 프로필 설정 화면으로 보냄
        print("유저 정보 로드 실패: $e");
        _status = AuthStatus.needsProfile;
      }
    }
    // 모든 로직이 끝난 후 마지막에 한번만 UI 업데이트 신호를 보냄
    notifyListeners();
  }

  Future<void> signInWithGoogle() async {
    _status = AuthStatus.authenticating;
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) return;

      final tokens = await account.authentication;
      final credential = firebase.GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: tokens.accessToken,
      );
      await _auth.signInWithCredential(credential);
      // 성공하면 _onAuthStateChanged가 자동으로 호출됨
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }
  
  // Kakao 로그인 (기존 로직 유지)
  Future<void> signInWithKakao() async {
    _status = AuthStatus.authenticating;
    notifyListeners();
    try {
      final provider = firebase.OAuthProvider('oidc.kakao');
      await _auth.signInWithProvider(provider);
    } catch (e) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }
    // 닉네임 설정 후 호출될 함수
  Future<void> refreshUserDetails() async {
    await _onAuthStateChanged(_firebaseUser);
  }
}