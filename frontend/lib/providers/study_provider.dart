import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    // --- [!] 1. 과목 로딩 변경 ---
    try {
      // ApiService를 통해 서버에서 과목 목록 가져오기
      final List<dynamic> serverSubjects = await ApiService.fetchSubjects();
      // 서버 응답(JSON List)을 Subject 모델 리스트로 변환
      _subjects = serverSubjects.map((json) => Subject.fromJson(json)).toList();
      print("서버에서 ${_subjects.length}개의 과목을 로드했습니다.");
      if (_subjects.isEmpty) {
        // [!] 서버에 과목이 하나도 없을 경우 기본 과목을 *서버에* 추가하는 로직 (선택 사항)
        print("서버에 과목이 없어 기본 과목을 추가합니다.");
        await _addDefaultSubjectsToServer(); // 아래에 새로 추가될 함수
        // 다시 로드
        final List<dynamic> reloadedSubjects = await ApiService.fetchSubjects();
        _subjects = reloadedSubjects.map((json) => Subject.fromJson(json)).toList();
      }
    } catch (e) {
      print("서버 과목 로드 실패: $e");
      _subjects = []; // 실패 시 빈 리스트
    }
    // ---

    // --- 2. 공부 기록 로딩 (기존 로직 유지, 단 과목 ID 매칭 수정) ---
    try {
      final List<dynamic> serverLogs = await ApiService.fetchStudyLogs();
      _sessions = serverLogs.map((log) {
        String subjectName = log['subjectName'];
        // [!] 서버에서 받은 subjectName을 기준으로 로컬 _subjects 리스트에서 Subject 찾기
        Subject foundSubject = _subjects.firstWhere(
          (s) => s.name == subjectName,
          // 못 찾으면 ID가 null인 임시 Subject 객체 생성 (오류 방지)
          orElse: () => Subject(name: subjectName, color: Colors.grey, serverId: 'unknown'),
        );

        DateTime startTime = DateTime.parse(log['startTime']);
        DateTime endTime = DateTime.parse(log['endTime']);
        String intervalType = log['intervalType'] ?? 'STUDY';
        int duration = log['durationSeconds'] ?? 0;

        return StudySession(
          id: log['id'].toString(), // 서버 로그 ID
          // [!] 찾은 Subject의 serverId 사용
          subjectId: foundSubject.serverId,
          startTime: startTime,
          endTime: endTime,
          date: DateFormat('yyyy-MM-dd').format(endTime.toLocal()),
          studyDuration: intervalType == 'STUDY' ? duration : 0,
          breakDuration: intervalType == 'BREAK' ? duration : 0,
          intervalType: intervalType,
        );
      }).toList();
      print("서버에서 ${serverLogs.length}개의 공부 기록을 로드했습니다.");
    } catch (e) {
      print("서버 로그 로드 실패: $e");
      _sessions = [];
    }

    notifyListeners();
  }

  void addSession(StudySession session) {
    _sessions.add(session);
    notifyListeners();
  }

  Future<void> addSubject(String name, Color color) async {
    // 색상을 "0xAARRGGBB" 문자열로 변환
    String colorString = '0x${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    try {
      // ApiService 호출하여 서버에 추가
      final Map<String, dynamic> newSubjectJson = await ApiService.addSubject(name, colorString);
      // 서버 응답을 Subject 모델로 변환
      final newSubject = Subject.fromJson(newSubjectJson);
      // 로컬 리스트에 추가
      _subjects.add(newSubject);
      notifyListeners(); // UI 업데이트
      print("과목 추가 성공: ${newSubject.name}");
    } catch (e) {
      print("과목 추가 실패: $e");
      // TODO: 사용자에게 에러 메시지 표시 (예: 스낵바)
      rethrow; // 에러를 다시 던져서 UI에서 처리할 수 있게 함
    }
  }
  
  Future<void> deleteSubject(int subjectId) async {
    // [!] ID 타입이 int인지 확인
    if (_subjects.length <= 1) {
       print("과목 삭제 실패: 최소 1개의 과목이 필요합니다.");
       // TODO: 사용자에게 알림
       return;
    }
    try {
      // ApiService 호출하여 서버에서 논리적 삭제
      await ApiService.deleteSubject(subjectId);
      // 로컬 리스트에서 해당 과목 제거
      _subjects.removeWhere((s) => s.id == subjectId);
      notifyListeners(); // UI 업데이트
      print("과목 삭제 성공 (ID: $subjectId)");
    } catch (e) {
      print("과목 삭제 실패: $e");
      // TODO: 사용자에게 에러 메시지 표시
      rethrow;
    }
  }

  Future<void> _addDefaultSubjectsToServer() async {
    // 기본 과목 목록 정의 (색상 포함)
    final defaultSubjects = [
      {'name': '수학', 'color': const Color(0xFF030213)},
      {'name': '영어', 'color': const Color(0xFF10b981)},
      {'name': '국어', 'color': const Color(0xFFf59e0b)},
    ];

    for (var subjectData in defaultSubjects) {
      try {
        String colorString = '0x${(subjectData['color']! as Color).value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
        await ApiService.addSubject(subjectData['name'] as String, colorString);
         print("기본 과목 추가: ${subjectData['name']}");
      } catch (e) {
        // 이미 존재하는 과목이거나 다른 오류 발생 시 무시하고 다음 과목 시도
        print("기본 과목 '${subjectData['name']}' 추가 중 오류 발생 (무시됨): $e");
      }
    }
  }
  
  // 이하는 타이머 로직을 위한 함수들입니다.
  // 이 부분은 StudyTrackerScreen에서 직접 호출하여 상태를 변경합니다.
  void startStudy(int? subjectServerId) { // [!] 타입 변경
     // [!] subjectServerId가 null이면 시작하지 않음 (오류 방지)
    if (subjectServerId == null) {
      print("과목 ID가 없어 타이머를 시작할 수 없습니다.");
      // TODO: 사용자에게 알림 (과목 선택 필요)
      return;
    }
    final now = DateTime.now();
    _currentSession = StudySession(
      // id는 서버에서 생성되므로 여기서는 임시값 사용 안 함 (또는 로컬 임시 ID)
      id: now.millisecondsSinceEpoch.toString(), // 로컬 임시 ID
      // [!] subjectId 대신 subjectServerId 사용 (DB ID) -> StudySession 모델 수정 필요!
      //     => StudySession 모델은 String subjectId를 유지하고, stopStudy에서 변환하는게 나을 수 있음
      //     => 여기서는 일단 serverId를 String으로 변환해서 기존 모델 유지
      subjectId: subjectServerId.toString(),
      startTime: now,
      date: DateFormat('yyyy-MM-dd').format(now),
      intervalType: 'STUDY', // 시작은 항상 STUDY
    );
    _isPaused = false;
    _lapStartTime = now;
    _lapTimes = [];
    _totalStudySeconds = 0;
    _totalBreakSeconds = 0;
    notifyListeners();
  }

  Future<void> stopStudy() async {
    if (_currentSession == null || _lapStartTime == null) return;
    final now = DateTime.now();
    final duration = now.difference(_lapStartTime!);

    List<LapTime> finalLaps = List.from(_lapTimes);

    // 마지막 랩 타임 추가
    finalLaps.add(LapTime(
      id: now.millisecondsSinceEpoch.toString(),
      type: _isPaused ? LapType.breakTime : LapType.study,
      duration: duration,
      subjectId: _currentSession!.subjectId, // 현재 세션의 (임시 또는 서버) 과목 ID
      timestamp: now
    ));

    try {
      // [!] 현재 세션의 subjectId (String)를 이용해 Subject 객체 찾기
      final subject = _subjects.firstWhere(
        (s) => s.serverId == _currentSession!.subjectId, // serverId로 비교
        orElse: () => _subjects.first // 못찾으면 첫번째 과목 사용 (예외 처리)
      );

      // [!] 서버 저장 함수 호출 시 sessionId와 과목 이름 전달
      //     currentSession.id는 현재 로컬 임시 ID이므로, 서버 저장을 위해 고유한 ID 생성 필요
      //     여기서는 간단하게 startTime의 밀리초 사용 (서버에서 session_id 컬럼으로 관리)
      String sessionId = _currentSession!.startTime.millisecondsSinceEpoch.toString();
      await ApiService.saveStudyLaps(finalLaps, sessionId, subject.name);

      // 데이터 다시 로드
      await loadData();
    } catch (e) {
      print("서버 전송 실패: $e");
      // TODO: 실패 처리 (예: 로컬에 임시 저장 후 나중에 재시도)
    }

    // 상태 초기화
    _currentSession = null;
    _isPaused = false;
    _lapStartTime = null;
    _lapTimes = [];
    _totalStudySeconds = 0;
    _totalBreakSeconds = 0;
    notifyListeners(); // 초기화 후 UI 업데이트
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
        subjectId: _currentSession!.subjectId, // 현재 세션의 과목 ID (String)
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
        subjectId: _currentSession!.subjectId, // 현재 세션의 과목 ID (String)
        timestamp: now));

    _isPaused = false;
    _lapStartTime = now; // 공부 시간 다시 시작
    notifyListeners();
  }
}