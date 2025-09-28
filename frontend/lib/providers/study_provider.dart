import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stardylog/services/api_service.dart';
import '../models/lap_time_model.dart';
import '../models/study_session_model.dart';
import '../models/subject_model.dart';

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
    // 세션 로드
    final sessionsData = prefs.getString('studySessions');
    if (sessionsData != null) {
      final List<dynamic> decoded = jsonDecode(sessionsData);
      _sessions = decoded.map((item) => StudySession.fromJson(item)).toList();
    } else {
      _sessions = [_getSampleSession()];
      await _saveSessions();
    }
    // 과목 로드
    final subjectsData = prefs.getString('studySubjects');
    if (subjectsData != null) {
      final List<dynamic> decoded = jsonDecode(subjectsData);
      _subjects = decoded.map((item) => Subject.fromJson(item)).toList();
    } else {
      _subjects = _getDefaultSubjects();
      await _saveSubjects();
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

    if (_isPaused) {
      _totalBreakSeconds += duration.inSeconds;
    } else {
      _totalStudySeconds += duration.inSeconds;
    }

    final completedSession = StudySession(
      id: _currentSession!.id,
      subjectId: _currentSession!.subjectId,
      startTime: _currentSession!.startTime,
      endTime: now,
      date: _currentSession!.date,
      studyDuration: _totalStudySeconds,
      breakDuration: _totalBreakSeconds,
    );
    _sessions.add(completedSession);
    _saveSessions();

    try {
      final subject = _subjects.firstWhere((s) => s.id == completedSession.subjectId);
      await ApiService.saveStudyLog(completedSession, subject.name);
    } catch (e) {
      print("서버 전송 실패: $e");
    }

    _currentSession = null;
    _isPaused = false;
    _lapStartTime = null;
    _lapTimes = [];
    _totalStudySeconds = 0;
    _totalBreakSeconds = 0;
    notifyListeners();
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