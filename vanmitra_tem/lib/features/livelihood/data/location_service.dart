import 'package:geolocator/geolocator.dart';

enum LocationFailure { servicesOff, denied, deniedForever, failed }

class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;
}

class GpsFix {
  const GpsFix({required this.lat, required this.lng, this.accuracyM});
  final double lat;
  final double lng;
  final double? accuracyM;
}

/// Where the phone is now. An interface so tests (and the host) can supply their own.
abstract class LocationService {
  Future<GpsFix> currentFix();
}

/// Uses the `geolocator` package, which the host app already depends on.
class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GpsFix> currentFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.servicesOff);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException(LocationFailure.denied);
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(LocationFailure.deniedForever);
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        // geolocator 11 (the host's version) takes these two directly
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );
      return GpsFix(lat: p.latitude, lng: p.longitude, accuracyM: p.accuracy);
    } catch (_) {
      throw const LocationException(LocationFailure.failed);
    }
  }
}
