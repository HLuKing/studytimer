import 'package:flutter/material.dart';

class Subject {
  final String id;
  final String name;
  final Color color;

  Subject({required this.id, required this.name, required this.color});

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'],
      name: json['name'],
      color: Color(int.parse(json['color'])),
    );
  }

  Map<String, dynamic> toJson() {
    // Color를 int(hex) 문자열로 저장
    return {
      'id': id,
      'name': name,
      'color': color.value.toString(),
    };
  }
}