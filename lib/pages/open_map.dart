import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/location_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/storage_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenMapPage extends StatefulWidget {
  const OpenMapPage({super.key});

  @override
  State<OpenMapPage> createState() => _OpenMapPageState();
}

class _OpenMapPageState extends State<OpenMapPage> {
  late MapLibreMapController mapController;
  final TextEditingController _searchController = TextEditingController();
  Symbol? _currentSymbol;
  bool showSuggestions = true;

  final String mapStyle = "https://tiles.openmap.vn/styles/day-v1/style.json";

  bool _hasSaved = false; // <-- thêm biến này

  void _onMapCreated(MapLibreMapController controller) async {
    mapController = controller;

    // Tải icon từ local asset và đặt tên là "custom-marker"
    try {
      final ByteData bytes = await rootBundle.load(
        "assets/images/markup_icon.png",
      );
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
        iconSize: 0.005,
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
              title: const Text("Weather Forecast"),
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
              leading: const Icon(Icons.save),
              title: const Text("Add to saved locations"),
              onTap: () async {
                Navigator.pop(ctx);

                final lat = symbol.options.geometry!.latitude;
                final lon = symbol.options.geometry!.longitude;

                final nameController = TextEditingController();

                final result = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Name the location."),
                      content: TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          hintText: "Name the location",
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context), // cancel
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final name = nameController.text.trim();
                            if (name.isNotEmpty) {
                              Navigator.pop(context, name);
                            } else {
                              Navigator.pop(
                                context,
                                "Custom Point (${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)})",
                              );
                            }
                          },
                          child: const Text("Save"),
                        ),
                      ],
                    );
                  },
                );

                if (result != null) {
                  final newLoc = {
                    "name": result,
                    "lat": lat,
                    "lon": lon,
                    "tz": "auto",
                  };
                  await StorageHelper.addLocation(newLoc);
                  _hasSaved = true; // đánh dấu đã lưu

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Location saved.: $result")),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text("Delete point"),
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

  // dialog thời tiết 7 ngày
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
                    times[index],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "$status\nMax: ${maxTemps[index]}°C  |  Min: ${minTemps[index]}°C",
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
      //lấy vị trí hiện tại từ hàm helper
      Position pos = await LocationHelper.determinePosition();
      //di chuyển camera đến vị trí, độ zoom 15
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 15.0),
      );

      await _addMarker(pos.latitude, pos.longitude);
      //thông báo nếu có lỗi
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Unable to get location: $e")));
      }
    }
  }

  Future<void> _searchLocation(String placeId) async {
    try {
      final apiKey = dotenv.env['API_KEY'];
      final url =
          "https://mapapis.openmap.vn/v1/place?ids=$placeId&apiKey=$apiKey";

      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data['features'] != null && data['features'].isNotEmpty) {
          final feature = data['features'][0];
          final coords = feature['geometry']['coordinates'];
          final name = feature['properties']['name'];

          final lon = coords[0];
          final lat = coords[1];
          final target = LatLng(lat, lon);

          // Move camera
          await mapController.animateCamera(
            CameraUpdate.newLatLngZoom(target, 15),
          );

          // Clear symbols cũ và add symbol mới
          await mapController.clearSymbols();
          await mapController.addSymbol(
            SymbolOptions(
              geometry: target,
              iconImage: "custom-marker",
              textField: name,
              textOffset: const Offset(0, 1.5),
            ),
          );

          debugPrint("Moved to $name ($lat, $lon)");
        } else {
          debugPrint("Không tìm thấy chi tiết cho placeId: $placeId");
        }
      } else {
        debugPrint("API error: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("searchLocationById error: $e");
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

  Future<List<Map<String, dynamic>>> fetchSuggestions(String query) async {
    if (query.trim().isEmpty) return [];
    final apiKey = dotenv.env['API_KEY'];
    final encoded = Uri.encodeQueryComponent(query.trim());
    final url =
        "https://mapapis.openmap.vn/v1/autocomplete?text=$encoded"
        "&size=5&apiKey=$apiKey";

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final features = data["features"] as List<dynamic>? ?? [];
        // mỗi feature có 'properties' -> lấy thẳng properties
        return features
            .map(
              (f) =>
                  (f as Map<String, dynamic>)["properties"]
                      as Map<String, dynamic>,
            )
            .toList();
      } else {
        debugPrint("Autocomplete API status: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Autocomplete error: $e");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OpenMap.vn"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, _hasSaved);
            // nếu đã lưu => true, nếu không => false
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: "Go to current location",
            onPressed: _goToCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: mapStyle,
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(21.03842, 105.834106), // Hà Nội
              zoom: 12.0,
            ),
            compassEnabled: true,
            myLocationEnabled: true,
          ),
          // --- Search box + suggestions ---
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
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
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed:(){},
                      ),
                    ),
                      onChanged: (val) {
                        setState(() {
                          showSuggestions = val.trim().isNotEmpty;
                        });},

                  ),
                ),

                // Suggestions
                Builder(
                  builder: (context) {
                    final query = _searchController.text.trim();
                    if (!showSuggestions || query.isEmpty) return const SizedBox.shrink();
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: fetchSuggestions(query),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final suggestions = snapshot.data!;
                        if (suggestions.isEmpty) return const SizedBox.shrink();

                        return Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(blurRadius: 4, color: Colors.black12),
                            ],
                          ),
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            itemBuilder: (ctx, index) {
                              final s = suggestions[index];
                              final name = s["name"] as String? ?? "";
                              final label = s["label"] as String? ?? "";
                              final placeId = s["id"] as String? ?? "";
                              return ListTile(
                                title: Text(name),
                                subtitle: Text(label),

                                onTap: () async {
                                  FocusScope.of(context).unfocus();
                                  _searchController.text = name;
                                  setState(() {
                                    showSuggestions = false; // ẩn gợi ý
                                  });

                                  // gọi search luôn
                                  await _searchLocation(placeId);
                                  debugPrint(
                                    "Selected place id: $placeId, name: $name",
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
