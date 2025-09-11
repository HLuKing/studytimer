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
      case Routes.welcome: return _page(const WelcomeScreen());
      case Routes.login: return _page(const LoginScreen());
      case Routes.home: return _page(const HomeScreen());
      default: return _page(const WelcomeScreen());
    }
  }
  static MaterialPageRoute _page(Widget child) => MaterialPageRoute(builder: (_) => child);
}