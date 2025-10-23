import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart'; // để dùng debugPrint

Future<Map<String, dynamic>?> fetchDirection({
  required double originLat,
  required double originLon,
  required double destLat,
  required double destLon,
  String vehicle = "car",
}) async {
  try {
    final apiKey = dotenv.env['API_KEY_ROUTES'];
    final url =
        "https://mapapis.openmap.vn/v1/direction?"
        "origin=$originLat,$originLon&"
        "destination=$destLat,$destLon&"
        "vehicle=$vehicle&apikey=$apiKey";

    // 🔹 Log URL đang gọi
    debugPrint("Fetching direction API URL: $url");

    final res = await http.get(Uri.parse(url));

    // 🔹 Log status code
    debugPrint("Response status: ${res.statusCode}");

    // 🔹 Log raw body (có thể cắt ngắn nếu quá dài)
    debugPrint("Raw response body: ${res.body.substring(0,
        res.body.length > 500 ? 500 : res.body.length)}");

    if (res.statusCode == 200) {
      final data = json.decode(res.body);

      // 🔹 Log cấu trúc JSON
      debugPrint("Decoded JSON keys: ${data.keys.toList()}");

      if (data["routes"] != null && data["routes"].isNotEmpty) {
        debugPrint("Found ${data["routes"].length} route(s),"
            " returning the first one.");
        return data["routes"][0]; // lấy route đầu tiên
      } else {
        debugPrint("No routes found in response!");
      }
    } else {
      debugPrint("Direction fetch failed with status: ${res.statusCode}");
    }
  } catch (e, stackTrace) {
    debugPrint("Error fetching direction: $e");
    debugPrint("StackTrace: $stackTrace");
  }

  return null;
}
