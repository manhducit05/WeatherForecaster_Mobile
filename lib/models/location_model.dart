class LocationModel {
  final String name;
  final double lat;
  final double lon;
  final String tz;

  LocationModel({
    required this.name,
    required this.lat,
    required this.lon,
    required this.tz,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is LocationModel &&
              runtimeType == other.runtimeType &&
              lat == other.lat &&
              lon == other.lon; // so sánh theo tọa độ

  @override
  int get hashCode => lat.hashCode ^ lon.hashCode;

  @override
  String toString() =>
      'LocationModel(name: $name, lat: $lat, lon: $lon, tz: $tz)';
}
