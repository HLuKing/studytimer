import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/goal_model.dart';

class GoalsProvider with ChangeNotifier {
  List<Goal> _goals = [];
  List<Goal> get goals => _goals;

  Future<void> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final goalsData = prefs.getString('studyGoals');
    if (goalsData != null) {
      final List<dynamic> decodedData = jsonDecode(goalsData);
      _goals = decodedData.map((item) => Goal.fromJson(item)).toList();
    } else {
      _goals = _getSampleGoals();
      await _saveGoals();
    }
    notifyListeners();
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> encodedData =
        _goals.map((goal) => goal.toJson()).toList();
    await prefs.setString('studyGoals', jsonEncode(encodedData));
  }

  void addGoal(Goal newGoal) {
    _goals.add(newGoal);
    _saveGoals();
    notifyListeners();
  }

  void updateGoal(String id, Goal updatedGoal) {
    final index = _goals.indexWhere((goal) => goal.id == id);
    if (index != -1) {
      _goals[index] = updatedGoal;
      _saveGoals();
      notifyListeners();
    }
  }

  void deleteGoal(String id) {
    _goals.removeWhere((goal) => goal.id == id);
    _saveGoals();
    notifyListeners();
  }

  // 공부 세션이 완료될 때 호출하여 목표 진행률 업데이트
  void updateGoalsProgress(double hours) {
    for (var goal in _goals) {
      goal.current += hours;
    }
    _saveGoals();
    notifyListeners();
  }

  List<Goal> _getSampleGoals() {
    return [
      Goal(
        id: '1',
        title: '토익 800점 달성',
        target: 100,
        current: 45,
        deadline: DateTime(2024, 12, 31),
        category: '영어',
      ),
      Goal(
        id: '2',
        title: '자격증 취득',
        target: 50,
        current: 15,
        deadline: DateTime(2024, 11, 30),
        category: '자격증',
      ),
    ];
  }
}