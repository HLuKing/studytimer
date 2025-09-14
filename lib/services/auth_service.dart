import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


class AuthService {
  final _auth = FirebaseAuth.instance;

  Future<void> signOut() async {
    await _auth.signOut();
    try { await GoogleSignIn().signOut(); } catch (_) {}
  }

  Future<void> forceGoogleReauth() async {
    // 1) Firebase 인증 세션 종료
    await FirebaseAuth.instance.signOut();

    // 2) 구글 계정 세션 종료 (로컬)
    final google = GoogleSignIn();
    try { await google.signOut(); } catch(_) {}

    // 3) 구글 연결 해제(권한 철회) - 다음 로그인 때 동의/선택창 보장
    try { await google.disconnect(); } catch (_) {}
  }

  // 구글

  Future<User?> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
    final account = await googleSignIn.signIn();
    if (account == null) return null; // 사용자가 취소

    final tokens = await account.authentication; // idToken / accessToken
    final credential = GoogleAuthProvider.credential(
      idToken: tokens.idToken,
      accessToken: tokens.accessToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  //카카오
  /// Firebase 콘솔에 OIDC 제공자:
  /// - Provider ID: oidc.kakao
  /// - Issuer: https://kauth.kakao.com
  /// - Client ID: Kakao REST API 키
  /// - Client Secret: (발급 시)
  /// - Redirect URI들 Kakao에 모두 등록
  Future<User?> signInWithKakaoOIDC({String prompt = 'consent'}) async {
    final provider = OAuthProvider('oidc.kakao');
    provider.setCustomParameters({'prompt': 'prompt'});

    final res = await _auth.signInWithProvider(provider);
    return res.user;
  }

  /// 카카오 계정 재로그인
  /// firebase 세션 끊고
  /// 다시 로그인 화면 강제
  Future<User?> forceKakaoReauth() async {
    await _auth.signOut();
    final provider = OAuthProvider('oidc.kakao');
    provider.setCustomParameters({'prompt': 'login'});
    final res = await _auth.signInWithProvider(provider);
    return res.user;
  }

  Future<void> signOutAll() async {
    await _auth.signOut();
    try { await GoogleSignIn().signOut(); } catch (_) {}
  }

  User? get currentUser => _auth.currentUser;
}