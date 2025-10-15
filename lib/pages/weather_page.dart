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

  late LocationModel _currentLocation;   // giữ 1 object cố định
  LocationModel? _selectedLocation; // giữ location đang chọn

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch();
  }

  Future<void> _initLocationAndFetch() async {
    try {
      final pos = await LocationHelper.determinePosition();
      final current = LocationModel(
        name: "Current Location",
        lat: pos.latitude,
        lon: pos.longitude,
        tz: "auto", // để API tự detect timezone
      );

      setState(() {
        _currentLocation = current;
        _selectedLocation = current;
      });

      await fetchWeather(current);
    } catch (e) {
      setState(() {
        _error = 'Location not found: $e';
        _loading = false;
      });
    }
  }

  Future<void> fetchWeather(LocationModel location) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
            '?latitude=${location.lat}&longitude=${location.lon}'
            '&hourly=temperature_2m,precipitation,weathercode,windspeed_10m'
            '&daily=temperature_2m_max,temperature_2m_min,weathercode'
            '&timezone=${location.tz}',
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

  void updateLocation(LocationModel location) {
    setState(() {
      _selectedLocation = location;
    });
    fetchWeather(location);
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
                  onPressed: _initLocationAndFetch,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (weatherData == null || _selectedLocation == null) {
      return const Scaffold(
        body: Center(child: Text('No weather data available')),
      );
    }

    return DetailWeatherPage(
      weatherData: weatherData!,
      currentLocation: _currentLocation,
      selectedLocation: _selectedLocation!,
      onLocationChange: updateLocation,
    );
  }
}
