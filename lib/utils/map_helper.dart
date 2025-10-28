import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'polyline_decoder.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapHelper {
  // ==========================================================
  //  1. Fetch routes (lấy nhiều tuyến đường)
  // ==========================================================
  static Future<Map<String, dynamic>> fetchDirection({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required String vehicle,
  }) async {
    final apiKey = dotenv.env['API_KEY_ROUTES'];
    final url = Uri.parse(
      "https://mapapis.openmap.vn/v1/direction?origin=$startLat,$startLng&destination=$endLat,$endLng&vehicle=$vehicle&alternatives=true&apikey=$apiKey",
    );

    final res = await http.get(url);

    if (res.statusCode != 200) {
      throw Exception("Lỗi gọi API: ${res.statusCode}");
    }

    final data = json.decode(res.body);

    if (data["routes"] == null || data["routes"].isEmpty) {
      throw Exception("Không có route trả về");
    }

    return {
      "data": data,
    };
  }

  // ==========================================================
  //  2. Vẽ nhiều tuyến đường + tự zoom camera
  // ==========================================================
  static Future<void> drawRoutesOnMap(
      BuildContext context,
      MapLibreMapController controller,
      List<dynamic> routes,
      ) async {
    if (routes.isEmpty) {
      debugPrint("Không có route nào để vẽ");
      return;
    }

    try {
      // Xóa source/layer cũ nếu có
      try {
        await controller.removeLayer("route-line");
      } catch (_) {}
      try {
        await controller.removeSource("route-source");
      } catch (_) {}

      List<LatLng> allPoints = [];
      List<Map<String, dynamic>> features = [];

      //  Vẽ từng tuyến
      for (int i = 0; i < routes.length; i++) {
        final overview = routes[i]["overview_polyline"]["points"];
        final points = decodePolyline(overview);
        allPoints.addAll(points);

        // Màu tuyến
        final color = switch (i) {
          0 => "#007AFF", // xanh dương – tuyến ngắn nhất
          1 => "#FF9500", // cam
          _ => "#FF3B30", // đỏ cho tuyến dài hơn
        };

        features.add({
          "type": "Feature",
          "geometry": {
            "type": "LineString",
            "coordinates":
            points.map((p) => [p.longitude, p.latitude]).toList(),
          },
          "properties": {"color": color},
        });
      }

      //  Tạo GeoJSON
      final geoJson = {
        "type": "FeatureCollection",
        "features": features,
      };

      //  Thêm source và layer
      await controller.addSource(
        "route-source",
        GeojsonSourceProperties(data: geoJson, lineMetrics: true),
      );

      await controller.addLineLayer(
        "route-source",
        "route-line",
        const LineLayerProperties(
          lineColor: ["get", "color"],
          lineWidth: 6.0,
          lineOpacity: 0.9,
          lineJoin: "round",
          lineCap: "round",
        ),
      );

      //  Tính bounds bao phủ toàn bộ route
      final bounds = _getBounds(allPoints);
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 60,
          right: 60,
          top: 100,
          bottom: 100,
        ),
      );

      debugPrint("Vẽ ${routes.length} tuyến đường thành công!");
    } catch (e, st) {
      debugPrint("Lỗi khi vẽ route: $e\n$st");
    }
  }

  // ==========================================================
  //  3. Hàm tính bounds (private)
  // ==========================================================
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
