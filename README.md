# PlotWise — iOS + Android (Flutter)

One codebase for both platforms. Flow: **Mark plot → Split into zones → Pick hybrids → Get field data → Zone advice (with reasons)**.

## Run it
Requires Flutter 3.22 or newer (`flutter --version`). iOS builds need a Mac with Xcode.

```bash
./setup.sh          # creates the ios/ and android/ folders and adds location permissions
flutter run         # picks a connected phone, emulator, or iOS simulator
flutter test        # geometry + smoke tests
```

The app runs end-to-end on demo data from `FakeFarmRepository`.

## Where your model plugs in
Everything goes through `lib/repository.dart` → `FarmRepository`:

| Method | Your implementation |
|---|---|
| `getHybrids()` | Read your genotype dataset → `Hybrid` traits |
| `syncSources(plot)` | Send `plot.boundary` and `plot.zones` polygons to your backend. It pulls NASA POWER history, the forecast, Copernicus soil moisture, the USDA NRCS soil survey, and Sentinel-2 / Landsat NDVI. Emit progress per source. |
| `getRecommendations(plot)` | Call your yield model. Return one `Recommendation` per zone: priority, actions, predicted vs potential yield, confidence, and `Reason`s (factor, detail, impact share, data source). |

Swap it in `lib/main.dart`: `FarmState(repository: YourRepository())`.
`Reason.impact` fits SHAP-style feature attributions directly.

## Structure
```
lib/models.dart            Plot, Zone, Hybrid, Recommendation, Reason, DataSource
lib/repository.dart        FarmRepository (interface) + FakeFarmRepository (demo)
lib/farm_state.dart        Shared state (provider / ChangeNotifier)
lib/geo.dart               Area, quick box, grid split clipped to the outline, point-in-polygon
lib/location.dart          GPS + permission prompt (geolocator)
lib/widgets/farm_map.dart  OpenStreetMap (flutter_map): outline, zones, taps
lib/screens/               home, plot_setup, subdivide, hybrids, data_sync, insights, zone_detail
```

## Notes
- Maps: OpenStreetMap tiles, no API key. For a production app with many users, use a
  commercial tile provider or your own tile server (OSM's public servers have a usage policy).
- Satellite layer: USGS imagery covers the US only. Change `_satUrl` in `farm_map.dart` for other regions.
- Persistence: plots are in memory. Add sqflite or drift for saving and offline use.

## Get an APK without installing anything (GitHub Actions)
1. Create a new repository on github.com and upload this folder (including the hidden `.github` folder).
2. Open the **Actions** tab. The "Build Android APK" workflow runs on every push; you can also press **Run workflow**.
3. When it finishes (about 5–8 minutes), open the run and download **plotwise-apk** under *Artifacts*.
4. Unzip it, copy `app-release.apk` to an Android phone, and open it (allow "install unknown apps" when asked).

## Or build locally
```bash
./setup.sh
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```
The APK is signed with a debug key, which is fine for testing on phones. For the Play Store,
set up a release signing key: https://docs.flutter.dev/deployment/android#sign-the-app
