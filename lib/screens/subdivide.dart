import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../farm_state.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/farm_map.dart';
import 'hybrids.dart';

const _palette = [
  Color(0xFF43A047), Color(0xFF00897B), Color(0xFF7CB342),
  Color(0xFF26A69A), Color(0xFF9CCC65), Color(0xFF00ACC1),
];

class SubdivideScreen extends StatefulWidget {
  const SubdivideScreen({super.key});

  @override
  State<SubdivideScreen> createState() => _SubdivideScreenState();
}

class _SubdivideScreenState extends State<SubdivideScreen> {
  late int _rows;
  late int _cols;
  String? _selected;

  @override
  void initState() {
    super.initState();
    final plot = context.read<FarmState>().draft;
    _rows = plot.rows;
    _cols = plot.cols;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FarmState>().subdivide(_rows, _cols);
    });
  }

  void _set(int rows, int cols) {
    setState(() {
      _rows = rows;
      _cols = cols;
    });
    context.read<FarmState>().subdivide(rows, cols);
  }

  @override
  Widget build(BuildContext context) {
    final plot = context.watch<FarmState>().draft;
    final text = Theme.of(context).textTheme;
    final zones = [
      for (var i = 0; i < plot.zones.length; i++)
        MapZone(
          plot.zones[i].id,
          plot.zones[i].polygon,
          _palette[i % _palette.length].withOpacity(plot.zones[i].id == _selected ? 0.7 : 0.35),
          Colors.white,
        ),
    ];

    return StepScaffold(
      title: 'Split into zones',
      step: 1,
      bottom: BottomActionBar(
        child: PrimaryAction(
          label: 'Next: pick hybrids',
          onPressed: plot.zones.isNotEmpty ? () => push(context, const HybridScreen()) : null,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FarmMap(
              boundary: plot.boundary,
              zones: zones,
              fitToBoundary: true,
              onZoneTap: (id) => setState(() => _selected = id),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Each zone gets its own hybrid and its own advice. Use more zones on a large or uneven plot.',
                  style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    NumberStepper(
                        label: 'Rows, north to south', value: _rows, min: 1, max: 6,
                        onChanged: (v) => _set(v, _cols)),
                    NumberStepper(
                        label: 'Columns, west to east', value: _cols, min: 1, max: 6,
                        onChanged: (v) => _set(_rows, v)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: plot.zones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final z = plot.zones[i];
                return FilterChip(
                  selected: z.id == _selected,
                  onSelected: (_) => setState(() => _selected = z.id),
                  label: Text('${z.id}: ${z.areaHa.fmt(2)} ha'),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
