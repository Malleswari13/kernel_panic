import 'dart:math' as math;

import 'format.dart';
import 'models.dart';

/// The single seam between the UI and your backend / model.
///
/// Replace [FakeFarmRepository] with a real implementation that:
///  - getHybrids():         reads your genotype dataset
///  - syncSources():        sends the plot + zone polygons to your backend, which pulls
///                          NASA POWER, the forecast, Copernicus + USDA soil and
///                          Sentinel-2 / Landsat NDVI, and emits progress per source
///  - getRecommendations(): calls your yield model, one Recommendation per zone
abstract class FarmRepository {
  Future<List<Hybrid>> getHybrids();
  Stream<List<DataSourceStatus>> syncSources(Plot plot);
  Future<List<Recommendation>> getRecommendations(Plot plot);
}

/// Demo data so the whole flow works before the model is connected.
class FakeFarmRepository implements FarmRepository {
  static const _hybrids = [
    Hybrid('hx4120', 'HX-4120', 'Demo Seeds', 105, 7, 6, 6, 7, 11.2),
    Hybrid('hx5580', 'HX-5580', 'Demo Seeds', 112, 5, 7, 8, 6, 12.6),
    Hybrid('dt3300', 'DT-3300 Drought Guard', 'AgriGen', 98, 9, 8, 5, 6, 9.4),
    Hybrid('ny6010', 'NY-6010', 'AgriGen', 118, 4, 5, 7, 8, 13.1),
    Hybrid('ex2750', 'EX-2750 Early', 'FieldLine', 92, 6, 6, 6, 5, 8.8),
  ];

  static const _catalogue = [
    DataSource('genotype', 'Hybrid genotype profiles', 'Your genotype dataset',
        'Maturity, stress tolerance and yield traits for the hybrids you entered', SourceCategory.genetics),
    DataSource('nasa_power', 'Season weather so far', 'NASA POWER',
        'Daily rainfall, temperature and sunlight since planting', SourceCategory.weather),
    DataSource('forecast', '10-day forecast', 'NASA GEOS forecast',
        'Rain and temperature outlook for the coming days', SourceCategory.weather),
    DataSource('c3s_soil', 'Soil moisture', 'Copernicus',
        'Surface soil moisture from Sentinel-1 / Climate Data Store', SourceCategory.soil),
    DataSource('ssurgo', 'Soil properties', 'USDA NRCS Soil Survey',
        'Texture, organic matter, drainage and water-holding capacity', SourceCategory.soil),
    DataSource('sentinel2', 'Crop vigour (10 m)', 'Copernicus Sentinel-2',
        'NDVI for each zone from the latest cloud-free image', SourceCategory.satellite),
    DataSource('landsat', 'Crop vigour (30 m)', 'USGS Landsat',
        'NDVI and water index history for the season', SourceCategory.satellite),
  ];

  static const _summaries = {
    'genotype': 'Traits loaded for your hybrids',
    'nasa_power': '96 days of weather, 412 mm rain',
    'forecast': 'Dry spell likely from day 4',
    'c3s_soil': 'Topsoil moisture below normal',
    'ssurgo': 'Silt loam, 2.4% organic matter',
    'sentinel2': 'Latest clear image: 3 days ago',
    'landsat': 'Latest clear image: 8 days ago',
  };

  @override
  Future<List<Hybrid>> getHybrids() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _hybrids;
  }

  @override
  Stream<List<DataSourceStatus>> syncSources(Plot plot) async* {
    final list = [for (final s in _catalogue) DataSourceStatus(s)];
    yield List.of(list);
    for (var i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(state: SyncState.running);
      yield List.of(list);
      await Future.delayed(Duration(milliseconds: 600 + i * 200));
      list[i] = list[i].copyWith(
          state: SyncState.done, summary: _summaries[list[i].source.id], updatedAt: DateTime.now());
      yield List.of(list);
    }
  }

  @override
  Future<List<Recommendation>> getRecommendations(Plot plot) async {
    await Future.delayed(const Duration(milliseconds: 1500));
    final byId = {for (final h in _hybrids) h.id: h};
    return [for (final z in plot.zones) _build(plot, z, byId[z.hybridId])];
  }

  Recommendation _build(Plot plot, Zone zone, Hybrid? h) {
    final rnd = math.Random((plot.id + zone.id).hashCode);
    final potential = h?.yieldPotential ?? 10.0;
    final stress = rnd.nextDouble();
    final predicted = potential * (1 - 0.45 * stress);
    final priority = stress > 0.62
        ? ZonePriority.high
        : stress > 0.30
            ? ZonePriority.medium
            : ZonePriority.low;
    final name = h?.name ?? 'This hybrid';
    final ndvi = (0.82 - 0.35 * stress).fmt(2);
    final confidence = 0.65 + 0.25 * rnd.nextDouble();

    Recommendation rec(String headline, List<String> actions, List<Reason> reasons) => Recommendation(
          zoneId: zone.id,
          priority: priority,
          headline: headline,
          actions: actions,
          reasons: reasons,
          predictedYield: predicted,
          potentialYield: potential,
          confidence: confidence,
        );

    if (priority == ZonePriority.low) {
      return rec('On track. Keep routine scouting.', [
        'Walk the zone weekly for pests and disease.',
        'No input changes needed right now.',
      ], [
        Reason(Factor.vegetation, 'Canopy is healthy',
            'NDVI $ndvi is at or above the plot average for this growth stage.', 0.45, 'Sentinel-2'),
        const Reason(Factor.weatherHistory, 'Rainfall close to normal',
            'Season rainfall is within 10% of the 20-year average here.', 0.30, 'NASA POWER'),
        Reason(Factor.genetics, '$name fits this season',
            'Its ${h?.maturityDays ?? 100}-day maturity fits the remaining season length.', 0.25,
            'Genotype dataset'),
      ]);
    }

    switch (rnd.nextInt(3)) {
      case 0:
        return rec('Water stress building. Irrigate this zone first.', [
          'Irrigate this zone within 3–5 days if water is available.',
          'Check for leaf rolling in the early afternoon.',
          'Hold fertilizer until soil moisture recovers.',
        ], [
          Reason(Factor.vegetation, 'Canopy vigour is dropping',
              'NDVI fell to $ndvi, lower than the rest of the plot and down since the last image.', 0.35,
              'Sentinel-2 + Landsat'),
          const Reason(Factor.forecast, 'Dry spell ahead',
              'Less than 5 mm of rain expected over the next 10 days, with highs near 33 °C.', 0.25,
              'NASA GEOS forecast'),
          const Reason(Factor.soil, 'Soil holds little water',
              'Sandier topsoil here dries out faster; current moisture is below normal.', 0.25,
              'USDA Soil Survey + Copernicus'),
          Reason(Factor.genetics, 'Moderate drought tolerance',
              '$name is rated ${h?.droughtTolerance ?? 5}/9 for drought tolerance.', 0.15, 'Genotype dataset'),
        ]);
      case 1:
        return rec('Likely nitrogen shortage. Side-dress this zone.', [
          'Confirm with a leaf test or chlorophyll meter.',
          'Side-dress nitrogen in this zone only.',
          'Apply before the rain expected on day 3 so it soaks in.',
        ], [
          Reason(Factor.vegetation, 'Pale canopy pattern',
              'NDVI $ndvi with a pattern typical of nitrogen shortage.', 0.35, 'Sentinel-2'),
          const Reason(Factor.weatherHistory, 'Heavy rain after planting',
              'About 140 mm fell in the 3 weeks after planting, which can wash nitrogen away.', 0.25,
              'NASA POWER'),
          const Reason(Factor.soil, 'Low organic matter',
              'Around 1.6% organic matter, so the soil supplies less nitrogen here.', 0.20, 'USDA Soil Survey'),
          Reason(Factor.genetics, 'High nitrogen demand',
              '$name has high yield potential and needs steady nitrogen to reach it.', 0.20, 'Genotype dataset'),
        ]);
      default:
        return rec('Wet, poorly drained area. Check for waterlogging.', [
          'Check low spots for standing water and yellow plants.',
          'Scout for root rot.',
          'Mark this zone for drainage work after harvest.',
        ], [
          const Reason(Factor.soil, 'Poorly drained soil',
              'Clay loam that drains slowly; soil moisture is well above normal.', 0.35,
              'USDA Soil Survey + Copernicus'),
          const Reason(Factor.weatherHistory, 'Wet season so far',
              'Rainfall is about 35% above average for this point in the season.', 0.25, 'NASA POWER'),
          Reason(Factor.vegetation, 'Patchy canopy', 'Low NDVI patches ($ndvi) in the lower part of the zone.',
              0.25, 'Landsat'),
          const Reason(Factor.forecast, 'More rain coming', 'About 35 mm expected over the next 4 days.', 0.15,
              'NASA GEOS forecast'),
        ]);
    }
  }
}
