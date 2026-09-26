import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../farm_state.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'insights.dart';
import 'plot_setup.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _newPlot(BuildContext context) {
    context.read<FarmState>().startNewPlot();
    push(context, const PlotSetupScreen());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FarmState>();
    return Scaffold(
      appBar: AppBar(title: const Text('My plots')),
      floatingActionButton: state.plots.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _newPlot(context),
              icon: const Icon(Icons.add),
              label: const Text('Add plot'),
            ),
      body: state.plots.isEmpty
          ? EmptyState(
              icon: Icons.agriculture,
              title: 'Add your first plot',
              body: 'Mark it on the map with GPS, split it into zones, and get advice for each zone this season.',
              actionLabel: 'Add plot',
              onAction: () => _newPlot(context),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: state.plots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) => _PlotCard(plot: state.plots[i]),
            ),
    );
  }
}

class _PlotCard extends StatelessWidget {
  const _PlotCard({required this.plot});
  final Plot plot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final urgent = plot.recommendations.where((r) => r.priority == ZonePriority.high).length;

    final (String status, Color color) = plot.recommendations.isEmpty
        ? ('Not analyzed yet', cs.onSurfaceVariant)
        : urgent > 0
            ? ('$urgent ${urgent == 1 ? 'zone needs' : 'zones need'} action', PriorityColors.high)
            : ('No urgent zones', PriorityColors.low);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.read<FarmState>().openPlot(plot.id);
          push(context, const InsightsScreen());
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.grass, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plot.name.isEmpty ? 'Unnamed plot' : plot.name,
                        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text('${plot.areaHa.fmt(2)} ha, ${plot.zones.length} zones, ${plot.season}',
                        style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(status, style: text.labelLarge?.copyWith(color: color)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
