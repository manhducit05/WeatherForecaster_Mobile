import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../utils/map_helper.dart';
import '../utils/location_helper.dart';

class DirectionRouteDialog extends StatefulWidget {
  final LatLng? defaultDestination;
  final String? defaultDestinationName;
  final MapLibreMapController mapController;

  const DirectionRouteDialog({
    super.key,
    this.defaultDestination,
    this.defaultDestinationName,
    required this.mapController,
  });

  @override
  State<DirectionRouteDialog> createState() => _DirectionRouteDialogState();
}

class _DirectionRouteDialogState extends State<DirectionRouteDialog> {
  int selectedMode = 0; // 0: car, 1: motorbike, 2: walk

  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();

  bool showFromSuggestions = false;
  bool showToSuggestions = false;
  LatLng? _fromLatLng;
  LatLng? _toLatLng;
  bool isLoadingRoute = false;

  // quản lý đa điểm đến
  bool hasMultipleDestinations = false;

  List<TextEditingController> waypointControllers = [];
  List<LatLng?> waypointLatLngs = [];
  List<bool> waypointSuggestionVisibility = [];

  @override
  void initState() {
    super.initState();
    if (widget.defaultDestination != null) {
      _toLatLng = widget.defaultDestination;
      _toController.text = widget.defaultDestinationName ?? "Địa điểm đã chọn";
    }
  }

  // thêm nhiều điểm đến
  void addWaypoint() {
    setState(() {
      waypointControllers.add(TextEditingController());
      waypointLatLngs.add(null);
      waypointSuggestionVisibility.add(false);

      hasMultipleDestinations = true; // ĐÁNH DẤU LÀ ĐANG CHẠY MULTI
    });
  }

  Widget _buildWaypointSuggestionList(String query, int index) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchSuggestions(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final suggestions = snapshot.data!;
        return Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
          ),
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (ctx, idx) {
              final s = suggestions[idx];
              return ListTile(
                leading: const Icon(Icons.place, color: Colors.teal),
                title: Text(s["name"]),
                subtitle: Text(s["label"]),
                onTap: () async {
                  final latlng = await _fetchPlaceLatLng(s["id"]);
                  if (latlng == null) return;

                  setState(() {
                    waypointControllers[index].text = s["name"];
                    waypointLatLngs[index] = latlng;
                    waypointSuggestionVisibility[index] = false;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<String?> _reverseGeocode(double lat, double lon) async {
    final apiKey = dotenv.env['API_KEY'];
    final url =
        "https://mapapis.openmap.vn/v1/place/reverse?lat=$lat&lng=$lon&apiKey=$apiKey";

    final res = await http.get(Uri.parse(url));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final features = data["features"] as List?;
      if (features != null && features.isNotEmpty) {
        final props = features.first["properties"];
        return props?["name"] ?? props?["label"];
      }
    }

    return null;
  }

  Future<List<Map<String, dynamic>>> fetchSuggestions(String query) async {
    final apiKey = dotenv.env['API_KEY'];
    final url =
        "https://mapapis.openmap.vn/v1/place/autocomplete?text=$query&apiKey=$apiKey";
    final res = await http.get(Uri.parse(url));

    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final features = data["features"] as List?;
      if (features == null) return [];
      return features.map<Map<String, dynamic>>((item) {
        final props = item["properties"] ?? {};
        return {
          "id": props["id"] ?? "",
          "name": props["name"] ?? "",
          "label": props["label"] ?? "",
        };
      }).toList();
    }
    return [];
  }

  // đảo ngược điểm đến và điểm đi
  void swapLocations() {
    final temp = _fromController.text;
    _fromController.text = _toController.text;
    _toController.text = temp;
  }

  Widget _buildTransportTabs() {
    final tabs = [
      {"icon": Icons.directions_car, "label": "Ô tô"},
      {"icon": Icons.motorcycle, "label": "Xe máy"},
      {"icon": Icons.directions_walk, "label": "Đi bộ"},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(tabs.length, (i) {
        final tab = tabs[i];
        final isSelected = i == selectedMode;
        return GestureDetector(
          onTap: () => setState(() => selectedMode = i),
          child: Column(
            children: [
              Icon(
                tab["icon"] as IconData,
                color: isSelected ? Colors.teal : Colors.grey,
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                tab["label"] as String,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.teal : Colors.grey,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildInputBox({
    required String hint,
    required TextEditingController controller,
    required bool isFrom,
    int? waypointIndex, // thêm tham số mới
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(
            isFrom ? Icons.circle_outlined : Icons.location_on,
            color: isFrom ? Colors.green : Colors.red,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Colors.grey),
            onPressed: () => setState(() {
              controller.clear();
              if (isFrom) {
                showFromSuggestions = false;
              } else if (!isFrom && waypointIndex == null) {
                showToSuggestions = false;
              } else if (waypointIndex != null) {
                waypointSuggestionVisibility[waypointIndex] = false;
              }
            }),
          )
              : null,
        ),

        onChanged: (val) {
          setState(() {
            if (isFrom) {
              showFromSuggestions = val.trim().isNotEmpty;
            } else if (!isFrom && waypointIndex == null) {
              showToSuggestions = val.trim().isNotEmpty;
            } else if (waypointIndex != null) {
              waypointSuggestionVisibility[waypointIndex] = val
                  .trim()
                  .isNotEmpty;
            }
          });
        },
      ),
    );
  }

  Widget _buildSuggestionList(String query, bool isFrom) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: fetchSuggestions(query),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final suggestions = snapshot.data!;
        return Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
          ),
          constraints: const BoxConstraints(maxHeight: 220),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (ctx, index) {
              final s = suggestions[index];
              return ListTile(
                leading: const Icon(Icons.place, color: Colors.teal),
                title: Text(s["name"]),
                subtitle: Text(s["label"]),
                onTap: () async {
                  final LatLng? latlng = await _fetchPlaceLatLng(s["id"]);
                  if (latlng == null) return;

                  setState(() {
                    if (isFrom) {
                      _fromController.text = s["name"];
                      _fromLatLng = latlng;
                      showFromSuggestions = false;
                    } else {
                      _toController.text = s["name"];
                      _toLatLng = latlng;
                      showToSuggestions = false;
                    }
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<LatLng?> _fetchPlaceLatLng(String placeId) async {
    try {
      final apiKey = dotenv.env['API_KEY'];
      final url =
          "https://mapapis.openmap.vn/v1/place?ids=$placeId&apiKey=$apiKey";
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final features = data["features"] as List?;
        if (features != null && features.isNotEmpty) {
          final geometry = features.first["geometry"];
          if (geometry != null && geometry["coordinates"] != null) {
            final coords = geometry["coordinates"] as List;
            // [lon, lat]
            return LatLng(coords[1].toDouble(), coords[0].toDouble());
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching place lat/lon: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTransportTabs(),
              const SizedBox(height: 16),

              /// BOX NHẬP + NÚT ĐẢO VỊ TRÍ
              SizedBox(
                height: 120,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    Column(
                      children: [
                        _buildInputBox(
                          hint: "Nhập điểm xuất phát...",
                          controller: _fromController,
                          isFrom: true,
                        ),
                        const SizedBox(height: 12),
                        _buildInputBox(
                          hint: "Nhập điểm đến...",
                          controller: _toController,
                          isFrom: false,
                        ),

                      ],
                    ),
                    Positioned(
                      right: 24,
                      child: IconButton(
                        onPressed: swapLocations,
                        icon: const Icon(Icons.swap_vert, color: Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: List.generate(waypointControllers.length, (
                    index,
                    ) {
                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildInputBox(
                        hint: "Nhập điểm đến ${index + 2}...",
                        controller: waypointControllers[index],
                        isFrom: false,
                        waypointIndex:
                        index, // quản lý riêng biệt ừng ô theo index
                      ),

                      if (waypointSuggestionVisibility[index])
                        _buildWaypointSuggestionList(
                          waypointControllers[index].text.trim(),
                          index,
                        ),
                    ],
                  );
                }),
              ),
              //  NÚT LẤY VỊ TRÍ CỦA TÔI
              TextButton.icon(
                onPressed: () async {
                  try {
                    final pos = await LocationHelper.determinePosition();
                    final lat = pos.latitude;
                    final lon = pos.longitude;

                    debugPrint("📍 My location: $lat, $lon");

                    final name = await _reverseGeocode(lat, lon);

                    setState(() {
                      _fromLatLng = LatLng(lat, lon);
                      _fromController.text = name ?? "Vị trí của tôi";
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Không thể lấy vị trí: $e")),
                    );
                  }
                },
                icon: const Icon(Icons.my_location, color: Colors.blue),
                label: const Text(
                  "Lấy vị trí của tôi",
                  style: TextStyle(color: Colors.blue),
                ),
              ),

              if (showFromSuggestions)
                _buildSuggestionList(_fromController.text.trim(), true),
              if (showToSuggestions)
                _buildSuggestionList(_toController.text.trim(), false),

              TextButton.icon(
                onPressed: addWaypoint,
                icon: const Icon(Icons.add_location_alt, color: Colors.teal),
                label: const Text(
                  "Thêm điểm đến",
                  style: TextStyle(color: Colors.teal),
                ),
              ),

              const SizedBox(height: 20),

              /// NÚT TÌM ĐƯỜNG
              ElevatedButton.icon(
                onPressed: () async {
                  if (_fromLatLng == null || _toLatLng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Vui lòng chọn đủ điểm xuất phát và điểm đến",
                        ),
                      ),
                    );
                    return;
                  }

                  setState(() => isLoadingRoute = true);

                  final vehicle = selectedMode == 0
                      ? "car"
                      : selectedMode == 1
                      ? "motor"
                      : "walking";

                  // 1. Gộp TẤT CẢ các điểm dừng (điểm đến chính và các waypoint phụ) theo thứ tự nhập
                  final List<LatLng> allDestinations = [];

                  // Thêm điểm đến đầu tiên (từ _toLatLng - ô nhập thứ 2 trên UI)
                  if (_toLatLng != null) {
                    allDestinations.add(_toLatLng!);
                  }

                  // Thêm các điểm waypoint phụ (từ waypointLatLngs - các ô nhập tiếp theo)
                  allDestinations.addAll(waypointLatLngs.whereType<LatLng>());

                  // 2. Xác định điểm kết thúc cuối cùng (End) và các Waypoint trung gian
                  final bool isMultiDestinationRoute =
                      allDestinations.length > 1;

                  LatLng finalDestination = _toLatLng!;
                  List<LatLng> intermediateWaypoints = [];

                  if (isMultiDestinationRoute) {
                    // Điểm End: là điểm cuối cùng được nhập
                    finalDestination = allDestinations.last;

                    // Waypoints: là TẤT CẢ các điểm còn lại, ngoại trừ điểm cuối cùng (End)
                    intermediateWaypoints = allDestinations.sublist(
                      0,
                      allDestinations.length - 1,
                    );

                    // Ghi đè _toLatLng bằng finalDestination (điểm kết thúc cuối cùng)
                  }

                  try {
                    if (isMultiDestinationRoute) {
                      // 🔹 Multi-direction
                      debugPrint(
                        "➡️ Multi-direction mode (Start -> Waypoints -> End)",
                      );

                      final multiResult = await MapHelper.fetchMultiDirection(
                        context: context,
                        controller: widget.mapController,
                        start: _fromLatLng!, // Start
                        end: finalDestination, // End (điểm cuối cùng nhập)
                        waypoints:
                        intermediateWaypoints, // Waypoints (điểm ở giữa theo thứ tự)
                        vehicle: vehicle,
                      );

                      setState(() => isLoadingRoute = false);

                      if (multiResult["points"] == null ||
                          multiResult["points"].isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Không tìm thấy tuyến đường nhiều điểm",
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context, {
                        "points": multiResult["points"],
                        "from": _fromLatLng,
                        "to": finalDestination, // Trả về End
                        "waypoints": intermediateWaypoints, // Trả về Waypoints
                        "vehicle": vehicle,
                        "data": multiResult["data"],
                      });
                    } else {
                      // 🔹 Single-direction (Chỉ có Start và End ban đầu)
                      debugPrint("➡️ Single-direction mode");

                      final points = await MapHelper.fetchDirection(
                        startLat: _fromLatLng!.latitude,
                        startLng: _fromLatLng!.longitude,
                        endLat: _toLatLng!.latitude,
                        endLng: _toLatLng!.longitude,
                        vehicle: vehicle,
                      );

                      setState(() => isLoadingRoute = false);

                      if (points.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Không tìm thấy tuyến đường"),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context, {
                        "points": points,
                        "from": _fromLatLng,
                        "to": _toLatLng,
                        "waypoints": [],
                        "vehicle": vehicle,
                      });
                    }
                  } catch (e) {
                    setState(() => isLoadingRoute = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Lỗi khi tìm đường: $e")),
                    );
                  }
                },
                icon: const Icon(Icons.alt_route),
                label: isLoadingRoute
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text("Tìm đường"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
