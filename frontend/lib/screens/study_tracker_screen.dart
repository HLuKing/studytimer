import 'dart:async';
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
  String _selectedSubjectId = '1';
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
    final studyProvider = Provider.of<StudyProvider>(context, listen: false);
    if (studyProvider.subjects.isNotEmpty) {
      _selectedSubjectId = studyProvider.subjects.first.id;
    }
    _startUiTimer();
    // 앱 실행 시 현재 시간으로 자동 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final Subject selectedSubject =
        subjects.firstWhere((s) => s.id == _selectedSubjectId, orElse: () => subjects.first);
   
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
            _buildWeekCalendarHeader(),
            // ### 2. 타임라인이 남은 공간을 모두 차지하도록 Expanded로 감싸기 ###
            Expanded(
              child: _buildTimelineView(),
            ),
            // ### 3. 컨트롤 바를 Column의 마지막 자식으로 배치 ###
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
    final start = session.startTime;
    final end = isCurrent ? DateTime.now() : session.endTime!;
    final subject = subjects.firstWhere((s) => s.id == session.subjectId, orElse: () => subjects.first);

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
          color: subject.color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${subject.name}\n${_formatTotalDuration(end.difference(start))}',
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
            if (provider.currentSession != null) _buildTimerDisplay(provider, selectedSubject),
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
        color: Theme.of(context).scaffoldBackgroundColor.withAlpha(200),
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
          final subject = subjects.firstWhere((s) => s.id == lap.subjectId);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        final studyProvider = Provider.of<StudyProvider>(context, listen: false);
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
                              onPressed: () {
                                if (studyProvider.subjects.length > 1) {
                                  studyProvider.deleteSubject(subject.id);
                                  if (_selectedSubjectId == subject.id) {
                                    _selectedSubjectId = studyProvider.subjects.first.id;
                                  }
                                  setState(() {}); // Rebuild sheet
                                }
                              },
                            )
                          ],
                        ),
                        onTap: () {
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
                    _showAddSubjectDialog(context);
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
    showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('새 과목 추가'),
            content: TextField(controller: nameController, decoration: const InputDecoration(hintText: "예: 물리학")),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
              ElevatedButton(
                  onPressed: () {
                    if (nameController.text.isNotEmpty) {
                      final studyProvider = Provider.of<StudyProvider>(context, listen: false);
                      final newSubject = Subject(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        color: Colors.primaries[studyProvider.subjects.length % Colors.primaries.length],
                      );
                      studyProvider.addSubject(newSubject);
                    }
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('추가')),
            ],
          );
        });
  }
}