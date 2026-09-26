import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../farm_state.dart';
import '../format.dart';
import '../location.dart';
import '../widgets/common.dart';
import '../widgets/farm_map.dart';
import 'subdivide.dart';

class PlotSetupScreen extends StatefulWidget {
  const PlotSetupScreen({super.key});

  @override
  State<PlotSetupScreen> createState() => _PlotSetupScreenState();
}

enum _CoordAction { goTo, addCorner }

class _PlotSetupScreenState extends State<PlotSetupScreen> {
  late final TextEditingController _name;
  bool _locating = false;
  bool _satellite = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<FarmState>().draft.name);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final c = await LocationService.current();
      if (!mounted) return;
      context.read<FarmState>().setCenter(c);
    } on LocationException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, 'No GPS fix yet. Move to open sky or type coordinates.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _typeCoords() async {
    final result = await showDialog<(_CoordAction, LatLng)>(
      context: context,
      builder: (_) => const _CoordinateDialog(),
    );
    if (result == null || !mounted) return;
    final state = context.read<FarmState>();
    final (action, point) = result;
    if (action == _CoordAction.goTo) {
      state.setCenter(point);
    } else {
      if (state.draft.center == null) state.setCenter(point);
      state.addVertex(point);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FarmState>();
    final plot = state.draft;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final n = plot.boundary.length;

    final hint = plot.center == null && n == 0
        ? 'Find your plot with GPS, type coordinates, or move the map.'
        : n < 3
            ? 'Tap each corner of your plot. $n of at least 3 marked.'
            : 'Outline done. Tap to add more corners, or continue.';

    return StepScaffold(
      title: 'Mark your plot',
      step: 0,
      bottom: BottomActionBar(
        child: PrimaryAction(
          label: 'Next: split into zones',
          onPressed: n >= 3 ? () => push(context, const SubdivideScreen()) : null,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _name,
              onChanged: state.setName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Plot name',
                hintText: 'e.g. River field',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.tonalIcon(
                      onPressed: _locating ? null : _locate,
                      icon: _locating
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      label: Text(_locating ? 'Finding you…' : 'Use my GPS'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _typeCoords,
                      icon: const Icon(Icons.edit_location_alt),
                      label: const Text('Type GPS'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: FarmMap(
                    center: plot.center,
                    boundary: plot.boundary,
                    marker: plot.center,
                    satellite: _satellite,
                    showVertices: true,
                    onTap: state.addVertex,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Card(
                    color: cs.surface.withOpacity(0.94),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(hint, style: text.bodyMedium),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 28,
                  child: FloatingActionButton.small(
                    heroTag: 'layers',
                    tooltip: _satellite ? 'Show street map' : 'Show satellite',
                    onPressed: () => setState(() => _satellite = !_satellite),
                    child: const Icon(Icons.layers),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n >= 3 ? '${plot.areaHa.fmt(2)} ha' : 'No outline yet',
                          style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('$n corners', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                PopupMenuButton<double>(
                  enabled: plot.center != null,
                  tooltip: 'Draw a box around your GPS point',
                  onSelected: state.quickBox,
                  itemBuilder: (_) => const [
                    PopupMenuItem<double>(value: 50.0, child: Text('50 × 50 m (0.25 ha)')),
                    PopupMenuItem<double>(value: 100.0, child: Text('100 × 100 m (1 ha)')),
                    PopupMenuItem<double>(value: 200.0, child: Text('200 × 200 m (4 ha)')),
                    PopupMenuItem<double>(value: 316.0, child: Text('316 × 316 m (10 ha)')),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(Icons.crop_square, color: plot.center != null ? cs.primary : cs.outline),
                        const SizedBox(width: 4),
                        Text('Quick box',
                            style: text.labelLarge
                                ?.copyWith(color: plot.center != null ? cs.primary : cs.outline)),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: n > 0 ? state.undoVertex : null,
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo last corner',
                ),
                IconButton(
                  onPressed: n > 0 ? state.clearBoundary : null,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear outline',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinateDialog extends StatefulWidget {
  const _CoordinateDialog();

  @override
  State<_CoordinateDialog> createState() => _CoordinateDialogState();
}

class _CoordinateDialogState extends State<_CoordinateDialog> {
  final _lat = TextEditingController();
  final _lon = TextEditingController();

  double? _parse(String s, double limit) {
    final v = double.tryParse(s.trim().replaceAll(',', '.'));
    return (v != null && v >= -limit && v <= limit) ? v : null;
  }

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lat = _parse(_lat.text, 90);
    final lon = _parse(_lon.text, 180);
    final valid = lat != null && lon != null;
    const keyboard = TextInputType.numberWithOptions(signed: true, decimal: true);

    return AlertDialog(
      title: const Text('Type GPS coordinates'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
              'Decimal degrees from your phone or handheld GPS, e.g. 12.3456 and -76.5432. Add each corner one at a time, or just go to the spot.'),
          const SizedBox(height: 12),
          TextField(
            controller: _lat,
            keyboardType: keyboard,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Latitude (−90 to 90)',
              border: const OutlineInputBorder(),
              errorText: _lat.text.isNotEmpty && lat == null ? 'Not a valid latitude' : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lon,
            keyboardType: keyboard,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Longitude (−180 to 180)',
              border: const OutlineInputBorder(),
              errorText: _lon.text.isNotEmpty && lon == null ? 'Not a valid longitude' : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: valid ? () => Navigator.pop(context, (_CoordAction.goTo, LatLng(lat!, lon!))) : null,
          child: const Text('Go to spot'),
        ),
        FilledButton(
          onPressed: valid ? () => Navigator.pop(context, (_CoordAction.addCorner, LatLng(lat!, lon!))) : null,
          child: const Text('Add corner'),
        ),
      ],
    );
  }
}
