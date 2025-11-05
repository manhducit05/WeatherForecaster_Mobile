import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:weather_forecaster/utils/polyline_decoder.dart';

class MapHelper {
  // ==========================================================
  // Fetch single-route (Google-like) - returns data + optional points
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
      "https://mapapis.openmap.vn/v1/direction"
      "?origin=${_numToStr(startLat)},${_numToStr(startLng)}"
      "&destination=${_numToStr(endLat)},${_numToStr(endLng)}"
      "&vehicle=$vehicle&alternatives=true&apikey=$apiKey",
    );

    debugPrint("fetchDirection URL: $url");
    final res = await http.get(url);

    debugPrint("fetchDirection status: ${res.statusCode}");
    if (res.statusCode != 200) {
      throw Exception("Lỗi gọi API: ${res.statusCode}");
    }

    final data = json.decode(res.body);
    if (data == null ||
        data["routes"] == null ||
        (data["routes"] as List).isEmpty) {
      throw Exception("Không có route trả về");
    }

    // try to decode overview_polyline if exists
    List<LatLng> points = [];
    try {
      final overview = data["routes"]?[0]?["overview_polyline"]?["points"];
      if (overview != null && overview is String && overview.isNotEmpty) {
        points = decodePolyline(overview);
        debugPrint("fetchDirection decoded overview points: ${points.length}");
      }
    } catch (e) {
      debugPrint("fetchDirection: decode overview failed: $e");
    }

    return {"data": data, "points": points};
  }

  // ==========================================================
  //  2. Fetch multi-stop route (OpenMap format: destination = end;wp1;wp2;...)
  //     returns merged decoded points + raw data
  // ==========================================================
  static Future<Map<String, dynamic>> fetchMultiDirection({
    required BuildContext context,
    required MapLibreMapController controller,
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
    String vehicle = "car",
  }) async {
    final apiKey = dotenv.env['API_KEY_ROUTES'];

    try {
      final wpStr = waypoints != null && waypoints.isNotEmpty
          ? waypoints.map((w) => "${w.latitude},${w.longitude}").join(";")
          : "";

      final destinationStr = wpStr.isEmpty
          ? "${end.latitude},${end.longitude}"
          : "$wpStr;${end.latitude},${end.longitude}";

      final url = Uri.parse(
        "https://mapapis.openmap.vn/v1/direction"
            "?origin=${start.latitude},${start.longitude}"
            "&destination=$destinationStr"
            "&alternatives=true&vehicle=$vehicle&apikey=$apiKey",
      );

      final res = await http.get(url);

      if (res.statusCode != 200) {
        debugPrint("API ERROR: ${res.statusCode}");
        return {"points": [], "data": {}};
      }

      final data = json.decode(res.body);

      final routes = data["routes"] as List?;
      if (routes == null || routes.isEmpty) {
        debugPrint("routes empty");
        return {"points": [], "data": data};
      }

      final legs = routes[0]["legs"];

      final List<LatLng> mergedPoints = [];
      int totalDistance = 0;
      int totalDuration = 0;

      /// ✅ Loop legs để lấy polyline + cộng tổng
      for (var leg in legs ?? []) {
        // ✅ Cộng tổng distance & duration
        final num dist = leg["distance"]?["value"] ?? 0;
        final num dura = leg["duration"]?["value"] ?? 0;

        totalDistance += dist.toInt();
        totalDuration += dura.toInt();

        // ✅ Lấy polyline
        for (var step in leg["steps"] ?? []) {
          final poly = step["polyline"]?["points"];
          if (poly != null && poly is String && poly.isNotEmpty) {
            mergedPoints.addAll(decodePolyline(poly));
          }
        }
      }

      debugPrint("✅ TOTAL MERGED = ${mergedPoints.length}");
      debugPrint("✅ TOTAL DISTANCE = $totalDistance m");
      debugPrint("✅ TOTAL DURATION = $totalDuration s");

      await MapHelper.drawRoutesOnMap(context, controller, mergedPoints);

      /// ✅ Trả thêm tổng values ra UI
      return {
        "points": mergedPoints,
        "data": data,
        "totalDistance": totalDistance,
        "totalDuration": totalDuration
      };
    } catch (e) {
      debugPrint("fetchMultiDirection ERROR: $e");
      return {"points": [], "data": {}};
    }
  }

  //  3. Vẽ nhiều tuyến đường + tự zoom camera (hỗ trợ routes list hoặc merged points)
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
      // Always clear old layers
      await MapHelper.clearRouteLayers(controller);

      // ==========================================================
      // CASE 1: routes is a List<LatLng>
      // ==========================================================
      if (_isListOfLatLng(routes)) {
        final pts = routes.cast<LatLng>();
        await _drawSingleLine(controller, pts, cameraPadding);
        return;
      }

      // ==========================================================
      // CASE 2: routes[0] is Map with key "points" or "merged_points"
      // ==========================================================
      if (routes.length == 1 && routes[0] is Map) {
        final r = routes[0] as Map;

        if (r.containsKey("points")) {
          final pts = (r["points"] as List).cast<LatLng>();
          await _drawSingleLine(controller, pts, cameraPadding);
          return;
        }
        if (r.containsKey("merged_points")) {
          final pts = (r["merged_points"] as List).cast<LatLng>();
          await _drawSingleLine(controller, pts, cameraPadding);
          return;
        }
      }

      // Treat as list of route objects (alternatives)

      List<LatLng> allPoints = [];

      for (int i = 0; i < routes.length; i++) {
        final route = routes[i];
        List<LatLng> points = [];

        // ---------------------------------------------------------
        // GeoJSON style geometry
        // ---------------------------------------------------------
        if (route is Map &&
            route["geometry"] is Map &&
            route["geometry"]["coordinates"] is List) {
          try {
            final coords = route["geometry"]["coordinates"] as List;
            for (final c in coords) {
              if (c is List && c.length >= 2) {
                points.add(
                  LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
                );
              }
            }
          } catch (e) {
            debugPrint("Geometry parse error route $i: $e");
          }
        }
        // ---------------------------------------------------------
        // Google overview_polyline
        // ---------------------------------------------------------
        else if (route is Map &&
            route["overview_polyline"]?["points"] != null) {
          try {
            final poly = route["overview_polyline"]["points"].toString();
            points = decodePolyline(poly);
          } catch (e) {
            debugPrint("decodePolyline failed for route $i: $e");
          }
        }

        // Already List<LatLng>
        else if (route is List) {
          try {
            final castList = route.cast<LatLng>();
            points = List<LatLng>.from(castList);
          } catch (_) {}
        }

        if (points.isEmpty) {
          debugPrint("Route $i không có geometry → skip");
          continue;
        }

        allPoints.addAll(points);

        final color = (i == 0)
            ? "#007AFF"
            : (i == 1)
            ? "#FF9500"
            : "#FF3B30";

        // Build GeoJSON Feature
        final feature = {
          "type": "Feature",
          "properties": {"route_index": i, "color": color},
          "geometry": {
            "type": "LineString",
            "coordinates": points
                .map((p) => [p.longitude, p.latitude])
                .toList(),
          },
        };

        final src = "route-source-$i";
        final layer = "route-line-$i";

        await controller.addSource(
          src,
          GeojsonSourceProperties(
            data: {
              "type": "FeatureCollection",
              "features": [feature],
            },
          ),
        );

        await controller.addLineLayer(
          src,
          layer,
          LineLayerProperties(
            lineColor: color,
            lineWidth: i == 0 ? 8.0 : 5.0,
            lineOpacity: i == 0 ? 1.0 : 0.4,
            lineJoin: "round",
            lineCap: "round",
          ),
        );
      }

      // ==========================================================
      // Fit camera
      // ==========================================================
      if (allPoints.isNotEmpty) {
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
        }
      }

      debugPrint(
        "Vẽ ${routes.length} route thành công (tổng ${allPoints.length} điểm)",
      );
    } catch (e, st) {
      debugPrint("Lỗi khi vẽ route: $e\n$st");
    }
  }

  // Draw single merged polyline (used for multi-stop merged points)

  static Future<void> _drawSingleLine(
    MapLibreMapController controller,
    List<LatLng> points,
    double cameraPadding,
  ) async {
    if (points.isEmpty) {
      debugPrint("drawSingleLine: points empty");
      return;
    }

    const sourceId = "route-source-merged";
    const layerId = "route-line-merged";

    // Remove old
    try {
      await controller.removeLayer(layerId);
    } catch (_) {}
    try {
      await controller.removeSource(sourceId);
    } catch (_) {}

    final feature = {
      "type": "Feature",
      "properties": {"color": "#007AFF"},
      "geometry": {
        "type": "LineString",
        "coordinates": points.map((p) => [p.longitude, p.latitude]).toList(),
      },
    };

    await controller.addSource(
      sourceId,
      GeojsonSourceProperties(
        data: {
          "type": "FeatureCollection",
          "features": [feature],
        },
      ),
    );

    await controller.addLineLayer(
      sourceId,
      layerId,
      LineLayerProperties(
        lineColor: "#007AFF",
        lineWidth: 8.0,
        lineOpacity: 1.0,
        lineJoin: "round",
        lineCap: "round",
      ),
    );

    // Auto fit camera
    final bounds = _getBounds(points);
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
    }
  }

  //  Helper: clear up to N route layers/sources safely
  static Future<void> clearRouteLayers(MapLibreMapController controller) async {
    // Xóa merged route
    await controller.removeLayer("route-line-merged");
    await controller.removeSource("route-source-merged");

    // Xóa tối đa 20 tuyến (dư cho chắc)
    for (int i = 0; i < 20; i++) {
      await controller.removeLayer("route-line-$i");
      await controller.removeSource("route-source-$i");
    }
  }

  //  4. Hàm tính bounds (private) - trả về null nếu ko có điểm
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


  //  5. Highlight route
  static Future<void> highlightRoute(
    MapLibreMapController controller,
    int selectedIndex,
    int totalRoutes,
  ) async {
    // If merged single-line exists, highlight it specially
    try {
      final mergedExists =
          true; // we attempt to set props for merged layer; if not exist, MapLibre will error which we catch
      if (mergedExists && selectedIndex == 0 && totalRoutes == 1) {
        // set merged layer to bold if present
        try {
          await controller.setLayerProperties(
            "route-line-merged",
            LineLayerProperties(lineWidth: 10.0, lineOpacity: 1.0),
          );
        } catch (_) {}
      }
    } catch (_) {}

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
        debugPrint("highlightRoute: cannot set props for route-line-$i: $e");
      }
    }
  }

  //  6. Thêm marker (point) với icon từ assets
  static Future<void> addStartEndMarker(
    MapLibreMapController controller,
    LatLng location, {
    required String iconAssetPath,
    required String imageId,
  }) async {
    final bytes = await rootBundle.load(iconAssetPath);
    await controller.addImage(imageId, bytes.buffer.asUint8List());

    final sourceId = "${imageId}_source";
    final layerId = "${imageId}_layer";

    try {
      await controller.removeLayer(layerId);
    } catch (_) {}
    try {
      await controller.removeSource(sourceId);
    } catch (_) {}

    await controller.addSource(
      sourceId,
      GeojsonSourceProperties(
        data: {
          "type": "FeatureCollection",
          "features": [
            {
              "type": "Feature",
              "geometry": {
                "type": "Point",
                "coordinates": [location.longitude, location.latitude],
              },
            },
          ],
        },
      ),
    );

    await controller.addLayer(
      sourceId,
      layerId,
      SymbolLayerProperties(
        iconImage: imageId,
        iconSize: 0.2,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );
  }

  static Future<void> clearMarkers(MapLibreMapController controller) async {
    for (final id in ["startIcon", "endIcon"]) {
      try {
        await controller.removeLayer("${id}_layer");
      } catch (_) {}
      try {
        await controller.removeSource("${id}_source");
      } catch (_) {}
    }
  }

  //  Helpers
  static String _numToStr(num v) {
    // Avoid spaces and locale issues
    return v.toString();
  }

  static bool _isListOfLatLng(List<dynamic> list) {
    if (list.isEmpty) return false;
    return list.first is LatLng;
  }
}
