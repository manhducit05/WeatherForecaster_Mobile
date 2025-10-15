import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // để search địa chỉ
import '../utils/location_helper.dart';

class OpenMapPage extends StatefulWidget {
  const OpenMapPage({super.key});

  @override
  State<OpenMapPage> createState() => _OpenMapPageState();
}

class _OpenMapPageState extends State<OpenMapPage> {
  late MapLibreMapController mapController;
  final TextEditingController _searchController = TextEditingController();

  // chỉ dùng style OpenMap.vn
  final String mapStyle = "https://tiles.openmap.vn/styles/day-v1/style.json";

  void _onMapCreated(MapLibreMapController controller) {
    mapController = controller;
  }

  // Lấy vị trí hiện tại và di chuyển camera
  Future<void> _goToCurrentLocation() async {
    try {
      Position pos = await LocationHelper.determinePosition();
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(pos.latitude, pos.longitude),
          15.0,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không lấy được vị trí: $e")),
        );
      }
    }
  }

  // Tìm kiếm địa chỉ và di chuyển map
  Future<void> _searchLocation() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        mapController.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(loc.latitude, loc.longitude),
            15.0,
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Không tìm thấy địa điểm")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi tìm kiếm: $e")),
        );
      }
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
            tooltip: "Chuyển đến vị trí hiện tại",
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
                      hintText: "Nhập địa điểm...",
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
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
