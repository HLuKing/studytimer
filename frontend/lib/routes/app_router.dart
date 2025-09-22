import 'package:flutter/material.dart';
import '../screens/welcome_screen.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';

class Routes {
  static const welcome = '/welcome';
  static const login = '/login';
  static const home = '/home';
}

class AppRouter {
  static Route onGenerateRoute(RouteSettings s) {
    switch (s.name) {
      case Routes.welcome: return _p(const WelcomeScreen());
      case Routes.login: return _p(const LoginScreen());
      case Routes.home: return _p(const HomeScreen());
      default: return _p(const WelcomeScreen());
    }
  }
  static MaterialPageRoute _p(Widget child) =>
      MaterialPageRoute(builder: (_) => child);
}