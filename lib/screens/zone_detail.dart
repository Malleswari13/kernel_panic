import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../farm_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/farm_map.dart';

IconData factorIcon(Factor f) => switch (f) {
      Factor.weatherHistory => Icons.history,
      Factor.forecast => Icons.cloud_outlined,
      Factor.soil => Icons.terrain,
      Factor.vegetation => Icons.satellite_alt,
      Factor.genetics => Icons.science_outlined,
    };

class ZoneDetailScreen extends StatelessWidget {
  const ZoneDetailScreen({super.key, required this.zoneId});
  final String zoneId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FarmState>();
    final plot = state.draft;
    final zones = plot.zones.where((z) => z.id == zoneId);
    final rec = plot.recommendationFor(zoneId);

    if (zones.isEmpty || rec == null) {
      return StepScaffold(
        title: 'Zone $zoneId',
        body: const Center(child: Text('This zone has no advice yet. Update the plot data first.')),
      );
    }

    final zone = zones.first;
    final color = PriorityColors.of(rec.priority);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final reasons = [...rec.reasons]..sort((a, b) => b.impact.compareTo(a.impact));

    return StepScaffold(
      title: zone.label,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 180,
              child: FarmMap(
                boundary: plot.boundary,
                fitToBoundary: true,
                interactive: false,
                zones: [
                  for (final z in plot.zones)
                    z.id == zoneId
                        ? MapZone(z.id, z.polygon, color.withOpacity(0.6), Colors.white)
                        : MapZone(z.id, z.polygon, Colors.grey.withOpacity(0.15), Colors.white60),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _HeaderCard(
            rec: rec,
            subtitle: [
              '${zone.areaHa.fmt(2)} ha',
              if (state.hybrid(zone.hybridId) != null) state.hybrid(zone.hybridId)!.name,
              if (zone.plantingDate != null) 'planted ${formatDay(zone.plantingDate!)}',
            ].join(', '),
          ),
          const SizedBox(height: 20),
          Text('What to do', style: text.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < rec.actions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: color.withOpacity(0.15),
                    child: Text('${i + 1}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(rec.actions[i], style: text.bodyLarge),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text('Why', style: text.titleMedium),
          Text('What drove this advice, biggest factor first.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          for (final r in reasons)
            Padding(padding: const EdgeInsets.only(bottom: 10), child: _ReasonCard(reason: r)),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.rec, required this.subtitle});
  final Recommendation rec;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = PriorityColors.of(rec.priority);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ratio = (rec.predictedYield / rec.potentialYield).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PriorityBadge(rec.priority),
            const SizedBox(height: 10),
            Text(rec.headline, style: text.headlineSmall),
            const SizedBox(height: 6),
            Text(subtitle, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Text('Expected yield', style: text.labelLarge)),
                Text('${rec.predictedYield.fmt()} / ${rec.potentialYield.fmt()} t/ha',
                    style: text.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: ratio,
              color: color,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Text(
              'About ${rec.yieldGap.fmt()} t/ha below what this hybrid can reach here. '
              'Model confidence ${(rec.confidence * 100).round()}%.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.reason});
  final Reason reason;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cs.tertiaryContainer,
              child: Icon(factorIcon(reason.factor), size: 22, color: cs.onTertiaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(reason.factor.label, style: text.labelMedium?.copyWith(color: cs.tertiary))),
                      Text('${(reason.impact * 100).round()}% of decision',
                          style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(reason.headline, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(reason.detail, style: text.bodyMedium),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: reason.impact, color: cs.tertiary),
                  const SizedBox(height: 6),
                  Text('Data: ${reason.source}', style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
