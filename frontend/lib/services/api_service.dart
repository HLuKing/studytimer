import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stardylog/models/study_session_model.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8080";

  static Future<Map<String, dynamic>?> fetchMe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    final res = await http.get(
      Uri.parse("$baseUrl/me"),
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception("me 호출 실패: ${res.statusCode}");
  }

  static Future<Map<String, dynamic>> setDisplayName(String displayName) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    final res = await http.post(
      Uri.parse("$baseUrl/me/display-name"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"displayName": displayName})
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } else if (res.statusCode == 409) {
      throw Exception("이미 사용 중인 닉네임입니다.");
    }
    throw Exception("닉네임 설정 실패: ${res.statusCode}");
  }

  static Future<void> saveStudyLog(StudySession session, String subjectName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || session.endTime == null) return;

    final token = await user.getIdToken();
    final url = Uri.parse("$baseUrl/api/logs/study");

    final endTimeString = session.endTime!.toIso8601String();
    final formattedEndTime = endTimeString.endsWith('Z')
        ? endTimeString.substring(0, 23) + 'Z'
        : endTimeString.substring(0, 23) + 'Z';

    final body = jsonEncode({
      'subjectName': subjectName,
      'studyDurationSeconds': session.studyDuration,
      'breakDurationSeconds': session.breakDuration,
      'endTime': formattedEndTime,
    });

    final res = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: body,
    );

    if (res.statusCode != 200) {
      throw Exception("공부 기록 저장 실패: ${res.statusCode} ${res.body}");
    }
    print("공부 기록이 서버에 저장되었습니다.");
  }
}