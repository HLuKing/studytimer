import 'dart:convert';

class Goal {
  final String id;
  final String title;
  final double target; // hours
  double current; // hours
  final DateTime deadline;
  final String category;

  Goal({
    required this.id,
    required this.title,
    required this.target,
    this.current = 0.0,
    required this.deadline,
    required this.category,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'],
      title: json['title'],
      target: (json['target'] as num).toDouble(),
      current: (json['current'] as num).toDouble(),
      deadline: DateTime.parse(json['deadline']),
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'target': target,
      'current': current,
      'deadline': deadline.toIso8601String(),
      'category': category,
    };
  }
}