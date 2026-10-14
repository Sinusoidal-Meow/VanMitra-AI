import 'dart:math' as math;

/// Geometry for the offline demo's boundary mapping: a plain-Dart port of what the real backend
/// does with `app/geo.py`, Shapely and PyProj (`app/services/boundary.py`).
///
/// Exact (same as the backend): positions, rings, WKT text, the split of a ring into segments,
/// GPS accuracy statistics, and the projection to UTM zone 43N (EPSG:32643, a Krueger-series
/// transverse Mercator, millimetre-accurate) used for every area, length and distance.
///
/// Approximate (Shapely does it with GEOS; here it is a small hand-written version):
///  * validity: self-intersection, spikes, too few points, a hole outside its shell;
///  * "zone within boundary": all vertices and edge midpoints covered, no edge crossing;
///  * overlap of two claims: Sutherland-Hodgman clipping (the intersection is exact when one of
///    the two polygons is convex; otherwise the first polygon is cut into triangles and the pieces
///    are returned as a MultiPolygon that tiles the overlap). Areas are exact either way.
/// For the simple polygons a village draws on a phone the answers are the same as the backend's.

/// Input that cannot be a boundary; [key] is the message key for the app.
class GeoError implements Exception {
  GeoError(this.key, this.detail);

  final String key;
  final String detail;

  @override
  String toString() => 'GeoError($key: $detail)';
}

/// (lon, lat), GeoJSON order.
typedef Pos = (double, double);
typedef Ring = List<Pos>;

// ── input: GeoJSON positions, rings, WKT (app/geo.py) ─────────────────────────

Pos position(List<num> p) {
  if (p.length < 2) {
    throw GeoError('geo.bad_position', 'a position needs longitude and latitude');
  }
  final lon = p[0].toDouble();
  final lat = p[1].toDouble();
  if (!(lon >= -180 && lon <= 180 && lat >= -90 && lat <= 90)) {
    throw GeoError('geo.out_of_range', 'position out of range: $lon, $lat');
  }
  return (lon, lat);
}

/// A closed linear ring (closed for the caller if the first point is not repeated).
Ring ring(List<List<num>> coords) {
  final pts = [for (final p in coords) position(p)];
  if (pts.isNotEmpty && pts.first != pts.last) pts.add(pts.first);
  if (pts.toSet().length < 3 || pts.length < 4) {
    throw GeoError('geo.ring_too_short', 'a boundary needs at least three distinct points');
  }
  return pts;
}

String _coords(Iterable<Pos> pts) => pts.map((p) => '${p.$1} ${p.$2}').join(', ');

String polygonWkt(List<Ring> rings) => 'POLYGON(${rings.map((r) => '(${_coords(r)})').join(', ')})';

String lineWkt(List<Pos> pts) {
  if (pts.length < 2) throw GeoError('geo.line_too_short', 'a line needs at least two points');
  return 'LINESTRING(${_coords(pts)})';
}

String pointWkt(double lon, double lat) {
  final p = position([lon, lat]);
  return 'POINT(${p.$1} ${p.$2})';
}

/// Cut the outer ring into segments at the given vertex indices. Segment k runs from break k to
/// break k+1 (the last one wraps round to the first break). One break gives one segment: the
/// whole ring.
List<Ring> splitRing(Ring closed, List<int> breaks) {
  final n = closed.length - 1; // distinct vertices; the last point repeats the first
  final cuts = breaks.toSet().toList()..sort();
  if (cuts.isEmpty) throw GeoError('geo.no_segments', 'at least one segment break is needed');
  if (cuts.first < 0 || cuts.last >= n) {
    throw GeoError('geo.break_out_of_range', 'segment breaks must be within 0..${n - 1}');
  }
  final segments = <Ring>[];
  for (var k = 0; k < cuts.length; k++) {
    final start = cuts[k];
    final end = k + 1 < cuts.length ? cuts[k + 1] : cuts.first + n;
    segments.add([for (var i = start; i <= end; i++) closed[i % n]]);
  }
  return segments;
}

/// Summary of GPS accuracy per vertex (B-14: points worse than the limit are flagged).
Map<String, dynamic> accuracyStats(List<double?>? values, int points, double limitM) {
  final known = [for (final v in values ?? const <double?>[]) if (v != null) v];
  return {
    'points': points,
    'with_accuracy': known.length,
    'worst_m': known.isEmpty ? null : known.reduce(math.max),
    'over_limit': known.where((v) => v > limitM).length,
    'limit_m': limitM,
  };
}

List<double> posJson(Pos p) => [p.$1, p.$2];
Pos posFromJson(dynamic c) => (((c as List)[0] as num).toDouble(), (c[1] as num).toDouble());
List<List<double>> ringJson(Iterable<Pos> r) => [for (final p in r) posJson(p)];
Ring ringFromJson(dynamic r) => [for (final c in r as List) posFromJson(c)];

/// The rings (outer first) of a GeoJSON Polygon map.
List<Ring> polygonRings(Map<String, dynamic> geojson) =>
    [for (final r in geojson['coordinates'] as List) ringFromJson(r)];

Ring lineFromJson(Map<String, dynamic> geojson) => ringFromJson(geojson['coordinates']);

// ── projection: WGS84 -> UTM zone 43N (EPSG:32643) ───────────────────────────

const double _a = 6378137.0;
const double _f = 1 / 298.257223563;
const double _k0 = 0.9996;
const double _lon0 = 75.0; // zone 43 central meridian
const double _falseEasting = 500000.0;

const double _n = _f / (2 - _f);
final double _bigA = _a / (1 + _n) * (1 + _n * _n / 4 + math.pow(_n, 4) / 64);
final List<double> _alpha = [
  _n / 2 - 2 * _n * _n / 3 + 5 * math.pow(_n, 3) / 16 + 41 * math.pow(_n, 4) / 180,
  13 * _n * _n / 48 - 3 * math.pow(_n, 3) / 5 + 557 * math.pow(_n, 4) / 1440,
  61 * math.pow(_n, 3) / 240 - 103 * math.pow(_n, 4) / 140,
  49561 * math.pow(_n, 4) / 161280,
];

double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
double _atanh(double x) => 0.5 * math.log((1 + x) / (1 - x));

/// (easting, northing) in metres of a (lon, lat), in UTM zone 43N whatever the place is.
Pos toUtm(Pos p) {
  final phi = p.$2 * math.pi / 180;
  final dl = (p.$1 - _lon0) * math.pi / 180;
  final sphi = math.sin(phi);
  final c = 2 * math.sqrt(_n) / (1 + _n);
  final t = _sinh(_atanh(sphi) - c * _atanh(c * sphi));
  final xi0 = math.atan2(t, math.cos(dl));
  final eta0 = _atanh(math.sin(dl) / math.sqrt(1 + t * t));
  var xi = xi0;
  var eta = eta0;
  for (var j = 1; j <= 4; j++) {
    xi += _alpha[j - 1] * math.sin(2 * j * xi0) * _cosh(2 * j * eta0);
    eta += _alpha[j - 1] * math.cos(2 * j * xi0) * _sinh(2 * j * eta0);
  }
  return (_falseEasting + _k0 * _bigA * eta, _k0 * _bigA * xi);
}

// ── planar helpers ───────────────────────────────────────────────────────────

double _cross(Pos o, Pos a, Pos b) => (a.$1 - o.$1) * (b.$2 - o.$2) - (a.$2 - o.$2) * (b.$1 - o.$1);

int _sign(double v) => v > 0 ? 1 : (v < 0 ? -1 : 0);

/// The ring without its closing point and without immediate repeats.
List<Pos> _open(Iterable<Pos> r) {
  final out = <Pos>[];
  for (final p in r) {
    if (out.isEmpty || out.last != p) out.add(p);
  }
  while (out.length > 1 && out.first == out.last) {
    out.removeLast();
  }
  return out;
}

double _signedArea(List<Pos> open) {
  var s = 0.0;
  for (var i = 0; i < open.length; i++) {
    final a = open[i];
    final b = open[(i + 1) % open.length];
    s += a.$1 * b.$2 - b.$1 * a.$2;
  }
  return s / 2;
}

double _utmArea(Iterable<Pos> r) => _signedArea(_open(r).map(toUtm).toList()).abs();

/// Area in hectares of a polygon (outer ring minus holes) in UTM metres, rounded to 4 places
/// (the backend's `area_ha`).
double areaHa(List<Ring> rings) {
  var m2 = 0.0;
  for (var i = 0; i < rings.length; i++) {
    final a = _utmArea(rings[i]);
    m2 += i == 0 ? a : -a;
  }
  return roundTo(m2 / 10000, 4);
}

/// Length in metres of a line, rounded to 2 places (the backend's `length_m`).
double lengthM(List<Pos> line) {
  var s = 0.0;
  for (var i = 1; i < line.length; i++) {
    final a = toUtm(line[i - 1]);
    final b = toUtm(line[i]);
    s += math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2));
  }
  return roundTo(s, 2);
}

/// Distance in metres from a point to a line, both in UTM (rounded by the caller).
double distanceToLineM(Pos point, List<Pos> line) {
  final p = toUtm(point);
  final pts = line.map(toUtm).toList();
  if (pts.isEmpty) return 0;
  if (pts.length == 1) return _dist(p, pts.first);
  var best = double.infinity;
  for (var i = 1; i < pts.length; i++) {
    best = math.min(best, _distToSegment(p, pts[i - 1], pts[i]));
  }
  return best;
}

double _dist(Pos a, Pos b) => math.sqrt(math.pow(a.$1 - b.$1, 2) + math.pow(a.$2 - b.$2, 2));

double _distToSegment(Pos p, Pos a, Pos b) {
  final dx = b.$1 - a.$1;
  final dy = b.$2 - a.$2;
  final len2 = dx * dx + dy * dy;
  if (len2 == 0) return _dist(p, a);
  final t = (((p.$1 - a.$1) * dx + (p.$2 - a.$2) * dy) / len2).clamp(0.0, 1.0);
  return _dist(p, (a.$1 + t * dx, a.$2 + t * dy));
}

/// [v] rounded half away from zero to [places] decimals.
double roundTo(double v, int places) {
  final m = math.pow(10, places).toDouble();
  return (v * m).roundToDouble() / m;
}

// ── segments, points in polygons ─────────────────────────────────────────────

bool _onSegment(Pos a, Pos b, Pos p) =>
    p.$1 >= math.min(a.$1, b.$1) &&
    p.$1 <= math.max(a.$1, b.$1) &&
    p.$2 >= math.min(a.$2, b.$2) &&
    p.$2 <= math.max(a.$2, b.$2);

/// How two segments meet: `proper` = they cross at a point inside both; `touch` = they share at
/// least one point (including a shared end point or an overlap).
({bool touch, bool proper, Pos? at}) _segments(Pos a, Pos b, Pos c, Pos d) {
  final d1 = _sign(_cross(c, d, a));
  final d2 = _sign(_cross(c, d, b));
  final d3 = _sign(_cross(a, b, c));
  final d4 = _sign(_cross(a, b, d));
  if (d1 * d2 < 0 && d3 * d4 < 0) {
    final t = _cross(c, d, a) / (_cross(c, d, a) - _cross(c, d, b));
    return (touch: true, proper: true, at: (a.$1 + t * (b.$1 - a.$1), a.$2 + t * (b.$2 - a.$2)));
  }
  if (d1 == 0 && _onSegment(c, d, a)) return (touch: true, proper: false, at: a);
  if (d2 == 0 && _onSegment(c, d, b)) return (touch: true, proper: false, at: b);
  if (d3 == 0 && _onSegment(a, b, c)) return (touch: true, proper: false, at: c);
  if (d4 == 0 && _onSegment(a, b, d)) return (touch: true, proper: false, at: d);
  return (touch: false, proper: false, at: null);
}

/// 1 inside, 0 on the ring, -1 outside (ray casting) for a ring given with or without its
/// closing point.
int _locate(Pos p, List<Pos> open) {
  var inside = false;
  for (var i = 0; i < open.length; i++) {
    final a = open[i];
    final b = open[(i + 1) % open.length];
    if (_cross(a, b, p) == 0 && _onSegment(a, b, p)) return 0;
    if ((a.$2 > p.$2) != (b.$2 > p.$2)) {
      final x = a.$1 + (p.$2 - a.$2) / (b.$2 - a.$2) * (b.$1 - a.$1);
      if (p.$1 < x) inside = !inside;
    }
  }
  return inside ? 1 : -1;
}

/// 1 inside the polygon (outer ring, holes), 0 on its edge, -1 outside.
int _locatePolygon(Pos p, List<List<Pos>> openRings) {
  final shell = _locate(p, openRings.first);
  if (shell != 1) return shell;
  for (var i = 1; i < openRings.length; i++) {
    final h = _locate(p, openRings[i]);
    if (h == 0) return 0;
    if (h == 1) return -1;
  }
  return 1;
}

String _fmt(double v) {
  final s = v.toString();
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

String _at(Pos p) => '[${_fmt(p.$1)} ${_fmt(p.$2)}]';

// ── validity ─────────────────────────────────────────────────────────────────

/// Why a polygon (outer ring first, then holes) is not valid, or null if it is: the same idea as
/// Shapely's `explain_validity`, with the same wording for the common cases.
String? explainInvalid(List<Ring> rings) {
  final opened = [for (final r in rings) _open(r)];
  for (final pts in opened) {
    if (pts.length < 3) return 'Too few points in geometry component${_at(pts.first)}';
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % n];
      for (var j = i + 1; j < n; j++) {
        final c = pts[j];
        final d = pts[(j + 1) % n];
        final adjacent = j == i + 1 || (i == 0 && j == n - 1);
        if (adjacent) {
          // two edges sharing a vertex must not fold back over each other (a spike)
          final shared = j == i + 1 ? b : a;
          final p = j == i + 1 ? a : d;
          final q = j == i + 1 ? d : c;
          if (_cross(p, shared, q) == 0 &&
              ((shared.$1 - p.$1) * (q.$1 - shared.$1) + (shared.$2 - p.$2) * (q.$2 - shared.$2)) <
                  0) {
            return 'Self-intersection${_at(shared)}';
          }
          continue;
        }
        final hit = _segments(a, b, c, d);
        if (hit.touch) {
          return '${hit.proper ? '' : 'Ring '}Self-intersection${_at(hit.at!)}';
        }
      }
    }
  }
  if (_signedArea(opened.first) == 0) return 'Self-intersection${_at(opened.first.first)}';
  for (var h = 1; h < opened.length; h++) {
    final hole = opened[h];
    for (final p in hole) {
      if (_locate(p, opened.first) < 0) return 'Hole lies outside shell${_at(p)}';
    }
    for (var i = 0; i < hole.length; i++) {
      final a = hole[i];
      final b = hole[(i + 1) % hole.length];
      for (var j = 0; j < opened.first.length; j++) {
        final hit = _segments(a, b, opened.first[j], opened.first[(j + 1) % opened.first.length]);
        if (hit.proper) return 'Hole lies outside shell${_at(hit.at!)}';
      }
    }
    for (var g = 1; g < opened.length; g++) {
      if (g == h) continue;
      for (final p in hole) {
        if (_locate(p, opened[g]) == 1) return 'Nested holes${_at(p)}';
      }
    }
  }
  return null;
}

// ── "zone within boundary" ───────────────────────────────────────────────────

/// Does [outer] (a polygon) cover [inner] (another)? Approximate: every vertex and every edge
/// midpoint of the inner outer ring is inside or on the outer polygon, none of its edges crosses
/// an edge of the outer polygon, and no hole of the outer polygon sits inside it.
bool polygonCovers(List<Ring> outer, List<Ring> inner) {
  final o = [for (final r in outer) _open(r)];
  final shell = _open(inner.first);
  for (var i = 0; i < shell.length; i++) {
    final a = shell[i];
    final b = shell[(i + 1) % shell.length];
    if (_locatePolygon(a, o) < 0) return false;
    if (_locatePolygon(((a.$1 + b.$1) / 2, (a.$2 + b.$2) / 2), o) < 0) return false;
    for (final ring in o) {
      for (var j = 0; j < ring.length; j++) {
        if (_segments(a, b, ring[j], ring[(j + 1) % ring.length]).proper) return false;
      }
    }
  }
  for (var h = 1; h < o.length; h++) {
    for (final p in o[h]) {
      if (_locate(p, shell) == 1) return false;
    }
  }
  return true;
}

// ── overlap of two polygons ──────────────────────────────────────────────────

bool _isConvex(List<Pos> open) {
  var sign = 0;
  for (var i = 0; i < open.length; i++) {
    final c = _cross(open[i], open[(i + 1) % open.length], open[(i + 2) % open.length]);
    final s = _sign(c);
    if (s == 0) continue;
    if (sign == 0) {
      sign = s;
    } else if (s != sign) {
      return false;
    }
  }
  return true;
}

List<Pos> _ccw(List<Pos> open) => _signedArea(open) < 0 ? open.reversed.toList() : open;

/// Sutherland-Hodgman: [subject] clipped by the convex counter-clockwise [clip].
List<Pos> _clip(List<Pos> subject, List<Pos> clip) {
  var out = subject;
  for (var i = 0; i < clip.length && out.isNotEmpty; i++) {
    final a = clip[i];
    final b = clip[(i + 1) % clip.length];
    final input = out;
    out = <Pos>[];
    var s = input.last;
    for (final e in input) {
      final eIn = _cross(a, b, e) >= 0;
      final sIn = _cross(a, b, s) >= 0;
      if (eIn) {
        if (!sIn) out.add(_meet(s, e, a, b));
        out.add(e);
      } else if (sIn) {
        out.add(_meet(s, e, a, b));
      }
      s = e;
    }
  }
  return out;
}

Pos _meet(Pos s, Pos e, Pos a, Pos b) {
  final ds = _cross(a, b, s);
  final de = _cross(a, b, e);
  final t = ds / (ds - de);
  return (s.$1 + t * (e.$1 - s.$1), s.$2 + t * (e.$2 - s.$2));
}

/// Ear clipping of a simple counter-clockwise polygon.
List<List<Pos>> _triangles(List<Pos> ccw) {
  final pts = [...ccw];
  final out = <List<Pos>>[];
  var guard = pts.length * pts.length + 10;
  while (pts.length > 3 && guard-- > 0) {
    var cut = -1;
    for (var i = 0; i < pts.length; i++) {
      final p = pts[(i + pts.length - 1) % pts.length];
      final c = pts[i];
      final n = pts[(i + 1) % pts.length];
      if (_cross(p, c, n) <= 0) continue; // reflex or flat
      var empty = true;
      for (final q in pts) {
        if (q == p || q == c || q == n) continue;
        if (_cross(p, c, q) >= 0 && _cross(c, n, q) >= 0 && _cross(n, p, q) >= 0) {
          empty = false;
          break;
        }
      }
      if (empty) {
        cut = i;
        break;
      }
    }
    if (cut < 0) cut = 0; // degenerate input: drop a vertex rather than loop
    final p = pts[(cut + pts.length - 1) % pts.length];
    final c = pts[cut];
    final n = pts[(cut + 1) % pts.length];
    if (_cross(p, c, n) > 0) out.add([p, c, n]);
    pts.removeAt(cut);
  }
  if (pts.length == 3 && _cross(pts[0], pts[1], pts[2]) > 0) out.add(pts);
  return out;
}

/// The pieces (open rings, lon/lat) where two simple rings overlap.
List<List<Pos>> _shellPieces(List<Pos> a, List<Pos> b) {
  final pa = _ccw(a);
  final pb = _ccw(b);
  if (pa.length < 3 || pb.length < 3) return const [];
  List<List<Pos>> raw;
  if (_isConvex(pa)) {
    raw = [_clip(pb, pa)];
  } else if (_isConvex(pb)) {
    raw = [_clip(pa, pb)];
  } else {
    raw = [for (final t in _triangles(pa)) _clip(pb, t)];
  }
  return [
    for (final r in raw)
      if (_open(r).length >= 3 && _utmArea(r) > 1e-9) _open(r),
  ];
}

/// Where two polygons overlap: `geojson` (Polygon or MultiPolygon, lon/lat) and `ha` (UTM area,
/// 4 places), or null when they do not overlap (or only along an edge). Holes are subtracted from the area.
({Map<String, dynamic> geojson, double ha})? overlapOf(List<Ring> a, List<Ring> b) {
  final oa = [for (final r in a) _open(r)];
  final ob = [for (final r in b) _open(r)];
  final pieces = _shellPieces(oa.first, ob.first);
  if (pieces.isEmpty) return null;
  var m2 = 0.0;
  for (final p in pieces) {
    m2 += _utmArea(p);
  }
  for (var i = 0; i < oa.length; i++) {
    for (var j = 0; j < ob.length; j++) {
      if (i == 0 && j == 0) continue;
      var part = 0.0;
      for (final p in _shellPieces(oa[i], ob[j])) {
        part += _utmArea(p);
      }
      // a hole in one polygon removes its share; a hole in both is counted back once
      m2 += (i == 0 || j == 0) ? -part : part;
    }
  }
  List<List<double>> closed(List<Pos> p) => ringJson([...p, p.first]);
  final geojson = pieces.length == 1
      ? {
          'type': 'Polygon',
          'coordinates': [closed(pieces.first)],
        }
      : {
          'type': 'MultiPolygon',
          'coordinates': [
            for (final p in pieces) [closed(p)],
          ],
        };
  final ha = roundTo(math.max(m2, 0) / 10000, 4);
  return ha <= 0 ? null : (geojson: geojson, ha: ha);
}
