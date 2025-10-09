// lib/pages/weather_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../pages/detail_weather_page.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});
  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  Map<String, dynamic>? weatherData;
  bool _loading = true;
  String? _error;

  // ✅ Các biến latitude, longitude, timezone có thể thay đổi
  double latitude = 13.7563;
  double longitude = 100.5018;
  String timezone = 'Asia/Bangkok';
  @override
  void initState() {
    super.initState();
    fetchWeather();
  }

  // Hàm cho phép đổi vị trí
  void updateLocation(double lat, double lon, String tz) {
    setState(() {
      latitude = lat;
      longitude = lon;
      timezone = tz;
    });
    fetchWeather();
  }

  // fetch dữ liệu
  Future<void> fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$latitude&longitude=$longitude'
        '&hourly=temperature_2m,precipitation,weathercode,windspeed_10m'
        '&daily=temperature_2m_max,temperature_2m_min,weathercode'
        '&timezone=$timezone',
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
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
    return DetailWeatherPage(
      weatherData: weatherData!,
      onLocationChange: updateLocation,
    );
  }
}
