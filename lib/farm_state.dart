import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'geo.dart';
import 'models.dart';
import 'repository.dart';

/// Shared state for the whole plot flow. Plots are kept in memory; add local storage
/// (e.g. sqflite / drift) for persistence and offline use.
class FarmState extends ChangeNotifier {
  FarmState({FarmRepository? repository}) : repo = repository ?? FakeFarmRepository() {
    _loadHybrids();
  }

  final FarmRepository repo;
  final List<Plot> plots = [];
  Plot draft = Plot();
  List<Hybrid> hybrids = [];
  List<DataSourceStatus> sources = [];
  bool analyzing = false;
  String? message;
  StreamSubscription<List<DataSourceStatus>>? _sync;

  bool get allSynced => sources.isNotEmpty && sources.every((s) => s.state == SyncState.done);

  Hybrid? hybrid(String? id) {
    for (final h in hybrids) {
      if (h.id == id) return h;
    }
    return null;
  }

  Future<void> _loadHybrids() async {
    try {
      hybrids = await repo.getHybrids();
    } catch (_) {
      message = 'Couldn\'t load the hybrid list.';
    }
    notifyListeners();
  }

  // ---- plot list ----
  void startNewPlot() {
    draft = Plot();
    sources = [];
    notifyListeners();
  }

  void openPlot(String id) {
    draft = plots.firstWhere((p) => p.id == id);
    sources = [];
    notifyListeners();
  }

  // ---- step 1: locate & outline ----
  void setName(String name) {
    draft.name = name;
    notifyListeners();
  }

  void setCenter(LatLng c) {
    draft.center = c;
    notifyListeners();
  }

  void _boundaryChanged(List<LatLng> b) {
    draft.boundary = b;
    draft.zones = [];
    draft.recommendations = [];
    notifyListeners();
  }

  void addVertex(LatLng p) => _boundaryChanged([...draft.boundary, p]);

  void undoVertex() {
    if (draft.boundary.isEmpty) return;
    _boundaryChanged(draft.boundary.sublist(0, draft.boundary.length - 1));
  }

  void clearBoundary() => _boundaryChanged([]);

  void quickBox(double sideM) {
    final c = draft.center;
    if (c == null) return;
    _boundaryChanged(Geo.boxAround(c, sideM / 2));
  }

  // ---- step 2: zones ----
  void subdivide(int rows, int cols) {
    final old = {for (final z in draft.zones) z.id: z};
    final fresh = [
      for (final z in Geo.subdivide(draft.boundary, rows, cols))
        old[z.id] == null ? z : z.copyWith(hybridId: old[z.id]!.hybridId, plantingDate: old[z.id]!.plantingDate)
    ];
    final changed = fresh.map((z) => z.id).join(',') != draft.zones.map((z) => z.id).join(',');
    draft
      ..rows = rows
      ..cols = cols
      ..zones = fresh;
    if (changed) draft.recommendations = [];
    notifyListeners();
  }

  // ---- step 3: hybrids ----
  void setSeason(String s) {
    draft.season = s;
    notifyListeners();
  }

  void assignHybrid(String zoneId, String hybridId) {
    draft.zones = [for (final z in draft.zones) z.id == zoneId ? z.copyWith(hybridId: hybridId) : z];
    notifyListeners();
  }

  void assignHybridToAll(String hybridId) {
    draft.zones = [for (final z in draft.zones) z.copyWith(hybridId: hybridId)];
    notifyListeners();
  }

  /// Sets the date on this zone and fills any zone that has no date yet.
  void setPlantingDate(String zoneId, DateTime date) {
    draft.zones = [
      for (final z in draft.zones)
        (z.id == zoneId || z.plantingDate == null) ? z.copyWith(plantingDate: date) : z
    ];
    notifyListeners();
  }

  // ---- step 4: data + model ----
  void syncData() {
    _sync?.cancel();
    sources = [];
    notifyListeners();
    _sync = repo.syncSources(draft).listen(
      (s) {
        sources = s;
        notifyListeners();
      },
      onError: (Object e) {
        message = 'Couldn\'t download field data. Check your connection and try again.';
        notifyListeners();
      },
    );
  }

  /// Returns true when recommendations are ready.
  Future<bool> analyze() async {
    if (analyzing) return false;
    analyzing = true;
    notifyListeners();
    try {
      draft.recommendations = await repo.getRecommendations(draft);
      draft.analyzedAt = DateTime.now();
      plots.removeWhere((p) => p.id == draft.id);
      plots.add(draft);
      return true;
    } catch (_) {
      message = 'Couldn\'t work out advice. Try again.';
      return false;
    } finally {
      analyzing = false;
      notifyListeners();
    }
  }

  String? takeMessage() {
    final m = message;
    message = null;
    return m;
  }

  @override
  void dispose() {
    _sync?.cancel();
    super.dispose();
  }
}
