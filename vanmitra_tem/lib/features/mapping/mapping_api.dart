// Form C boundary on the VanMitra backend: versions, landmarks per side, use zones,
// the boundary walk and overlaps with neighbours [Rule 12(1)(g), 12(3)].
// Geometry is GeoJSON, [lon, lat] order.

import 'package:latlong2/latlong.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';

class MappingApi {
  final ApiClient _api = ApiClient();

  /// The current boundary, or null when none has been saved yet.
  Future<Map<String, dynamic>?> boundary(String caseId) async {
    try {
      return await _api.get(ApiEndpoints.boundary(caseId)) as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveBoundary(
    String caseId, {
    required List<LatLng> points,
    required String source,
    List<double?>? accuracyM,
  }) async {
    return await _api.post(ApiEndpoints.boundary(caseId), body: {
      'polygon': polygonJson(points),
      'source': source,
      'segment_breaks': fourSideBreaks(points.length),
      if (accuracyM != null && accuracyM.length == points.length) 'vertex_accuracy_m': accuracyM,
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addLandmark(
    String caseId, {
    required int segmentSeq,
    required String name,
    required String kind,
    required LatLng at,
    String? photoMediaId,
  }) async {
    return await _api.post(ApiEndpoints.landmarks(caseId), body: {
      'segment_seq': segmentSeq,
      'name': name,
      'kind': kind,
      'lat': at.latitude,
      'lon': at.longitude,
      if (photoMediaId != null) 'photo_media_id': photoMediaId,
    }) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addUseZone(
    String caseId, {
    required String useType,
    required List<LatLng> points,
    String? name,
    String? season,
  }) async {
    return await _api.post(ApiEndpoints.useZones(caseId), body: {
      'use_type': useType,
      'polygon': polygonJson(points),
      if (name != null && name.isNotEmpty) 'name': name,
      if (season != null && season.isNotEmpty) 'season': season,
    }) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> walks(String caseId) async {
    final res = await _api.get(ApiEndpoints.walks(caseId)) as List<dynamic>?;
    return (res ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> recordWalk(
    String caseId, {
    required DateTime walkedOn,
    required List<Map<String, String>> participants,
    List<LatLng>? trace,
    String? notes,
  }) async {
    return await _api.post(ApiEndpoints.walks(caseId), body: {
      'walked_on': _date(walkedOn),
      'participants': participants,
      if (trace != null && trace.length >= 2)
        'trace': {
          'type': 'LineString',
          'coordinates': [for (final p in trace) [p.longitude, p.latitude]],
        },
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> disputes(String caseId) async {
    final res = await _api.get(ApiEndpoints.disputes(caseId)) as List<dynamic>?;
    return (res ?? []).cast<Map<String, dynamic>>();
  }
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A closed GeoJSON polygon ring from the drawn points.
Map<String, dynamic> polygonJson(List<LatLng> points) => {
      'type': 'Polygon',
      'coordinates': [
        [
          for (final p in points) [p.longitude, p.latitude],
          [points.first.longitude, points.first.latitude],
        ]
      ],
    };

/// Split the ring into the four sides (चतु:सीमा): breaks at 0, ¼, ½ and ¾ of the points.
/// With three points there are three sides.
List<int> fourSideBreaks(int n) {
  if (n < 4) return [for (var i = 0; i < n; i++) i];
  return {0, n ~/ 4, n ~/ 2, (3 * n) ~/ 4}.toList()..sort();
}

/// Points of a GeoJSON Polygon's outer ring (without the repeated last point).
List<LatLng> outerRing(Map<String, dynamic>? geometry) {
  final rings = geometry?['coordinates'] as List<dynamic>?;
  if (rings == null || rings.isEmpty) return [];
  final ring = (rings.first as List<dynamic>)
      .map((c) => LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();
  if (ring.length > 1 && ring.first == ring.last) ring.removeLast();
  return ring;
}

/// Points of a GeoJSON LineString.
List<LatLng> lineString(Map<String, dynamic>? geometry) {
  final coords = geometry?['coordinates'] as List<dynamic>?;
  if (coords == null) return [];
  return coords
      .map((c) => LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList();
}

/// Customary uses inside the CFR area (server: UseZoneType).
const Map<String, String> kUseZoneTypes = {
  'grazing': 'Grazing · चराई',
  'mfp': 'Minor forest produce · गौण वनोपज',
  'water': 'Water source · पाणवठा',
  'fishing': 'Fishing · मासेमारी',
  'fuelwood': 'Fuelwood · सरपण',
  'sacred': 'Sacred grove / burial ground · देवराई',
  'shifting_cultivation': 'Shifting cultivation',
  'habitat': 'Habitat of PTG / pre-agricultural community',
  'other': 'Other',
};
