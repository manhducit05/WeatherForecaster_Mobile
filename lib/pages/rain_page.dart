import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'home_page.dart';

class RainPage extends StatelessWidget {
  const RainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/bg_rainy.png"), // ảnh nền
            fit: BoxFit.cover, // phủ toàn màn hình
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- TOP BAR (location + avatar + button) ---
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
                            builder: (context) => const HomePage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Go To Cloudy Page",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white,
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
                  "Rainy",
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                const SizedBox(height: 8),
                SvgPicture.asset(
                  "assets/images/rainy.svg",
                  width: 200,
                  height: 200,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                const Text(
                  "16°C",
                  style: TextStyle(
                    fontSize: 64,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Sunday | 19 Dec 2023",
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

                // --- 24-hour forecast container ---
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 5),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
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
                            backgroundColor: Colors.amber,
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
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
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
    double fontSize;
    double iconSize;
    double opacity;

    switch (level) {
      case 0:
        fontSize = 20;
        iconSize = 35;
        opacity = 1.0;
        break;
      case 1:
        fontSize = 16;
        iconSize = 30;
        opacity = 0.7;
        break;
      case 2:
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
      const FlSpot(0, 30),
      const FlSpot(1, 26),
      const FlSpot(2, 22),
      const FlSpot(3, 24),
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
          const sidePadding = 24.0;
          final innerWidth = chartWidth - sidePadding * 2;
          final spacing = innerWidth / (spots.length - 1);

          return Stack(
            children: [
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
                        color: Colors.amber,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
              ...List.generate(spots.length, (index) {
                final spot = spots[index];
                double posX = sidePadding + spot.x * spacing;
                double relative = (spot.y - minY) / (maxY - minY);
                double chartHeight = 120;
                double posY = (1 - relative) * chartHeight + 60;
                return Positioned(
                  left: posX - 20,
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
