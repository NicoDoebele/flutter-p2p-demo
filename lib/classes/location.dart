class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  // Create a Location instance from a Map
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  String toString() {
    return 'Location(latitude: $latitude, longitude: $longitude)';
  }
}