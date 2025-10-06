import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../constant/text.dart';
import 'package:weather_animation/weather_animation.dart';

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

  // hàm chọn icon trạng thái thời tiết lớn
  String _bigIconForCode(int code) {
    if (code == 0) return "assets/images/sun.svg";
    if ([1, 2].contains(code)) return "assets/images/partly_cloudy.svg";
    if (code == 3) return "assets/images/cloud.svg";
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code)) {
      return "assets/images/rainy.svg";
    }
    if ([95, 96, 99].contains(code)) return "assets/images/thunderstorm.svg";
    return "assets/images/cloud.svg";
  }

  // hàm chọn icon trạng thái thời tiết nhỏ
  String _smallIconForCode(int code) {
    if (code == 0) return "assets/images/sun.svg";
    if ([1, 2].contains(code)) return "assets/images/partly_cloudy.svg";
    if (code == 3) return "assets/images/cloud.svg";
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code)) {
      return "assets/images/rainy.svg";
    }
    if ([95, 96, 99].contains(code)) return "assets/images/thunderstorm.svg";
    return "assets/images/cloud.svg";
  }

  // Format định dạng ngày
  String _weekdayShort(DateTime d) {
    const names = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"];
    return names[(d.weekday - 1) % 7];
  }

  // Xử lý ngày được chọn để xem thời tiết
  int _selectedDateIndex = 0;

  // Xử lý trạng thái thời tiết khi đổi ngày
  bool get isRainySelectedDay {
    final daily = (widget.weatherData['daily'] ?? {}) as Map<String, dynamic>;
    final dailyCodes = List<dynamic>.from(daily['weathercode'] ?? []);
    if (_selectedDateIndex >= dailyCodes.length) return false;
    final code = dailyCodes[_selectedDateIndex] as int;
    // Các code mưa: 51,53,55,61,63,65,80,81,82; bão: 95,96,97
    return [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 97].contains(code);
  }

  // ✅ Getter tự tính todayCode dựa trên dữ liệu
  int get _todayCode {
    final daily = (widget.weatherData['daily'] ?? {}) as Map<String, dynamic>;
    final hourly = (widget.weatherData['hourly'] ?? {}) as Map<String, dynamic>;

    final dailyCodes = List<dynamic>.from(daily['weathercode'] ?? []);
    final hourlyCodes = (hourly['weathercode'] as List? ?? [])
        .map((e) => (e as num).toInt())
        .toList();

    if (dailyCodes.isNotEmpty) {
      return dailyCodes[_selectedDateIndex] as int;
    } else if (hourlyCodes.isNotEmpty) {
      return hourlyCodes[0];
    } else {
      return 3; // fallback
    }
  }

  // ✅ Các getter trạng thái animation
  bool get isSunny => _todayCode == 0;

  bool get isPartlyCloudy => [1, 2].contains(_todayCode);

  bool get isCloudy => _todayCode == 3;

  bool get isRainy => [51, 53, 55, 61, 63, 65, 80, 81, 82].contains(_todayCode);

  bool get isThunderStorm => [95, 96, 99].contains(_todayCode);
  @override
  Widget build(BuildContext context) {
    // safety checks, chia weather data nhận được thành các List để sử dụng
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
    // report dialog
    void showIncidentReportDialog(BuildContext context) {
      String? tempFeeling;
      String? weatherCondition;
      TextEditingController otherController = TextEditingController();

      showDialog(
        context: context,

        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              bool isFormValid =
                  tempFeeling != null &&
                  weatherCondition != null &&
                  otherController.text.trim().isNotEmpty;

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                title: const Text(
                  "Incident Report",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        // ✅ 0. Subtitle
                        "Help us improve the weather app by sharing the weather conditions at your location.",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      // ✅ 1. Temperature perception
                      const Text(
                        "Current temperature (how it feels)",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: [
                          ChoiceChip(
                            label: const Text("Feels warmer"),
                            selected: tempFeeling == "Feels warmer",
                            selectedColor: Colors.amber.shade300,
                            onSelected: (v) {
                              setState(() => tempFeeling = "Feels warmer");
                            },
                          ),
                          ChoiceChip(
                            label: const Text("Accurate"),
                            selected: tempFeeling == "Accurate",
                            selectedColor: Colors.amber.shade300,
                            onSelected: (v) {
                              setState(() => tempFeeling = "Accurate");
                            },
                          ),
                          ChoiceChip(
                            label: const Text("Feels colder"),
                            selected: tempFeeling == "Feels colder",
                            selectedColor: Colors.amber.shade300,
                            onSelected: (v) {
                              setState(() => tempFeeling = "Feels colder");
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ✅ 2. Weather condition
                      const Text(
                        "Current weather condition",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: [
                          for (var item in [
                            "Clear",
                            "Mostly cloudy",
                            "Partly cloudy",
                            "Rain",
                            "Snow",
                            "Other",
                          ])
                            ChoiceChip(
                              label: Text(item),
                              selected: weatherCondition == item,
                              selectedColor: Colors.amber.shade300,
                              onSelected: (v) {
                                setState(() => weatherCondition = item);
                              },
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ✅ 3. Additional comments
                      const Text(
                        "Additional comments",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherController,
                        maxLines: 3,
                        onChanged: (v) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:
                              "Share your questions and suggestions with us.",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: isFormValid
                        ? () {
                            if (kDebugMode) {
                              print("Temp feeling: $tempFeeling");
                              print("Weather condition: $weatherCondition");
                              print("Comments: ${otherController.text}");
                            }
                            // Đóng dialog hiện tại
                            Navigator.pop(context);

                            // Hiển thị thông báo thành công
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Report submitted successfully!"),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFormValid
                          ? Colors.amber
                          : Colors.grey.shade400,
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text("Submit"),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: isRainySelectedDay ? null : const Color(0xFFD59A2F),
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: double.infinity,
            decoration: isRainySelectedDay
                ? const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/images/bg_rainy.png"),
                      fit: BoxFit.cover,
                    ),
                  )
                : const BoxDecoration(color: Color(0xFFD59A2F)),
          ),
          // ✅ HIỆU ỨNG NẮNG (ánh sáng lung linh)
          if (isSunny)
            SunWidget(
              sunConfig: SunConfig(
                width: 380,
                blurSigma: 17,
                blurStyle: BlurStyle.solid,
                isLeftLocation: true,
                coreColor: Color.fromARGB(
                  255,   // alpha = 1.0  → 255
                  245,   // red   = 0.9608 → ~245
                  124,   // green = 0.4863 → ~124
                  0,     // blue  = 0.0000 → 0
                ),
                midColor: Color.fromARGB(
                  255,   // alpha
                  255,   // red   = 1.0000
                  238,   // green = 0.9333 → ~238
                  88,    // blue  = 0.3451 → ~88
                ),
                outColor: Color.fromARGB(
                  255,   // alpha
                  255,   // red   = 1.0000
                  167,   // green = 0.6549 → ~167
                  38,    // blue  = 0.1490 → ~38
                ),
                animMidMill: 1500,
                animOutMill: 1500,
              ),
            ),

          // ✅ HIỆU ỨNG MƯA / SẤM / MÂY (ưu tiên bão > mưa > mây)
          if (isThunderStorm) ...[
            WindWidget(
              windConfig: WindConfig(
                width: 5,
                y: 208,
                windGap: 10,
                blurSigma: 6,
                color: const Color.fromARGB(255, 96, 125, 139), // 0.3765, 0.4902, 0.5451
                slideXStart: 0,
                slideXEnd: 350,
                pauseStartMill: 50,
                pauseEndMill: 6000,
                slideDurMill: 1000,
                blurStyle: BlurStyle.solid,
              ),
            ),

            RainWidget(
              rainConfig: RainConfig(
                count: 40,
                lengthDrop: 13,
                widthDrop: 4,
                color: const Color.fromARGB(153, 120, 144, 156), // 0.6000, 0.4706, 0.5647, 0.6118
                isRoundedEndsDrop: true,
                widgetRainDrop: null,
                fallRangeMinDurMill: 500,
                fallRangeMaxDurMill: 1500,
                areaXStart: 41,
                areaXEnd: 264,
                areaYStart: 208,
                areaYEnd: 620,
                slideX: 2,
                slideY: 0,
                slideDurMill: 2000,
                slideCurve: const Cubic(0.40, 0.00, 0.20, 1.00),
                fallCurve: const Cubic(0.55, 0.09, 0.68, 0.53),
                fadeCurve: const Cubic(0.95, 0.05, 0.80, 0.04),
              ),
            ),

            ThunderWidget(
              thunderConfig: ThunderConfig(
                thunderWidth: 11,
                blurSigma: 28,
                blurStyle: BlurStyle.solid,
                color: const Color.fromARGB(153, 255, 238, 88), // 0.6000, 1.0000, 0.9333, 0.3451
                flashStartMill: 50,
                flashEndMill: 300,
                pauseStartMill: 50,
                pauseEndMill: 6000,
                points: const [
                  Offset(110.0, 210.0),
                  Offset(120.0, 240.0),
                ],
              ),
            ),

            WindWidget(
              windConfig: WindConfig(
                width: 7,
                y: 300,
                windGap: 15,
                blurSigma: 7,
                color: const Color.fromARGB(255, 96, 125, 139),
                slideXStart: 0,
                slideXEnd: 350,
                pauseStartMill: 50,
                pauseEndMill: 6000,
                slideDurMill: 1000,
                blurStyle: BlurStyle.solid,
              ),
            ),

          ]

          else if (isRainy) ...[
            RainWidget(
              rainConfig: RainConfig(
                count: 25,
                lengthDrop: 13,
                widthDrop: 4,
                color: const Color.fromARGB(255, 158, 158, 158), // 1.0, 0.6196, 0.6196, 0.6196
                isRoundedEndsDrop: true,
                widgetRainDrop: null,
                fallRangeMinDurMill: 500,
                fallRangeMaxDurMill: 1500,
                areaXStart: 41,
                areaXEnd: 350,
                areaYStart: 208,
                areaYEnd: 620,
                slideX: 6,
                slideY: 0,
                slideDurMill: 2000,
                slideCurve: const Cubic(0.40, 0.00, 0.20, 1.00),
                fallCurve: const Cubic(0.55, 0.09, 0.68, 0.53),
                fadeCurve: const Cubic(0.95, 0.05, 0.80, 0.04),
              ),
            ),
          ]
          else if (isCloudy || isPartlyCloudy) ...[
              SunWidget(
                sunConfig: SunConfig(
                  width: 300,
                  blurSigma: 8,
                  blurStyle: BlurStyle.solid,
                  isLeftLocation: true,
                  coreColor: const Color.fromARGB(255, 255, 183, 77),   // 1.0, 1.0, 0.7176, 0.3020
                  midColor: const Color.fromARGB(255, 255, 255, 141),   // 1.0, 1.0, 1.0, 0.5529
                  outColor: const Color.fromARGB(255, 255, 209, 128),   // 1.0, 1.0, 0.8196, 0.5020
                  animMidMill: 2000,
                  animOutMill: 2000,
                ),
              ),

              CloudWidget(
                cloudConfig: CloudConfig(
                  size: 250,
                  color: const Color.fromARGB(168, 250, 250, 250), // 0.6588, 0.9804, 0.9804, 0.9804
                  icon: const IconData(63056, fontFamily: 'MaterialIcons'),
                  widgetCloud: null,
                  x: 20,
                  y: 3,
                  scaleBegin: 1,
                  scaleEnd: 1.08,
                  scaleCurve: const Cubic(0.40, 0.00, 0.20, 1.00),
                  slideX: 20,
                  slideY: 0,
                  slideDurMill: 3000,
                  slideCurve: const Cubic(0.40, 0.00, 0.20, 1.00),
                ),
              ),

              CloudWidget(
                cloudConfig: CloudConfig(
                  size: 160,
                  color: const Color.fromARGB(168, 250, 250, 250), // 0.6588, 0.9804, 0.9804, 0.9804
                  icon: const IconData(63056, fontFamily: 'MaterialIcons'),
                  widgetCloud: null,
                  x: 140,
                  y: 97,
                  scaleBegin: 1,
                  scaleEnd: 1.1,
                  scaleCurve: const Cubic(0.40, 0.00, 0.20, 1.00),
                  slideX: 20,
                  slideY: 4,
                  slideDurMill: 2000,
                  slideCurve: const Cubic(0.40, 0.00, 0.20, 1.00),
                ),
              ),
          ],
          SafeArea(
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
                          backgroundImage: AssetImage(
                            "assets/images/avatar.png",
                          ),
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
                                  child: const Text("Close"),
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
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) =>
                        FadeTransition(opacity: anim, child: child),
                    child: SvgPicture.asset(
                      _bigIconForCode(todayCode),
                      key: ValueKey(todayCode),
                      width: 200,
                      height: 200,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
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
                            DateTime.tryParse(dailyTimes[idx]) ??
                            DateTime.now();
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: 70,
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: isSelected
                                ? BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  )
                                : null,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isSelected ? 18 : 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                  child: Text(_weekdayShort(dt)),
                                ),
                                const SizedBox(height: 6),
                                AnimatedScale(
                                  scale: isSelected ? 1.2 : 1.0,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                  child: SvgPicture.asset(
                                    iconPath,
                                    width: 28,
                                    height: 28,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
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
                      color: Colors.white.withValues(alpha: 0.15),
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
                            onPressed: () {
                              showIncidentReportDialog(context);
                            },
                            child: const Text(
                              "Incident Report",
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
