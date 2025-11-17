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
import '../widgets/routes_selector.dart';
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
  LatLng? _searchedPosition; // null = mặc định dùng vị trí của tôi

  int _selectedRouteIndex = 0;
  List<Map<String, dynamic>> _routes = [];

  String? _routeDistance;
  String? _routeDuration;
  List<dynamic>? _routeSteps;

  // kiem tra xem da diem den hay khong
  bool _isMultiRoute = false;
  Widget _buildMultiRouteInfo() {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alt_route, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              "$_routeDistance • $_routeDuration",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _onMapCreated(MapLibreMapController controller) async {
    mapController = controller;
    debugPrint("Map created");

    mapController.onSymbolTapped.clear();

    mapController.onFeatureTapped.add((
      point,
      coordinates,
      id,
      layerId,
      annotation,
    ) {
      if (annotation is Symbol) {
        final placeId = annotation.data?["placeId"];
        _showMarkerMenu(annotation, placeId: placeId);
      } else {
        _handleRouteLineTap(layerId, id);
      }
    });
  }

  void _selectRoute(int newIndex) {
    // Đảm bảo chỉ mục hợp lệ và có sự thay đổi
    if (newIndex >= 0 &&
        newIndex < _routes.length &&
        _selectedRouteIndex != newIndex) {
      // 1. Cập nhật trạng thái
      setState(() {
        _selectedRouteIndex = newIndex;
      });

      // 2. Đồng bộ hóa với MapHelper (Highlight trên bản đồ)
      // Đảm bảo controller đã sẵn sàng
      if (_routes.isNotEmpty) {
        // Gọi hàm highlight mà bạn đã định nghĩa trong MapHelper
        MapHelper.highlightRoute(
          mapController,
          _selectedRouteIndex,
          _routes.length,
        );
      }

      // 3. (Tùy chọn) Cập nhật thông tin chi tiết khác (khoảng cách, thời gian, v.v.)
      if (_routes.isNotEmpty) {
        final legData = _routes[_selectedRouteIndex]["legs"][0];
        // ... (logic cập nhật _routeDistance, _routeDuration, ...)
        debugPrint(
          "Tuyến đường được chọn: $_selectedRouteIndex, Distance: ${legData["distance"]["text"]}",
        );
      }
    }
  }

  void _handleRouteLineTap(String layerId, String featureId) {
    // Kiểm tra xem layerId có phải là một trong các layer tuyến đường của bạn không
    if (layerId.startsWith("route-line-")) {
      final indexStr = layerId.substring("route-line-".length);
      final routeIndex = int.tryParse(indexStr);

      if (routeIndex != null) {
        debugPrint("Đã click vào tuyến đường có chỉ mục (index): $routeIndex");

        // Thay thế logic highlight trực tiếp bằng việc gọi hàm cập nhật State
        // Hàm này sẽ tự động gọi MapHelper.highlightRoute và cập nhật RoutesSelector
        _selectRoute(routeIndex);
      }
    }
  }
  // bộ icon
  final List<Map<String, String>> mapIcons = [
    {
      "key": "location-pin",
      "path": "assets/images/location-pin.png",
    },
    {
      "key": "searched-location",
      "path": "assets/images/searched-location.png",
    },
    {
      "key": "start-marker",
      "path": "assets/images/icon/start-marker.png",
    },
    {
      "key": "end-marker",
      "path": "assets/images/icon/end-marker.png",
    },
    // bộ icon
    {
      "key": "gas_station-icon",
      "path": "assets/images/icon/gas_station-icon.png",
    },
    {
      "key": "health-icon",
      "path": "assets/images/icon/health-icon.png",
    },
    {
      "key": "hotel-icon",
      "path": "assets/images/icon/hotel-icon.png",
    },
    {
      "key": "pharmacy-icon",
      "path": "assets/images/icon/pharmacy-icon.png",
    },

    {
      "key": "restaurant-icon",
      "path": "assets/images/icon/restaurant-icon.png",
    },
    {
      "key": "school-icon",
      "path": "assets/images/icon/education-icon.png",
    },
  ];


  Future<void> _loadIconsFromList() async {
    for (var icon in mapIcons) {
      final key = icon["key"]!;
      final path = icon["path"]!;

      try {
        final ByteData bytes = await rootBundle.load(path);
        final Uint8List list = bytes.buffer.asUint8List();
        await mapController.addImage(key, list);

        debugPrint("Loaded icon: $key");
      } catch (e) {
        debugPrint("Failed to load $key: $e");
      }
    }
  }
  Future<void> _onStyleLoaded() async {
    if (!mounted) return;
    _styleLoaded = true;
    debugPrint("onStyleLoaded fired");

    // 1) Load icon
    await _loadIconsFromList();

    // 2) Vẽ lại polyline nếu đã có route
    if (_routes.isNotEmpty) {
      debugPrint("Style reloaded → redraw ${_routes.length} routes");
      await MapHelper.drawRoutesOnMap(mapController, _routes);
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
        iconImage: "location-pin",
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

                // Hiện dialog lấy hướng đi
                final result = await showDialog(
                  context: context,
                  builder: (_) => DirectionRouteDialog(
                    defaultDestination: dest,
                    defaultDestinationName: destName,
                    mapController: mapController,
                  ),
                );

                if (result == null) return;

                final from = result['from'] as LatLng;
                final to = result['to'] as LatLng; // to = dest (fixed)
                final waypoints =
                    (result["waypoints"] as List?)?.cast<LatLng>() ?? [];
                final vehicle = result['vehicle'] ?? 'car';

                // Đảm bảo map style load xong
                if (!_styleLoaded) {
                  await Future.delayed(const Duration(milliseconds: 300));
                }

                await MapHelper.clearMarkers(mapController);

                //  CASE 1: Không có waypoint → SINGLE DIRECTION

                if (waypoints.isEmpty) {
                  final directionResult = await MapHelper.fetchDirection(
                    startLat: from.latitude,
                    startLng: from.longitude,
                    endLat: to.latitude,
                    endLng: to.longitude,
                    vehicle: vehicle,
                  );

                  final routes = directionResult["data"]["routes"];
                  if (routes.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Không tìm thấy tuyến đường"),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _routes = routes.cast<Map<String, dynamic>>();
                    _selectedRouteIndex = 0;
                  });

                  final leg = routes[0]["legs"][0];

                  final startLocation = LatLng(
                    leg["start_location"]["lat"],
                    leg["start_location"]["lng"],
                  );

                  final endLocation = LatLng(
                    leg["end_location"]["lat"],
                    leg["end_location"]["lng"],
                  );

                  // Vẽ routes
                  await MapHelper.drawRoutesOnMap(mapController, routes);

                  // START + END marker
                  await MapHelper.addStartEndMarker(
                    mapController,
                    startLocation,
                    iconAssetPath: "assets/images/start-position-marker.png",
                    imageId: "startIcon",
                  );
                  await MapHelper.addStartEndMarker(
                    mapController,
                    endLocation,
                    iconAssetPath: "assets/images/end-position-marker.png",
                    imageId: "endIcon",
                  );
                  if (to.latitude != endLocation.latitude ||
                      to.longitude != endLocation.longitude) {
                    await MapHelper.drawDashedLine(
                      controller:
                          mapController, // Giả định mapController là MapLibreMapController
                      from: endLocation,
                      to: to,
                      color: "#A9A9A9", // Màu đỏ (đã chuyển sang hex)
                      lineWidth: 3.0,
                      dashArray: [1.0, 1.0], // Độ dài nét đứt và khoảng trống
                    );
                  }
                  // UI update
                  setState(() {
                    _routeDistance = leg["distance"]["text"];
                    _routeDuration = leg["duration"]["text"];
                    _routeSteps = leg["steps"];
                  });

                  return;
                }
                //  CASE 2: Có waypoint → MULTI DIRECTION
                final directionResult = await MapHelper.fetchMultiDirection(
                  controller: mapController,
                  start: from,
                  end: to,
                  waypoints: waypoints,
                  vehicle: vehicle,
                );

                final routes = directionResult["data"]["routes"] ?? [];
                if (routes.isEmpty) return;

                setState(() {
                  _routes = routes.cast<Map<String, dynamic>>();
                  _isMultiRoute = waypoints.isNotEmpty;
                });

                // Lấy toàn bộ legs
                final legs = routes[0]["legs"].cast<Map<String, dynamic>>();

                final startLocation = LatLng(
                  legs.first["start_location"]["lat"],
                  legs.first["start_location"]["lng"],
                );

                final endLocation = LatLng(
                  legs.last["end_location"]["lat"],
                  legs.last["end_location"]["lng"],
                );

                await MapHelper.clearMarkers(mapController);

                // Vẽ routes
                await MapHelper.drawRoutesOnMap(mapController, routes);

                // Marker START + END
                await MapHelper.addStartEndMarker(
                  mapController,
                  startLocation,
                  iconAssetPath: "assets/images/start-position-marker.png",
                  imageId: "startIcon",
                );
                await MapHelper.addStartEndMarker(
                  mapController,
                  endLocation,
                  iconAssetPath: "assets/images/end-position-marker.png",
                  imageId: "endIcon",
                );
                if (waypoints.isNotEmpty) {
                  int index = 1;
                  for (final w in waypoints) {
                    await MapHelper.addStartEndMarker(
                      mapController,
                      w,
                      iconAssetPath:
                          "assets/images/position-waypoint-marker.png",
                      imageId: "waypoint_$index",
                    );
                    index++;
                  }
                }
                // ---- Tổng hợp steps/distance/duration ----
                List allSteps = [];
                for (final leg in legs) {
                  if (leg["steps"] != null) {
                    allSteps.addAll(leg["steps"]);
                  }
                }

                final int sumMeters =
                    (directionResult["totalDistance"] ?? 0) as int;
                final int sumSeconds =
                    (directionResult["totalDuration"] ?? 0) as int;

                String formatDistance(int m) =>
                    m >= 1000 ? "${(m / 1000).toStringAsFixed(1)} km" : "$m m";

                String formatDuration(int s) {
                  final h = s ~/ 3600;
                  final m = (s % 3600) ~/ 60;
                  if (h > 0) return "$h giờ $m phút";
                  return "$m phút";
                }

                if (to.latitude != endLocation.latitude ||
                    to.longitude != endLocation.longitude) {
                  await MapHelper.drawDashedLine(
                    controller:
                        mapController, // Giả định mapController là MapLibreMapController
                    from: endLocation,
                    to: to,
                    color: "#A9A9A9", // Màu đỏ (đã chuyển sang hex)
                    lineWidth: 3.0,
                    dashArray: [1.0, 1.0], // Độ dài nét đứt và khoảng trống
                  );
                }
                setState(() {
                  _routeDistance = formatDistance(sumMeters);
                  _routeDuration = formatDuration(sumSeconds);
                  _routeSteps = allSteps;
                });

                return;
              },
            ),

            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text("7-day weather forecast"),
              onTap: () async {
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

  IconData _getManeuverIcon(String? maneuver) {
    if (maneuver == null) return Icons.directions;

    switch (maneuver) {
      // --- Rẽ phải / trái ---
      case "right":
        return Icons.turn_right;
      case "left":
        return Icons.turn_left;

      // --- Chếch trái/phải ---
      case "slight right":
        return Icons.turn_slight_right;
      case "slight left":
        return Icons.turn_slight_left;

      // --- Gấp trái/phải ---
      case "sharp right":
        return Icons.turn_sharp_right;
      case "sharp left":
        return Icons.turn_sharp_left;

      // --- Đi thẳng ---
      case "straight":
      case "continue":
        return Icons.straight;

      // --- Quay đầu (có thể API không trả về, nhưng phòng hờ) ---
      case "uturn":
      case "u-turn":
      case "uturn-left":
      case "uturn-right":
        return Icons.u_turn_left;

      // --- Vòng xuyến (nếu API có hỗ trợ) ---
      case "roundabout-left":
        return Icons.roundabout_left;
      case "roundabout-right":
        return Icons.roundabout_right;

      default:
        return Icons.directions; // icon mặc định
    }
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
                  leading: Icon(_getManeuverIcon(step["maneuver"])),
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
      // dieu chinh vi tri tim kiem dia diem xung quanh
      _searchedPosition = null;
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

          // chinh vi tri tim kiem dia diem xung quanh
          _searchedPosition = target;
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
              iconImage: "searched-location",
              textField: name,
              iconSize: 0.2,
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

  List<Map<String, dynamic>> _nearbyResults = [];
  bool _showNearbySheet = false;
  List<Symbol> _nearbySymbols = [];
  Widget _buildCategoryChip(String label, IconData icon, String category) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 20),
        label: Text(label),
        onPressed: () async {
          try {
            // 1️⃣ Lấy vị trí
            double lat;
            double lon;

            // 1️⃣ Xác định vị trí đang sử dụng
            if (_searchedPosition != null) {
              lat = _searchedPosition!.latitude;
              lon = _searchedPosition!.longitude;
            } else {
              final pos = await LocationHelper.determinePosition();
              lat = pos.latitude;
              lon = pos.longitude;
            }

            // 2️⃣ Lấy dữ liệu nearby
            final results = await MapHelper.fetchNearby(
              lat: lat,
              lon: lon,
              category: category,
            );

            // 3️⃣ Hiển thị sheet
            setState(() {
              _nearbyResults = results;
              _showNearbySheet = true;
            });

            // 4️⃣ Vẽ các symbol trên Map
            // Xóa group symbol cũ (nếu có)
            if (_nearbySymbols.isNotEmpty) {
              await mapController.removeSymbols(_nearbySymbols);
              _nearbySymbols.clear();
            }
            // Thêm symbol mới
            for (var item in results) {
              final symbol = await mapController.addSymbol(
                SymbolOptions(
                  geometry: LatLng(item["lat"], item["lon"]),
                  iconImage: "$category-icon",
                  iconSize: 3.5,
                ),
              );
              _nearbySymbols.add(symbol);
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Không thể lấy vị trí: $e")));
          }
        },
      ),
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
                builder: (_) =>
                    DirectionRouteDialog(mapController: mapController),
              );
              if (result == null) return;

              final from = result["from"] as LatLng;
              final to = result["to"] as LatLng;
              final waypoints =
                  (result["waypoints"] as List?)?.cast<LatLng>() ?? [];
              final vehicle = result['vehicle'] ?? 'car';

              if (!_styleLoaded) {
                await Future.delayed(const Duration(milliseconds: 300));
              }

              // Clear old markers/routes
              await MapHelper.clearMarkers(mapController);

              if (waypoints.isEmpty) {
                // ========== 1️⃣ Single-direction ==========
                final directionResult = await MapHelper.fetchDirection(
                  startLat: from.latitude,
                  startLng: from.longitude,
                  endLat: to.latitude,
                  endLng: to.longitude,
                  vehicle: vehicle,
                );

                final routes = directionResult["data"]["routes"];
                if (routes.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Không tìm thấy tuyến đường")),
                  );
                  return;
                }

                setState(() {
                  _routes = routes.cast<Map<String, dynamic>>();
                  _selectedRouteIndex = 0;
                  final legData = routes[0]["legs"][0];
                  _routeDistance = legData["distance"]["text"];
                  _routeDuration = legData["duration"]["text"];
                  _routeSteps = legData["steps"];
                });

                final startLocation = LatLng(
                  routes[0]["legs"][0]["start_location"]["lat"],
                  routes[0]["legs"][0]["start_location"]["lng"],
                );
                final endLocation = LatLng(
                  routes[0]["legs"][0]["end_location"]["lat"],
                  routes[0]["legs"][0]["end_location"]["lng"],
                );

                await MapHelper.drawRoutesOnMap(mapController, routes);
                await MapHelper.addStartEndMarker(
                  mapController,
                  startLocation,
                  iconAssetPath: "assets/images/start-position-marker.png",
                  imageId: "startIcon",
                );
                await MapHelper.addStartEndMarker(
                  mapController,
                  endLocation,
                  iconAssetPath: "assets/images/end-position-marker.png",
                  imageId: "endIcon",
                );
                if (to.latitude != endLocation.latitude ||
                    to.longitude != endLocation.longitude) {
                  await MapHelper.drawDashedLine(
                    controller:
                        mapController, // Giả định mapController là MapLibreMapController
                    from: endLocation,
                    to: to,
                    color: "#A9A9A9", // Màu đỏ (đã chuyển sang hex)
                    lineWidth: 3.0,
                    dashArray: [1.0, 1.0], // Độ dài nét đứt và khoảng trống
                  );
                  // Vẽ marker cho điểm to (điểm đến thực sự)
                  await MapHelper.addStartEndMarker(
                    mapController,
                    to,
                    iconAssetPath: "assets/images/end-position-marker.png",
                    imageId: "realDestIcon",
                  );
                }
              } else {
                Map<String, dynamic> directionResult;
                // ========== 2️⃣ Multi-direction ==========
                directionResult = await MapHelper.fetchMultiDirection(
                  controller: mapController,
                  start: from,
                  end: to,
                  waypoints: waypoints,
                  vehicle: vehicle,
                );

                final routes = directionResult["data"]["routes"] ?? [];
                if (routes.isEmpty) return;

                setState(() {
                  _routes = routes.cast<Map<String, dynamic>>();
                  _isMultiRoute = waypoints.isNotEmpty;
                });

                // Lấy toàn bộ legs
                final legs = routes[0]["legs"].cast<Map<String, dynamic>>();

                // START = start_location của leg đầu tiên
                final startLocation = LatLng(
                  legs.first["start_location"]["lat"],
                  legs.first["start_location"]["lng"],
                );

                // END = end_location của leg cuối cùng
                final endLocation = LatLng(
                  legs.last["end_location"]["lat"],
                  legs.last["end_location"]["lng"],
                );

                // Clear markers cũ
                await MapHelper.clearMarkers(mapController);

                // Vẽ route
                await MapHelper.drawRoutesOnMap(mapController, routes);

                // START marker
                await MapHelper.addStartEndMarker(
                  mapController,
                  startLocation,
                  iconAssetPath: "assets/images/start-position-marker.png",
                  imageId: "startIcon",
                );

                // END marker
                await MapHelper.addStartEndMarker(
                  mapController,
                  endLocation,
                  iconAssetPath: "assets/images/end-position-marker.png",
                  imageId: "endIcon",
                );
                if (to.latitude != endLocation.latitude ||
                    to.longitude != endLocation.longitude) {
                  await MapHelper.drawDashedLine(
                    controller:
                        mapController, // Giả định mapController là MapLibreMapController
                    from: endLocation,
                    to: to,
                    color: "#A9A9A9", // Màu đỏ (đã chuyển sang hex)
                    lineWidth: 3.0,
                    dashArray: [1.0, 1.0], // Độ dài nét đứt và khoảng trống
                  );
                  await MapHelper.addStartEndMarker(
                    mapController,
                    to,
                    iconAssetPath: "assets/images/end-position-marker.png",
                    imageId: "realDestIcon",
                  );
                }
                if (waypoints.isNotEmpty) {
                  int index = 1;
                  for (final w in waypoints) {
                    await MapHelper.addStartEndMarker(
                      mapController,
                      w,
                      iconAssetPath:
                          "assets/images/position-waypoint-marker.png",
                      imageId: "waypoint_$index",
                    );
                    index++;
                  }
                }
                // TÍNH TOÁN TỔNG DISTANCE + DURATION + STEPS CHO TOÀN ROUTE
                List allSteps = [];
                for (final leg in legs) {
                  if (leg["steps"] != null) {
                    allSteps.addAll(leg["steps"]);
                  }
                }

                final int sumMeters =
                    (directionResult["totalDistance"] ?? 0) as int;
                final int sumSeconds =
                    (directionResult["totalDuration"] ?? 0) as int;

                debugPrint("UI UPDATE - SUM METERS: $sumMeters");
                debugPrint("UI UPDATE - SUM SECONDS: $sumSeconds");

                String formatDistance(int m) =>
                    m >= 1000 ? "${(m / 1000).toStringAsFixed(1)} km" : "$m m";

                String formatDuration(int s) {
                  final h = s ~/ 3600;
                  final m = (s % 3600) ~/ 60;
                  if (h > 0) return "$h giờ $m phút";
                  return "$m phút";
                }

                setState(() {
                  _routeDistance = formatDistance(sumMeters);
                  _routeDuration = formatDuration(sumSeconds);
                  _routeSteps = allSteps;
                });

                return; // NHỚ return để không rơi xuống case thường
              }
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
          if (_routeDistance != null && _routeDuration != null)
            DraggableScrollableSheet(
              initialChildSize: 0.12,
              minChildSize: 0.12,
              maxChildSize: 0.22,
              builder: (context, scrollController) {
                return Stack(
                  children: [
                    // --- NỘI DUNG CHÍNH ---
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // --- Thanh kéo ---
                            Container(
                              height: 4,
                              width: 40,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[400],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),

                            // --- Thông tin route ---
                            if (_routes.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _isMultiRoute
                                    ? _buildMultiRouteInfo()
                                    : RoutesSelector(
                                  routes: _routes,
                                  selectedIndex: _selectedRouteIndex,
                                  onSelect: _selectRoute,
                                ),
                              ),

                            const SizedBox(height: 16),

                            // --- Nút thao tác ---
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    _showStepsDialog(context, _routeSteps!);
                                  },
                                  icon: const Icon(Icons.directions),
                                  label: const Text("Xem chi tiết"),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final text =
                                        "Tuyến đường dài $_routeDistance, thời gian di chuyển $_routeDuration.";
                                    Share.share(text);
                                  },
                                  icon: const Icon(Icons.share),
                                  label: const Text("Chia sẻ"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Nút X ĐÓNG SHEET ---
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            // chỉ ẩn sheet, không đóng trang
                            setState(() {
                              _routeDistance = null;
                              _routeDuration = null;
                            });
                            // xóa tuyến đường trên bản đồ
                            MapHelper.clearRouteLayers(mapController);
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.black54,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          Positioned(
            top: 60, // Đặt dưới search box (tùy chỉnh theo UI)
            left: 0,
            right: 0,
            child: SizedBox(
              height: 50,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryChip(
                    "Restaurant",
                    Icons.restaurant,
                    "restaurant",
                  ),
                  _buildCategoryChip("Hotel", Icons.hotel, "hotel"),
                  _buildCategoryChip(
                    "Fuel",
                    Icons.local_gas_station,
                    "gas_station",
                  ),
                  _buildCategoryChip("Health", Icons.local_hospital, "health"),
                  _buildCategoryChip("Education", Icons.school, "education"),
                  _buildCategoryChip(
                    "Pharmacy",
                    Icons.local_pharmacy,
                    "pharmacy",
                  ),
                ],
              ),
            ),
          ),
          // --- Search box + suggestions ---
          Positioned(
            top: 5,
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
          if (_showNearbySheet)
            Align(
              alignment: Alignment.bottomCenter,
              child: DraggableScrollableSheet(
                minChildSize: 0.25,
                maxChildSize: 0.6,
                initialChildSize: 0.25,
                builder: (context, scrollController) {
                  return Stack(
                    children: [
                      // Nội dung danh sách
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18),
                          ),
                        ),
                        child: ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.only(
                            top: 30,
                          ), // chừa chỗ cho nút X
                          itemCount: _nearbyResults.length,
                          itemBuilder: (_, index) {
                            final item = _nearbyResults[index];

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withAlpha(
                                    (0.1 * 255).toInt(),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.place,
                                  color: Colors.blue,
                                ),
                              ),
                              title: Text(
                                item["name"],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                item["address"],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black54),
                              ),
                              onTap: () {
                                final id = item["id"];
                                // Đóng sheet
                                setState(() {
                                  _showNearbySheet = false;
                                });
                                // Gọi hàm tìm kiếm sau khi sheet đóng
                                Future.delayed(
                                  const Duration(milliseconds: 80),
                                  () {
                                    _searchLocation(id);
                                  },
                                );
                              },
                            );
                          },
                          separatorBuilder: (_, __) => const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Divider(height: 1, color: Colors.black12),
                          ),
                        ),
                      ),

                      // Nút X đóng sheet
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              setState(() {
                                _showNearbySheet = false;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.close_rounded,
                                color: Colors.black54,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
