import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/set_display_name_screen.dart';

class Routes {
  static const login = '/login';
  static const home = '/home';
  static const setDisplayName = '/set-display-name';
}

class AppRouter {
  static Route onGenerateRoute(RouteSettings s) {
    switch (s.name) {
      case Routes.login: return _p(const LoginScreen());
      case Routes.home: return _p(const HomeScreen());
      case Routes.setDisplayName: return _p(const SetDisplayNameScreen());
      default: return _p(const LoginScreen());
    }
  }
  static MaterialPageRoute _p(Widget child) =>
      MaterialPageRoute(builder: (_) => child);
}