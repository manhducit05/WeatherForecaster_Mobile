import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/rain_page.dart';

class AppRoutes {
  static const home = '/';
  static const rainy = '/rainy';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const HomePage());
      case rainy:
        return MaterialPageRoute(builder: (_) => const RainPage());
      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text("No route defined")),
          ),
        );
    }
  }
}
