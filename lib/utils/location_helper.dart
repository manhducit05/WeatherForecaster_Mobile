import 'package:geolocator/geolocator.dart';

class LocationHelper {
  // Hàm xin quyền và trả về vị trí hiện tại
  static Future<Position> determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Dịch vụ vị trí chưa bật.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Người dùng từ chối quyền vị trí.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Quyền vị trí bị từ chối vĩnh viễn. Hãy cấp quyền trong cài đặt.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
