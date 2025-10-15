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
              lon == other.lon &&
              tz == other.tz; // so sánh theo nhiều field

  @override
  int get hashCode => lat.hashCode ^ lon.hashCode ^ tz.hashCode;

  @override
  String toString() => 'LocationModel(name: $name, lat: $lat, lon: $lon, tz: $tz)';
}
