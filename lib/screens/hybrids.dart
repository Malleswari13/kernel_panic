import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../farm_state.dart';
import '../format.dart';
import '../models.dart';
import '../widgets/common.dart';
import 'data_sync.dart';

class HybridScreen extends StatefulWidget {
  const HybridScreen({super.key});

  @override
  State<HybridScreen> createState() => _HybridScreenState();
}

class _HybridScreenState extends State<HybridScreen> {
  late final TextEditingController _season;

  @override
  void initState() {
    super.initState();
    _season = TextEditingController(text: context.read<FarmState>().draft.season);
  }

  @override
  void dispose() {
    _season.dispose();
    super.dispose();
  }

  Future<void> _pickHybrid({String? zoneId}) async {
    final state = context.read<FarmState>();
    final current = zoneId == null
        ? null
        : state.draft.zones.firstWhere((z) => z.id == zoneId).hybridId;
    final picked = await showModalBottomSheet<Hybrid>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HybridSheet(
        hybrids: state.hybrids,
        selectedId: current,
        title: zoneId == null ? 'Hybrid for all zones' : 'Hybrid for zone $zoneId',
      ),
    );
    if (picked == null) return;
    if (zoneId == null) {
      state.assignHybridToAll(picked.id);
    } else {
      state.assignHybrid(zoneId, picked.id);
    }
  }

  Future<void> _pickDate(Zone zone) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: zone.plantingDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Planting date for ${zone.label}',
    );
    if (d != null && mounted) context.read<FarmState>().setPlantingDate(zone.id, d);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FarmState>();
    final plot = state.draft;
    final missing = plot.zones.where((z) => z.hybridId == null).length;

    return StepScaffold(
      title: 'Hybrids this season',
      step: 2,
      bottom: BottomActionBar(
        child: PrimaryAction(
          label: missing == 0 ? 'Next: get field data' : 'Pick a hybrid for $missing more',
          onPressed: plot.zones.isNotEmpty && missing == 0 ? () => push(context, const DataSyncScreen()) : null,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _season,
            onChanged: state.setSeason,
            decoration: const InputDecoration(labelText: 'Season', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('${plot.zones.length} zones', style: Theme.of(context).textTheme.titleMedium)),
              TextButton(onPressed: () => _pickHybrid(), child: const Text('Same hybrid everywhere')),
            ],
          ),
          for (final zone in plot.zones)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ZoneHybridCard(
                zone: zone,
                hybrid: state.hybrid(zone.hybridId),
                onPickHybrid: () => _pickHybrid(zoneId: zone.id),
                onPickDate: () => _pickDate(zone),
              ),
            ),
        ],
      ),
    );
  }
}

class _ZoneHybridCard extends StatelessWidget {
  const _ZoneHybridCard({required this.zone, required this.hybrid, required this.onPickHybrid, required this.onPickDate});

  final Zone zone;
  final Hybrid? hybrid;
  final VoidCallback onPickHybrid;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final h = hybrid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ZoneTag(zone.id),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(zone.label, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    Text('${zone.areaHa.fmt(2)} ha', style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPickHybrid,
                icon: const Icon(Icons.science_outlined),
                label: Text(h?.name ?? 'Choose hybrid'),
              ),
            ),
            if (h != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(label: Text('${h.maturityDays} days')),
                  Chip(label: Text('Drought ${h.droughtTolerance}/9')),
                  Chip(label: Text('Up to ${h.yieldPotential.fmt()} t/ha')),
                ],
              ),
            ],
            const Divider(height: 24),
            TextButton.icon(
              onPressed: onPickDate,
              icon: const Icon(Icons.calendar_month),
              label: Text(zone.plantingDate == null ? 'Add planting date' : 'Planted ${formatDay(zone.plantingDate!)}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HybridSheet extends StatelessWidget {
  const _HybridSheet({required this.hybrids, required this.selectedId, required this.title});

  final List<Hybrid> hybrids;
  final String? selectedId;
  final String title;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: text.titleLarge),
            ),
            if (hybrids.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('The hybrid list is still loading from your genotype data. Try again in a moment.'),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final h in hybrids)
                      ListTile(
                        leading: Icon(
                          h.id == selectedId ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: h.id == selectedId ? Theme.of(context).colorScheme.primary : null,
                        ),
                        title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${h.company}. ${h.maturityDays}-day maturity, drought ${h.droughtTolerance}/9, heat ${h.heatTolerance}/9, disease ${h.diseaseResistance}/9'),
                        trailing: Text('${h.yieldPotential.fmt()} t/ha'),
                        onTap: () => Navigator.pop(context, h),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
