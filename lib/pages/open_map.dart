import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';

class CurrentLocationMapLibre extends StatefulWidget {
  const CurrentLocationMapLibre({super.key});

  @override
  State<CurrentLocationMapLibre> createState() => _CurrentLocationMapLibreState();
}

class _CurrentLocationMapLibreState extends State<CurrentLocationMapLibre> {
  MaplibreMapController? mapController;
  LatLng? _currentLatLng;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
      });

      // Di chuyển camera tới vị trí hiện tại
      if (mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLng(
          LatLng(pos.latitude, pos.longitude),
        ));
      }
    } catch (e) {
      debugPrint("Lỗi lấy vị trí: $e");
    }
  }

  void _onMapCreated(MaplibreMapController controller) {
    mapController = controller;

    // Nếu vị trí đã lấy xong, di chuyển camera
    if (_currentLatLng != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(_currentLatLng!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("MapLibre VN - Vị trí hiện tại")),
      body: _currentLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : MaplibreMap(
        styleString: "https://tiles.openmap.vn/styles/day-v1/style.json",
        initialCameraPosition: CameraPosition(
          target: _currentLatLng!,
          zoom: 15,
        ),
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        // myLocationRenderMode: MyLocationRenderMode.GPS,
        minMaxZoomPreference: const MinMaxZoomPreference(4, 18),
      ),
    );
  }
}
