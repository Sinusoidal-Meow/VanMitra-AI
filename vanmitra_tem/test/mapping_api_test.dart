import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:vanmitra_ai/features/mapping/mapping_api.dart';

void main() {
  group('fourSideBreaks', () {
    test('three points make three sides', () {
      expect(fourSideBreaks(3), [0, 1, 2]);
    });

    test('four or more points make four sides, all within the ring', () {
      for (final n in [4, 5, 7, 12, 101]) {
        final breaks = fourSideBreaks(n);
        expect(breaks.length, 4, reason: 'n=$n');
        expect(breaks.first, 0);
        expect(breaks.last, lessThan(n), reason: 'server rejects breaks >= n');
        expect(breaks, orderedEquals([...breaks]..sort()));
      }
    });
  });

  test('polygonJson closes the ring in [lon, lat] order', () {
    final pts = [const LatLng(19.9, 73.2), const LatLng(19.9, 73.3), const LatLng(20.0, 73.3)];
    final ring = (polygonJson(pts)['coordinates'] as List).first as List;
    expect(ring.length, 4);
    expect(ring.first, [73.2, 19.9]);
    expect(ring.last, ring.first);
    expect(outerRing(polygonJson(pts)), pts);
  });
}
