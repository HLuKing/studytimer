import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/study_session_model.dart';
import '../models/subject_model.dart';
import '../providers/settings_provider.dart';
import '../providers/study_provider.dart';
import 'dart:math';

// 과목별 색상 가져오기
Map<String, Color> getSubjectColors(BuildContext context) {
  final studyProvider = Provider.of<StudyProvider>(context, listen: false);
  final colors = [
    Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red,
    Colors.teal, Colors.pink, Colors.amber
  ];
  Map<String, Color> subjectColorMap = {};
  int colorIndex = 0;
  // Provider에 있는 subjects 리스트 순서대로 색상 할당
  for (var subject in studyProvider.subjects) {
    subjectColorMap[subject.name] = colors[colorIndex % colors.length];
    colorIndex++;
  }
  subjectColorMap.putIfAbsent('기타', () => Colors.grey); // 혹시 모를 '기타' 과목
  return subjectColorMap;
}

// 간단한 통계 아이템 위젯 (재사용)
class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final String? subLabel;
  final TextStyle? valueStyle;
  final TextStyle? labelStyle;

  const _StatItem({
    required this.value,
    required this.label,
    this.subLabel,
    this.valueStyle,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Text(label, style: labelStyle ?? Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: valueStyle ?? const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        if (subLabel != null)
          Text(subLabel!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}


class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now(); // 일간/주간/월간 뷰 기준 날짜
  DateTime _calendarViewDate = DateTime.now(); // 캘린더 표시 기준 (월/분기/연도 이동용)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.index = 0; // 기본 '일간' 탭
    _tabController.addListener(() { // 탭 변경 시 캘린더 뷰 초기화
      if (_tabController.indexIsChanging) {
        setState(() {
          _calendarViewDate = _selectedDate;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- 시간 포맷 함수 ---
  String formatTime(double totalSeconds, {bool showSeconds = true}) {
    if (totalSeconds.isNaN || totalSeconds.isInfinite || totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds.toInt());
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (!showSeconds) return "${twoDigits(hours)}:${twoDigits(minutes)}";
    return "${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}";
  }
  String formatHourMinute(double totalSeconds) {
     if (totalSeconds.isNaN || totalSeconds.isInfinite || totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0 && minutes == 0 && totalSeconds > 0) return "< 1m"; // 1분 미만 표시
    if (hours > 0) return "${hours}h ${minutes}m";
    return "${minutes}m";
  }

  // --- 날짜 계산 헬퍼 함수 ---
  DateTime _getWeekStart(DateTime date) => date.subtract(Duration(days: date.weekday % 7)); // 일요일 시작
  DateTime _getWeekEnd(DateTime date) => _getWeekStart(date).add(const Duration(days: 6));
  int _getQuarter(DateTime date) => (date.month - 1) ~/ 3 + 1;
  DateTime _getQuarterStart(DateTime date) => DateTime(date.year, ((_getQuarter(date) - 1) * 3) + 1, 1);
  DateTime _getQuarterEnd(DateTime date) => DateTime(date.year, _getQuarterStart(date).month + 3, 0);

  @override
  Widget build(BuildContext context) {
    final studyProvider = context.watch<StudyProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('통계'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true, // 탭 개수가 많으므로 스크롤 가능하게
          tabs: const [
            Tab(text: '일간'),
            Tab(text: '주간'),
            Tab(text: '월간'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyView(studyProvider.sessions, settingsProvider.dailyGoal),
          _buildWeeklyView(studyProvider.sessions), // 주간 뷰
          _buildMonthlyView(studyProvider.sessions), // 월간 뷰
        ],
      ),
    );
  }

  // --- 각 탭별 뷰 빌더 ---

  Widget _buildDailyView(List<StudySession> sessions, double dailyGoal) {
    // 선택된 날짜의 세션 필터링
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final selectedSessions = sessions.where((s) => s.date == dateStr).toList();
    
    // 일간 통계 계산
    double totalStudySeconds = 0;
    double totalBreakSeconds = 0;
    double maxFocusSeconds = 0;
    DateTime? firstStartTime;
    DateTime? lastEndTime;
    Map<String, double> subjectSeconds = {};
    List<Subject> subjects = Provider.of<StudyProvider>(context, listen: false).subjects;

    for (var session in selectedSessions) {
      final start = session.startTime;
      final studyDuration = session.studyDuration.toDouble();
      final breakDuration = session.breakDuration.toDouble();

      totalStudySeconds += studyDuration;
      totalBreakSeconds += breakDuration;
      maxFocusSeconds = maxFocusSeconds > studyDuration ? maxFocusSeconds : studyDuration;

      if (firstStartTime == null || start.isBefore(firstStartTime)) {
        firstStartTime = start;
      }
      if (lastEndTime == null || (session.endTime != null && session.endTime!.isAfter(lastEndTime))) {
        lastEndTime = session.endTime;
      }
      
      final subject = subjects.firstWhere((s) => s.id == session.subjectId, orElse: () => subjects.first);
      subjectSeconds[subject.name] = (subjectSeconds[subject.name] ?? 0) + studyDuration;
    }
    
    final subjectColors = getSubjectColors(context);

    // 과목별 파이 차트 데이터
    final subjectPieData = subjectSeconds.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${(entry.value / totalStudySeconds * 100).toStringAsFixed(0)}%',
        color: subjectColors[entry.key] ?? Colors.grey,
        radius: 40,
        titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)
      );
    }).toList();
    
    // 공부/휴식 파이 차트 데이터
    final totalSeconds = totalStudySeconds + totalBreakSeconds;
    final studyBreakPieData = (totalSeconds > 0) ? [
       PieChartSectionData(
        value: totalStudySeconds,
        title: '${(totalStudySeconds / totalSeconds * 100).toStringAsFixed(0)}%',
        color: Theme.of(context).colorScheme.primary,
         radius: 40,
         titleStyle: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold)
      ),
       PieChartSectionData(
        value: totalBreakSeconds,
        title: '${(totalBreakSeconds / totalSeconds * 100).toStringAsFixed(0)}%',
        color: Colors.grey.shade400,
         radius: 40,
         titleStyle: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)
      ),
    ] : <PieChartSectionData>[]; // 데이터 없으면 빈 리스트


    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDailyCalendarView(sessions), // 캘린더 (공통 사용)
        const SizedBox(height: 16),
        if (selectedSessions.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(32.0), child: Center(child: Text('선택한 날짜에 공부 기록이 없습니다.'))))
        else ...[
          // 기본 정보 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_selectedDate), style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(value: formatTime(totalStudySeconds), label: '총 공부 시간', subLabel: '(휴식 ${formatTime(totalBreakSeconds)})'),
                      _StatItem(value: formatTime(maxFocusSeconds), label: '최대 집중 시간'),
                    ],
                  ),
                   const SizedBox(height: 16),
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(value: firstStartTime != null ? DateFormat('a h:mm', 'ko_KR').format(firstStartTime) : '-', label: '시작 시간'),
                      _StatItem(value: lastEndTime != null ? DateFormat('a h:mm', 'ko_KR').format(lastEndTime) : '-', label: '종료 시간'),
                    ],
                  ),
                   const SizedBox(height: 16),
                  _buildHourlyBarChartSimple(selectedSessions), // 12시 기준 바 그래프
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 파이 차트 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('과목별 비율', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildPieChartWithLegend(subjectPieData, subjectSeconds, subjectColors, totalStudySeconds),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16), // 카드 사이 간격

          // 2. 공부 / 휴식 비율 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('공부 / 휴식 비율', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildPieChartWithLegend(studyBreakPieData, {'공부': totalStudySeconds, '휴식': totalBreakSeconds}, {'공부': Theme.of(context).colorScheme.primary, '휴식': Colors.grey.shade400}, totalSeconds),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 시간대별 공부 시간 카드
          Card(
            child: Padding(
               padding: const EdgeInsets.all(16.0),
               child: Column(
                 children: [
                    Text(DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(_selectedDate), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                   _buildHourlyTimeline(selectedSessions, subjects), // 시간대별 타임라인
                 ]
               )
            )
          ),
          const SizedBox(height: 16),
           // 타임라인 리스트 카드
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('타임라인', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...selectedSessions.map((session) => _buildTimelineListItem(session, subjects)),
                ]
              )
            )
          )
        ]
      ],
    );
  }
  
  // --- 주간 뷰 ---
Widget _buildWeeklyView(List<StudySession> sessions) {
    final subjects = Provider.of<StudyProvider>(context, listen: false).subjects;
    final subjectColors = getSubjectColors(context);

// --- 데이터 계산 ---
    final currentQuarter = _getQuarter(_calendarViewDate);
    final quarterStart = _getQuarterStart(_calendarViewDate);
    final quarterEnd = _getQuarterEnd(_calendarViewDate);
    final List<DateTime> weeksInQuarter = [];
    DateTime weekIterator = _getWeekStart(quarterStart);
    while (weekIterator.isBefore(quarterEnd) || DateUtils.isSameDay(weekIterator, quarterEnd)) {
      // 분기에 걸쳐있는 주만 포함
      if (weekIterator.year == _calendarViewDate.year && _getQuarter(weekIterator) == currentQuarter) {
         weeksInQuarter.add(weekIterator);
      } else if (_getWeekEnd(weekIterator).year == _calendarViewDate.year && _getQuarter(_getWeekEnd(weekIterator)) == currentQuarter) {
         weeksInQuarter.add(weekIterator); // 주 끝이 분기에 포함되면 추가
      }
      weekIterator = weekIterator.add(const Duration(days: 7));
    }

    final selectedWeekStart = _getWeekStart(_selectedDate);
    final selectedWeekEnd = _getWeekEnd(_selectedDate);
    final previousWeekStart = selectedWeekStart.subtract(const Duration(days: 7));
    // 주간 데이터 집계 함수
    Map<String, dynamic> calculateWeekStats(DateTime weekStart) {
      final weekEnd = _getWeekEnd(weekStart);
      double totalStudy = 0;
      double totalBreak = 0; // 휴식 시간 추가
      Map<int, double> dailyTotals = { for (var i = 0; i < 7; i++) i: 0.0 };
      Map<String, double> subjectTotals = {};
      Map<int, DateTime?> dailyStartTimes = { for (var i = 0; i < 7; i++) i: null };
      Map<int, DateTime?> dailyEndTimes = { for (var i = 0; i < 7; i++) i: null };
      Map<int, Map<String, double>> dailySubjectSeconds = { for (var i = 0; i < 7; i++) i: {} };

      for (var session in sessions) {
        final sessionDate = DateTime.parse(session.date);
        // 날짜 비교 수정: weekStart <= sessionDate <= weekEnd
        if (!sessionDate.isBefore(DateUtils.dateOnly(weekStart)) && !sessionDate.isAfter(DateUtils.dateOnly(weekEnd))) {
          final studySec = session.studyDuration.toDouble();
          final breakSec = session.breakDuration.toDouble(); // 휴식 시간 가져오기
          final dayIndex = sessionDate.weekday % 7;
          final subject = subjects.firstWhere((s) => s.id == session.subjectId, orElse: () => subjects.first);

          totalStudy += studySec;
          totalBreak += breakSec; // 휴식 시간 합산
          dailyTotals[dayIndex] = (dailyTotals[dayIndex] ?? 0.0) + studySec;
          subjectTotals[subject.name] = (subjectTotals[subject.name] ?? 0.0) + studySec;
          dailySubjectSeconds[dayIndex]![subject.name] = (dailySubjectSeconds[dayIndex]![subject.name] ?? 0) + studySec;

          if (dailyStartTimes[dayIndex] == null || session.startTime.isBefore(dailyStartTimes[dayIndex]!)) {
            dailyStartTimes[dayIndex] = session.startTime;
          }
          final endTime = session.endTime ?? session.startTime.add(Duration(seconds: session.studyDuration));
           if (dailyEndTimes[dayIndex] == null || endTime.isAfter(dailyEndTimes[dayIndex]!)) {
            dailyEndTimes[dayIndex] = endTime;
          }
        }
      }
      return {
        'totalStudy': totalStudy, 'totalBreak': totalBreak, 'dailyTotals': dailyTotals,
        'subjectTotals': subjectTotals, 'dailyStartTimes': dailyStartTimes, 'dailyEndTimes': dailyEndTimes,
        'dailySubjectSeconds': dailySubjectSeconds
      };
    }

    final selectedWeekStats = calculateWeekStats(selectedWeekStart);
    final previousWeekStats = calculateWeekStats(previousWeekStart);



    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- 1. 분기별 주간 선택기 ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.chevronLeft),
                      onPressed: () => setState(() => _calendarViewDate = DateTime(_calendarViewDate.year, _calendarViewDate.month - 3, 1)),
                    ),
                    Text('${_calendarViewDate.year}년 $currentQuarter분기', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(
                      icon: const Icon(LucideIcons.chevronRight),
                      onPressed: () => setState(() => _calendarViewDate = DateTime(_calendarViewDate.year, _calendarViewDate.month + 3, 1)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap( // Wrap으로 변경하여 자동 줄바꿈
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: weeksInQuarter.map((weekStart) {
                    
                    final weekStat = calculateWeekStats(weekStart); // 각 주의 통계 계산
                    final isSelected = DateUtils.isSameDay(selectedWeekStart, weekStart);
                    return SizedBox(
                      width: MediaQuery.of(context).size.width / 4 - 20, // 화면 너비에 따라 조절
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDate = weekStart),
                        child: Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${DateFormat('M/d').format(weekStart)} ~', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(formatHourMinute(weekStat['totalStudy']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // --- 2. 주간 요약 및 비교 ---
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                 Text(
                    '${DateFormat('M월 d일 (E)', 'ko_KR').format(selectedWeekStart)} ~ ${DateFormat('M월 d일 (E)', 'ko_KR').format(selectedWeekEnd)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(value: formatHourMinute(selectedWeekStats['totalStudy']), label: '총 시간'),
                      _StatItem(value: formatHourMinute(selectedWeekStats['totalStudy'] / 7), label: '하루 평균'), // 7일 평균
                    ],
                  ),
                const SizedBox(height: 16),
                // ### 4. Pass total weekly times to the chart ###
                _buildComparisonBarChart(
                  selectedWeekStats['dailyTotals'], // 전체 시간 전달
                  previousWeekStats['dailyTotals']  // 전체 시간 전달
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

// --- 3. 시작/종료 시간 ---
        Card(
           child: Padding(
            padding: const EdgeInsets.all(16.0),
             child: Column(
               // 제목 왼쪽 정렬
              children: [
                const Text('시작시간 / 종료시간', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                 _buildStartEndBarChart(selectedWeekStats),
              ]
            )
           )
        ),
         const SizedBox(height: 16),

// --- 4. 과목별 비율 ---
        Card(
           child: Padding(
            padding: const EdgeInsets.all(16.0),
             child: Column(
              children: [
                 const Text('과목별 비율', style: TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 _buildRatioPieChart(
                   selectedWeekStats['totalStudy'],
                   0,
                   subjectColors,
                   '',
                   dataMapOverride: selectedWeekStats['subjectTotals'] // 과목 데이터 전달
                 ),
              ]
            )
           )
        ),
        const SizedBox(height: 16),


// --- 5. 공부 / 휴식 비율 ---
        Card(
         child: Padding(
          padding: const EdgeInsets.all(16.0),
           child: Column(
            children: [
              const Text('공부 / 휴식 비율', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Builder( // Builder를 사용해 context 접근
                 builder: (context) {
                   final double totalStudy = selectedWeekStats['totalStudy'] ?? 0.0;
                   final double totalBreak = selectedWeekStats['totalBreak'] ?? 0.0;
                   final double totalSeconds = totalStudy + totalBreak;
                   final primaryColor = Theme.of(context).colorScheme.primary; // 테마에서 primary 색상 가져오기
                   final onPrimaryColor = Theme.of(context).colorScheme.onPrimary; // primary 위의 색상

                   final List<PieChartSectionData> weeklyStudyBreakPieData = (totalSeconds > 0) ? [
                     PieChartSectionData(
                       value: totalStudy,
                       title: '', // '${(totalStudy / totalSeconds * 100).toStringAsFixed(0)}%', // 제목 제거
                       color: primaryColor, // 테마 기본 색상 (검은색)
                       radius: 20, // 두께
                     ),
                     PieChartSectionData(
                       value: totalBreak,
                       title: '', // '${(totalBreak / totalSeconds * 100).toStringAsFixed(0)}%', // 제목 제거
                       color: Colors.grey.shade400, // 휴식 색상
                       radius: 20, // 두께
                     ),
                   ] : <PieChartSectionData>[];

                   // 2. _buildRatioPieChart 대신 _buildPieChartWithLegend를 호출합니다.
                   return _buildPieChartWithLegend(
                     weeklyStudyBreakPieData, // 직접 만든 데이터 전달
                     {'공부': totalStudy, '휴식': totalBreak}, // 범례용 데이터
                     {'공부': primaryColor, '휴식': Colors.grey.shade400}, // 범례용 색상
                     totalSeconds // 전체 시간
                   );
                 }
               ),
               // --- 수정 끝 ---
            ]
          )
         )
      ),
      const SizedBox(height: 16),


// --- 6. 과목별 공부 시간 (일별) ---
        Card(
           child: Padding(
            padding: const EdgeInsets.all(16.0),
             child: Column(
              
              children: [
                 const Text('과목별 공부시간', style: TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 // ### dailySubjectSeconds 전달 확인 ###
                 _buildStackedBarChart(selectedWeekStats['dailySubjectSeconds'], subjectColors, subjects, true),
              ]
            )
           )
        ),
        const SizedBox(height: 16),

// --- 7. 공부 시간 누적 ---
        Card(
           child: Padding(
            padding: const EdgeInsets.all(16.0),
             child: Column(
              
              children: [
                 const Text('공부시간 누적', style: TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 16),
                 // ### dailySubjectSeconds 전달 확인 ###
                 _buildCumulativeAreaChart(selectedWeekStats['dailySubjectSeconds'], subjectColors, subjects, true),
              ]
            )
           )
        ),
      ],
    );
  }

Map<dynamic, DateTime?> _calculateDailyStartTimes(List<StudySession> sessions, dynamic keySelector(StudySession session)) {
    final Map<dynamic, DateTime> startTimes = {};
    for (var session in sessions) {
      final key = keySelector(session);
      if (!startTimes.containsKey(key) || session.startTime.isBefore(startTimes[key]!)) {
        startTimes[key] = session.startTime;
      }
    }
    return startTimes;
  }

  Map<dynamic, DateTime?> _calculateDailyEndTimes(List<StudySession> sessions, dynamic keySelector(StudySession session)) {
    final Map<dynamic, DateTime> endTimes = {};
    for (var session in sessions) {
      final key = keySelector(session);
      final endTime = session.endTime ?? session.startTime.add(Duration(seconds: session.studyDuration + session.breakDuration));
      if (!endTimes.containsKey(key) || endTime.isAfter(endTimes[key]!)) {
        endTimes[key] = endTime;
      }
    }
    return endTimes;
  }

  // 월간 비교 막대 차트 (주간 함수 기반 수정)
  Widget _buildMonthlyComparisonBarChart(
      Map<int, double> currentMonthTotals, // 일별 공부 시간 (초)
      Map<int, double> previousMonthTotals, // 일별 공부 시간 (초)
      int daysInMonth
  ) {
    // 시간(초)을 시간(hour) 단위로 변환
    final List<double> currentHours = List.generate(daysInMonth, (i) => (currentMonthTotals[i+1] ?? 0.0) / 3600.0);
    final List<double> previousHours = List.generate(daysInMonth, (i) => (previousMonthTotals[i+1] ?? 0.0) / 3600.0);

    // Y축 최대값 계산
    final double maxCurrent = currentHours.fold<double>(0.0, (p, e) => max(p, e));
    final double maxPrevious = previousHours.fold<double>(0.0, (p, e) => max(p, e));
    final double maxY = max(max(maxCurrent, maxPrevious) * 1.2, 0.5); // 최소 0.5시간
    final double dotHeight = max(maxY * 0.01, 0.01); // 점 높이 (최소값 보장)


    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          barGroups: List.generate(daysInMonth, (dayIndex) { // 0부터 daysInMonth-1
            final dayOfMonth = dayIndex + 1; // 1부터 daysInMonth
            final thisMonthHour = currentHours[dayIndex];
            final lastMonthHour = previousHours[dayIndex];

            return BarChartGroupData(
              x: dayOfMonth, // X축 값은 1일부터 시작
              barsSpace: 2, // 월간은 간격 좁게
              barRods: [
                BarChartRodData( // 이번 달 막대
                  toY: thisMonthHour,
                  color: Theme.of(context).colorScheme.primary, // 테마 기본 색상 (검은색)
                  width: 4, // 얇게
                  borderRadius: BorderRadius.zero,
                ),
                BarChartRodData( // 지난 달 점
                  // 점 위치 조정 (막대 가운데 오도록)
                  fromY: lastMonthHour > 0 ? lastMonthHour - dotHeight : 0,
                  toY: lastMonthHour,
                  color: Colors.grey.shade600, // 점 색상
                  width: 4, // 점 두께
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day == 1 || day % 7 == 0 || day == daysInMonth) { // 1일, 7일 간격, 마지막 날
                    return Padding( // 간격 조정
                       padding: const EdgeInsets.only(top: 4.0),
                       child: Text('$day', style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
              },
              reservedSize: 20, interval: 1, // 모든 X값에 대해 위젯 호출
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles( // Y축 (시간 표시)
              showTitles: true, reservedSize: 30, // 공간 확보
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('0h', style: TextStyle(fontSize: 10));
                // 정수 시간만 표시
                if (value > 0 && value == value.toInt() && value <= meta.max) {
                   return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
              interval: max( (maxY / 4).floorToDouble() , 1.0) // 4~5개 라벨 나오도록 간격 조절
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData( // 가로선만 표시
            show: true, drawVerticalLine: false,
            horizontalInterval: max( (maxY / 4).floorToDouble() , 1.0), // Y축 라벨과 동일한 간격
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          barTouchData: BarTouchData( // 툴팁 설정
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.black87, // 배경색
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  // 막대/점 상관없이 해당 날짜 정보 표시
                  final dayOfMonth = group.x.toInt();
                  final thisMonthVal = currentHours[dayOfMonth - 1];
                  final lastMonthVal = previousHours[dayOfMonth - 1];

                  String title = "${dayOfMonth}일\n";
                  String thisMonthStr = "이번달: ${formatHourMinute(thisMonthVal * 3600)}\n";
                  String lastMonthStr = "지난달: ${formatHourMinute(lastMonthVal * 3600)}";

                  return BarTooltipItem(
                    title,
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                    children: [
                      TextSpan(text: thisMonthStr, style: TextStyle(color: Colors.grey.shade300, fontSize: 10)),
                      TextSpan(text: lastMonthStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                    ]
                  );
              },
            ),
          ),
        ),
      ),
    );
  }

  // 월간 시작/종료 시간 막대 차트 (주간 함수 기반 수정)
  Widget _buildMonthlyStartEndBarChart(
      Map<int, double> dailyStudyTotals, // 일별 *공부* 시간 (초 단위)
      Map<dynamic, DateTime?> dailyStartTimes, // Map key: day (1~31)
      Map<dynamic, DateTime?> dailyEndTimes,   // Map key: day (1~31)
      int daysInMonth
  ) {
      // BarChart 데이터 생성
      final barGroups = List.generate(daysInMonth, (index) {
          final day = index + 1;
          // 막대 높이는 시간 단위 (h)
          final hours = (dailyStudyTotals[day] ?? 0.0) / 3600.0;
          return BarChartGroupData(x: day, barRods: [
              BarChartRodData(
                toY: hours,
                // 색상은 테마 기본색 연하게
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                width: 5, // 얇게
                borderRadius: BorderRadius.zero
              )
          ]);
      });
      // Y축 최대값 (시간 단위)
      final maxY = barGroups.fold<double>(0.0, (prev, group) => max(prev, group.barRods.first.toY)) * 1.2;

      return SizedBox(
        height: 150, // 차트 높이
        child: BarChart(
          BarChartData(
              maxY: max(maxY, 1.0), // 최소 높이 1시간
              barGroups: barGroups,
              titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                        final day = value.toInt();
                        if (day == 1 || day % 7 == 0 || day == daysInMonth) { // 1일, 7일 간격, 마지막 날
                          return Padding( // 간격 조정
                             padding: const EdgeInsets.only(top: 4.0),
                             child: Text('$day', style: const TextStyle(fontSize: 10)),
                          );
                        }
                        return const Text('');
                    },
                    reservedSize: 20, interval: 1,
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles( // Y축 (주간과 유사)
                      showTitles: true, reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                          if (value == 0) return const Text('0h');
                          if (value > 0 && (value % 2 == 0 || value.toStringAsFixed(1).endsWith('.5')) && value <= meta.max) {
                            return Text('${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}h', style: const TextStyle(fontSize: 10));
                          }
                          return const Text('');
                      },
                      interval: max( (maxY / 4).floorToDouble() , 0.5) // Y축 간격 조절
                  )),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData( // 그리드 (주간과 유사)
                  show: true, drawVerticalLine: false,
                  horizontalInterval: max( (maxY / 4).floorToDouble() , 0.5), // Y축 간격 조절
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)
              ),
              // --- 툴팁 로직 ---
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = group.x.toInt(); // 날짜 (1 ~ daysInMonth)
                    final hours = rod.toY; // 공부 시간 (h)
                    final startTime = dailyStartTimes[day];
                    final endTime = dailyEndTimes[day];
                    String tooltipText = "${day}일\n"; // 날짜 표시
                    tooltipText += "공부: ${formatHourMinute(hours * 3600)}\n";
                    if (startTime != null) tooltipText += "시작: ${DateFormat('HH:mm').format(startTime)}\n";
                    if (endTime != null) tooltipText += "종료: ${DateFormat('HH:mm').format(endTime)}";
                    return BarTooltipItem(
                      tooltipText,
                      const TextStyle(color: Colors.white, fontSize: 10),
                    );
                  },
                ),
             ),
          ),
        ),
      );
    }

  // --- 월간 뷰 ---
Widget _buildMonthlyView(List<StudySession> sessions) {
  // --- 1. 월간 데이터 집계 ---
  final subjects = Provider.of<StudyProvider>(context, listen: false).subjects;
  final subjectColors = getSubjectColors(context);
  final year = _selectedDate.year;
  final month = _selectedDate.month;
  final daysInMonth = DateUtils.getDaysInMonth(year, month);
  final List<StudySession> allSessions = sessions; // 다른 달 비교용

  double monthTotalStudySeconds = 0;
  double monthTotalBreakSeconds = 0;
  // 이번달 일별 *공부* 시간 (초 단위, Map key: 1 ~ daysInMonth)
  Map<int, double> currentMonthDailyStudyTotals = { for (int i = 1; i <= daysInMonth; i++) i: 0.0 };
  // 월간 과목별 *공부* 시간 (초 단위)
  Map<String, double> monthlySubjectTotals = {};
  // 일별/과목별 *공부* 시간 (초 단위, Map key: 1 ~ daysInMonth)
  Map<int, Map<String, double>> dailySubjectSeconds = { for (int i = 1; i <= daysInMonth; i++) i: {} };

  // 이번달 세션 데이터 집계
  for (var session in sessions) {
    final sessionDate = DateTime.parse(session.date);
    if (sessionDate.year == year && sessionDate.month == month) {
      final dayOfMonth = sessionDate.day;
      final studySec = session.studyDuration.toDouble();
      final breakSec = session.breakDuration.toDouble();

      monthTotalStudySeconds += studySec;
      monthTotalBreakSeconds += breakSec;
      currentMonthDailyStudyTotals[dayOfMonth] = (currentMonthDailyStudyTotals[dayOfMonth] ?? 0.0) + studySec;

      if (session.intervalType == 'STUDY' && studySec > 0) {
        final subject = subjects.firstWhere((sub) => sub.id == session.subjectId, orElse: () => subjects.first);
        monthlySubjectTotals[subject.name] = (monthlySubjectTotals[subject.name] ?? 0.0) + studySec;
        dailySubjectSeconds[dayOfMonth]![subject.name] = (dailySubjectSeconds[dayOfMonth]![subject.name] ?? 0) + studySec;
      }
    }
  }

  // 지난달 일별 *공부* 시간 계산 (비교용)
  final prevMonthDate = DateTime(year, month - 1, 1);
  final daysInPrevMonth = DateUtils.getDaysInMonth(prevMonthDate.year, prevMonthDate.month);
  // 지난달 일별 *공부* 시간 (초 단위, Map key: 1 ~ daysInMonth)
  Map<int, double> prevMonthDailyStudyTotals = { for (int i = 1; i <= daysInMonth; i++) i: 0.0 };
  double prevMonthTotalStudySeconds = 0;
  for (var session in sessions) {
    final sessionDate = DateTime.parse(session.date);
    if (sessionDate.year == prevMonthDate.year && sessionDate.month == prevMonthDate.month) {
       prevMonthTotalStudySeconds += session.studyDuration;
       if(sessionDate.day <= daysInMonth) { // 현재 월 일수보다 작거나 같은 날짜만 집계
          prevMonthDailyStudyTotals[sessionDate.day] = (prevMonthDailyStudyTotals[sessionDate.day] ?? 0.0) + session.studyDuration;
       }
    }
  }
  // 월간 총 공부 시간 비교값
  final double comparisonDiff = monthTotalStudySeconds - prevMonthTotalStudySeconds;

  // 공부 기록이 있는 과목 리스트 (범례용)
  final subjectsWithData = subjects.where((s) => (monthlySubjectTotals[s.name] ?? 0.0) > 0).toList();

  // 이번달 일별 시작/종료 시간 계산
  final monthlySessions = sessions.where((s) {
     final sessionDate = DateTime.parse(s.date);
     return sessionDate.year == year && sessionDate.month == month;
  }).toList();
  // Map key: 1 ~ daysInMonth
  final dailyStartTimes = _calculateDailyStartTimes(monthlySessions, (s) => DateTime.parse(s.date).day);
  final dailyEndTimes = _calculateDailyEndTimes(monthlySessions, (s) => DateTime.parse(s.date).day);


  // --- 2. UI 구성 (ListView - 주간 탭 순서 기준) ---
  return ListView(
    padding: const EdgeInsets.all(16),
    children: [
      // --- 카드 1: 월간 캘린더 네비게이터 ---
      _buildMonthlyCalendarNavigator(), // 월 이동 UI
      const SizedBox(height: 16),

      // --- 카드 2: 월간 요약 및 비교 차트 ---
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text('${year}년 ${month}월', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row( // 총 시간, 하루 평균
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(value: formatHourMinute(monthTotalStudySeconds), label: '총 시간', subLabel: '(휴식 ${formatHourMinute(monthTotalBreakSeconds)})'),
                  _StatItem(value: formatHourMinute(monthTotalStudySeconds / daysInMonth), label: '하루 평균'),
                ],
              ),
              const SizedBox(height: 16),
               Text( // 지난달 총 시간 비교
                '지난달 대비: ${comparisonDiff >= 0 ? '+' : ''}${formatHourMinute(comparisonDiff.abs())}',
                style: TextStyle(fontSize: 12, color: comparisonDiff >= 0 ? Colors.green : Colors.red),
              ),
              const SizedBox(height: 16),
              // 월간 비교 차트 (이번달 막대 vs 지난달 점)
              _buildMonthlyComparisonBarChart(currentMonthDailyStudyTotals, prevMonthDailyStudyTotals, daysInMonth),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // --- 카드 3: 시작/종료 시간 차트 ---
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('시작/종료 시간', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // 월간 시작/종료 차트 (일별 공부 시간 막대 + 툴팁)
              _buildMonthlyStartEndBarChart(currentMonthDailyStudyTotals, dailyStartTimes, dailyEndTimes, daysInMonth),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // --- 카드 4: 과목별 비율 ---
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('과목별 비율', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Builder( // Builder 추가
                builder: (context) {
                  // PieChartSectionData 리스트 생성
                  final List<PieChartSectionData> subjectPieData = monthlySubjectTotals.entries
                      .where((entry) => entry.value > 0)
                      .map((entry) {
                        return PieChartSectionData(
                          value: entry.value, title: '',
                          color: subjectColors[entry.key] ?? Colors.grey, radius: 20,
                        );
                      }).toList();

                  return _buildPieChartWithLegend( // 함수 호출
                    subjectPieData, monthlySubjectTotals, subjectColors, monthTotalStudySeconds
                  );
                }
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // --- 카드 5: 공부 / 휴식 비율 ---
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('공부 / 휴식 비율', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
               Builder( // Builder 추가
                builder: (context) {
                  final double totalSeconds = monthTotalStudySeconds + monthTotalBreakSeconds;
                  final primaryColor = Theme.of(context).colorScheme.primary;

                  // PieChartSectionData 리스트 생성
                  final List<PieChartSectionData> studyBreakPieData = (totalSeconds > 0) ? [
                    PieChartSectionData( value: monthTotalStudySeconds, title: '', color: primaryColor, radius: 20 ),
                    PieChartSectionData( value: monthTotalBreakSeconds, title: '', color: Colors.grey.shade400, radius: 20 ),
                  ] : <PieChartSectionData>[];

                  return _buildPieChartWithLegend( // 함수 호출
                    studyBreakPieData,
                    {'공부': monthTotalStudySeconds, '휴식': monthTotalBreakSeconds},
                    {'공부': primaryColor, '휴식': Colors.grey.shade400},
                    totalSeconds
                  );
                }
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // --- 카드 6: 일별 공부 시간 (과목별 누적 막대) ---
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('일별 공부 시간', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // 누적 막대 차트 호출 (isWeekly: false)
              _buildStackedBarChart(dailySubjectSeconds, subjectColors, subjects, false),
              const SizedBox(height: 16),
              _buildChartLegend(subjectColors, subjectsWithData), // 범례
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),

      // --- 카드 7: 공부 시간 누적 ---
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text('공부시간 누적', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // 누적 영역 차트 호출 (isWeekly: false)
              _buildCumulativeAreaChart(dailySubjectSeconds, subjectColors, subjects, false),
            ],
          ),
        ),
      ),
    ],
  );
}

  


  // --- 공통 위젯 빌더 ---

  // 주간 비교 막대 차트
// 주간 비교 막대 차트 (막대 + 점 그래프)

  Widget _buildComparisonBarChart(Map<int, double> currentWeekTotals, Map<int, double> previousWeekTotals) {
    
    // 시간(초)을 시간(hour) 단위로 변환
    final List<double> currentHours = List.generate(7, (i) => (currentWeekTotals[i] ?? 0.0) / 3600.0);
    final List<double> previousHours = List.generate(7, (i) => (previousWeekTotals[i] ?? 0.0) / 3600.0);

    // Y축 최대값 계산
    final double maxCurrent = currentHours.fold<double>(0.0, (p, e) => max(p, e));
    final double maxPrevious = previousHours.fold<double>(0.0, (p, e) => max(p, e));
    final double maxY = max(max(maxCurrent, maxPrevious) * 1.2, 0.5); // 최소 0.5시간
    final double dotHeight = maxY * 0.01; // 점의 세로 크기 (Y축 기준)

    return SizedBox(
      height: 200, // 차트 높이 조절
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          
          // ### 1. BarChartGroupData에 막대(이번주)와 점(지난주)을 모두 포함 ###
          barGroups: List.generate(7, (dayIndex) {
            final thisWeekHour = currentHours[dayIndex];
            final lastWeekHour = previousHours[dayIndex];
            
            return BarChartGroupData(
              x: dayIndex,
              // ### 2. 막대 사이의 간격을 줘서 겹치지 않게 함 ###
              barsSpace: 4, 
              barRods: [
                // Rod 1: "이번 주" (막대)
                BarChartRodData(
                  toY: thisWeekHour,
                  color: Theme.of(context).primaryColor,
                  width: 15,
                  borderRadius: BorderRadius.zero,
                ),
                // Rod 2: "지난주" (점처럼 보이게)
                BarChartRodData(
                  // Y좌표(lastWeekHour)에서 0.01만큼의 아주 짧은 막대를 그림
                  fromY: lastWeekHour > 0 ? lastWeekHour - dotHeight : 0, // 0이면 0에서 시작
                  toY: lastWeekHour,
                  color: Colors.grey.shade600,
                  width: 5, // 점처럼 보이도록 두께 조절
                  borderRadius: const BorderRadius.all(Radius.circular(2.5)),
                ),
              ],
            );
          }),
          
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final days = ['일', '월', '화', '수', '목', '금', '토'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Text(days[value.toInt()], style: const TextStyle(fontSize: 10)),
                );
              },
              reservedSize: 30
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('0h', style: TextStyle(fontSize: 10));
                if (value == meta.max) return Text('${value.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 10));
                if (value > 0 && (value >= meta.max / 2 - 0.1 && value <= meta.max / 2 + 0.1)) {
                   return Text('${value.toStringAsFixed(1)}h', style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
              interval: maxY / 2 > 0 ? maxY / 2 : 1
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)
          ),
          
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.black87,
              // ### 3. 툴팁 로직 수정 (rodIndex로 이번주/지난주 구분 안함) ###
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                // 어떤 막대(rod)를 터치하든 해당 요일(group)의 정보를 모두 보여줌
                final dayIndex = group.x.toInt();
                final thisWeekVal = currentHours[dayIndex];
                final lastWeekVal = previousHours[dayIndex];
                
                String title = "${['일', '월', '화', '수', '목', '금', '토'][dayIndex]}\n";
                String thisWeekStr = "이번주: ${formatHourMinute(thisWeekVal * 3600)}\n";
                String lastWeekStr = "지난주: ${formatHourMinute(lastWeekVal * 3600)}";
                
                return BarTooltipItem(
                  title,
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  children: [
                    TextSpan(text: thisWeekStr, style: TextStyle(color: Colors.grey.shade300)),
                    TextSpan(text: lastWeekStr, style: TextStyle(color: Colors.grey.shade600)),
                  ]
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // 시작/종료 시간 막대 차트 (주간)
Widget _buildStartEndBarChart(Map<String, dynamic> weekStats) {
      final dailyTotals = weekStats['dailyTotals'] as Map<int, double>;
      final dailyStartTimes = weekStats['dailyStartTimes'] as Map<int, DateTime?>;
      final dailyEndTimes = weekStats['dailyEndTimes'] as Map<int, DateTime?>;
      final maxY = dailyTotals.values.fold<double>(0.0, (prev, element) => max(prev, element / 3600.0)) * 1.2;

       return SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
             maxY: max(maxY, 1.0),
             barGroups: List.generate(7, (dayIndex) {
                 final hours = (dailyTotals[dayIndex] ?? 0.0) / 3600.0;
                 return BarChartGroupData(x: dayIndex, barRods: [
                     BarChartRodData(toY: hours, color: Theme.of(context).primaryColor.withOpacity(0.6), width: 15)
                 ]);
             }),
              titlesData: FlTitlesData(
                 bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                       final days = ['일', '월', '화', '수', '목', '금', '토'];
                       return Text(days[value.toInt()], style: const TextStyle(fontSize: 10));
                    },
                     reservedSize: 20
                 )),
                 leftTitles: AxisTitles(sideTitles: SideTitles(
                   showTitles: true,
                   reservedSize: 30,
                   getTitlesWidget: (value, meta) {
                     if (value == 0) return const Text('0h');
                     if (value > 0 && (value % 2 == 0 || value.toStringAsFixed(1).endsWith('.5'))) {
                       return Text('${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}h', style: const TextStyle(fontSize: 10));
                     }
                     return const Text('');
                   },
                    interval: 0.5 // 30분 단위 표시 시도
                 )),
                 topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                 rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
             ),
             borderData: FlBorderData(show: false),
             gridData: FlGridData(
                 show: true,
                 drawVerticalLine: false,
                 getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)
             ),
              // TODO: 터치 시 시작/종료 시간 툴팁 표시 로직 추가
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final dayIndex = group.x.toInt();
                    final hours = rod.toY;
                    final startTime = dailyStartTimes[dayIndex];
                    final endTime = dailyEndTimes[dayIndex];
                    String tooltipText = "${['일', '월', '화', '수', '목', '금', '토'][dayIndex]}\n";
                    tooltipText += "공부: ${formatHourMinute(hours * 3600)}\n";
                    if (startTime != null) tooltipText += "시작: ${DateFormat('HH:mm').format(startTime)}\n";
                    if (endTime != null) tooltipText += "종료: ${DateFormat('HH:mm').format(endTime)}";
                    return BarTooltipItem(
                      tooltipText,
                      const TextStyle(color: Colors.white, fontSize: 10),
                    );
                  },
                ),
             ),
          ),
        ),
      );
  }

  // 비율 도넛 차트 (공부/휴식, 과목별 공통 사용)
  Widget _buildRatioPieChart(double value1, double value2, Map<String, Color> colorMap, String bottomText, {Map<String, double>? dataMapOverride}) {
    
    final dataMap = dataMapOverride ?? {'_value1': value1, '_value2': value2};
    final totalValue = dataMap.values.fold<double>(0.0, (sum, item) => sum + item);
    if (totalValue <= 0) return const SizedBox(height: 150, child: Center(child: Text('데이터 없음')));

    final sections = dataMap.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '',
        color: colorMap[entry.key] ?? Colors.grey,
        radius: 20,
      );
    }).toList();

    if (totalValue == 0) return const SizedBox(height: 150, child: Center(child: Text('데이터 없음')));

    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 45, // 도넛 모양
              sectionsSpace: 2,
              startDegreeOffset: -90, 
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              ...dataMap.entries.map((entry) {
                final percentage = totalValue > 0 ? (entry.value / totalValue * 100) : 0;
                final displayName = entry.key == '_value1' ? '공부' : (entry.key == '_value2' ? '휴식' : entry.key);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, color: colorMap[entry.key] ?? Colors.grey),
                      const SizedBox(width: 8),
                      Text(displayName, style: Theme.of(context).textTheme.bodySmall),
                      const Spacer(),
                      Text('${formatHourMinute(entry.value)} (${percentage.toStringAsFixed(0)}%)', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              }).toList(),
              if (bottomText.isNotEmpty) ...[
                const Divider(height: 16),
                Text(bottomText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyCalendarNavigator() {
     final year = _selectedDate.year;
     final month = _selectedDate.month;
     return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          // 이전 달로 이동 (setState 호출)
          onPressed: () => setState(() => _selectedDate = DateTime(year, month - 1, 1)),
        ),
        Text(
          '${year}년 ${month}월', // 년/월 표시
          style: Theme.of(context).textTheme.titleMedium, // 테마 스타일 적용
        ),
        IconButton(
          icon: const Icon(LucideIcons.chevronRight),
          // 다음 달로 이동 (setState 호출)
           onPressed: () => setState(() => _selectedDate = DateTime(year, month + 1, 1)),
        ),
      ],
    );
  }

  // 과목별 누적 막대 차트 (주간/월간 공통 사용)
  Widget _buildStackedBarChart(Map<dynamic, Map<String, double>> dailyData, Map<String, Color> subjectColors, List<Subject> subjects, bool isWeekly) {
    final barGroups = dailyData.entries.map((entry) {
      final xValue = entry.key; // 요일 인덱스(0-6) 또는 일자(1-31)
      final subjectData = entry.value;
      final rods = <BarChartRodData>[];
      double currentY = 0;
      final sortedSubjects = subjectData.keys.toList()..sort();

      for (var subjectName in sortedSubjects) {
        final seconds = subjectData[subjectName]!;
        if (seconds <= 0) continue;
        final hours = seconds / 3600.0;
        rods.add(BarChartRodData(
            fromY: currentY, toY: currentY + hours,
            color: subjectColors[subjectName] ?? Colors.grey,
            width: isWeekly ? 15 : 8,
            borderRadius: BorderRadius.zero));
        currentY += hours;
      }
      if (rods.isEmpty) rods.add(BarChartRodData(toY: 0, color: Colors.transparent));
      return BarChartGroupData(x: xValue is int ? xValue : int.parse(xValue.toString()), barRods: rods);
    }).toList();

     final maxY = barGroups.fold<double>(0.0, (prev, group) => max(prev, group.barRods.fold<double>(0, (p, r) => p + (r.toY - r.fromY)))) * 1.2;

      return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          maxY: max(maxY, 1.0),
          alignment: BarChartAlignment.spaceAround,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (isWeekly) {
                  final days = ['일', '월', '화', '수', '목', '금', '토'];
                  return Text(days[value.toInt()], style: const TextStyle(fontSize: 10));
                } else { // 월간
                  final day = value.toInt();
                  final daysInMonth = dailyData.length;
                   if (day % 5 == 0 || day == 1 || day == daysInMonth) {
                     return Text('$day', style: const TextStyle(fontSize: 10));
                  }
                  return const Text('');
                }
              },
              reservedSize: 20,
              interval: 1,
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 30,
                getTitlesWidget: (value, meta) {
                   if (value % 2 == 0 && value != 0) return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10));
                   return const Text('');
                }
            )),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)
          ),
          barTouchData: BarTouchData(touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => Colors.black87,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                 final subjectName = subjectColors.entries.firstWhere((entry) => entry.value == rod.color, orElse: () => MapEntry('기타', Colors.grey)).key;
                 final hours = rod.toY - rod.fromY;
                 final label = isWeekly ? ['일', '월', '화', '수', '목', '금', '토'][group.x.toInt()] : '${group.x.toInt()}일';
                 return BarTooltipItem(
                   '$label $subjectName\n',
                   const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                   children: <TextSpan>[TextSpan(text: formatHourMinute(hours * 3600), style: const TextStyle(color: Colors.white))],
                 );
              }
          )),
        ),
      ),
    );
  }

  // 공부 시간 누적 영역 차트 (주간/월간 공통 사용)
  Widget _buildCumulativeAreaChart(Map<dynamic, Map<String, double>> dailyData, Map<String, Color> subjectColors, List<Subject> subjects, bool isWeekly) {
    List<FlSpot> spots = [];
    double cumulativeSeconds = 0;
    List<String> xLabels = [];

    dailyData.entries.forEach((entry) {
      final xValue = entry.key; // 요일 인덱스 또는 일자
      final subjectData = entry.value;
      cumulativeSeconds += subjectData.values.fold<double>(0.0, (sum, item) => sum + item);
      spots.add(FlSpot(xValue.toDouble(), cumulativeSeconds / 3600.0)); // 시간 단위로

      // X축 레이블 생성
      if (isWeekly) {
          xLabels.add(['일', '월', '화', '수', '목', '금', '토'][xValue]);
      } else {
          if (xValue % 5 == 0 || xValue == 1 || xValue == dailyData.length) {
              xLabels.add('$xValue');
          } else {
              xLabels.add('');
          }
      }
    });

     if (cumulativeSeconds == 0) return const SizedBox(height: 250, child: Center(child: Text('데이터 없음')));

      final maxY = spots.isNotEmpty ? spots.last.y * 1.2 : 1.0;

    return SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: max(maxY, 1.0),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Theme.of(context).primaryColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false), // 점 숨기기
              belowBarData: BarAreaData( // 영역 채우기
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.3),
                    Theme.of(context).primaryColor.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                   if (index >= 0 && index < xLabels.length) {
                       return Text(xLabels[index], style: const TextStyle(fontSize: 10));
                   }
                   return const Text('');
              },
               reservedSize: 20,
               interval: 1, // 모든 지점에 대해 레이블 생성 시도
            )),
            leftTitles: AxisTitles(sideTitles: SideTitles(
               showTitles: true, reservedSize: 30,
               getTitlesWidget: (value, meta) {
                   if (value == 0) return const Text('0h');
                    if (value > 0 && (value % (maxY / 4).ceil() == 0 || value == maxY) ) { // Y축 4등분 표시 시도
                       return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10));
                   }
                   return const Text('');
               },
               interval: (maxY / 4).ceilToDouble() > 0 ? (maxY / 4).ceilToDouble() : 1 // Y축 간격
            )),
             topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
             rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)
          ),
           lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => Colors.black87,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                       final xLabel = isWeekly ? ['일', '월', '화', '수', '목', '금', '토'][spot.x.toInt()] : '${spot.x.toInt()}일';
                      return LineTooltipItem(
                         '$xLabel\n',
                         const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                         children: [
                           TextSpan(text: '누적: ${formatHourMinute(spot.y * 3600)}', style: const TextStyle(color: Colors.white)),
                         ]
                      );
                    }).toList();
                  }
              )
           ),
        ),
      ),
    );
  }

  // 캘린더 뷰 구현 (간단 버전)
  Widget _buildDailyCalendarView(List<StudySession> sessions) {
      // 월별 데이터 그룹화 (현재 표시된 달 기준)
    final sessionsByDate = <String, double>{};
    for (var session in sessions) {
      final sessionDate = DateTime.parse(session.date);
      if(sessionDate.year == _calendarViewDate.year && sessionDate.month == _calendarViewDate.month){
          sessionsByDate[session.date] = (sessionsByDate[session.date] ?? 0) + session.studyDuration;
      }
    }

    final year = _calendarViewDate.year;
    final month = _calendarViewDate.month;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final firstDayOfMonth = DateTime(year, month, 1);
    final firstWeekday = (firstDayOfMonth.weekday + 6) % 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft),
                  // 이전 달로 이동
                  onPressed: () => setState(() => _calendarViewDate = DateTime(year, month - 1, 1)),
                ),
                Text('${month}월', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight),
                   // 다음 달로 이동
                   onPressed: () => setState(() => _calendarViewDate = DateTime(year, month + 1, 1)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['일', '월', '화', '수', '목', '금', '토'].map((day) => Text(day, style: Theme.of(context).textTheme.bodySmall)).toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.0),
              itemCount: daysInMonth + firstWeekday,
              itemBuilder: (context, index) {
                if (index < firstWeekday) {
                  return Container(); // 빈 칸
                }
                final day = index - firstWeekday + 1;
                final date = DateTime(year, month, day);
                final dateStr = DateFormat('yyyy-MM-dd').format(date);
                final studySeconds = sessionsByDate[dateStr] ?? 0;
                final studyHours = studySeconds / 3600.0;
                final isSelected = DateUtils.isSameDay(_selectedDate, date);
                final isToday = DateUtils.isSameDay(DateTime.now(), date);

                 // 색상 강도 계산 (React 코드 참고)
                Color bgColor;
                if (studyHours == 0) bgColor = Colors.grey.shade200.withOpacity(0.2);
                else if (studyHours < 2) bgColor = Theme.of(context).primaryColor.withOpacity(0.2);
                else if (studyHours < 4) bgColor = Theme.of(context).primaryColor.withOpacity(0.4);
                else if (studyHours < 6) bgColor = Theme.of(context).primaryColor.withOpacity(0.6);
                else if (studyHours < 8) bgColor = Theme.of(context).primaryColor.withOpacity(0.8);
                else bgColor = Theme.of(context).primaryColor;


                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedDate = date;
                    _calendarViewDate = date;
                  }),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(4),
                      border: isToday ? Border.all(color: Theme.of(context).primaryColor, width: 1.5) : null,
                      boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.5), blurRadius: 3)] : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day.toString(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: studyHours > 4
                                  ? Colors.white
                                  : Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                            ),
                          ),
                          if (studyHours > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              formatHourMinute(studySeconds),
                              style: TextStyle(
                                fontSize: 11,
                                color: studyHours > 4
                                    ? Colors.white.withOpacity(0.8)
                                    : Colors.grey.shade600,
                              ),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // 월간 탭의 네비게이터 (월 이동)
  

  // 차트 범례 위젯
  Widget _buildChartLegend(Map<String, Color> subjectColors, List<Subject> subjects) {
      // 실제 데이터가 있는 과목만 필터링 (선택 사항)
     final relevantSubjects = subjects.where((sub) => subjectColors.containsKey(sub.name)).toList();
     if (relevantSubjects.isEmpty) return const SizedBox.shrink();

     return Wrap( // 여러 줄로 표시될 수 있도록 Wrap 사용
       spacing: 16.0, // 가로 간격
       runSpacing: 8.0, // 세로 간격
       alignment: WrapAlignment.center,
       children: relevantSubjects.map((subject) {
          return Row(
             mainAxisSize: MainAxisSize.min,
             children: [
                Container(width: 10, height: 10, color: subjectColors[subject.name]),
                const SizedBox(width: 4),
                Text(subject.name, style: Theme.of(context).textTheme.bodySmall)
             ]
          );
       }).toList(),
     );
  }

  // 간단한 시간대별 바 차트 (0-24시)
  Widget _buildHourlyBarChartSimple(List<StudySession> sessions) {
      final hourlyData = List.filled(24, 0.0); // 0시 ~ 23시

      for(var session in sessions){
          final start = session.startTime;
          final end = session.endTime ?? start.add(Duration(seconds: session.studyDuration));
          int startHour = start.hour;
          int endHour = end.hour;

          // 세션이 여러 시간에 걸쳐 있을 경우 분배
          if(startHour == endHour) {
              hourlyData[startHour] += (session.studyDuration / 3600.0);
          } else {
              // 시작 시간 처리
              double firstHourRatio = (60.0 - start.minute) / 60.0;
              hourlyData[startHour] += (session.studyDuration / 3600.0) * firstHourRatio;
              
              // 중간 시간 처리
              for(int h = startHour + 1; h < endHour; h++){
                  hourlyData[h] += 1.0; // 1시간 전체
              }

              // 종료 시간 처리
              double lastHourRatio = end.minute / 60.0;
               // endHour가 24시(다음날 0시)일 경우 예외 처리
              if (endHour < 24) {
                 hourlyData[endHour] += (session.studyDuration / 3600.0) * lastHourRatio;
              } else if (end.minute > 0) { // 정확히 24:00 종료가 아닌 경우
                 // 23시 인덱스에 남은 시간 추가 (간단 처리)
                 // 실제로는 더 정확한 계산이 필요할 수 있음
                 hourlyData[23] += (session.studyDuration / 3600.0) * lastHourRatio;
              }
          }
      }

      // 시간 레이블 (0, 12, 24)
      final timeLabels = ['0:00', '12:00', '24:00'];

      return Column(
        children: [
          SizedBox(
            height: 100, // 차트 높이
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (index) {
                double barHeight = hourlyData[index] * 100.0; // 시간당 최대 100px 높이 가정
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: Theme.of(context).primaryColor,
                    height: barHeight.clamp(0, 100), // 최대 높이 제한
                  ),
                );
              }),
            ),
          ),
           const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: timeLabels.map((label) => Text(label, style: Theme.of(context).textTheme.bodySmall)).toList(),
          )
        ],
      );
  }

  // 파이 차트와 범례 위젯
  Widget _buildPieChartWithLegend(List<PieChartSectionData> sections, Map<String, double> dataMap, Map<String, Color> colorMap, double totalValue) {
    if (sections.isEmpty) return const SizedBox(height: 100, child: Center(child: Text('데이터 없음')));
    
    final newSections = sections.map((s) {
      return s.copyWith(
        title: '',
        radius: 20,
      );
    }).toList();

    return Row(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: PieChart(
            PieChartData(
              sections: newSections,
              centerSpaceRadius: 45,
              sectionsSpace: 0,
              startDegreeOffset: -90,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: dataMap.entries.map((entry) {
              final percentage = totalValue > 0 ? (entry.value / totalValue * 100) : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Container(width: 12, height: 12, color: colorMap[entry.key] ?? Colors.grey),
                    const SizedBox(width: 8),
                    Text(entry.key, style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    Text('${formatHourMinute(entry.value)} (${percentage.toStringAsFixed(0)}%)', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // 시간대별 타임라인 바
  Widget _buildHourlyTimeline(List<StudySession> sessions, List<Subject> subjects) {

    final subjectColors = getSubjectColors(context);
    // 0시부터 23시까지
    return Column(
      children: List.generate(24, (hour) {
        // 해당 시간대의 세션 필터링
        List<Map<String, dynamic>> hourSegments = [];
        for (var session in sessions) {
          final start = session.startTime;
          final end = session.endTime ?? start;

          final isBreak = session.intervalType == 'BREAK';
          final duration = isBreak ? session.breakDuration : session.studyDuration;

          if (duration <= 0) continue;

          final subject = subjects.firstWhere((s) => s.id == session.subjectId, orElse: () => subjects.first);

        //    맵에서 색상을 찾습니다.
          final color = isBreak
              ? Colors.grey.shade400 // 휴식: 회색
              : subjectColors[subject.name] ?? Theme.of(context).colorScheme.primary; // 공부: 맵에서 찾은 색상
          final sessionStartHour = start.hour;
          final sessionEndHour = (end.minute == 0 && end.second == 0 && end.hour > start.hour) 
                             ? end.hour - 1 // 11:00 정각 종료는 10시 칸까지
                             : end.hour;    // 11:10 종료는 11시 칸까지

          if (hour >= sessionStartHour && hour <= sessionEndHour) {
            // 이 시간 내에서의 시작 분, 종료 분 계산
            int startMinute = (hour == sessionStartHour) ? start.minute : 0;
            int endMinute = (hour == sessionEndHour) ? end.minute : 60;
            if (startMinute >= endMinute) continue;
            if (hour == sessionEndHour && end.minute == 0 && end.second == 0) endMinute = 0;

            // [!] 11:00 정각 종료 시 endMinute이 0이므로, 10시 칸(hour=10)은 60으로 설정
            if (hour == sessionStartHour && hour < sessionEndHour && end.minute == 0 && end.second == 0) endMinute = 60;

            if (startMinute >= endMinute && !(startMinute == 0 && endMinute == 0)) continue;

            hourSegments.add({
              'start': startMinute,
              'end': endMinute,
              'color': color,
            });
          }
        }

        hourSegments.sort((a, b) => a['start'].compareTo(b['start']));
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            children: [
              SizedBox(width: 25, child: Text('$hour', style: Theme.of(context).textTheme.bodySmall)),
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(2),
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: hourSegments.map((segment) {
                          final leftPercent = segment['start'] / 60.0;
                          final widthPercent = (segment['end'] - segment['start']) / 60.0;
                          if (widthPercent <= 0) return const SizedBox.shrink();
                          return Positioned(
                            left: constraints.maxWidth * leftPercent,
                            width: constraints.maxWidth * widthPercent,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              color: segment['color'],
                            )
                          );
                        }).toList(),
                      );
                    }
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // 타임라인 리스트 아이템
  Widget _buildTimelineListItem(StudySession session, List<Subject> subjects) {
    final start = session.startTime;
    final end = session.endTime ?? start;

    final bool isBreak = session.intervalType == 'BREAK';

    final subject = isBreak
        ? Subject(
            // id: null, // 임시 객체이므로 서버 id는 없음
            name: '휴식',
            color: Colors.grey.shade400,
            serverId: '--' // [!] serverId 추가 (임의의 값)
          )
        : subjects.firstWhere(
            // [!] s.id 대신 s.serverId 와 비교
            (s) => s.serverId == session.subjectId,
            // 못 찾을 경우 기본값
            orElse: () => Subject(id: null, name: '삭제된 과목?', color: Colors.grey, serverId: session.subjectId)
          );
        final duration = (isBreak ? session.breakDuration : session.studyDuration).toDouble();
    // TODO: Expandable 기능 추가 필요

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
         leading: Text(DateFormat('a h:mm', 'ko_KR').format(start), style: Theme.of(context).textTheme.bodySmall),
         title: Row(
            children: [
              Container(width: 4, height: 30, color: subject.color, margin: const EdgeInsets.only(right: 8)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject.name, style: Theme.of(context).textTheme.bodyMedium),
                  Text('${formatHourMinute(duration)} (${DateFormat('a h:mm', 'ko_KR').format(start)} - ${DateFormat('a h:mm', 'ko_KR').format(end)})', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ]
         ),
         trailing: const Icon(LucideIcons.plus, size: 16), // Expand 아이콘으로 변경 필요
         onTap: () {
           // TODO: Expand 기능 구현
         },
      )
    );
  }
}