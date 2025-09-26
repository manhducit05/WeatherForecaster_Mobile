// lib/pages/weather_page.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../pages/default_page.dart';
import '../pages/rain_page.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  Map<String, dynamic>? weatherData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  Future<void> fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Query lấy hourly (temp, wind, precipitation, weathercode) + daily 7 ngày
      final uri = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=21.0285&longitude'
              '=105.8542&hourly=temperature_2m,precipitation,weathercode'
              ',windspeed_10m&daily=temperature_2m_max,temperature_2m_min'
              ',weathercode&timezone=Asia/Bangkok'
      );

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            weatherData = data;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${res.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Fetch failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  bool isRainy(int? code) {
    if (code == null) return false;
    return [
      51, 53, 55, 56, 57,
      61, 63, 65, 66, 67,
      80, 81, 82,
      95, 96, 99
    ].contains(code);
  }
  int? _extractTodayWeatherCode(Map<String, dynamic> data) {
    try {
      // Thử lấy daily.weathercode[0]
      final daily = data['daily'] as Map<String, dynamic>?;
      final List<dynamic>? dailyCodes = daily != null ? (daily['weathercode'] as List<dynamic>?) : null;
      if (dailyCodes != null && dailyCodes.isNotEmpty) {
        return (dailyCodes[0] as num).toInt();
      }

      // Fallback → hourly.weathercode[0]
      final hourly = data['hourly'] as Map<String, dynamic>?;
      final List<dynamic>? hourlyCodes = hourly != null ? (hourly['weathercode'] as List<dynamic>?) : null;
      if (hourlyCodes != null && hourlyCodes.isNotEmpty) {
        return (hourlyCodes[0] as num).toInt();
      }
    } catch (_) {
      // ignore and return null
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Weather')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: fetchWeather,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (weatherData == null) {
      return const Scaffold(
        body: Center(child: Text('Không có dữ liệu thời tiết')),
      );
    }

    // Lấy mã weathercode hôm nay (ưu tiên daily, fallback hourly)
    final int? todayCode = _extractTodayWeatherCode(weatherData!);

    // Quyết định hiển thị RainPage hay HomePage (cloud)
    if (isRainy(todayCode)) {
      return RainPage(weatherData: weatherData!);
    } else {
      return HomePage(weatherData: weatherData!);
    }
  }
}
