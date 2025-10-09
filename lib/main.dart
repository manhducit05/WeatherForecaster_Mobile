import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chỉ cho phép dọc (portraitUp và portraitDown)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(
    ScreenUtilInit(
      designSize: const Size(1080, 2400), // kích thước thiết kế gốc
      minTextAdapt: true, // tự scale chữ
      splitScreenMode: true, // hỗ trợ chia đôi màn hình
      builder: (_, child) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Routing Demo',
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
