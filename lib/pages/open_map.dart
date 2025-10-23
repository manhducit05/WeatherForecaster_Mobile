import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/location_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../utils/storage_helper.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../widgets/direction_route_dialog_widget.dart';

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
      final placeId = symbol.data?["placeId"]; // lấy lại id đã lưu
      _showMarkerMenu(symbol, placeId: placeId);
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
            ListTile(
              leading: const Icon(Icons.directions),
              title: const Text("Get Directions to here"),
              onTap: () async {
                Navigator.pop(ctx);

                final dest = LatLng(
                  symbol.options.geometry!.latitude,
                  symbol.options.geometry!.longitude,
                );

                // Lấy tên địa điểm từ marker (textField)
                final destName = symbol.options.textField ?? "Địa điểm đã chọn";

                final result = await showDialog(
                  context: context,
                  builder: (_) => DirectionRouteDialog(
                    defaultDestination: dest,
                    defaultDestinationName: destName,
                  ),
                );

                if (result != null) {
                  final from = result['from'];
                  final to = result['to'];

                  debugPrint("From: ${from.latitude}, ${from.longitude}");
                  debugPrint("To: ${to.latitude}, ${to.longitude}");

                }
              },
            ),
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

          // Khi tạo marker, lưu luôn placeId vào symbol.data
          _currentSymbol = await mapController.addSymbol(
            SymbolOptions(
              geometry: target,
              iconImage: "custom-marker",
              textField: name,
              textOffset: const Offset(0, 1.5),
            ),
            {'placeId': placeId}, // <--- gán thêm metadata tại đây
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
                      onPressed: () => Navigator.pop(ctx),
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
              // Mở hộp thoại nhập điểm xuất phát và điểm đến
              final result = await showDialog(
                context: context,
                builder: (_) => const DirectionRouteDialog(),
              );
              // Khi người dùng nhấn “Xác nhận”
              if (result != null) {
                final from = result["from"];
                final to = result["to"];
                debugPrint("From: $from | To: $to");

                // TODO: sau này xử lý phần vẽ đường ở đây
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
