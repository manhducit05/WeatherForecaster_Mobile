import 'package:geolocator/geolocator.dart';

class LocationHelper {
  // Hàm xin quyền và trả về vị trí hiện tại
  static Future<Position> determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location service is not enabled.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('The user denied location permission.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission was permanently denied. Please grant permission in settings.',
      );
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    );
  }
}
