import 'package:flutter/material.dart';

enum LapType { study, breakTime }

class LapTime {
  final String id;
  final LapType type;
  final Duration duration;
  final String subjectId;
  final DateTime timestamp;

  LapTime({
    required this.id,
    required this.type,
    required this.duration,
    required this.subjectId,
    required this.timestamp,
  });
}