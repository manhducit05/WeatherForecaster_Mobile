import 'package:flutter/material.dart';
import '../pages/weather_page.dart';

class AppRoutes {
  static const home = '/';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const WeatherPage(), // không cần args nữa
        );
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
