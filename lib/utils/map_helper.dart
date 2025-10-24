import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'polyline_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapHelper {
  static Future<List<LatLng>> fetchDirection({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String vehicle,
  }) async {
    final apiKey = dotenv.env['API_KEY_ROUTES'];
    final url = Uri.parse(
        "https://mapapis.openmap.vn/v1/direction?"
            "origin=$startLat,$startLng&destination=$endLat,$endLng"
            "&vehicle=$vehicle&apikey=$apiKey");

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception("Lỗi gọi API: ${res.statusCode}");
    }

    final data = json.decode(res.body);

    if (data["routes"] == null || data["routes"].isEmpty) {
      throw Exception("Không có route trả về");
    }

    final overview = data["routes"][0]["overview_polyline"]["points"];
    final routePoints = decodePolyline(overview);

    print("Đã decode ${routePoints.length} điểm từ polyline");
    return routePoints;
  }

  static Future<void> drawRouteOnMap(
      MapLibreMapController controller, List<LatLng> points) async {
    if (points.isEmpty) {
      print("Không có điểm nào để vẽ");
      return;
    }

    try {
      // 🔹 Xóa layer và source cũ nếu tồn tại
      try {
        await controller.removeLayer("route-line");
      } catch (_) {}
      try {
        await controller.removeSource("route-source");
      } catch (_) {}

      // 🔹 Chuẩn hóa GeoJSON (chuẩn RFC 7946)
      final geoJson = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "geometry": {
              "type": "LineString",
              "coordinates": points
                  .map((p) => [p.longitude, p.latitude])
                  .toList(),
            },
            "properties": {},
          }
        ],
      };

      // Đợi style map sẵn sàng hoàn toàn
      await Future.delayed(const Duration(milliseconds: 300));

      await controller.addSource(
        "route-source",
        GeojsonSourceProperties(
          data: geoJson,
          lineMetrics: true, // 🔹 hữu ích khi muốn animate hoặc gradient
        ),
      );

      await controller.addLineLayer(
        "route-source",
        "route-line",
        const LineLayerProperties(
          lineColor: "#ff0000",
          lineWidth: 5.0,
          lineOpacity: 0.9,
          lineJoin: "round",
          lineCap: "round",
        ),
      );

      print("Route layer added!");

      // 🔹 Di chuyển camera bao trùm toàn tuyến
      final bounds = _getBounds(points);
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 60,
          right: 60,
          top: 100,
          bottom: 100,
        ),
      );

      print("Camera moved to route bounds");
    } catch (e, st) {
      print("Lỗi khi vẽ route: $e\n$st");
    }
  }

  static LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
