import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';
import '../models/lap_time_model.dart';
import '../models/study_session_model.dart';
import '../models/subject_model.dart';
import '../providers/auth_provider.dart';
import '../providers/study_provider.dart';
import '../widgets/image_with_fallback.dart';

// ### 1. 2D 스크롤 동기화를 위한 클래스 추가 ###
class _SyncScrollController {
  final List<ScrollController> _controllers = [];

  void add(ScrollController controller) {
    _controllers.add(controller);
    controller.addListener(_onScroll);
  }

  void _onScroll() {
    for (var controller in _controllers) {
      if (!controller.hasClients) continue;
      final newOffset = _controllers.first.offset;
      if (controller.offset != newOffset) {
        controller.jumpTo(newOffset);
      }
    }
  }

  void dispose() {
    for (var controller in _controllers) {
      controller.removeListener(_onScroll);
      controller.dispose();
    }
  }
}

class StudyTrackerScreen extends StatefulWidget {
  const StudyTrackerScreen({super.key});

  @override
  State<StudyTrackerScreen> createState() => _StudyTrackerScreenState();
}

class _StudyTrackerScreenState extends State<StudyTrackerScreen> {
    // ### 1. 레이아웃을 위한 고정 변수 선언 ###
  static const double _hourHeight = 60.0;
  static const double _dayWidth = 70.0;
  static const double _timeColWidth = 50.0;

  DateTime _selectedDate = DateTime.now();
  int? _selectedSubjectId;
  Timer? _timer;
  Duration _currentLapDuration = Duration.zero;

  // ### 2. 스크롤 컨트롤러 재구성 ###
  final _SyncScrollController _horizontalControllers = _SyncScrollController();
  late ScrollController _bodyHorizontalScrollController;
  late ScrollController _headerHorizontalScrollController;
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _lapScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _bodyHorizontalScrollController = ScrollController();
    _headerHorizontalScrollController = ScrollController();
    _horizontalControllers.add(_bodyHorizontalScrollController);
    _horizontalControllers.add(_headerHorizontalScrollController);

    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final studyProvider = Provider.of<StudyProvider>(context, listen: false);
      if (studyProvider.subjects.isNotEmpty && _selectedSubjectId == null) {
        // 첫 번째 과목의 서버 ID (int?) 를 기본값으로 설정
        setState(() {
           _selectedSubjectId = studyProvider.subjects.first.id;
        });
      }
      _startUiTimer(); // 타이머 시작은 Provider 접근 후에

      // 현재 시간으로 자동 스크롤
      if (_verticalScrollController.hasClients) {
        final now = DateTime.now();
        _verticalScrollController.jumpTo(
          now.hour * _hourHeight - (MediaQuery.of(context).size.height / 4),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _horizontalControllers.dispose();
    _verticalScrollController.dispose();
    _lapScrollController.dispose();
    super.dispose();
  }

  void _startUiTimer() {
    _timer?.cancel(); // 기존 타이머가 있으면 취소
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final studyProvider = context.read<StudyProvider>();
      if (studyProvider.currentSession != null && studyProvider.lapStartTime != null) {
        final now = DateTime.now();
        if (mounted) {
          setState(() {
            _currentLapDuration = now.difference(studyProvider.lapStartTime!);
          });
        }
      }
    });
  }

  // 메인 타이머 및 랩타임 포맷 (HH:mm:ss)
  String _formatLapDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
  }

  // 총 시간 포맷 (시간이 0이면 mm:ss, 있으면 H:mm)
  String _formatTotalDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return "${hours}h ${twoDigits(minutes)}m";
    }
    final seconds = duration.inSeconds.remainder(60);
    return "${twoDigits(minutes)}:${twoDigits(seconds)}";
  }
  List<DateTime> _getWeekDates() {
    final today = _selectedDate;
    // 주의 시작을 일요일로 변경
    final startOfWeek = today.subtract(Duration(days: today.weekday % 7));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final studyProvider = context.watch<StudyProvider>();
    final subjects = studyProvider.subjects;

    final Subject selectedSubject = _selectedSubjectId == null || subjects.isEmpty
      ? Subject(id: null, name: '과목 없음', color: Colors.grey, serverId: '') // 기본값
      : subjects.firstWhere(
          (s) => s.id == _selectedSubjectId, // int? 끼리 비교
          orElse: () => subjects.isNotEmpty ? subjects.first : Subject(id: null, name: '과목 없음', color: Colors.grey, serverId: '') // 못 찾을 경우 대비
        );

    // 랩타임 리스트가 업데이트될 때마다 맨 아래로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_lapScrollController.hasClients && _lapScrollController.position.hasContentDimensions) {
        _lapScrollController.animateTo(
          _lapScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('스터디 로그', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (authProvider.firebaseUser != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  child: authProvider.firebaseUser!.photoURL != null
                      ? ClipOval(
                          child: ImageWithFallback(
                          imageUrl: authProvider.firebaseUser!.photoURL!,
                          width: 32,
                          height: 32,
                        ))
                      : const Icon(LucideIcons.user, size: 16),
                ),
                const SizedBox(width: 8),
                Text(authProvider.userDetails?['displayName'] ?? '...((구)이름없음)'),
              ]),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildWeekCalendarHeader(),
                    Expanded(
                      child: _buildTimelineView(),
                    ),
                  ],
                ),
              ),
            ),
            
            // 선택된 Subject 객체를 컨트롤 바에 전달
            _buildControlBar(studyProvider, selectedSubject),
          ],
        ),
      ),
    );
  }

  // --- UI Builder Methods ---

  // ### 3. 요일 헤더 UI 구조 변경 ###
  Widget _buildWeekCalendarHeader() {
    final weekDates = _getWeekDates();
    final today = DateTime.now();
    return Row(
      children: [
        SizedBox(width: _timeColWidth, child: const Center(child: Text('시간', style: TextStyle(color: Colors.grey)))),
        Expanded(
          child: SingleChildScrollView(
            controller: _headerHorizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: weekDates.map((day) {
                final isSelected = day.year == _selectedDate.year && day.month == _selectedDate.month && day.day == _selectedDate.day;
                final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
                return SizedBox(
                  width: _dayWidth,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDate = day),
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Text(DateFormat('E', 'ko_KR').format(day),
                              style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : isToday ? Colors.blue : Colors.grey)),
                          Text(day.day.toString(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : isToday ? Colors.blue : Theme.of(context).textTheme.bodyLarge?.color)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ### 4. 타임라인 뷰 UI 구조 변경 ###
Widget _buildTimelineView() {
  final weekDates = _getWeekDates();

  return SingleChildScrollView(
    controller: _verticalScrollController,
    child: SingleChildScrollView(
      controller: _bodyHorizontalScrollController,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeColumn(),
          ...weekDates.map((date) {
            // ### 1. Container를 없애고 SizedBox로 되돌리기 ###
            return SizedBox(
              width: _dayWidth,
              height: 24 * _hourHeight,
              child: _buildDayColumn(date),
            );
          }).toList(),
        ],
      ),
    ),
  );
}

    // ### 2. 하루치 UI를 그리는 함수 분리 ###
  Widget _buildDayColumn(DateTime date) {
    final studyProvider = context.watch<StudyProvider>();
    final subjects = studyProvider.subjects;
    final now = DateTime.now();
    final daySessions =
        studyProvider.sessions.where((s) => s.date == DateFormat('yyyy-MM-dd').format(date)).toList();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade200),
          right: date.weekday == DateTime.saturday // 요일이 토요일이면
            ? BorderSide(color: Colors.grey.shade200) // 오른쪽 줄을 그리고
            : BorderSide.none, // 아니면 그리지 않음
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _buildHourLines(),
          ...daySessions.map((session) => _buildSessionBlock(session, _hourHeight, subjects)),
          if (studyProvider.currentSession != null &&
              DateFormat('yyyy-MM-dd').format(date) == studyProvider.currentSession!.date)
            _buildSessionBlock(studyProvider.currentSession!, _hourHeight, subjects, isCurrent: true),
          if (DateFormat('yyyy-MM-dd').format(date) == DateFormat('yyyy-MM-dd').format(now))
            _buildCurrentTimeIndicator(now, _hourHeight),
        ],
      ),
    );
  }

  // ### 5. 시간 열 로직 수정 (25개 라벨) ###
  Widget _buildTimeColumn() {
    return SizedBox(
      width: _timeColWidth,
      height: 24 * _hourHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(25, (index) { // 00:00 부터 24:00 까지 총 25개 라벨
          return Positioned(
            top: index * _hourHeight - 3,
            left: 0,
            right: 0,
            child: Text(
              '${index.toString().padLeft(2, '0')}:00',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          );
        }),
      ),
    );
  }

  // ### 6. 마지막 줄이 그려지도록 수정 ###
  Widget _buildHourLines() {
    return Column(
      children: List.generate(24, (index) {
        return Container(
          height: _hourHeight,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
              // 마지막 칸(23:00)에만 bottom border 추가
              bottom: index == 23 ? BorderSide(color: Colors.grey.shade200) : BorderSide.none,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSessionBlock(StudySession session, double hourHeight, List<Subject> subjects,
      {bool isCurrent = false}) {

    final bool isBreak = session.intervalType == 'BREAK';
    Color blockColor;
    String blockText;

    if (isBreak) {
      //  2. 휴식 시간일 경우
      blockColor = Colors.grey.shade400; // 회색
      blockText = "휴식"; // "휴식" 텍스트
    } else {
      //  3. 공부 시간일 경우 (기존 로직)
      final subject = subjects.firstWhere(
          (s) => s.serverId == session.subjectId,
          orElse: () => Subject(id: null, name: '??', color: Colors.grey, serverId: session.subjectId)
       );
      blockColor = subject.color;
      blockText = subject.name;
    }
    final start = session.startTime;
    final end = isCurrent ? DateTime.now() : session.endTime!;
    final top = (start.hour + start.minute / 60.0) * hourHeight;
    final height = end.difference(start).inMinutes / 60.0 * hourHeight;
    if (height <= 0) return const SizedBox.shrink();

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: blockColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${blockText}\n${_formatTotalDuration(end.difference(start))}',
          style: const TextStyle(color: Colors.white, fontSize: 10),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(DateTime now, double hourHeight) {
    final top = (now.hour + now.minute / 60.0) * hourHeight;
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
          ),
          Expanded(child: Container(height: 2, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildControlBar(StudyProvider provider, Subject selectedSubject) {
    return Material(
      elevation: 10,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            if (provider.currentSession != null) _buildLapTimeList(provider, provider.subjects),
            if (provider.currentSession != null) _buildTimerDisplay(provider, selectedSubject), // selectedSubject 전달
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: provider.currentSession != null ? null : () => _showSubjectSheet(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(backgroundColor: selectedSubject.color, radius: 8),
                        const SizedBox(width: 8),
                        // selectedSubject.name 사용
                        Text(selectedSubject.name),
                        const Icon(LucideIcons.chevronUp, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildActionButton(provider),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(StudyProvider provider) {
    if (provider.currentSession == null) {
      return ElevatedButton.icon(
        onPressed: () {
          provider.startStudy(_selectedSubjectId);
          setState(() => _currentLapDuration = Duration.zero);
        },
        icon: const Icon(LucideIcons.play),
        label: const Text('시작'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      return Row(
        children: [
          ElevatedButton(
            onPressed: provider.isPaused ? provider.resumeStudy : provider.pauseStudy,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF0F0F0),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(provider.isPaused ? LucideIcons.play : LucideIcons.pause, size: 18),
                const SizedBox(width: 4),
                Text(provider.isPaused ? '재시작' : '일시정지'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: provider.stopStudy,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              children: [Icon(LucideIcons.square, size: 18), SizedBox(width: 4), Text('완료')],
            ),
          ),
        ],
      );
    }
  }

  Widget _buildTimerDisplay(StudyProvider provider, Subject selectedSubject) {
    final totalStudy = Duration(seconds: provider.totalStudySeconds);
    final totalBreak = Duration(seconds: provider.totalBreakSeconds);
    
    final currentStudyTime = provider.isPaused ? totalStudy : totalStudy + _currentLapDuration;
    final currentBreakTime = provider.isPaused ? totalBreak + _currentLapDuration : totalBreak;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            _formatLapDuration(_currentLapDuration),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: provider.isPaused ? Colors.green : selectedSubject.color,
            ),
          ),
          Text(provider.isPaused ? '🛌 쉬는 시간' : '📚 ${selectedSubject.name} 공부 중'),
          const SizedBox(height: 4),
          Text(
            '총 공부: ${_formatTotalDuration(currentStudyTime)} | 쉬는시간: ${_formatTotalDuration(currentBreakTime)}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildLapTimeList(StudyProvider provider, List<Subject> subjects) {
    return Container(
      height: 100,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        controller: _lapScrollController, // 스크롤 컨트롤러 연결
        itemCount: provider.lapTimes.length,
        itemBuilder: (context, index) {
          final lap = provider.lapTimes[index];
          final subject = subjects.firstWhere(
            (s) => s.serverId == lap.subjectId,
            orElse: () => Subject(id: null, name: '??', color: Colors.grey, serverId: lap.subjectId) // 못 찾을 경우 대비
          );
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                CircleAvatar(
                    backgroundColor: lap.type == LapType.study ? subject.color : Colors.grey,
                    radius: 4),
                const SizedBox(width: 8),
                Text(lap.type == LapType.study ? subject.name : '쉬는시간'),
                const Spacer(),
                Text(_formatLapDuration(lap.duration)),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSubjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        final studyProvider = Provider.of<StudyProvider>(context);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, scrollController) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('과목 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(sheetContext)),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: studyProvider.subjects.map((subject) {
                      return ListTile(
                        leading: CircleAvatar(backgroundColor: subject.color, radius: 12),
                        title: Text(subject.name),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_selectedSubjectId == subject.id) const Padding(
                              padding: EdgeInsets.only(right: 8.0),
                              child: CircleAvatar(radius: 4, backgroundColor: Colors.black),
                              ),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                              onPressed: () async { // async 추가
                                // subject.id 가 null 이 아닌지 확인 후 deleteSubject 호출
                                if (subject.id != null && studyProvider.subjects.length > 1) {
                                  try {
                                    await studyProvider.deleteSubject(subject.id!); // await 사용
                                    // 삭제 후 선택된 ID 재설정 (삭제된 ID와 같았다면)
                                    if (_selectedSubjectId == subject.id) {
                                      // listen: false 로 Provider 다시 가져와서 사용
                                      final latestSubjects = Provider.of<StudyProvider>(context, listen: false).subjects;
                                      setState(() {
                                         _selectedSubjectId = latestSubjects.isNotEmpty ? latestSubjects.first.id : null;
                                      });
                                    }
                                    // 시트 닫기 불필요 (Provider가 업데이트하면 자동으로 리빌드됨)
                                    // Navigator.pop(sheetContext); // 삭제
                                  } catch (e) {
                                     // TODO: 사용자에게 삭제 실패 알림
                                     print("삭제 실패 UI 알림 필요: $e");
                                     if(mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('과목 삭제 실패: $e'), backgroundColor: Colors.red)
                                        );
                                     }
                                  }
                                } else if (studyProvider.subjects.length <= 1) {
                                     if(mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('최소 1개의 과목이 필요합니다.'), backgroundColor: Colors.orange)
                                        );
                                     }
                                }
                              },
                            )
                          ],
                        ),
                        onTap: () {
                          // setState로 _selectedSubjectId (int?) 업데이트
                          setState(() {
                            _selectedSubjectId = subject.id;
                          });
                          Navigator.pop(sheetContext);
                        },
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(LucideIcons.plus),
                  title: const Text('새 과목 추가'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showAddSubjectDialog(context); // 새 과목 추가 다이얼로그 호출
                  },
                )
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddSubjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    Color selectedColor = Colors.primaries[Random().nextInt(Colors.primaries.length)]; // 랜덤 색상

    final studyProvider = Provider.of<StudyProvider>(context, listen: false);
    String? _errorText;

    showDialog(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setStateInDialog) {
              return AlertDialog(
              title: const Text('새 과목 추가'),
              content: Column( // 색상 변경 UI를 위해 StatefulBuilder 사용
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      hintText: "예: 물리학",
                      errorText: _errorText,
                      errorStyle: const TextStyle(color: Colors.red),
                      // 1. 배경색을 칠하도록 설정합니다.
                        filled: true, 
                        
                        // 2. '살짝 회색' 배경색을 지정합니다.
                        // (더 진하게 하려면 shade200을 사용하세요)
                        fillColor: Colors.grey.shade100, 

                        // 3. 테두리 스타일을 밑줄 대신 박스(Outline)로 변경합니다.
                        border: OutlineInputBorder(
                          // 기본 테두리는 숨깁니다.
                          borderSide: BorderSide.none, 
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        // 평소에 보일 연한 테두리
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        // 클릭했을 때 보일 테두리
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      onChanged: (value) {
                        if(_errorText != null) {
                        setStateInDialog(() {
                          _errorText = null; // 입력 시 에러 메시지 초기화
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // 색상 선택 UI (간단 버전: 버튼 클릭 시 랜덤 변경)
                  Row(
                    children: [
                      const Text("색상: "),
                      GestureDetector(
                        onTap: () {
                          setStateInDialog(() { // 다이얼로그 내부 상태만 변경
                            selectedColor = Colors.primaries[Random().nextInt(Colors.primaries.length)];
                          });
                        },
                        child: CircleAvatar(backgroundColor: selectedColor, radius: 12),
                      ),
                      const SizedBox(width: 8),
                      TextButton(onPressed: () {
                          setStateInDialog(() {
                            selectedColor = Colors.primaries[Random().nextInt(Colors.primaries.length)];
                          });
                      }, child: const Text("변경"))
                    ],
                  )
                ],
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
                  ElevatedButton(
                    onPressed: () async {
                      final subjectName = nameController.text.trim();

                      // 유효성 검사 1: 이름이 비어있는지 확인
                      if (subjectName.isEmpty) {
                        setStateInDialog(() {
                          _errorText = "과목 이름을 입력해주세요";
                        });
                        return; // 함수 종료
                      }

                      // 유효성 검사 2: 이름이 중복되는지 확인 (대소문자 무시)
                      if (studyProvider.subjects.any((s) => s.name.toLowerCase() == subjectName.toLowerCase())) {
                        setStateInDialog(() {
                          _errorText = "이미 등록된 과목입니다";
                        });
                        return; // 함수 종료
                      }

                      // 유효성 검사 통과: 오류 메시지 초기화
                      setStateInDialog(() {
                        _errorText = null;
                      });

                      // 기존 API 호출 로직
                      try {
                        await studyProvider.addSubject(subjectName, selectedColor);
                        if (mounted) Navigator.pop(dialogContext); // 성공 시 닫기
                      } catch (e) {
                        print("추가 실패 UI 알림 필요: $e");
                        if (mounted) {
                          Navigator.pop(dialogContext); // 일단 닫고
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('과목 추가 실패: $e'), backgroundColor: Colors.red)
                          );
                        }
                      }
                    },
                    child: const Text('추가')
                  ),
                ],
            );
      });
      }
    );
  }
}