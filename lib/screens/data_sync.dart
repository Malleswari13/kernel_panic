import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../farm_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'insights.dart';

IconData categoryIcon(SourceCategory c) => switch (c) {
      SourceCategory.genetics => Icons.science_outlined,
      SourceCategory.weather => Icons.cloud_outlined,
      SourceCategory.soil => Icons.terrain,
      SourceCategory.satellite => Icons.satellite_alt,
    };

class DataSyncScreen extends StatefulWidget {
  const DataSyncScreen({super.key});

  @override
  State<DataSyncScreen> createState() => _DataSyncScreenState();
}

class _DataSyncScreenState extends State<DataSyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<FarmState>().syncData();
    });
  }

  Future<void> _analyze() async {
    final ok = await context.read<FarmState>().analyze();
    if (!mounted || !ok) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const InsightsScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FarmState>();
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    if (state.message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final m = state.takeMessage();
        if (m != null && mounted) showMessage(context, m);
      });
    }

    final total = state.sources.length;
    final done = state.sources.where((s) => s.state == SyncState.done).length;
    final byCategory = <SourceCategory, List<DataSourceStatus>>{};
    for (final s in state.sources) {
      byCategory.putIfAbsent(s.source.category, () => []).add(s);
    }

    return StepScaffold(
      title: 'Field data',
      step: 3,
      bottom: BottomActionBar(
        child: PrimaryAction(
          label: state.analyzing ? 'Working out advice…' : 'Get zone advice',
          loading: state.analyzing,
          onPressed: state.allSynced ? _analyze : null,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Getting data for ${state.draft.name.isEmpty ? 'your plot' : state.draft.name}',
              style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            total > 0 && done == total
                ? 'All $total sources ready.'
                : '$done of $total sources ready. This needs an internet connection.',
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(end: total == 0 ? 0.0 : done / total),
            duration: const Duration(milliseconds: 300),
            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, borderRadius: BorderRadius.circular(4)),
          ),
          for (final entry in byCategory.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(entry.key.label, style: text.titleSmall?.copyWith(color: cs.primary)),
            ),
            for (final s in entry.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SourceRow(status: s, onRetry: state.syncData),
              ),
          ],
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.status, required this.onRetry});
  final DataSourceStatus status;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    final Widget trailing = switch (status.state) {
      SyncState.pending => Icon(Icons.schedule, color: cs.outline, semanticLabel: 'Waiting'),
      SyncState.running => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
      SyncState.done => const Icon(Icons.check_circle, color: PriorityColors.low, semanticLabel: 'Ready'),
      SyncState.failed => IconButton(
          onPressed: onRetry, icon: const Icon(Icons.refresh, color: PriorityColors.high), tooltip: 'Try again'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: cs.secondaryContainer,
              child: Icon(categoryIcon(status.source.category), size: 22, color: cs.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status.source.name, style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  Text(status.source.provider, style: text.labelMedium?.copyWith(color: cs.primary)),
                  Text(
                    status.error ?? status.summary ?? status.source.description,
                    style: text.bodySmall?.copyWith(
                        color: status.error != null ? PriorityColors.high : cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}
