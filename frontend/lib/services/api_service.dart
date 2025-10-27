import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:stardylog/models/study_session_model.dart';
import '../models/lap_time_model.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:8080";

  static Future<Map<String, dynamic>?> fetchMe() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final token = await user.getIdToken();
    print("=========================================");
    print("Firebase ID 토큰 (이것을 복사하세요):");
    print(token);
    print("=========================================");
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

  static Future<void> saveStudyLaps(List<LapTime> laps, String sessionId, String subjectName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || laps.isEmpty) return;

    final token = await user.getIdToken();
    final url = Uri.parse("$baseUrl/api/logs/study");

    final List<Map<String, dynamic>> lapsData = laps.map((lap) {
      final startTime = lap.timestamp.subtract(lap.duration);
      final endTime = lap.timestamp;

      final startTimeString = startTime.toIso8601String();
      final formattedStartTime = startTimeString.endsWith('Z')
          ? startTimeString.substring(0, 23) + 'Z'
          : startTimeString.substring(0, 23) + 'Z';

      final endTimeString = endTime.toIso8601String();
      final formattedEndTime = endTimeString.endsWith('Z')
          ? endTimeString.substring(0, 23) + 'Z'
          : endTimeString.substring(0, 23) + 'Z';

          return {
            'sessionId': sessionId,
            'subjectName': subjectName,
            'intervalType': lap.type == LapType.study ? 'STUDY' : 'BREAK',
            'durationSeconds': lap.duration.inSeconds,
            'startTime': formattedStartTime,
            'endTime': formattedEndTime,
          };
    }).toList();


    final body = jsonEncode(lapsData);

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

  static Future<List<dynamic>> fetchStudyLogs() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    
    final token = await user.getIdToken();
    final url = Uri.parse("$baseUrl/api/logs/study");

    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      // Spring Boot가 반환한 JSON 배열(List)을 디코딩
      // 한글 깨짐 방지를 위해 utf8.decode 사용
      return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    }
    throw Exception("공부 기록 로드 실패: ${res.statusCode}");
  }

  static Future<List<dynamic>> fetchSubjects() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return []; // 로그인 안 했으면 빈 리스트 반환

    final token = await user.getIdToken();
    final url = Uri.parse("$baseUrl/api/subjects");

    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      // UTF-8 디코딩 후 JSON 리스트 반환
      return jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
    } else {
      print("과목 로드 실패: ${res.statusCode} ${res.body}"); // 에러 로그 추가
      throw Exception("과목 로드 실패: ${res.statusCode}");
    }
  }

  // 2. 새 과목 추가하기 (POST /api/subjects)
  static Future<Map<String, dynamic>> addSubject(String name, String colorString) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("로그인이 필요합니다.");

    final token = await user.getIdToken();
    final url = Uri.parse("$baseUrl/api/subjects");

    final body = jsonEncode({
      'name': name,
      'color': colorString, // "0xAARRGGBB" 형식
    });

    final res = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: body,
    );

    if (res.statusCode == 201) { // 201 Created 확인
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else if (res.statusCode == 409) {
      throw Exception("이미 사용 중인 과목 이름입니다.");
    } else {
      print("과목 추가 실패: ${res.statusCode} ${res.body}"); // 에러 로그 추가
      throw Exception("과목 추가 실패: ${res.statusCode}");
    }
  }

  // 3. 과목 수정하기 (PUT /api/subjects/{id})
  static Future<Map<String, dynamic>> updateSubject(int subjectId, String name, String colorString) async {
     final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("로그인이 필요합니다.");

    final token = await user.getIdToken();
    final url = Uri.parse("$baseUrl/api/subjects/$subjectId"); // URL에 ID 포함

    final body = jsonEncode({
      'name': name,
      'color': colorString,
    });

    final res = await http.put( // PUT 메소드 사용
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: body,
    );

     if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } else if (res.statusCode == 409) {
      throw Exception("이미 사용 중인 과목 이름입니다.");
    } else if (res.statusCode == 404) {
      throw Exception("과목을 찾을 수 없거나 수정 권한이 없습니다.");
    } else {
      print("과목 수정 실패: ${res.statusCode} ${res.body}"); // 에러 로그 추가
      throw Exception("과목 수정 실패: ${res.statusCode}");
    }
  }


  // 4. 과목 삭제하기 (DELETE /api/subjects/{id}) - 논리적 삭제
  static Future<void> deleteSubject(int subjectId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("로그인이 필요합니다.");

    final token = await user.getIdToken();
    final url = Uri.parse("$baseUrl/api/subjects/$subjectId"); // URL에 ID 포함

    final res = await http.delete( // DELETE 메소드 사용
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode != 204) { // 204 No Content 확인
       print("과목 삭제 실패: ${res.statusCode} ${res.body}"); // 에러 로그 추가
      throw Exception("과목 삭제 실패: ${res.statusCode}");
    }
     print("과목이 삭제되었습니다 (ID: $subjectId)"); // 성공 로그 추가
  }
}