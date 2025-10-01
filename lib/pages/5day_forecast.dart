import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class FiveDayForecastPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String timezone; // optional, default 'auto'

  const FiveDayForecastPage({
    Key? key,
    required this.latitude,
    required this.longitude,
    this.timezone = 'auto',
  }) : super(key: key);

  @override
  State<FiveDayForecastPage> createState() => _FiveDayForecastPageState();
}

class _FiveDayForecastPageState extends State<FiveDayForecastPage> {
  late Future<List<WeatherDay>> _futureForecast;

  @override
  void initState() {
    super.initState();
    _futureForecast = fetchFiveDayForecast(widget.latitude, widget.longitude, widget.timezone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('5-Day Forecast'),
        centerTitle: true,
      ),
      body: FutureBuilder<List<WeatherDay>>(
        future: _futureForecast,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Lỗi khi tải dự báo: ${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Không có dữ liệu dự báo'));
          }

          final days = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final day = days[index];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      // date & weekday
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.EEEE().format(day.date), // weekday
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('dd MMM yyyy').format(day.date),
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),

                      // icon
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Text(
                              _weatherCodeToEmoji(day.weatherCode),
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _weatherCodeToText(day.weatherCode),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      // temps
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${day.tempMax.toStringAsFixed(0)}° / ${day.tempMin.toStringAsFixed(0)}°',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.water_drop, size: 14, color: Colors.blueAccent),
                                const SizedBox(width: 4),
                                Text('${day.precipitationProbabilityMax?.toStringAsFixed(0) ?? '-'}%'),
                                const SizedBox(width: 10),
                                const Icon(Icons.air, size: 14),
                                const SizedBox(width: 4),
                                Text('${day.windspeedMax?.toStringAsFixed(0) ?? '-'} km/h'),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Model for a day's forecast
class WeatherDay {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int weatherCode;
  final double? precipitationProbabilityMax;
  final double? windspeedMax;

  WeatherDay({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.weatherCode,
    this.precipitationProbabilityMax,
    this.windspeedMax,
  });
}

/// Fetch 5-day forecast from Open-Meteo
Future<List<WeatherDay>> fetchFiveDayForecast(double lat, double lon, String timezone) async {
  // Open-Meteo daily endpoint — lấy max/min temp, weathercode, precipitation_probability_max, windspeed_10m_max
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': lat.toString(),
    'longitude': lon.toString(),
    'daily': 'temperature_2m_max,temperature_2m_min,weathercode,precipitation_probability_max,windspeed_10m_max',
    'timezone': timezone,
    'forecast_days': '5',
  });

  final res = await http.get(uri);
  if (res.statusCode != 200) {
    throw Exception('HTTP ${res.statusCode}');
  }

  final body = json.decode(res.body) as Map<String, dynamic>;

  if (!body.containsKey('daily')) {
    throw Exception('API response không chứa trường "daily"');
  }

  final daily = body['daily'] as Map<String, dynamic>;

  final dates = List<String>.from(daily['time'] ?? []);
  final maxTemps = List<num>.from(daily['temperature_2m_max'] ?? []);
  final minTemps = List<num>.from(daily['temperature_2m_min'] ?? []);
  final weatherCodes = List<num>.from(daily['weathercode'] ?? []);
  final precipProbs = daily.containsKey('precipitation_probability_max')
      ? List<num>.from(daily['precipitation_probability_max'] ?? [])
      : List<num>.filled(dates.length, 0);
  final windspeedMax = daily.containsKey('windspeed_10m_max')
      ? List<num>.from(daily['windspeed_10m_max'] ?? [])
      : List<num>.filled(dates.length, 0);

  final List<WeatherDay> result = [];

  for (int i = 0; i < dates.length; i++) {
    final dateStr = dates[i];
    DateTime parsed = DateTime.parse(dateStr);
    result.add(WeatherDay(
      date: parsed,
      tempMax: maxTemps[i].toDouble(),
      tempMin: minTemps[i].toDouble(),
      weatherCode: weatherCodes[i].toInt(),
      precipitationProbabilityMax: precipProbs.isNotEmpty ? precipProbs[i].toDouble() : null,
      windspeedMax: windspeedMax.isNotEmpty ? windspeedMax[i].toDouble() : null,
    ));
  }

  return result;
}

/// Helper: map weather code to a human text (Open-Meteo uses WMO weather codes)
String _weatherCodeToText(int code) {
  // simplified mapping
  if (code == 0) return 'Clear';
  if (code == 1 || code == 2) return 'Partly cloudy';
  if (code == 3) return 'Overcast';
  if (code >= 45 && code <= 48) return 'Fog';
  if ((code >= 51 && code <= 57) || (code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return 'Rain';
  if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return 'Snow';
  if (code >= 95) return 'Thunderstorm';
  return 'Unknown';
}

/// Helper: return a simple emoji as icon (replace with asset path if you have images)
String _weatherCodeToEmoji(int code) {
  if (code == 0) return '☀️';
  if (code == 1 || code == 2) return '⛅';
  if (code == 3) return '☁️';
  if (code >= 45 && code <= 48) return '🌫️';
  if ((code >= 51 && code <= 57) || (code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return '🌧️';
  if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return '❄️';
  if (code >= 95) return '⛈️';
  return 'ℹ️';
}
