import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardylog/services/api_service.dart';
import '../models/lap_time_model.dart';
import '../models/study_session_model.dart';
import '../models/subject_model.dart';
import '../services/api_service.dart';
import '../models/lap_time_model.dart';

class StudyProvider with ChangeNotifier {
  List<StudySession> _sessions = [];
  List<Subject> _subjects = [];

  List<StudySession> get sessions => _sessions;
  List<Subject> get subjects => _subjects;

  // --- 실시간 타이머 상태 ---
  StudySession? _currentSession;
  StudySession? get currentSession => _currentSession;

  bool _isPaused = false;
  bool get isPaused => _isPaused;

  DateTime? _lapStartTime;
  DateTime? get lapStartTime => _lapStartTime;

  List<LapTime> _lapTimes = [];
  List<LapTime> get lapTimes => _lapTimes;

  int _totalStudySeconds = 0;
  int get totalStudySeconds => _totalStudySeconds;

  int _totalBreakSeconds = 0;
  int get totalBreakSeconds => _totalBreakSeconds;
  // ---

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final subjectsData = prefs.getString('studySubjects');
    if (subjectsData != null) {
      final List<dynamic> decoded = jsonDecode(subjectsData);
      _subjects = decoded.map((item) => Subject.fromJson(item)).toList();
    } else {
      _subjects = _getDefaultSubjects(); // 샘플 데이터 사용
      await _saveSubjects();
    }

    // 2. 공부 기록(Session)은 서버에서 가져오도록 변경
    try {
      final List<dynamic> serverLogs = await ApiService.fetchStudyLogs();
      
      // 3. 서버 데이터(StudyLogResponse)를 앱 모델(StudySession)로 변환
      _sessions = serverLogs.map((log) {
        String subjectName = log['subjectName'];
        // 서버에서 받은 subjectName을 기준으로 로컬 _subjects 리스트에서 subjectId 찾기
        String subjectId = _subjects.firstWhere(
          (s) => s.name == subjectName,
          orElse: () => _subjects.first, // 못찾으면 첫번째 과목으로 지정
        ).id;
        
        DateTime startTime = DateTime.parse(log['startTime']);
        DateTime endTime = DateTime.parse(log['endTime']);
        String intervalType = log['intervalType'] ?? 'STUDY'; // "study" or "breakTime"

        int duration = log['durationSeconds'] ?? 0;
        
        return StudySession(
          id: log['id'].toString(),
          subjectId: subjectId,
          startTime: startTime, 
          endTime: endTime,
          date: DateFormat('yyyy-MM-dd').format(endTime.toLocal()), // 현지 시간 기준으로 날짜 저장
          studyDuration: intervalType == 'STUDY' ? duration : 0,
          breakDuration: intervalType == 'BREAK' ? duration : 0,
        );
      }).toList();
      
      print("서버에서 ${serverLogs.length}개의 공부 기록을 로드했습니다.");

    } catch (e) {
      print("서버 로그 로드 실패: $e");
      _sessions = []; // 실패 시 비우기
    }

    notifyListeners();
  }
  
  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encoded = _sessions.map((s) => s.toJson()).toList();
    await prefs.setString('studySessions', jsonEncode(encoded));
  }
  
  Future<void> _saveSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encoded = _subjects.map((s) => s.toJson()).toList();
    await prefs.setString('studySubjects', jsonEncode(encoded));
  }

  void addSession(StudySession session) {
    _sessions.add(session);
    _saveSessions();
    notifyListeners();
  }

  void addSubject(Subject subject) {
    _subjects.add(subject);
    _saveSubjects();
    notifyListeners();
  }
  
  void deleteSubject(String id) {
    if (_subjects.length <= 1) return;
    _subjects.removeWhere((s) => s.id == id);
    _saveSubjects();
    notifyListeners();
  }

  // 샘플 데이터
  List<Subject> _getDefaultSubjects() {
    return [
      Subject(id: '1', name: '수학', color: const Color(0xFF3b82f6)),
      Subject(id: '2', name: '영어', color: const Color(0xFF10b981)),
      Subject(id: '3', name: '국어', color: const Color(0xFFf59e0b)),
      Subject(id: '4', name: '과학', color: const Color(0xFF8b5cf6)),
    ];
  }
  
  StudySession _getSampleSession() {
      final today = DateTime.now();
      final tuesday = today.subtract(Duration(days: today.weekday - 2));
      final tuesdayDate = "${tuesday.year}-${tuesday.month.toString().padLeft(2, '0')}-${tuesday.day.toString().padLeft(2, '0')}";
      return StudySession(
        id: 'sample-1',
        subjectId: '1',
        startTime: DateTime(tuesday.year, tuesday.month, tuesday.day, 5),
        endTime: DateTime(tuesday.year, tuesday.month, tuesday.day, 6),
        date: tuesdayDate,
        studyDuration: 3600
      );
  }
  
  // 이하는 타이머 로직을 위한 함수들입니다.
  // 이 부분은 StudyTrackerScreen에서 직접 호출하여 상태를 변경합니다.
  void startStudy(String subjectId) {
    final now = DateTime.now();
    _currentSession = StudySession(
      id: now.millisecondsSinceEpoch.toString(),
      subjectId: subjectId,
      startTime: now,
      date: "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}",
    );
    _isPaused = false;
    _lapStartTime = now;
    _lapTimes = [];
    _totalStudySeconds = 0;
    _totalBreakSeconds = 0;
    notifyListeners();
  }

  void stopStudy() async {
    if (_currentSession == null || _lapStartTime == null) return;
    final now = DateTime.now();
    final duration = now.difference(_lapStartTime!);

    List<LapTime> finalLaps = List.from(_lapTimes);

    if (_isPaused) {
      finalLaps.add(LapTime(
        id: now.millisecondsSinceEpoch.toString(),
        type: LapType.breakTime,
        duration: duration,
        subjectId: _currentSession!.subjectId,
        timestamp: now
      ));
    } else {
      finalLaps.add(LapTime(
        id: now.millisecondsSinceEpoch.toString(),
        type: LapType.study,
        duration: duration,
        subjectId: _currentSession!.subjectId,
        timestamp: now
      ));
    }

    try {
      final subject = _subjects.firstWhere((s) => s.id == currentSession!.subjectId);
      await ApiService.saveStudyLaps(finalLaps, _currentSession!.id, subject.name);

      await loadData();
    } catch (e) {
      print("서버 전송 실패: $e");
    }

    _currentSession = null;
    _isPaused = false;
    _lapStartTime = null;
    _lapTimes = [];
    _totalStudySeconds = 0;
    _totalBreakSeconds = 0;
  }

  void pauseStudy() {
    if (_currentSession == null || _isPaused || _lapStartTime == null) return;

    final now = DateTime.now();
    final duration = now.difference(_lapStartTime!);
    _totalStudySeconds += duration.inSeconds;

    _lapTimes.add(LapTime(
        id: now.millisecondsSinceEpoch.toString(),
        type: LapType.study,
        duration: duration,
        subjectId: _currentSession!.subjectId,
        timestamp: now));

    _isPaused = true;
    _lapStartTime = now; // 쉬는 시간 시작
    notifyListeners();
  }
  
  void resumeStudy() {
    if (_currentSession == null || !_isPaused || _lapStartTime == null) return;

    final now = DateTime.now();
    final duration = now.difference(_lapStartTime!);
    _totalBreakSeconds += duration.inSeconds;

    _lapTimes.add(LapTime(
        id: now.millisecondsSinceEpoch.toString(),
        type: LapType.breakTime,
        duration: duration,
        subjectId: _currentSession!.subjectId,
        timestamp: now));

    _isPaused = false;
    _lapStartTime = now; // 공부 시간 다시 시작
    notifyListeners();
  }
}