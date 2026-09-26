import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'geo.dart';

/// One management zone inside a plot (grid cell clipped to the plot outline).
class Zone {
  const Zone({
    required this.id,
    required this.label,
    required this.polygon,
    required this.areaHa,
    this.hybridId,
    this.plantingDate,
  });

  final String id; // "A1", "B2"… rows from north, columns from west
  final String label;
  final List<LatLng> polygon;
  final double areaHa;
  final String? hybridId;
  final DateTime? plantingDate;

  Zone copyWith({String? hybridId, DateTime? plantingDate}) => Zone(
        id: id,
        label: label,
        polygon: polygon,
        areaHa: areaHa,
        hybridId: hybridId ?? this.hybridId,
        plantingDate: plantingDate ?? this.plantingDate,
      );
}

class Plot {
  Plot()
      : id = DateTime.now().microsecondsSinceEpoch.toString(),
        season = '${DateTime.now().year} main season';

  final String id;
  String name = '';
  LatLng? center;
  List<LatLng> boundary = [];
  int rows = 2;
  int cols = 2;
  List<Zone> zones = [];
  String season;
  List<Recommendation> recommendations = [];
  DateTime? analyzedAt;

  double get areaHa => Geo.areaHa(boundary);

  Recommendation? recommendationFor(String zoneId) {
    for (final r in recommendations) {
      if (r.zoneId == zoneId) return r;
    }
    return null;
  }
}

/// Traits come from your genotype dataset. Scores are 1 (poor) to 9 (excellent).
class Hybrid {
  const Hybrid(this.id, this.name, this.company, this.maturityDays, this.droughtTolerance,
      this.heatTolerance, this.nitrogenEfficiency, this.diseaseResistance, this.yieldPotential);

  final String id;
  final String name;
  final String company;
  final int maturityDays;
  final int droughtTolerance;
  final int heatTolerance;
  final int nitrogenEfficiency;
  final int diseaseResistance;
  final double yieldPotential; // t/ha
}

enum ZonePriority {
  high('Act now'),
  medium('Watch'),
  low('On track');

  const ZonePriority(this.label);
  final String label;
}

enum Factor {
  weatherHistory('Season weather'),
  forecast('Forecast'),
  soil('Soil'),
  vegetation('Crop vigour'),
  genetics('Hybrid genetics');

  const Factor(this.label);
  final String label;
}

/// One explanation behind a recommendation. [impact] = share of the decision (0..1).
class Reason {
  const Reason(this.factor, this.headline, this.detail, this.impact, this.source);
  final Factor factor;
  final String headline;
  final String detail;
  final double impact;
  final String source;
}

class Recommendation {
  const Recommendation({
    required this.zoneId,
    required this.priority,
    required this.headline,
    required this.actions,
    required this.reasons,
    required this.predictedYield,
    required this.potentialYield,
    required this.confidence,
  });

  final String zoneId;
  final ZonePriority priority;
  final String headline;
  final List<String> actions;
  final List<Reason> reasons;
  final double predictedYield; // t/ha
  final double potentialYield; // t/ha
  final double confidence; // 0..1

  double get yieldGap => math.max(0, potentialYield - predictedYield);
}

enum SourceCategory {
  genetics('Genetics'),
  weather('Weather'),
  soil('Soil'),
  satellite('Satellite imagery');

  const SourceCategory(this.label);
  final String label;
}

class DataSource {
  const DataSource(this.id, this.name, this.provider, this.description, this.category);
  final String id;
  final String name;
  final String provider;
  final String description;
  final SourceCategory category;
}

enum SyncState { pending, running, done, failed }

class DataSourceStatus {
  const DataSourceStatus(this.source,
      {this.state = SyncState.pending, this.summary, this.error, this.updatedAt});

  final DataSource source;
  final SyncState state;
  final String? summary;
  final String? error;
  final DateTime? updatedAt;

  DataSourceStatus copyWith({SyncState? state, String? summary, String? error, DateTime? updatedAt}) =>
      DataSourceStatus(source,
          state: state ?? this.state,
          summary: summary ?? this.summary,
          error: error ?? this.error,
          updatedAt: updatedAt ?? this.updatedAt);
}
