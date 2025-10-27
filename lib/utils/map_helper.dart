import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'polyline_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapHelper {
  static Future<Map<String, dynamic>> fetchDirection({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String vehicle,
  }) async {
    final apiKey = dotenv.env['API_KEY_ROUTES'];
    final url = Uri.parse(
      "https://mapapis.openmap.vn/v1/direction?origin=$startLat,$startLng&destination=$endLat,$endLng&vehicle=$vehicle&apikey=$apiKey",
    );

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

    return {
      "points": routePoints,
      "data": data, // 👈 trả luôn toàn bộ JSON gốc
    };
  }

  static Future<void> drawRouteOnMap(
    BuildContext context,
    MapLibreMapController controller,
    List<LatLng> points,
    Map<String, dynamic> routeData,
  ) async {
    if (points.isEmpty) {
      debugPrint("Không có điểm nào để vẽ");
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

      // 🔹 Chuẩn hóa GeoJSON
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
          },
        ],
      };

      // Đợi style map sẵn sàng hoàn toàn
      await Future.delayed(const Duration(milliseconds: 300));

      await controller.addSource(
        "route-source",
        GeojsonSourceProperties(data: geoJson, lineMetrics: true),
      );

      await controller.addLineLayer(
        "route-source",
        "route-line",
        const LineLayerProperties(
          lineColor: "#0080FF",
          lineWidth: 6.0,
          lineOpacity: 0.9,
          lineJoin: "round",
          lineCap: "round",
        ),
      );

      // 🔹 Di chuyển camera
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

      debugPrint("Route layer added!");
    } catch (e, st) {
      debugPrint("Lỗi khi vẽ route: $e\n$st");
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
