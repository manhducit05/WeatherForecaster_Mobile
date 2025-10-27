import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'dart:convert';
import '../utils/storage_helper.dart';
import '../utils/location_helper.dart';
import '../widgets/direction_route_dialog_widget.dart';
import '../utils/map_helper.dart';

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
  bool _hasSaved = false;
  bool _styleLoaded = false;

  void _onMapCreated(MapLibreMapController controller) async {
    mapController = controller;
    debugPrint("Map created");

    // giữ nguyên listener symbol tap
    mapController.onSymbolTapped.add((symbol) {
      final placeId = symbol.data?["placeId"];
      _showMarkerMenu(symbol, placeId: placeId);
    });
  }

  Future<void> _onStyleLoaded() async {
    if (!mounted) return;
    _styleLoaded = true;
    debugPrint("🗺️ onStyleLoaded fired");

    // Load image AFTER style loaded — an toàn hơn
    try {
      final ByteData bytes = await rootBundle.load(
        "assets/images/markup_icon.png",
      );
      final Uint8List list = bytes.buffer.asUint8List();
      await mapController.addImage("custom-marker", list);
      debugPrint("custom-marker added after style loaded");
    } catch (e) {
      debugPrint("addImage failed in _onStyleLoaded: $e");
    }
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
  void _showMarkerMenu(Symbol symbol, {String? placeId}) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Wrap(
          children: [
            if (placeId != null)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("Show place info"),
                onTap: () async {
                  Navigator.pop(ctx);
                  final placeData = await _fetchPlaceDetail(placeId);
                  if (placeData != null && mounted) {
                    _showPlaceInfoDialog(placeData);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("No info available")),
                    );
                  }
                },
              ),
            // Khi click marker -> Get Directions
            ListTile(
              leading: const Icon(Icons.directions),
              title: const Text("Get Directions to here"),
              onTap: () async {
                Navigator.pop(ctx);

                final dest = LatLng(
                  symbol.options.geometry!.latitude,
                  symbol.options.geometry!.longitude,
                );
                final destName =
                    symbol.options.textField ?? "Selected location";

                final result = await showDialog(
                  context: context,
                  builder: (_) => DirectionRouteDialog(
                    defaultDestination: dest,
                    defaultDestinationName: destName,
                  ),
                );

                if (result == null) return;

                final from = result['from'] as LatLng;
                final to = result['to'] as LatLng;

                // Đảm bảo style đã load
                if (!_styleLoaded) {
                  await Future.delayed(const Duration(milliseconds: 300));
                }
                final vehicle = result['vehicle'] ?? 'car';
                // Lấy route
                final directionResult = await MapHelper.fetchDirection(
                  startLat: from.latitude,
                  startLng: from.longitude,
                  endLat: to.latitude,
                  endLng: to.longitude,
                  vehicle: vehicle,
                );

                final List<LatLng> routePoints = directionResult["points"];
                final Map<String, dynamic> data = directionResult["data"];

                final leg = data["routes"][0]["legs"][0];
                final distance = leg["distance"]["text"];
                final duration = leg["duration"]["text"];
                final steps = leg["steps"];

                _showRouteDialog(context, distance, duration, steps);

                // Zoom bao trùm
                await mapController.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    _boundsFromLatLngList(routePoints),
                    left: 50,
                    right: 50,
                    top: 100,
                    bottom: 100,
                  ),
                );

                // Thêm marker đầu-cuối
                await mapController.addSymbol(
                  SymbolOptions(
                    geometry: to,
                    iconImage: "custom-marker",
                    iconSize: 0.005,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text("7-day weather forecast"),
              onTap: () async {
                Navigator.pop(ctx); // đóng bottom sheet

                final lat = symbol.options.geometry!.latitude;
                final lon = symbol.options.geometry!.longitude;

                final weatherData = await _fetchWeather(lat, lon);
                if (weatherData != null && mounted) {
                  _showWeatherDialog(weatherData);
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Unable to fetch weather data"),
                    ),
                  );
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
                      SnackBar(content: Text("Location saved: $result")),
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

  void _showRouteDialog(
    BuildContext context,
    String distance,
    String duration,
    List<dynamic> steps,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                "Thời gian: $duration\nQuãng đường: $distance",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showStepsDialog(context, steps);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text("Xem chi tiết"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      final text =
                          "Tuyến đường dài $distance, thời gian di chuyển $duration.";
                      Share.share(text);
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("Chia sẻ"),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStepsDialog(BuildContext context, List<dynamic> steps) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return ListView.builder(
              controller: scrollController,
              itemCount: steps.length,
              itemBuilder: (context, index) {
                final step = steps[index];
                final instruction = step["html_instructions"] ?? "";
                final distance = step["distance"]["text"];
                final duration = step["duration"]["text"];

                return ListTile(
                  leading: const Icon(Icons.turn_right),
                  title: Text(
                    instruction.replaceAll(
                      RegExp(r'<[^>]*>'),
                      '',
                    ), // bỏ tag HTML
                  ),
                  subtitle: Text("$distance - $duration"),
                );
              },
            );
          },
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

          // Gán lại _currentSymbol bằng symbol vừa tạo
          _currentSymbol = await mapController.addSymbol(
            SymbolOptions(
              geometry: target,
              iconImage: "custom-marker",
              textField: name,
              textOffset: const Offset(0, 1.5),
            ),
          );

          // Sau đó hiển thị menu
          _showMarkerMenu(_currentSymbol!, placeId: placeId);
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

  // hàm format giờ đóng-mở cửa của địa điểm
  String _formatOpeningHours(List<dynamic>? hours) {
    if (hours == null || hours.isEmpty) {
      return "No opening hours info available";
    }

    final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    final buffer = StringBuffer();

    for (int i = 0; i < hours.length && i < days.length; i++) {
      final pair = hours[i];

      // Kiểm tra cấu trúc đúng dạng [open, close]
      if (pair is List && pair.length == 2) {
        final open = pair[0];
        final close = pair[1];

        // Kiểm tra xem open/close có phải List và đủ phần tử
        if (open is List &&
            open.length >= 3 &&
            close is List &&
            close.length >= 3) {
          final o =
              "${open[1].toString().padLeft(2, '0')}:${open[2].toString().padLeft(2, '0')}";
          final c =
              "${close[1].toString().padLeft(2, '0')}:${close[2].toString().padLeft(2, '0')}";
          buffer.writeln("${days[i]}: $o - $c");
        }
      }
    }
    // Nếu buffer rỗng (tức là không parse được dòng nào)
    if (buffer.isEmpty) {
      return "No opening hours info available";
    }

    return buffer.toString().trim();
  }

  // show dialog hiển thị location detail
  void _showPlaceInfoDialog(Map<String, dynamic> place) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên địa điểm
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.place,
                        color: Colors.blueAccent,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          place["name"] ?? "Unknown place",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (place["label"] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      place["label"],
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),

                  // Thông tin chi tiết
                  if (place["phone"] != null)
                    _infoRow(Icons.phone, place["phone"], color: Colors.green),

                  if (place["website"] != null)
                    _infoRow(
                      Icons.language,
                      place["website"],
                      color: Colors.blueAccent,
                    ),

                  if (place["street"] != null)
                    _infoRow(
                      Icons.location_on,
                      place["street"],
                      color: Colors.redAccent,
                    ),
                  if (place["lat"] != null && place["lon"] != null)
                    _infoRow(
                      Icons.map_outlined,
                      "WGS84: ${place["lat"]}, ${place["lon"]}",
                      color: Colors.indigo,
                    ),
                  if (place["forcodes"] != null)
                    _infoRow(
                      Icons.qr_code,
                      "Forcodes: ${place["forcodes"]}",
                      color: Colors.orange,
                    ),
                  if (place["zipcode"] != null)
                    _infoRow(
                      Icons.local_post_office,
                      "Zipcode: ${place["zipcode"]}",
                      color: Colors.teal,
                    ),
                  const Divider(height: 24),

                  if (place["opening_hours_v2"] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Opening hours",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatOpeningHours(place["opening_hours_v2"]),
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text("Close"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  // dialog chi duong

  /// Widget hiển thị 1 dòng thông tin có icon và text
  Widget _infoRow(IconData icon, String text, {Color color = Colors.black54}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // hàm fetch để lấy location detail
  Future<Map<String, dynamic>?> _fetchPlaceDetail(String placeId) async {
    try {
      final apiKey = dotenv.env['API_KEY'];
      final url =
          "https://mapapis.openmap.vn/v1/place?ids=$placeId&apiKey=$apiKey";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        // Kiểm tra kỹ trước khi truy cập index
        final features = data["features"];
        if (features is List && features.isNotEmpty) {
          final first = features.first;

          if (first is Map) {
            final props = first["properties"] ?? {};
            final geometry = first["geometry"] ?? {};

            // Nếu có toạ độ hợp lệ, thêm vào properties
            if (geometry["coordinates"] is List &&
                geometry["coordinates"].length == 2) {
              props["lat"] = geometry["coordinates"][1];
              props["lon"] = geometry["coordinates"][0];
            }

            // Gộp lại để sau có thể truyền nguyên map này vào _showPlaceInfoDialog()
            return {...props, "geometry": geometry};
          } else {
            debugPrint("features[0] không có properties");
          }
        } else {
          debugPrint("Không có features cho placeId: $placeId");
        }
      } else {
        debugPrint("Fetch place detail failed: ${res.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching place detail: $e");
    }
    return null;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    double? x0, x1, y0, y1;
    for (final latLng in list) {
      if (x0 == null) {
        x0 = x1 = latLng.latitude;
        y0 = y1 = latLng.longitude;
      } else {
        if (latLng.latitude > x1!) x1 = latLng.latitude;
        if (latLng.latitude < x0) x0 = latLng.latitude;
        if (latLng.longitude > y1!) y1 = latLng.longitude;
        if (latLng.longitude < y0!) y0 = latLng.longitude;
      }
    }
    return LatLngBounds(
      southwest: LatLng(x0!, y0!),
      northeast: LatLng(x1!, y1!),
    );
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
            icon: const Icon(Icons.directions),
            tooltip: "Chỉ đường",
            onPressed: () async {
              final result = await showDialog(
                context: context,
                builder: (_) => const DirectionRouteDialog(),
              );
              if (result == null) return;

              final from = result["from"] as LatLng;
              final to = result["to"] as LatLng;

              if (!_styleLoaded) {
                await Future.delayed(const Duration(milliseconds: 300));
              }

              final vehicle = result['vehicle'] ?? 'car';

              final directionResult = await MapHelper.fetchDirection(
                startLat: from.latitude,
                startLng: from.longitude,
                endLat: to.latitude,
                endLng: to.longitude,
                vehicle: vehicle,
              );

              // lấy routePoints và data từ result

              final List<LatLng> routePoints = directionResult["points"];
              final Map<String, dynamic> data = directionResult["data"];

              final leg = data["routes"][0]["legs"][0];
              final distance = leg["distance"]["text"];
              final duration = leg["duration"]["text"];
              final steps = leg["steps"];

              _showRouteDialog(context, distance, duration, steps);

              await mapController.animateCamera(
                CameraUpdate.newLatLngBounds(
                  _boundsFromLatLngList(routePoints),
                  left: 50,
                  right: 50,
                  top: 100,
                  bottom: 100,
                ),
              );

              await mapController.addSymbol(
                SymbolOptions(
                  geometry: from,
                  iconImage: "custom-marker",
                  iconSize: 0.005,
                ),
              );
              await mapController.addSymbol(
                SymbolOptions(
                  geometry: to,
                  iconImage: "custom-marker",
                  iconSize: 0.005,
                ),
              );
            },
          ),
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
            onStyleLoadedCallback: _onStyleLoaded, // <-- thêm vào đây
            initialCameraPosition: const CameraPosition(
              target: LatLng(21.03842, 105.834106), // Hà Nội
              zoom: 12.0,
            ),
            compassEnabled: true,
            myLocationEnabled: true,
          ),
          // Overlay box

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
                        onPressed: () {},
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        showSuggestions = val.trim().isNotEmpty;
                      });
                    },
                  ),
                ),

                // Suggestions
                Builder(
                  builder: (context) {
                    final query = _searchController.text.trim();
                    if (!showSuggestions || query.isEmpty) {
                      return const SizedBox.shrink();
                    }
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
