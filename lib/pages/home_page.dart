import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'rain_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD59A2F), // màu vàng cam
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // --- TOP BAR (location + avatar) ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.location_on, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        "New York",
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RainPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Go To Rainy Page",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white, // màu gạch dưới
                      ),
                    ),
                  ),
                  const CircleAvatar(
                    radius: 18,
                    backgroundImage: AssetImage("assets/images/avatar.png"),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // --- WEATHER ICON + STATUS ---
              const Text(
                "Cloudy",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
              const SizedBox(height: 8),
              // const Icon(Icons.cloud, color: Colors.white, size: 100),
              SvgPicture.asset(
                "assets/images/cloud.svg",
                width: 200,
                height: 200,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ), // thay cho color
              ),
              // --- TEMPERATURE ---
              const Text(
                "26°C",
                style: TextStyle(
                  fontSize: 64,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                "Sunday | 12 Dec 2023",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),

              const SizedBox(height: 20),
              // --- WEEK FORECAST ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  _DayWeather(day: "FRI", icon: "rainy.svg", level: 2),
                  _DayWeather(day: "SAT", icon: "sunny.svg", level: 1),
                  _DayWeather(day: "SUN", icon: "partly_cloudy.svg", level: 0),
                  _DayWeather(day: "MON", icon: "cloudy_rain.svg", level: 1),
                  _DayWeather(day: "TUES", icon: "thunderstorm.svg", level: 2),
                ],
              ),
              const SizedBox(height: 10),

              //
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15), // nền mờ mờ
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Label ---
                    Row(
                      children: [
                        SvgPicture.asset(
                          "assets/icons/clock.svg",
                          width: 16,
                          height: 16,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "24-hour forecast",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // --- Chart ---
                    const HourlyChart(),
                    const SizedBox(height: 16),

                    // --- Button ---
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEACA8F),
                          shadowColor: Colors.transparent,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 60,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {},
                        child: const Text(
                          "5-day forecast",
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- CUSTOM WIDGETS ---
class _DayWeather extends StatelessWidget {
  final String day;
  final String icon;
  final int level; // 0 = current, 1 = near, 2 = far

  const _DayWeather({required this.day, required this.icon, this.level = 1});

  @override
  Widget build(BuildContext context) {
    // cấu hình theo level
    double fontSize;
    double iconSize;
    double opacity;

    switch (level) {
      case 0: // hôm nay
        fontSize = 20;
        iconSize = 35;
        opacity = 1.0;
        break;
      case 1: // gần
        fontSize = 16;
        iconSize = 30;
        opacity = 0.7;
        break;
      case 2: // xa
      default:
        fontSize = 14;
        iconSize = 28;
        opacity = 0.5;
        break;
    }

    return Opacity(
      opacity: opacity,
      child: Column(
        children: [
          Text(
            day,
            style: TextStyle(color: Colors.white70, fontSize: fontSize),
          ),
          const SizedBox(height: 8),
          SvgPicture.asset(
            "assets/icons/$icon",
            width: iconSize,
            height: iconSize,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ],
      ),
    );
  }
}

class HourlyChart extends StatelessWidget {
  const HourlyChart({super.key});

  @override
  Widget build(BuildContext context) {
    final spots = [
      const FlSpot(0, 30), // Now
      const FlSpot(1, 26), // 22:00
      const FlSpot(2, 22), // 00:00
      const FlSpot(3, 24), // 2:00
    ];

    final hours = ["Now", "22:00", "00:00", "2:00"];
    final winds = ["11.7km/h", "9.3km/h", "12km/h", "15km/h"];
    final icons = [
      "assets/icons/night_icon1.svg",
      "assets/icons/night_icon2.svg",
      "assets/icons/night_icon3.svg",
      "assets/icons/night_icon4.svg",
    ];

    const minY = 10.0;
    const maxY = 35.0;

    return SizedBox(
      height: 230,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth;
          const sidePadding = 24.0; // khoảng cách 2 bên
          final innerWidth = chartWidth - sidePadding * 2;
          final spacing = innerWidth / (spots.length - 1);

          return Stack(
            children: [
              // --- Chart line ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: sidePadding),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.white,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Overlay text + icon ---
              ...List.generate(spots.length, (index) {
                final spot = spots[index];

                // vị trí X (có padding 2 bên)
                double posX = sidePadding + spot.x * spacing;

                // vị trí Y (dịch xuống dưới line cố định 40px)
                double relative = (spot.y - minY) / (maxY - minY);
                double chartHeight = 120;
                double posY = (1 - relative) * chartHeight + 60;
                return Positioned(
                  left: posX - 20, // trừ nửa để căn giữa
                  top: posY,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${spot.y.toInt()}°",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SvgPicture.asset(
                        icons[index],
                        width: 30,
                        height: 30,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        winds[index],
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        hours[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
