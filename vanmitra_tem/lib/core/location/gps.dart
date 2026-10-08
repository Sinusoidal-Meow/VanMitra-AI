// One place to ask for the phone's position: checks that location is on and permitted,
// and says in plain words what is wrong when it is not.

import 'package:geolocator/geolocator.dart';

class GpsUnavailable implements Exception {
  GpsUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Make sure location is switched on and allowed; throws [GpsUnavailable] otherwise.
Future<void> ensureGpsReady() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw GpsUnavailable('Location is switched off. Turn on GPS and try again.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw GpsUnavailable('VanMitra needs location permission to record where this was taken.');
  }
}

/// The current position (high accuracy, up to 20 s).
Future<Position> currentPosition() async {
  await ensureGpsReady();
  return Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.best,
    timeLimit: const Duration(seconds: 20),
  );
}

/// A stream of positions every [distanceFilterM] metres, for walking a boundary.
Future<Stream<Position>> positionStream({int distanceFilterM = 5}) async {
  await ensureGpsReady();
  return Geolocator.getPositionStream(
    locationSettings: LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: distanceFilterM,
    ),
  );
}
