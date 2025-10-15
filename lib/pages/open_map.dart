import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../utils/location_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class OpenMapPage extends StatefulWidget {
  const OpenMapPage({super.key});

  @override
  State<OpenMapPage> createState() => _OpenMapPageState();
}

class _OpenMapPageState extends State<OpenMapPage> {
  late MapLibreMapController mapController;
  final TextEditingController _searchController = TextEditingController();
  Symbol? _currentSymbol;
  Map<String, dynamic>? _weatherData;

  final String mapStyle = "https://tiles.openmap.vn/styles/day-v1/style.json";

  void _onMapCreated(MapLibreMapController controller) async { // Thêm 'async'
    mapController = controller;

    // 💡 FIX: Tải icon từ local asset và đặt tên là "custom-marker"
    try {
      final ByteData bytes = await rootBundle.load("assets/images/markup_icon.png");
      final Uint8List list = bytes.buffer.asUint8List();
      // Tải hình ảnh vào map controller với ID mới
      await mapController.addImage("custom-marker", list);
    } catch (e) {
      debugPrint("Error loading icon: $e");
    }


    // Lắng nghe khi nhấn vào Symbol
    mapController.onSymbolTapped.add((symbol) {
      _showMarkerMenu(symbol);
    });
  }

  Future<void> _addMarker(double lat, double lon) async {
    // Xóa marker cũ (nếu có)
    if (_currentSymbol != null) {
      await mapController.removeSymbol(_currentSymbol!);
    }

    // Thêm marker mới
    _currentSymbol = await mapController.addSymbol(
      SymbolOptions(
        geometry: LatLng(lat, lon),
        iconImage: "custom-marker",
        iconSize: 0.5,
      ),
    );
  }

  // Hiện menu khi click marker
  void _showMarkerMenu(Symbol symbol) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text("Xem thời tiết"),
              onTap: () async {
                Navigator.pop(ctx);
                final lat = symbol.options.geometry!.latitude;
                final lon = symbol.options.geometry!.longitude;
                final data = await _fetchWeather(lat, lon);
                if (data != null && mounted) {
                  _showWeatherDialog(data);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text("Xóa điểm này"),
              onTap: () async {
                Navigator.pop(ctx);
                await mapController.removeSymbol(symbol);
                _currentSymbol = null;
              },
            ),
          ],
        );
      },
    );
  }
  Future<void> _showWeatherDialog(Map<String, dynamic> data) async {
    final daily = data["daily"];
    final times = List<String>.from(daily["time"]);
    final maxTemps = List<double>.from(daily["temperature_2m_max"]);
    final minTemps = List<double>.from(daily["temperature_2m_min"]);
    final codes = List<int>.from(daily["weathercode"]);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("7-day weather forecast"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: times.length,
              itemBuilder: (context, index) {
                final status = _mapWeatherText(codes[index]);
                return ListTile(
                  leading: Icon(
                    _mapWeatherIcon(codes[index]),
                    color: Colors.blueAccent,
                  ),
                  title: Text(
                    "${times[index]}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "$status\Max: ${maxTemps[index]}°C  |  Min: ${minTemps[index]}°C",
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

// Phân loại trạng thái thời tiết
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

// Thêm icon tương ứng cho đẹp hơn
  IconData _mapWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny;
    if ([1, 2, 3].contains(code)) return Icons.cloud;
    if ([45, 48].contains(code)) return Icons.foggy; // Flutter 3.10+ có
    if ([51, 53, 55, 61, 63, 65, 80, 81, 82].contains(code)) return Icons.grain;
    if ([71, 73, 75, 77, 85, 86].contains(code)) return Icons.ac_unit;
    if ([95, 96, 99].contains(code)) return Icons.flash_on;
    return Icons.help_outline;
  }


  Future<void> _goToCurrentLocation() async {
    try {
      Position pos = await LocationHelper.determinePosition();
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15.0),
      );

      await _addMarker(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Unable to get location: $e")));
      }
    }
  }

  Future<void> _searchLocation() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(loc.latitude, loc.longitude), 15.0),
        );

        await _addMarker(loc.latitude, loc.longitude);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location not found")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Search error: $e")));
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchWeather(double lat, double lon) async {
    final url =
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lon'
        '&hourly=temperature_2m,precipitation,weathercode,windspeed_10m'
        '&daily=temperature_2m_max,temperature_2m_min,weathercode'
        '&timezone=auto';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        return json.decode(res.body) as Map<String, dynamic>;
      } else {
        debugPrint("Lỗi fetch weather: ${res.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Exception fetch weather: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OpenMap.vn"),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: "Go to current location",
            onPressed: _goToCurrentLocation,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Enter location...",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchLocation,
                ),
              ],
            ),
          ),
        ),
      ),
      body: MapLibreMap(
        styleString: mapStyle,
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: LatLng(21.03842, 105.834106), // Hà Nội
          zoom: 12.0,
        ),
        compassEnabled: true,
        myLocationEnabled: true,
      ),
    );
  }
}
