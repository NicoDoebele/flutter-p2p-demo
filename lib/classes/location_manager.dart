import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'location.dart';

class LocationManager {
  static Position? _currentPosition;
  static StreamSubscription<Position>? _positionStreamSubscription;
  static final LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 1,
  );
  static bool _locationEnabled = false;

  static Future<void> initialize() async {
    if (_locationEnabled) {
      return;
    }

    _locationEnabled = true;

    _currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);

    Geolocator.getPositionStream(locationSettings: _locationSettings).listen((Position position) {
      _currentPosition = position;
    });
  }

  static Future<void> dispose() async {
    if (!_locationEnabled) {
      return;
    }

    _locationEnabled = false;

    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  static Position? getCurrentPosition() {
    return _currentPosition;
  }

  static Location? getCurrentLocation() {
    if (!_locationEnabled) {
      return null;
    }

    if (_currentPosition == null) {
      return null;
    }

    return Location(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
    );
  }

  static bool isLocationEnabled() {
    return _locationEnabled;
  }

  static void updateLocationStatus(bool enabled) {
    if (enabled) {
      initialize();
    } else {
      dispose();
    }
  }
}