import 'package:flutter/material.dart';
import 'package:weather_forecaster/utils/storage_helper.dart';
import 'routes/app_routes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supertokens_flutter/supertokens.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Chỉ cho phép dọc (portraitUp và portraitDown)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await StorageHelper.init();
  await dotenv.load(fileName: ".env");
  SuperTokens.init(apiDomain: "http://36.50.63.53:8080", apiBasePath: "/auth");
  await Hive.initFlutter();
  await Hive.openBox('logininfo');
  bool loggedIn = await SuperTokens.doesSessionExist();

  runApp(
    ScreenUtilInit(
      designSize: const Size(1080, 2400), // kích thước thiết kế gốc
      minTextAdapt: true, // tự scale chữ
      splitScreenMode: true, // hỗ trợ chia đôi màn hình
      builder: (_, child) => MyApp(loggedIn: loggedIn),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool loggedIn;
  const MyApp({super.key, required this.loggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Routing Demo',
      initialRoute: loggedIn ? AppRoutes.home : AppRoutes.login,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
