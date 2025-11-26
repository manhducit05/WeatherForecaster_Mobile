import 'package:flutter/material.dart';
import '../pages/weather_page.dart';
import '../pages/open_map.dart';
import '../pages/sign_in_page.dart';
import '../pages/sign_up_page.dart';

class AppRoutes {
  static const home = '/';
  static const String map = '/map';
  static const String login = '/login';
  static const String register = '/register';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const WeatherPage(),
        );
      case map:
        return MaterialPageRoute(builder: (_) => const OpenMapPage());
      case login:
        return MaterialPageRoute(builder: (_) => const SignInPage());
      case register:
        return MaterialPageRoute(builder: (_) => const SignUpPage());
      default:
        return _errorRoute("No route defined for ${settings.name}");
    }
  }

  static MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        body: Center(child: Text(message)),
      ),
    );
  }
}
