import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../geo.dart';

class MapZone {
  const MapZone(this.id, this.polygon, this.fill, this.border);
  final String id;
  final List<LatLng> polygon;
  final Color fill;
  final Color border;
}

const _boundaryColor = Color(0xFFFFD54F);
const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
// USGS imagery covers the US only. Swap for a global imagery source if needed.
const _satUrl =
    'https://basemap.nationalmap.gov/arcgis/rest/services/USGSImageryOnly/MapServer/tile/{z}/{y}/{x}';

/// OpenStreetMap view (iOS + Android) showing the plot outline, zones and GPS marker.
/// [onTap] receives map taps (drawing corners). If it's null, taps hit [onZoneTap].
class FarmMap extends StatefulWidget {
  const FarmMap({
    super.key,
    this.center,
    this.boundary = const [],
    this.zones = const [],
    this.marker,
    this.satellite = false,
    this.fitToBoundary = false,
    this.showVertices = false,
    this.interactive = true,
    this.onTap,
    this.onZoneTap,
  });

  final LatLng? center;
  final List<LatLng> boundary;
  final List<MapZone> zones;
  final LatLng? marker;
  final bool satellite;
  final bool fitToBoundary;
  final bool showVertices;
  final bool interactive;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<String>? onZoneTap;

  @override
  State<FarmMap> createState() => _FarmMapState();
}

class _FarmMapState extends State<FarmMap> {
  final _controller = MapController();
  bool _ready = false;

  @override
  void didUpdateWidget(FarmMap old) {
    super.didUpdateWidget(old);
    final c = widget.center;
    if (_ready && c != null && c != old.center) {
      _controller.move(c, math.max(_controller.camera.zoom, 17));
    }
  }

  void _handleTap(LatLng point) {
    if (widget.onTap != null) {
      widget.onTap!(point);
      return;
    }
    final cb = widget.onZoneTap;
    if (cb == null) return;
    for (final z in widget.zones) {
      if (Geo.contains(z.polygon, point)) {
        cb(z.id);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.boundary;
    final canFit = widget.fitToBoundary && pts.length >= 3;
    final hasLocation = widget.center != null || pts.isNotEmpty;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: widget.center ?? (pts.isNotEmpty ? pts.first : const LatLng(5, 20)),
        initialZoom: hasLocation ? 17 : 3,
        initialCameraFit: canFit
            ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(28))
            : null,
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onMapReady: () => _ready = true,
        onTap: (_, point) => _handleTap(point),
      ),
      children: [
        TileLayer(
          urlTemplate: widget.satellite ? _satUrl : _osmUrl,
          userAgentPackageName: 'com.agri.plotwise',
          maxNativeZoom: widget.satellite ? 16 : 19,
        ),
        if (pts.length >= 3)
          PolygonLayer(polygons: [
            Polygon(
              points: pts,
              color: widget.zones.isEmpty ? _boundaryColor.withOpacity(0.25) : null,
              borderColor: _boundaryColor,
              borderStrokeWidth: 3,
            ),
          ]),
        if (pts.length == 2)
          PolylineLayer(polylines: [Polyline(points: pts, color: _boundaryColor, strokeWidth: 3)]),
        if (widget.zones.isNotEmpty)
          PolygonLayer(polygons: [
            for (final z in widget.zones)
              Polygon(points: z.polygon, color: z.fill, borderColor: z.border, borderStrokeWidth: 1.5),
          ]),
        MarkerLayer(markers: [
          if (widget.showVertices)
            for (final p in pts)
              Marker(point: p, width: 16, height: 16, child: _dot(Colors.white, _boundaryColor)),
          if (widget.marker != null)
            Marker(
                point: widget.marker!,
                width: 22,
                height: 22,
                child: _dot(const Color(0xFF1976D2), Colors.white)),
        ]),
        const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
      ],
    );
  }

  Widget _dot(Color fill, Color border) => Container(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: border, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
        ),
      );
}
