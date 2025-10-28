import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../utils/map_helper.dart';

class DirectionRouteDialog extends StatefulWidget {
  final LatLng? defaultDestination;
  final String? defaultDestinationName;

  const DirectionRouteDialog({
    super.key,
    this.defaultDestination,
    this.defaultDestinationName,
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

  @override
  void initState() {
    super.initState();
    if (widget.defaultDestination != null) {
      _toLatLng = widget.defaultDestination;
      _toController.text = widget.defaultDestinationName ?? "Địa điểm đã chọn";
    }
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
                    } else {
                      showToSuggestions = false;
                    }
                  }),
                )
              : null,
        ),
        onChanged: (val) {
          setState(() {
            if (isFrom) {
              showFromSuggestions = val.trim().isNotEmpty;
            } else {
              showToSuggestions = val.trim().isNotEmpty;
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
              Stack(
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
                    right: 8,
                    child: IconButton(
                      onPressed: swapLocations,
                      icon: const Icon(Icons.swap_vert, color: Colors.teal),
                    ),
                  ),
                ],
              ),

              if (showFromSuggestions)
                _buildSuggestionList(_fromController.text.trim(), true),
              if (showToSuggestions)
                _buildSuggestionList(_toController.text.trim(), false),

              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_location_alt, color: Colors.teal),
                label: const Text(
                  "Thêm điểm đến",
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              const SizedBox(height: 16),
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
                  // 🔹 Thêm log trước khi gọi API
                  debugPrint(
                    "Fetching direction from (${_fromLatLng!.latitude},"
                    " ${_fromLatLng!.longitude}) "
                    "to (${_toLatLng!.latitude}, ${_toLatLng!.longitude})"
                    " | vehicle: $vehicle",
                  );
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
                  // Trả kết quả về cho OpenMapPage để vẽ route
                  Navigator.pop(context, {
                    "points": points,
                    "from": _fromLatLng,
                    "to": _toLatLng,
                    "vehicle": vehicle,
                  });
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
