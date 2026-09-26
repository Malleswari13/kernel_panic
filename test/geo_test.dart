import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:plotwise/geo.dart';

void main() {
  test('quick box is about 1 ha and splits into equal zones', () {
    final box = Geo.boxAround(const LatLng(10, 20), 50);
    expect(Geo.areaHa(box), closeTo(1.0, 0.01));
    final zones = Geo.subdivide(box, 2, 3);
    expect(zones.length, 6);
    expect(zones.fold<double>(0, (s, z) => s + z.areaHa), closeTo(1.0, 0.01));
  });

  test('L-shaped plot skips the empty corner', () {
    const l = [
      LatLng(0, 0), LatLng(0, 0.002), LatLng(0.001, 0.002),
      LatLng(0.001, 0.001), LatLng(0.002, 0.001), LatLng(0.002, 0),
    ];
    final zones = Geo.subdivide(l, 2, 2);
    expect(zones.map((z) => z.id), ['A1', 'B1', 'B2']);
    expect(zones.fold<double>(0, (s, z) => s + z.areaHa), closeTo(Geo.areaHa(l), 0.001));
  });

  test('point in polygon', () {
    final box = Geo.boxAround(const LatLng(10, 20), 50);
    expect(Geo.contains(box, const LatLng(10, 20)), isTrue);
    expect(Geo.contains(box, const LatLng(11, 20)), isFalse);
  });
}
