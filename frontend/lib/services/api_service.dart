import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8080";

  static Future<void> testBackend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("로그인 필요");
      return;
    }

    final token = await user.getIdToken(true);
    final response = await http.get(
      Uri.parse("$baseUrl/me"),
      headers: {
        "Authorization": "Bearer $token",
      },
    );
    
    print("백엔드 응답: ${response.statusCode} - ${response.body}");
    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final json = jsonDecode(response.body);
      print("서버에서 받은 유저: $json");
    }
  }
}