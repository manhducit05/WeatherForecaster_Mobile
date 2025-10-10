// lib/pages/weather_page.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../pages/detail_weather_page.dart';
import '../utils/location_helper.dart';
import '../models/location_model.dart';


class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});
  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  Map<String, dynamic>? weatherData;
  bool _loading = true;
  String? _error;

  double? latitude;
  double? longitude;
  String timezone = 'auto';

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch(); // ✅ lấy vị trí trước khi fetch
  }

  Future<void> _initLocationAndFetch() async {
    try {
      final pos = await LocationHelper.determinePosition();
      setState(() {
        latitude = pos.latitude;
        longitude = pos.longitude;
      });
      await fetchWeather();
    } catch (e) {
      setState(() {
        _error = 'Không lấy được vị trí: $e';
        _loading = false;
      });
    }
  }

  void updateLocation(double lat, double lon, String tz) {
    setState(() {
      latitude = lat;
      longitude = lon;
      timezone = tz;
    });
    fetchWeather();
  }

  Future<void> fetchWeather() async {
    if (latitude == null || longitude == null) {
      return; // chưa có vị trí thì bỏ qua
    }

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
                  onPressed: _initLocationAndFetch, // ✅ thử lại cả vị trí + fetch
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
      currentLocation: LocationModel(
        name: "Vị trí hiện tại",
        lat: latitude!,
        lon: longitude!,
        tz: timezone,
      ),
    );
  }
}
