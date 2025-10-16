import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/location_model.dart';

class StorageHelper {
  static const String _fileName = "locations.json";

  // Copy từ assets sang storage lần đầu
  static Future<File> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$_fileName");

    if (!await file.exists()) {
      final data = await rootBundle.loadString("assets/data/locations.json");
      await file.writeAsString(data);
    }
    return file;
  }

  // Đọc danh sách
  static Future<List<dynamic>> readLocations() async {
    final file = await init();
    final content = await file.readAsString();
    return json.decode(content);
  }

  // Ghi danh sách
  static Future<void> writeLocations(List<dynamic> locations) async {
    final file = await init();
    await file.writeAsString(json.encode(locations));
  }

// Thêm địa điểm (luôn thêm vào áp chót, trước "Open map")
  static Future<void> addLocation(Map<String, dynamic> location) async {
    final list = await readLocations();

    // Tìm và loại bỏ "Open map" (tz == "chooseFromMap")
    final openMapItem = list.firstWhere(
          (item) => item['tz'] == "chooseFromMap",
      orElse: () => null,
    );
    list.removeWhere((item) => item['tz'] == "chooseFromMap");

    // Thêm địa điểm mới
    list.add(location);

    // Đưa lại "Open map" về cuối danh sách
    if (openMapItem != null) {
      list.add(openMapItem);
    }

    // Ghi lại file
    await writeLocations(list);
  }
  // Load danh sách thành List<LocationModel>
  static Future<List<LocationModel>> loadLocations() async {
    final list = await readLocations();
    return list.map((item) => LocationModel(
      name: item['name'],
      lat: (item['lat'] as num).toDouble(),
      lon: (item['lon'] as num).toDouble(),
      tz: item['tz'],
    )).toList();
  }
}
