import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:weather_forecaster/utils/location_helper.dart'; // Đường dẫn đúng
import 'package:geocoding/geocoding.dart';


class CurrentLocationOSM extends StatefulWidget {
  const CurrentLocationOSM({super.key});
  @override
  State<CurrentLocationOSM> createState() => _CurrentLocationOSMState();
}

class _CurrentLocationOSMState extends State<CurrentLocationOSM> {
  LatLng? _currentLatLng;
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await LocationHelper.determinePosition();
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
      });
    } catch (e) {
      debugPrint("Lỗi lấy vị trí: $e");
    }
  }
  Future<void> _searchAndGo(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final LatLng target = LatLng(locations.first.latitude, locations.first.longitude);

        debugPrint("Địa điểm tìm thấy: $target");

        _mapController.move(target, 14.0);

        setState(() {
          _currentLatLng = target;
        });
      } else {
        debugPrint("Không tìm thấy địa chỉ nào cho: $address");
      }
    } catch (e) {
      debugPrint("Không tìm thấy địa chỉ: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: "Nhập địa điểm...",
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _searchAndGo,
        ),
      ),
      body: _currentLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLatLng!, // đúng với flutter_map
          initialZoom: 15,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: "com.example.weather_forecaster",
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLatLng!,
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
