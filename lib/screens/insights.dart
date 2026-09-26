import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../farm_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/farm_map.dart';
import 'data_sync.dart';
import 'plot_setup.dart';
import 'zone_detail.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FarmState>();
    final plot = state.draft;
    final recs = plot.recommendations;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return StepScaffold(
      title: plot.name.isEmpty ? 'Your plot' : plot.name,
      actions: [
        IconButton(
          tooltip: 'Edit outline and zones',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => push(context, const PlotSetupScreen()),
        ),
        IconButton(
          tooltip: 'Update data and advice',
          icon: const Icon(Icons.refresh),
          onPressed: () => push(context, const DataSyncScreen()),
        ),
      ],
      body: recs.isEmpty
          ? EmptyState(
              icon: Icons.insights,
              title: 'No advice yet',
              body: 'Download the latest weather, soil and satellite data to get advice for each zone.',
              actionLabel: 'Get field data',
              onAction: () => push(context, const DataSyncScreen()),
            )
          : Column(
              children: [
                SizedBox(
                  height: 240,
                  child: Stack(
                    children: [
                      Positioned.fill(
                       child: FarmMap(
                        boundary: plot.boundary,
                        fitToBoundary: true,
                        zones: [
                          for (final z in plot.zones)
                            MapZone(
                              z.id,
                              z.polygon,
                              PriorityColors.of(plot.recommendationFor(z.id)?.priority ?? ZonePriority.low)
                                  .withOpacity(0.5),
                              Colors.white,
                            ),
                        ],
                        onZoneTap: (id) => push(context, ZoneDetailScreen(zoneId: id)),
                       ),
                      ),
                      const Positioned(left: 8, top: 8, child: _Legend()),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Summary(zones: plot.zones, recs: recs),
                      const SizedBox(height: 16),
                      Text('Where to focus first', style: text.titleMedium),
                      const SizedBox(height: 8),
                      for (final rec in [...recs]..sort((a, b) => a.priority.index.compareTo(b.priority.index)))
                        for (final zone in plot.zones.where((z) => z.id == rec.zoneId))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _RecommendationCard(
                              zone: zone,
                              rec: rec,
                              hybridName: state.hybrid(zone.hybridId)?.name,
                              onTap: () => push(context, ZoneDetailScreen(zoneId: zone.id)),
                            ),
                          ),
                      Text(
                        'Based on data from ${plot.analyzedAt == null ? 'today' : formatDayTime(plot.analyzedAt!)}. Tap a zone for the reasons.',
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in ZonePriority.values) ...[
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: PriorityColors.of(p), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(p.label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(width: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.zones, required this.recs});
  final List<Zone> zones;
  final List<Recommendation> recs;

  @override
  Widget build(BuildContext context) {
    final area = {for (final z in zones) z.id: z.areaHa};
    var totalArea = area.values.fold<double>(0, (a, b) => a + b);
    if (totalArea <= 0) totalArea = 1e-9;
    final predicted = recs.fold<double>(0, (s, r) => s + r.predictedYield * (area[r.zoneId] ?? 0)) / totalArea;
    final gap = recs.fold<double>(0, (s, r) => s + r.yieldGap * (area[r.zoneId] ?? 0)) / totalArea;
    final urgent = recs.where((r) => r.priority == ZonePriority.high).length;

    return Row(
      children: [
        Expanded(child: _Stat(label: 'Expected yield', value: '${predicted.fmt()} t/ha')),
        const SizedBox(width: 10),
        Expanded(child: _Stat(label: 'Room to gain', value: '${gap.fmt()} t/ha')),
        const SizedBox(width: 10),
        Expanded(
          child: _Stat(
            label: 'Act now',
            value: '$urgent of ${recs.length} zones',
            color: urgent > 0 ? PriorityColors.high : null,
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label, value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: text.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: text.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({required this.zone, required this.rec, required this.hybridName, required this.onTap});

  final Zone zone;
  final Recommendation rec;
  final String? hybridName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PriorityColors.of(rec.priority);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      ZoneTag(zone.id, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('${zone.areaHa.fmt(2)} ha, ${hybridName ?? 'no hybrid'}',
                                      style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                                ),
                                PriorityBadge(rec.priority),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(rec.headline, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              'Expected ${rec.predictedYield.fmt()} of ${rec.potentialYield.fmt()} t/ha possible',
                              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
