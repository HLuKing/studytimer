import 'package:flutter/material.dart';

// 라이트 테마
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  primaryColor: const Color(0xFF030213),
  scaffoldBackgroundColor: const Color(0xFFFFFFFF),
  cardColor: const Color(0xFFFFFFFF),
  dividerColor: const Color.fromRGBO(0, 0, 0, 0.1),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFF252525)),
    titleLarge: TextStyle(color: Color(0xFF030213), fontWeight: FontWeight.w500),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF030213), // 앱의 기본 색상을 seedColor로 지정
    brightness: Brightness.light, // 라이트 모드
  ).copyWith(
    // fromSeed로 자동 생성된 색상 중 특별히 바꾸고 싶은 색상만 여기서 덮어쓴다.
    secondary: const Color(0xFFE9EBEF),
    onSecondary: const Color(0xFF030213),
    error: const Color(0xFFD4183D),
    onError: const Color(0xFFFFFFFF),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: const Color(0xFF030213),
    linearTrackColor: const Color(0xFF030213).withAlpha(26),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
      side: const BorderSide(color: Color.fromRGBO(0, 0, 0, 0.1), width: 1),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFFFFFFFF),
    selectedItemColor: Color(0xFF030213),
    unselectedItemColor: Colors.grey,
    type: BottomNavigationBarType.fixed,
  ),
);

// 다크 테마
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: const Color(0xFFFAFAFA),
  scaffoldBackgroundColor: const Color(0xFF252525),
  cardColor: const Color(0xFF252525),
  dividerColor: const Color(0xFF454545),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFFFAFAFA)),
    titleLarge: TextStyle(color: Color(0xFFFAFAFA), fontWeight: FontWeight.w500),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF030213), // 라이트 테마와 동일한 seedColor를 사용
    brightness: Brightness.dark, // 다크 모드
  ).copyWith(
    // 다크 모드에서 특별히 바꾸고 싶은 색상 지정
    secondary: const Color(0xFF454545),
    onSecondary: const Color(0xFFFAFAFA),
    error: const Color(0xFF652541),
    onError: const Color(0xFFA33B40),
  ),
  progressIndicatorTheme: ProgressIndicatorThemeData(
    color: const Color(0xFFFAFAFA),
    linearTrackColor: const Color(0xFFFAFAFA).withAlpha(26),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
      side: const BorderSide(color: Color(0xFF454545), width: 1),
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF252525),
    selectedItemColor: Color(0xFFFAFAFA),
    unselectedItemColor: Colors.grey,
    type: BottomNavigationBarType.fixed,
  ),
);