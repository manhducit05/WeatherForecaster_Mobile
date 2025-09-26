import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  final Map<String, dynamic> weatherData;
  const HomePage({super.key, required this.weatherData});

  String _mapWeatherText(int code) {
    if (code == 0) return "Clear sky";
    if ([1, 2].contains(code)) return "Partly cloudy";
    if (code == 3) return "Cloudy";
    if ([45, 48].contains(code)) return "Fog";
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code)) return "Rain";
    if ([71, 73, 75, 77, 85, 86].contains(code)) return "Snow";
    if ([95, 96, 99].contains(code)) return "Thunderstorm";
    return "Unknown";
  }
  String _bigIconForCode(int code) {
    // big svg in assets/images (like your original)
    if (code == 0) return "assets/images/sun.svg";
    if ([1, 2].contains(code)) return "assets/images/partly_cloudy.svg";
    if (code == 3) return "assets/images/cloud.svg";
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code))
      return "assets/images/rain.svg";
    if ([95, 96, 99].contains(code)) return "assets/images/thunderstorm.svg";
    return "assets/images/cloud.svg";
  }

  String _smallIconForCode(int code) {
    // small icons in assets/icons/
    if (code == 0) return "assets/icons/sunny.svg";
    if ([1, 2].contains(code)) return "assets/icons/partly_cloudy.svg";
    if (code == 3) return "assets/icons/cloud.svg";
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code))
      return "assets/icons/rainy.svg";
    if ([95, 96, 99].contains(code)) return "assets/icons/thunderstorm.svg";
    return "assets/icons/cloud.svg";
  }

  String _weekdayShort(DateTime d) {
    const names = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    return names[(d.weekday - 1) % 7];
  }

  int _nearestHourlyIndex(List<String> timesIso, DateTime now) {
    for (int i = 0; i < timesIso.length; i++) {
      final dt = DateTime.parse(timesIso[i]);
      if (!dt.isBefore(now)) {
        return i;
      }
    }
    // all times before now -> return last index
    return timesIso.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    // safety checks
    final daily = (weatherData['daily'] ?? {}) as Map<String, dynamic>;
    final hourly = (weatherData['hourly'] ?? {}) as Map<String, dynamic>;

    // chuẩn hóa thành 4 danh sách theo ngày
    final dailyTimes = List<String>.from(daily['time'] ?? []);
    final dailyMax = List<dynamic>.from(daily['temperature_2m_max'] ?? []);
    final dailyMin = List<dynamic>.from(daily['temperature_2m_min'] ?? []);
    final dailyCodes = List<dynamic>.from(daily['weathercode'] ?? []);

    // chuẩn hóa thành 4 danh sách theo giờ
    final hourlyTimes = List<String>.from(hourly['time'] ?? []);
    final hourlyTemps = (hourly['temperature_2m'] as List? ?? [])
        .map((e) => (e as num).toDouble())
        .toList();
    final hourlyWinds = (hourly['windspeed_10m'] as List? ?? [])
        .map((e) => (e as num).toDouble())
        .toList();
    final hourlyCodes = (hourly['weathercode'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList();

    // Today's daily values (fallbacks if missing)
    final todayCode = (dailyCodes.isNotEmpty
        ? (dailyCodes[0] as int)
        : (hourlyCodes.isNotEmpty ? hourlyCodes[0] : 3));
    final todayMax = dailyMax.isNotEmpty
        ? (dailyMax[0] as num).toDouble()
        : (hourlyTemps.isNotEmpty ? hourlyTemps[0] : 0.0);
    final todayMin = dailyMin.isNotEmpty
        ? (dailyMin[0] as num).toDouble()
        : (hourlyTemps.isNotEmpty ? hourlyTemps[0] : 0.0);


    final rawDateStr = dailyTimes.isNotEmpty
        ? dailyTimes[0]
        : DateTime.now().toIso8601String().split('T')[0];

// parse string thành DateTime
    final parsedDate = DateTime.tryParse(rawDateStr) ?? DateTime.now();

// format thành string để hiển thị
    final todayDate = DateFormat('EEEE | dd MMM yyyy').format(parsedDate);

    // Build 5-day forecast (use available daily length)
    // --- Build 5-day forecast: 2 ngày trước, hôm nay, 2 ngày sau (nếu có) ---

    // Xác định index hôm nay
    int todayIndex = dailyTimes.indexWhere((t) {
      final dt = DateTime.tryParse(t);
      if (dt == null) return false;
      final now = DateTime.now();
      return dt.year == now.year && dt.month == now.month && dt.day == now.day;
    });
    if (todayIndex == -1) todayIndex = 0;

    int totalDays = dailyTimes.length;
    int start = todayIndex - 2;
    int end = todayIndex + 2;

    // Điều chỉnh để không bị âm hoặc vượt quá length
    if (start < 0) {
      end += -start; // bù thêm vào cuối
      start = 0;
    }
    if (end >= totalDays) {
      start -= (end - totalDays + 1); // bù ngược lại về đầu
      end = totalDays - 1;
    }
    if (start < 0) start = 0;

    // Giới hạn đúng 5 ngày
    List<int> indices = [];
    for (int i = start; i <= end && indices.length < 5; i++) {
      indices.add(i);
    }

    // Build danh sách 5 ngày
    final fiveDays = indices.map((idx) {
      final dt = DateTime.tryParse(dailyTimes[idx]) ?? DateTime.now();
      return {
        'day': _weekdayShort(dt),
        'max': (dailyMax[idx] as num).toDouble(),
        'min': (dailyMin[idx] as num).toDouble(),
        'code': (dailyCodes[idx] as num).toInt(),
        'isToday': idx == todayIndex, // <-- đánh dấu hôm nay
      };
    }).toList();

    // Build hourly 4 points: now + next 3 steps, each +2 hours
    final List<Map<String, dynamic>> hourlyPoints = [];
    if (hourlyTimes.isNotEmpty && hourlyTemps.isNotEmpty) {
      final now = DateTime.now();
      int startIndex = _nearestHourlyIndex(hourlyTimes, now);

      // pick indices start, start+2, start+4, start+6 (cap to last)
      for (int i = 0; i < 4; i++) {
        int idx = startIndex + i * 2;
        if (idx >= hourlyTimes.length) idx = hourlyTimes.length - 1;
        final dt = DateTime.parse(hourlyTimes[idx]);
        final label = (i == 0)
            ? "Now"
            : "${dt.hour.toString().padLeft(2, '0')}:00";
        final temp = (idx < hourlyTemps.length)
            ? hourlyTemps[idx]
            : hourlyTemps.last;
        final wind = (idx < hourlyWinds.length)
            ? hourlyWinds[idx]
            : (hourlyWinds.isNotEmpty ? hourlyWinds.last : 0.0);
        final code = (idx < hourlyCodes.length) ? hourlyCodes[idx] : todayCode;
        hourlyPoints.add({
          'hour': label,
          'temp': temp,
          'wind': wind,
          'code': code,
        });
      }
    }
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
                        "Asia/BangKok",
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
                  const CircleAvatar(
                    radius: 18,
                    backgroundImage: AssetImage("assets/images/avatar.png"),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // --- WEATHER ICON + STATUS ---
              Text(
                _mapWeatherText(todayCode),
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
              const SizedBox(height: 8),
              SvgPicture.asset(
                _bigIconForCode(todayCode),
                width: 200,
                height: 200,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              // --- TEMPERATURE ---
              Text(
                "${todayMax.toInt()}°C",
                style: const TextStyle(
                  fontSize: 64,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                todayDate,
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),

              const SizedBox(height: 20),
              // --- WEEK FORECAST ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(fiveDays.length, (i) {
                  final d = fiveDays[i];
                  final iconPath = _smallIconForCode(d['code'] as int);

                  // nếu là hôm nay => level = 0, nếu kề hôm nay => level = 1, còn lại = 2
                  int level;
                  if (d['isToday'] == true) {
                    level = 0;
                  } else {
                    level = 2;
                  }

                  return _DayWeather(
                    day: d['day'] as String,
                    iconPath: iconPath,
                    level: level,
                  );
                }),
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

                    const SizedBox(height: 8),

                    // --- Chart using hourlyPoints ---
                    HourlyChart(items: hourlyPoints),

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
  final String iconPath;
  final int level; // 0 = current, 1 = near, 2 = far

  const _DayWeather({
    required this.day,
    required this.iconPath,
    this.level = 1,
  });

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
            iconPath,
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
  final List<Map<String, dynamic>> items; // each: {hour, temp, wind, code}

  const HourlyChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text(
            "No hourly data",
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    // Build spots for chart (x = index)
    final spots = List.generate(
      items.length,
      (i) => FlSpot(i.toDouble(), (items[i]['temp'] as double)),
    );
    final temps = items.map((e) => e['temp'] as double).toList();
    final minY = (temps.reduce((a, b) => a < b ? a : b) - 3).clamp(
      -50.0,
      100.0,
    );
    final maxY = (temps.reduce((a, b) => a > b ? a : b) + 3).clamp(
      -50.0,
      100.0,
    );

    return SizedBox(
      height: 230,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth;
          const sidePadding = 24.0; // khoảng cách 2 bên
          final innerWidth = chartWidth - sidePadding * 2;
          final spacing = (items.length > 1)
              ? innerWidth / (items.length - 1)
              : 0.0;
          final chartHeight = 120.0;

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

              // --- Overlay text + icon + wind + hour ---
              ...List.generate(items.length, (index) {
                final item = items[index];
                final temp = (item['temp'] as double);
                final wind =
                    (item['wind'] as double).toStringAsFixed(1) + "km/h";
                final hour = item['hour'] as String;
                final code = item['code'] as int;

                final posX = sidePadding + index * spacing;
                final relative = (temp - minY) / (maxY - minY);
                final posY = (1 - relative) * chartHeight + 60;

                // small icon path
                String smallIcon = "assets/icons/cloud.svg";
                if ([0].contains(code))
                  smallIcon = "assets/icons/sunny.svg";
                else if ([1, 2].contains(code))
                  smallIcon = "assets/icons/partly_cloudy.svg";
                else if (code == 3)
                  smallIcon = "assets/icons/cloud.svg";
                else if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code))
                  smallIcon = "assets/icons/rainy.svg";
                else if ([95, 96, 99].contains(code))
                  smallIcon = "assets/icons/thunderstorm.svg";

                return Positioned(
                  left: posX - 20, // center
                  top: posY,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${temp.toInt()}°",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SvgPicture.asset(
                        smallIcon,
                        width: 30,
                        height: 30,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        wind,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        hour,
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
