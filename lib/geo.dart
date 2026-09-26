import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'models.dart';

class Geo {
  static const _earthRadiusM = 6371000.0;
  static double _rad(double d) => d * math.pi / 180.0;

  /// Area in m² using a local equirectangular projection (accurate for field-sized plots).
  static double areaM2(List<LatLng> poly) {
    if (poly.length < 3) return 0;
    final lat0 = _rad(poly.map((p) => p.latitude).reduce((a, b) => a + b) / poly.length);
    final o = poly.first;
    final xs = <double>[];
    final ys = <double>[];
    for (final p in poly) {
      xs.add(_rad(p.longitude - o.longitude) * math.cos(lat0) * _earthRadiusM);
      ys.add(_rad(p.latitude - o.latitude) * _earthRadiusM);
    }
    var sum = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final j = (i + 1) % poly.length;
      sum += xs[i] * ys[j] - xs[j] * ys[i];
    }
    return sum.abs() / 2;
  }

  static double areaHa(List<LatLng> poly) => areaM2(poly) / 10000;

  /// Square box around a point. [halfSizeM] = distance from centre to each edge.
  static List<LatLng> boxAround(LatLng c, double halfSizeM) {
    final dLat = halfSizeM / _earthRadiusM * 180 / math.pi;
    final dLon = dLat / math.cos(_rad(c.latitude));
    return [
      LatLng(c.latitude + dLat, c.longitude - dLon),
      LatLng(c.latitude + dLat, c.longitude + dLon),
      LatLng(c.latitude - dLat, c.longitude + dLon),
      LatLng(c.latitude - dLat, c.longitude - dLon),
    ];
  }

  /// Split a plot into a rows × cols grid, clipping each cell to the plot outline.
  static List<Zone> subdivide(List<LatLng> boundary, int rows, int cols) {
    if (boundary.length < 3) return [];
    final lats = boundary.map((p) => p.latitude);
    final lons = boundary.map((p) => p.longitude);
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    final minLon = lons.reduce(math.min), maxLon = lons.reduce(math.max);
    final dLat = (maxLat - minLat) / rows;
    final dLon = (maxLon - minLon) / cols;
    final total = areaHa(boundary);
    final zones = <Zone>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final top = maxLat - r * dLat, bottom = top - dLat;
        final left = minLon + c * dLon, right = left + dLon;
        final cell = clipToRect(boundary, bottom, top, left, right);
        if (cell.length < 3) continue;
        final a = areaHa(cell);
        if (a < total * 0.01) continue; // ignore slivers
        final id = '${String.fromCharCode(65 + r)}${c + 1}';
        zones.add(Zone(id: id, label: 'Zone $id', polygon: cell, areaHa: a));
      }
    }
    return zones;
  }

  /// Sutherland–Hodgman clipping of any polygon against an axis-aligned rectangle.
  static List<LatLng> clipToRect(
      List<LatLng> poly, double minLat, double maxLat, double minLon, double maxLon) {
    var out = poly;
    out = _clip(out, (p) => p.longitude >= minLon, (a, b) => _atLon(a, b, minLon));
    out = _clip(out, (p) => p.longitude <= maxLon, (a, b) => _atLon(a, b, maxLon));
    out = _clip(out, (p) => p.latitude >= minLat, (a, b) => _atLat(a, b, minLat));
    out = _clip(out, (p) => p.latitude <= maxLat, (a, b) => _atLat(a, b, maxLat));
    return out;
  }

  static LatLng _atLon(LatLng a, LatLng b, double lon) {
    final t = (lon - a.longitude) / (b.longitude - a.longitude);
    return LatLng(a.latitude + t * (b.latitude - a.latitude), lon);
  }

  static LatLng _atLat(LatLng a, LatLng b, double lat) {
    final t = (lat - a.latitude) / (b.latitude - a.latitude);
    return LatLng(lat, a.longitude + t * (b.longitude - a.longitude));
  }

  static List<LatLng> _clip(
      List<LatLng> input, bool Function(LatLng) inside, LatLng Function(LatLng, LatLng) cross) {
    if (input.isEmpty) return input;
    final out = <LatLng>[];
    var prev = input.last;
    for (final cur in input) {
      final curIn = inside(cur), prevIn = inside(prev);
      if (curIn) {
        if (!prevIn) out.add(cross(prev, cur));
        out.add(cur);
      } else if (prevIn) {
        out.add(cross(prev, cur));
      }
      prev = cur;
    }
    return out;
  }

  /// Ray-casting point-in-polygon test (used for tapping zones).
  static bool contains(List<LatLng> poly, LatLng p) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      final crosses = (a.latitude > p.latitude) != (b.latitude > p.latitude) &&
          p.longitude <
              (b.longitude - a.longitude) * (p.latitude - a.latitude) / (b.latitude - a.latitude) +
                  a.longitude;
      if (crosses) inside = !inside;
    }
    return inside;
  }
}
