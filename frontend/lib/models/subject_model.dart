import 'package:flutter/material.dart';

class Subject {
  final int? id;
  final String name;
  final Color color;
  final String serverId;

  Subject({
    this.id, 
    required this.name, 
    required this.color,
    required this.serverId,
    });

  factory Subject.fromJson(Map<String, dynamic> json) {
    // 서버에서 받은 color 문자열 (e.g., "0xFF030213")을 Color 객체로 변환 시도
    Color parsedColor = Colors.grey; // 기본값
    try {
      if (json['color'] != null && json['color'].startsWith('0x')) {
         parsedColor = Color(int.parse(json['color']));
      } else if (json['color'] != null) {
         // "FF030213" 같은 형식 처리 (앞에 "0xFF" 추가)
         parsedColor = Color(int.parse("0xFF${json['color']}"));
      }
    } catch (e) {
      print("Color parsing error: ${json['color']} - $e");
    }

    return Subject(
      // [!] 서버 ID (숫자)를 int? 로 변환
      id: json['id'] as int?, 
      name: json['name'],
      color: parsedColor,
      // [!] serverId를 String으로 저장
      serverId: json['id']?.toString() ?? '', 
    );
  }

  Map<String, dynamic> toJson() {
    // Color를 "0xAARRGGBB" 형태의 문자열로 저장
    String colorString = '0x${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';

    return {
      // 서버로 보낼 때는 int id 대신 String serverId 사용 안 함 (주로 name, color만 보냄)
      // 'id': id?.toString(), // 로컬 저장용으로 필요하면 사용
      'name': name,
      'color': colorString, // "0xFF030213" 형식으로 저장
    };
  }
}