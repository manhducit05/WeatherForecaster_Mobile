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

    // defensive: ensure routes exists
    if (data == null || data["routes"] == null || (data["routes"] as List).isEmpty) {
      throw Exception("Không có route trả về");
    }

    return {"data": data};
  }

  // ==========================================================
  //  2. Vẽ nhiều tuyến đường + tự zoom camera (sửa an toàn)
  // ==========================================================
  static Future<void> drawRoutesOnMap(
      BuildContext context,
      MapLibreMapController controller,
      List<dynamic> routes, {
        double cameraPadding = 80.0,
      }) async {
    if (routes.isEmpty) {
      debugPrint("Không có route nào để vẽ");
      return;
    }

    try {
      // ---- remove previously added per-route layers/sources safely ----
      for (int i = 0; i < 10; i++) {
        // try some reasonable previous ids in case existing ones used different counts
        try {
          await controller.removeLayer("route-line-$i");
        } catch (_) {}
        try {
          await controller.removeSource("route-source-$i");
        } catch (_) {}
      }
      // Also try generic ids used before
      try {
        await controller.removeLayer("route-line");
      } catch (_) {}
      try {
        await controller.removeSource("route-source");
      } catch (_) {}

      List<LatLng> allPoints = [];

      // Vẽ từng tuyến, tạo source/layer riêng cho mỗi tuyến
      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];

        // lấy chuỗi polyline an toàn:
        String? polylineEncoded;
        // Google-style: overview_polyline.points
        if (route != null && route["overview_polyline"] != null && route["overview_polyline"]["points"] != null) {
          polylineEncoded = route["overview_polyline"]["points"]?.toString();
        }
        // Or OSRM-like: geometry (encoded polyline), or maybe route["geometry"]
        else if (route != null && route["geometry"] != null && route["geometry"] is String) {
          polylineEncoded = route["geometry"] as String;
        }

        List<LatLng> points = [];

        // If API already returned coordinates array (GeoJSON-like), handle it:
        if (route != null && route["geometry"] is Map && route["geometry"]["coordinates"] is List) {
          try {
            final coords = route["geometry"]["coordinates"] as List;
            for (final c in coords) {
              if (c is List && c.length >= 2) {
                final lon = (c[0] as num).toDouble();
                final lat = (c[1] as num).toDouble();
                points.add(LatLng(lat, lon));
              }
            }
          } catch (e) {
            debugPrint("Error parsing geometry.coordinates for route $i: $e");
          }
        } else if (polylineEncoded != null && polylineEncoded.isNotEmpty) {
          // decode polyline string
          try {
            points = decodePolyline(polylineEncoded);
          } catch (e) {
            debugPrint("decodePolyline failed for route $i: $e");
            points = [];
          }
        } else {
          debugPrint("Route $i has no geometry/polyline -> skipping");
          continue; // skip this route if no geometry
        }

        if (points.isEmpty) {
          debugPrint("Route $i decode result empty -> skipping");
          continue;
        }

        allPoints.addAll(points);

        final color = (i == 0) ? "#007AFF" : (i == 1) ? "#FF9500" : "#FF3B30";

        // Build a valid GeoJSON Feature for this single route
        final feature = {
          "type": "Feature",
          "properties": {
            "route_index": i,
            "color": color,
          },
          "geometry": {
            "type": "LineString",
            "coordinates": points.map((p) => [p.longitude, p.latitude]).toList(),
          },
        };

        // Add a GeoJSON source for this route
        final sourceId = "route-source-$i";
        final layerId = "route-line-$i";

        await controller.addSource(
          sourceId,
          GeojsonSourceProperties(data: {
            "type": "FeatureCollection",
            "features": [feature],
          }),
        );

        // Add line layer for this route
        await controller.addLineLayer(
          sourceId,
          layerId,
          LineLayerProperties(
            lineColor: color,
            lineWidth: i == 0 ? 8.0 : 5.0,
            lineOpacity: i == 0 ? 1.0 : 0.4,
            lineJoin: "round",
            lineCap: "round",
          ),
        );
      }

      if (allPoints.isEmpty) {
        debugPrint("No drawable points found after parsing all routes");
        return;
      }

      // compute bounds defensively
      final bounds = _getBounds(allPoints);
      if (bounds != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            bounds,
            left: cameraPadding,
            right: cameraPadding,
            top: cameraPadding,
            bottom: cameraPadding,
          ),
        );
      } else {
        debugPrint("Could not compute bounds for routes");
      }

      debugPrint("Vẽ ${routes.length} tuyến đường (có ${allPoints.length} điểm) thành công!");
    } catch (e, st) {
      debugPrint("Lỗi khi vẽ route: $e\n$st");
    }
  }

  // ==========================================================
  //  3. Hàm tính bounds (private) - trả về null nếu ko có điểm
  // ==========================================================
  static LatLngBounds? _getBounds(List<LatLng> points) {
    if (points.isEmpty) return null;

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

    // Add tiny padding if bounds degenerate
    if ((maxLat - minLat).abs() < 1e-6) {
      maxLat += 0.0005;
      minLat -= 0.0005;
    }
    if ((maxLng - minLng).abs() < 1e-6) {
      maxLng += 0.0005;
      minLng -= 0.0005;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // ==========================================================
  //  4. Highlight route
  // ==========================================================
  static Future<void> highlightRoute(
      MapLibreMapController controller,
      int selectedIndex,
      int totalRoutes,
      ) async {
    for (int i = 0; i < totalRoutes; i++) {
      final isSelected = (i == selectedIndex);

      try {
        await controller.setLayerProperties(
          "route-line-$i",
          LineLayerProperties(
            lineWidth: isSelected ? 8.0 : 5.0,
            lineOpacity: isSelected ? 1.0 : 0.4,
          ),
        );
      } catch (e) {
        // layer may not exist (skip)
        debugPrint("highlightRoute: cannot set props for route-line-$i: $e");
      }
    }
  }
}
