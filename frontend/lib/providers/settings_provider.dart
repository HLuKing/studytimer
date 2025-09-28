import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  double _dailyGoal = 4.0;
  bool _notifications = true;
  bool _isDarkMode = false;
  bool _soundEnabled = true;

  double get dailyGoal => _dailyGoal;
  bool get notifications => _notifications;
  bool get isDarkMode => _isDarkMode;
  bool get soundEnabled => _soundEnabled;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsData = prefs.getString('studySettings');
    if (settingsData != null) {
      final settings = jsonDecode(settingsData);
      _dailyGoal = (settings['dailyGoal'] as num?)?.toDouble() ?? 4.0;
      _notifications = settings['notifications'] ?? true;
      _isDarkMode = settings['darkMode'] ?? false;
      _soundEnabled = settings['soundEnabled'] ?? true;
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = {
      'dailyGoal': _dailyGoal,
      'notifications': _notifications,
      'darkMode': _isDarkMode,
      'soundEnabled': _soundEnabled,
    };
    await prefs.setString('studySettings', jsonEncode(settings));
    notifyListeners();
  }

  void updateDailyGoal(double newGoal) {
    _dailyGoal = newGoal;
    _saveSettings();
  }

  void updateNotifications(bool enabled) {
    _notifications = enabled;
    _saveSettings();
  }

  void updateDarkMode(bool enabled) {
    _isDarkMode = enabled;
    _saveSettings();
  }

  void updateSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    _saveSettings();
  }
}