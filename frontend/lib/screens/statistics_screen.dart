import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';
import '../models/study_session_model.dart';
import '../providers/settings_provider.dart';
import '../providers/study_provider.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessions = context.watch<StudyProvider>().sessions;
    final dailyGoal = context.watch<SettingsProvider>().dailyGoal;

    // 오늘 날짜 문자열 (YYYY-MM-DD)
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    
    // 통계 계산
    final todaySessions = sessions.where((s) => s.date == todayStr).toList();
    final weekSessions = _getThisWeekSessions(sessions);
    final monthSessions = _getThisMonthSessions(sessions);

    final todayStats = _calculateStats(todaySessions);
    final weekStats = _calculateStats(weekSessions);
    final monthStats = _calculateStats(monthSessions);
    
    final dailyProgress = (todayStats['studyDuration']! / (dailyGoal * 3600)).clamp(0.0, 1.0);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('통계'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '오늘'),
              Tab(text: '이번 주'),
              Tab(text: '이번 달'),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 오늘의 목표 카드
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(LucideIcons.target),
                      title: Text('오늘의 목표', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(todayStats['studyDuration']!)),
                        Text('${dailyGoal.toInt()}시간 목표'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: dailyProgress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dailyProgress >= 1.0
                          ? '목표 달성! 🎉'
                          : '목표까지 ${_formatDuration((dailyGoal * 3600) - todayStats['studyDuration']!)} 남음',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 탭별 통계 뷰
            SizedBox(
              height: 400, // TabBarView requires a constrained height within a ListView
              child: TabBarView(
                children: [
                  _buildTodayView(context, todayStats, todaySessions.length),
                  _buildWeekView(context,weekStats, weekSessions),
                  _buildMonthView(context,monthStats, monthSessions.length),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  Map<String, double> _calculateStats(List<StudySession> sessions) {
    double studyDuration = 0;
    double breakDuration = 0;
    for (var session in sessions) {
      studyDuration += session.studyDuration;
      breakDuration += session.breakDuration;
    }
    return {'studyDuration': studyDuration, 'breakDuration': breakDuration};
  }

  String _formatDuration(double totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final duration = Duration(seconds: totalSeconds.toInt());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
  
  List<StudySession> _getThisWeekSessions(List<StudySession> sessions) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekStr = startOfWeek.toIso8601String().split('T')[0];
    return sessions.where((s) => s.date.compareTo(startOfWeekStr) >= 0).toList();
  }

  List<StudySession> _getThisMonthSessions(List<StudySession> sessions) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfMonthStr = startOfMonth.toIso8601String().split('T')[0];
    return sessions.where((s) => s.date.compareTo(startOfMonthStr) >= 0).toList();
  }

  Widget _buildTodayView(BuildContext context,Map<String, double> stats, int sessionCount) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Text('오늘의 공부', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(value: _formatDuration(stats['studyDuration']!), label: '공부시간'),
                _StatItem(value: _formatDuration(stats['breakDuration']!), label: '쉬는시간'),
              ],
            ),
            _StatItem(value: '$sessionCount개 세션', label: '완료'),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(BuildContext context,Map<String, double> stats, List<StudySession> weekSessions) {
    final weeklyData = List.filled(7, 0.0);
    for (var session in weekSessions) {
      final dayIndex = session.startTime.weekday - 1; // 월요일 = 0
      weeklyData[dayIndex] += session.studyDuration / 3600.0; // 시간 단위로
    }
    final maxHours = weeklyData.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('주간 통계', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(value: _formatDuration(stats['studyDuration']!), label: '총 공부시간'),
                _StatItem(value: '${weekSessions.length}', label: '총 세션'),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(child: _WeeklyChart(data: weeklyData, maxHours: maxHours)),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthView(BuildContext context,Map<String, double> stats, int sessionCount) {
    final daysInMonth = DateTime.now().day;
    final avgHours = (stats['studyDuration']! / 3600) / daysInMonth;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Text('월간 통계', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(value: _formatDuration(stats['studyDuration']!), label: '총 공부시간'),
                 _StatItem(value: '$sessionCount', label: '총 세션'),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withAlpha(128),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('일평균 ${avgHours.toStringAsFixed(1)}시간 공부했어요'),
            )
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  final List<double> data;
  final double maxHours;
  const _WeeklyChart({required this.data, required this.maxHours});

  @override
  Widget build(BuildContext context) {
    final days = ['월', '화', '수', '목', '금', '토', '일'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final barHeight = (data[index] / (maxHours == 0 ? 1 : maxHours)) * 100;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('${data[index].toStringAsFixed(1)}h', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Container(
              height: barHeight,
              width: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(days[index]),
          ],
        );
      }),
    );
  }
}