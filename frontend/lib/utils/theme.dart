import 'package:flutter/material.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  
  // 1. 배경색 (로그인 화면의 Colors.grey[100])
  scaffoldBackgroundColor: const Color(0xFFF5F5F5), 
  
  // 2. 카드색 (로그인 화면의 Colors.white)
  cardColor: const Color(0xFFFFFFFF), 
  
  dividerColor: Colors.grey.shade200,
  
  // 3. 연보라색 제거 (Primary 색상을 검은색으로 고정)
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF030213), // 검은색
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF030213), // 앱의 기본색 (그래프, 아이콘 등)
    onPrimary: Colors.white,
    secondary: Colors.grey.shade200,  // 휴식 시간 등 보조색
    onSecondary: Colors.black,
  ),
  
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white, // AppBar 배경 흰색
    foregroundColor: Color(0xFF030213), // AppBar 글자/아이콘 검은색
    elevation: 0, // 그림자 제거
    surfaceTintColor: Colors.transparent, // 스크롤 시 색상 변경 방지
    titleTextStyle: TextStyle( // 제목 스타일 명시
       color: Color(0xFF030213),
       fontSize: 20,
       fontWeight: FontWeight.bold // 제목 굵게
    ),
    iconTheme: IconThemeData(color: Color(0xFF030213)), // 아이콘 색상
    actionsIconTheme: IconThemeData(color: Color(0xFF030213)), // 액션 아이콘 색상
  ),

  // 4. 카드 테마 (그림자 대신 연한 테두리 사용)
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white, // 카드 배경은 항상 흰색
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.0),
      side: BorderSide(color: Colors.grey.shade200, width: 1),
    ),
  ),

  // 5. 하단 네비게이션 바 테마
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: Color(0xFF030213), // 선택: 검은색
    unselectedItemColor: Colors.grey,     // 비선택: 회색
    type: BottomNavigationBarType.fixed,
  ),
  
  // 6. 탭바 테마 (통계 화면)
  tabBarTheme: TabBarThemeData(
    labelColor: const Color(0xFF030213), // 선택된 탭: 검은색
    unselectedLabelColor: Colors.grey, // 비선택 탭: 회색
    indicatorColor: const Color(0xFF030213), // 하단 밑줄: 검은색
  ),
);

// 다크 테마
final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF252525),
  cardColor: const Color(0xFF252525),
  dividerColor: const Color(0xFF454545),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Color(0xFFFAFAFA)),
    titleLarge: TextStyle(color: Color(0xFFFAFAFA), fontWeight: FontWeight.w500),
    titleMedium: TextStyle(color: Color(0xFF030213)),
  ),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF030213), // 라이트 테마와 동일한 seedColor를 사용
    brightness: Brightness.dark, // 다크 모드
  ).copyWith(
    // 다크 모드에서 특별히 바꾸고 싶은 색상 지정
    primary: const Color(0xFFFAFAFA),
    onPrimary: Colors.black,
    secondary: Colors.grey.shade700,
    onSecondary: Colors.white,
    surface: Colors.white,       // AppBar 배경색
    onSurface: const Color(0xFF030213), // AppBar 위 글자/아이콘 색상
    error: const Color(0xFF652541),
    onError: const Color(0xFFA33B40),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white, // AppBar 배경 흰색
    foregroundColor: Color(0xFF030213), // AppBar 글자/아이콘 검은색
    elevation: 0, // 그림자 제거
    surfaceTintColor: Colors.transparent, // 스크롤 시 색상 변경 방지
    titleTextStyle: TextStyle( // 제목 스타일 명시
       color: Color(0xFF030213),
       fontSize: 20,
       fontWeight: FontWeight.bold // 제목 굵게
    ),
    iconTheme: IconThemeData(color: Color(0xFF030213)), // 아이콘 색상
    actionsIconTheme: IconThemeData(color: Color(0xFF030213)), // 액션 아이콘 색상
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