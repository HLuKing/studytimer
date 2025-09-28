import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:provider/provider.dart';
import '../models/goal_model.dart';
import '../providers/goals_provider.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final goalsProvider = context.watch<GoalsProvider>();
    final goals = goalsProvider.goals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('목표 관리'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.plus),
            onPressed: () => _showGoalDialog(context),
          ),
        ],
      ),
      body: goals.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.target, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('설정된 목표가 없습니다.'),
                  Text('첫 목표를 추가해보세요!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                return GoalCard(goal: goal);
              },
            ),
    );
  }
}

class GoalCard extends StatelessWidget {
  final Goal goal;

  const GoalCard({super.key, required this.goal});

  @override
  Widget build(BuildContext context) {
    final progress = (goal.current / goal.target).clamp(0.0, 1.0);
    final daysLeft = goal.deadline.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(goal.title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.pencil, size: 18),
                  onPressed: () => _showGoalDialog(context, goal: goal),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(context, goal.id),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text(goal.category),
                  padding: EdgeInsets.zero,
                ),
                Text(
                  daysLeft < 0 ? '마감일 지남' : 'D-${daysLeft + 1}',
                  style: TextStyle(
                      color: daysLeft < 3 ? Colors.red : Colors.grey,
                      fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${goal.current.toStringAsFixed(1)}시간'),
                Text('${goal.target.toStringAsFixed(1)}시간 목표'),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).toStringAsFixed(1)}% 달성'),
                Text(
                    '${(goal.target - goal.current).toStringAsFixed(1)}시간 남음'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String goalId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('목표 삭제'),
          content: const Text('정말로 이 목표를 삭제하시겠습니까?'),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('삭제', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Provider.of<GoalsProvider>(context, listen: false)
                    .deleteGoal(goalId);
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

// 목표 추가/수정 다이얼로그
void _showGoalDialog(BuildContext context, {Goal? goal}) {
  final isEditing = goal != null;
  final titleController = TextEditingController(text: isEditing ? goal.title : '');
  final categoryController = TextEditingController(text: isEditing ? goal.category : '');
  final targetController = TextEditingController(text: isEditing ? goal.target.toString() : '');
  DateTime selectedDate = isEditing ? goal.deadline : DateTime.now();

  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(isEditing ? '목표 수정' : '새 목표 추가'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '목표 제목'),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: '카테고리'),
              ),
              TextField(
                controller: targetController,
                decoration: const InputDecoration(labelText: '목표 시간 (시간)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return ListTile(
                    title: const Text("마감일"),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2101),
                      );
                      if (picked != null && picked != selectedDate) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                  );
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('취소'),
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
          ),
          TextButton(
            child: Text(isEditing ? '저장' : '추가'),
            onPressed: () {
              final newGoal = Goal(
                id: isEditing ? goal.id : DateTime.now().millisecondsSinceEpoch.toString(),
                title: titleController.text,
                category: categoryController.text,
                target: double.tryParse(targetController.text) ?? 0,
                deadline: selectedDate,
                current: isEditing ? goal.current : 0,
              );

              if (isEditing) {
                Provider.of<GoalsProvider>(context, listen: false).updateGoal(goal.id, newGoal);
              } else {
                Provider.of<GoalsProvider>(context, listen: false).addGoal(newGoal);
              }

              Navigator.of(dialogContext).pop();
            },
          ),
        ],
      );
    },
  );
}