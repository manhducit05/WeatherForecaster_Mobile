import 'package:flutter/material.dart';
import '../pages/weather_page.dart';
import '../pages/open_map.dart';

class AppRoutes {
  static const home = '/';
  static const String map = '/map';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const WeatherPage(),
        );
      case map:
        return MaterialPageRoute(builder: (_) => const CurrentLocationOSM());

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
