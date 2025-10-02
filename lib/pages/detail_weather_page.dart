import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../constant/text.dart';

class DetailWeatherPage extends StatefulWidget {
  final Map<String, dynamic> weatherData;
  final Function(double lat, double lon, String tz) onLocationChange;

  const DetailWeatherPage({
    super.key,
    required this.weatherData,
    required this.onLocationChange,
  });

  @override
  State<DetailWeatherPage> createState() => _DetailWeatherPage();
}

class _DetailWeatherPage extends State<DetailWeatherPage> {
  // Danh sách location mẫu (bạn có thể thay bằng dữ liệu thật)
  final List<Map<String, dynamic>> _locations = [
    {'name': 'Bangkok', 'lat': 13.7563, 'lon': 100.5018, 'tz': 'Asia/Bangkok'},
    {
      'name': 'New York',
      'lat': 40.7128,
      'lon': -74.0060,
      'tz': 'America/New_York',
    },
    {'name': 'London', 'lat': 51.5074, 'lon': -0.1278, 'tz': 'Europe/London'},
    {'name': 'Tokyo', 'lat': 35.6895, 'lon': 139.6917, 'tz': 'Asia/Tokyo'},
    {
      'name': 'Sydney',
      'lat': -33.8688,
      'lon': 151.2093,
      'tz': 'Australia/Sydney',
    },
    {'name': 'Paris', 'lat': 48.8566, 'lon': 2.3522, 'tz': 'Europe/Paris'},
    {
      'name': 'Los Angeles',
      'lat': 34.0522,
      'lon': -118.2437,
      'tz': 'America/Los_Angeles',
    },
  ];
  @override
  void initState() {
    super.initState();

    final currentTz = widget.weatherData['timezone'] ?? 'Asia/Bangkok';

    _selectedLocation = _locations.firstWhere(
      (loc) => loc['tz'] == currentTz,
      orElse: () => _locations.first,
    );
  }

  // Biến giữ location đang chọn
  Map<String, dynamic>? _selectedLocation;
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
    if (code == 0) return "assets/images/sun.svg";
    if ([1, 2].contains(code)) return "assets/images/partly_cloudy.svg";
    if (code == 3) return "assets/images/cloud.svg";
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code))
      return "assets/images/rainy.svg";
    if ([95, 96, 99].contains(code)) return "assets/images/thunderstorm.svg";
    return "assets/images/cloud.svg";
  }

  String _smallIconForCode(int code) {
    if (code == 0) return "assets/images/sun.svg";
    if ([1, 2].contains(code)) return "assets/images/partly_cloudy.svg";
    if (code == 3) return "assets/images/cloud.svg";
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code))
      return "assets/images/rainy.svg";
    if ([95, 96, 99].contains(code)) return "assets/images/thunderstorm.svg";
    return "assets/images/cloud.svg";
  }

  String _weekdayShort(DateTime d) {
    const names = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    return names[(d.weekday - 1) % 7];
  }

  int _nearestHourlyIndex(List<String> timesIso, DateTime now) {
    for (int i = 0; i < timesIso.length; i++) {
      final dt = DateTime.parse(timesIso[i]);
      if (!dt.isBefore(now)) return i;
    }
    return timesIso.length - 1;
  }

  // xử lý ngày được chọn để xem thời tiết
  int _selectedDateIndex = 0;

  // xử lý trạng thái thời tiết khi đổi ngày
  bool get isRainySelectedDay {
    final daily = (widget.weatherData['daily'] ?? {}) as Map<String, dynamic>;
    final dailyCodes = List<dynamic>.from(daily['weathercode'] ?? []);
    if (_selectedDateIndex >= dailyCodes.length) return false;
    final code = dailyCodes[_selectedDateIndex] as int;
    // Các code mưa: 51,53,55,61,63,65,80,81,82; bão: 95,96,97
    return [51, 53, 55, 61, 63, 65, 80, 81, 82,  95, 96, 97].contains(code);
  }

  @override
  Widget build(BuildContext context) {
    // safety checks
    final daily = (widget.weatherData['daily'] ?? {}) as Map<String, dynamic>;
    final hourly = (widget.weatherData['hourly'] ?? {}) as Map<String, dynamic>;

    final dailyTimes = List<String>.from(daily['time'] ?? []);
    final dailyMax = List<dynamic>.from(daily['temperature_2m_max'] ?? []);
    final dailyMin = List<dynamic>.from(daily['temperature_2m_min'] ?? []);
    final dailyCodes = List<dynamic>.from(daily['weathercode'] ?? []);

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

    // Today
    final todayCode = (dailyCodes.isNotEmpty
        ? (dailyCodes[_selectedDateIndex] as int)
        : (hourlyCodes.isNotEmpty ? hourlyCodes[0] : 3));

    final todayMax = dailyMax.isNotEmpty
        ? (dailyMax[_selectedDateIndex] as num).toDouble()
        : (hourlyTemps.isNotEmpty ? hourlyTemps[0] : 0.0);

    final rawDateStr = dailyTimes.isNotEmpty
        ? dailyTimes[_selectedDateIndex]
        : DateTime.now().toIso8601String().split('T')[0];

    // parse string thành DateTime
    final parsedDate = DateTime.tryParse(rawDateStr) ?? DateTime.now();

    // format thành string để hiển thị
    final todayDate = DateFormat('EEEE | dd MMM yyyy').format(parsedDate);

    // Build 5-day forecast (use available daily length)

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

    // Hourly forecast
    final List<Map<String, dynamic>> hourlyPoints = [];
    if (hourlyTimes.isNotEmpty && hourlyTemps.isNotEmpty) {
      final String selectedDateStr = dailyTimes[_selectedDateIndex];
      final DateTime dayStart = DateTime.parse("${selectedDateStr}T00:00:00");
      final DateTime dayEnd = dayStart.add(const Duration(days: 1));

      for (int i = 0; i < hourlyTimes.length; i++) {
        DateTime t = DateTime.parse(hourlyTimes[i]);
        if (t.isAfter(dayStart) && t.isBefore(dayEnd)) {
          hourlyPoints.add({
            'hour': "${t.hour.toString().padLeft(2, '0')}:00",
            'temp': hourlyTemps[i],
            'wind': (i < hourlyWinds.length) ? hourlyWinds[i] : 0.0,
            'code': (i < hourlyCodes.length) ? hourlyCodes[i] : todayCode,
          });
        }
      }
    }

    return Scaffold(
      backgroundColor: isRainySelectedDay ? null : const Color(0xFFD59A2F),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: isRainySelectedDay
            ? const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/bg_rainy.png"),
                  fit: BoxFit.cover,
                ),
              )
            : null,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // --- TOP BAR ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white),
                        const SizedBox(width: 4),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            dropdownColor: Colors.black87,
                            elevation: 0, // loại bỏ bóng
                            value: _selectedLocation,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                            ),
                            items: _locations.map((loc) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: loc,
                                child: Text(
                                  loc['name'],
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _selectedLocation = val;
                              });
                              widget.onLocationChange(
                                val['lat'],
                                val['lon'],
                                val['tz'],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    PopupMenuButton<int>(
                      iconSize: 40,
                      icon: const CircleAvatar(
                        radius: 18,
                        backgroundImage: AssetImage("assets/images/avatar.png"),
                      ),
                      color: Colors.black87,
                      onSelected: (value) {
                        String title = "";
                        String content = "";

                        switch (value) {
                          case 1:
                            title = AppTexts.titleUserAgreement;
                            content = AppTexts.userAgreement;
                            break;
                          case 2:
                            title = AppTexts.titlePrivacyPolicy;
                            content = AppTexts.privacyPolicy;
                            break;
                          case 3:
                            title = AppTexts.titleAppVersion;
                            content = AppTexts.appVersionInfo;
                            break;
                        }

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(title),
                            content: SingleChildScrollView(
                              child: Text(content),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Đóng"),
                              ),
                            ],
                          ),
                        );
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 1,
                          child: Text(
                            "User Agreement",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 2,
                          child: Text(
                            "Privacy Policy",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 3,
                          child: Text(
                            "App Version",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 15),

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

                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: dailyTimes.length,
                    itemBuilder: (context, idx) {
                      final dt =
                          DateTime.tryParse(dailyTimes[idx]) ?? DateTime.now();
                      final iconPath = _smallIconForCode(
                        dailyCodes[idx] as int,
                      );
                      final isSelected = idx == _selectedDateIndex;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDateIndex = idx;
                          });
                        },
                        child: Container(
                          width: 70,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                )
                              : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _weekdayShort(dt),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isSelected ? 18 : 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SvgPicture.asset(
                                iconPath,
                                width: isSelected ? 35 : 28,
                                height: isSelected ? 35 : 28,
                                colorFilter: const ColorFilter.mode(
                                  Colors.white,
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${(dailyMax[idx] as num).toInt()}° / ${(dailyMin[idx] as num).toInt()}°",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: isSelected ? 14 : 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // --- HOURLY FORECAST ---
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
                      // label
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
                      HourlyChart(
                        items: hourlyPoints,
                        iconForCode: _smallIconForCode,
                      ),
                      const SizedBox(height: 10),

                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            shadowColor: Colors.transparent,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(20),
                              ),
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
                ),
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
  final String iconPath;
  final int level;

  const _DayWeather({
    required this.day,
    required this.iconPath,
    this.level = 1,
  });

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

class HourlyChart extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final String Function(int) iconForCode;

  const HourlyChart({
    super.key,
    required this.items,
    required this.iconForCode,
  });

  @override
  State<HourlyChart> createState() => _HourlyChartState();
}

class _HourlyChartState extends State<HourlyChart> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollToNow();
  }

  void _scrollToNow() {
    // tìm giờ hiện tại
    final now = DateTime.now();
    final nowHour = now.hour.toString().padLeft(2, '0');

    // tìm index trong items
    final indexNow = widget.items.indexWhere((item) {
      // item['hour'] dạng "2025-10-02 13:00" hoặc "13:00" => tùy bạn parse
      final hourStr = item['hour'] as String;
      // kiểm tra nếu chuỗi giờ chứa giờ hiện tại
      return hourStr.contains("$nowHour:");
    });

    if (indexNow != -1) {
      // mỗi khối rộng 80px
      final targetOffset = indexNow * 80.0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(targetOffset);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
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

    // giờ hiện tại
    final now = DateTime.now();
    final nowHour = now.hour.toString().padLeft(2, '0');
    return SizedBox(
      height: 220,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: items.length * 80,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              const sidePadding = 40.0;
              final innerWidth = chartWidth - sidePadding * 2;
              final spacing = (items.length > 1)
                  ? innerWidth / (items.length - 1)
                  : 0.0;
              final chartHeight = 120.0;

              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: sidePadding,
                    ),
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

                  ...List.generate(items.length, (index) {
                    final item = items[index];
                    final temp = item['temp'] as double;
                    final hourRaw = item['hour'] as String;
                    final wind =
                        "${(item['wind'] as double).toStringAsFixed(1)}km/h";
                    final code = item['code'] as int;
                    final smallIcon = widget.iconForCode(code);

                    // Nếu giờ chứa giờ hiện tại -> hiển thị "Now"
                    DateTime? parsed;
                    try {
                      parsed = DateTime.parse(hourRaw);
                    } catch (_) {
                      // fallback nếu chỉ có HH:mm
                      final now = DateTime.now();
                      final parts = hourRaw.split(':'); // ["13","00"]
                      parsed = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        int.parse(parts[0]),
                        int.parse(parts[1]),
                      );
                    }

                    final nowDt = DateTime.now();
                    final isSameDay =
                        parsed.year == nowDt.year &&
                        parsed.month == nowDt.month &&
                        parsed.day == nowDt.day;

                    final isSameHour = parsed.hour == nowDt.hour;

                    final displayHour = (isSameDay && isSameHour)
                        ? "Now"
                        : hourRaw;

                    final posX = sidePadding + index * spacing;
                    final relative = (temp - minY) / (maxY - minY);
                    final posY = (1 - relative) * chartHeight + 30;
                    final infoTop = chartHeight + 30;

                    return Stack(
                      children: [
                        Positioned(
                          left: posX - 15,
                          top: posY - 28,
                          child: Text(
                            "${temp.toInt()}°",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Positioned(
                          left: posX - 15,
                          top: infoTop,
                          child: Column(
                            children: [
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
                                displayHour,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
