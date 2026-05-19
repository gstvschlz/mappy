# mappy

A local-only Android field-mapping app for geological observations. Built with Flutter (Dart). Designed for offline use at remote field sites — photos, descriptions, GPS pins, background track recording, and ZIP/CSV/GeoJSON exports.

No accounts, no cloud, no sync. All data stays on the device unless you export it.

---

## What's in this repo

Everything for the app **except** the Flutter-generated Android scaffold (Gradle files, MainActivity.kt, launcher icons, gradle wrapper). The bootstrap script generates those once you have Flutter installed.

```
lib/                  # Dart source (app code)
test/                 # Unit tests for DB DAOs, exports, measure tool
tools/bootstrap.ps1   # One-time scaffold generator + patcher
pubspec.yaml          # Dependencies (locked in plan)
build.yaml            # Drift codegen options
analysis_options.yaml # Lints
```

---

## First-time setup

You need:
1. **Flutter SDK** — install per https://docs.flutter.dev/get-started/install/windows. Use a stable channel (3.22+).
2. **Android Studio** (or just the Android command-line tools + SDK platform 26+ and a recent NDK).
3. A phone with **USB debugging enabled** for development builds.

Then, from the repo root in PowerShell:

```powershell
pwsh -ExecutionPolicy Bypass -File tools\bootstrap.ps1
```

The bootstrap script:
- Runs `flutter create .` to produce the Android scaffold (skips existing files).
- Patches `AndroidManifest.xml` with the permissions mappy needs (camera, fine/background location, foreground-service, notifications, photo storage).
- Sets `minSdkVersion` to 26.
- Runs `flutter pub get`.
- Runs `build_runner` to generate Drift database glue (`*.g.dart`).

---

## Running

Plug your phone in (USB debugging on) and:

```powershell
flutter run
```

For a release APK to sideload:

```powershell
flutter build apk --release
# APK location: build/app/outputs/flutter-apk/app-release.apk
```

Copy the APK to the phone, allow "Install from unknown sources" for whichever file manager you use, and tap to install.

(For successive rebuilds to upgrade in place rather than reinstall, sign with a stable keystore — see "Release signing" below.)

---

## Features (v1)

- **Map** with three tile sources — OpenStreetMap, OpenTopoMap (topographic, contours), Esri World Imagery (satellite). Toggle from the app bar.
- **Offline tile pre-download** — draw a region (or use the current viewport), pick zoom range, FMTC caches every tile for offline use.
- **Live GPS** marker, follow-me toggle, lat/lon readout.
- **New observation** — in-app multi-shot camera with scale-bar hint and compass-bearing overlay, free-text description, GPS auto-captured at save. EXIF GPS + bearing + altitude written into every JPEG.
- **Manual pin placement** — long-press anywhere on the map.
- **Projects** — one project per trip, switch from the Projects tab. All exports and lists scope to the active project.
- **Track recording** — background-capable foreground service with persistent notification. Tap the timeline icon to start/stop.
- **Measure tool** — tap vertices for distance (auto-switches to area readout once you have ≥3 points).
- **Observation list** with full-text search by description.
- **Soft delete** — observations go to a Trash screen and can be restored or deleted permanently.
- **Export & backup** — one-tap ZIP backup to `Downloads/mappy/` containing:
  - `observations.geojson` — FeatureCollection, points + linestrings, properties carry descriptions/photo filenames.
  - `observations.csv` — one row per observation.
  - `tracks.csv` — one row per recorded GPS point.
  - `photos/<observationId>/*.jpg` — every photo, EXIF-tagged.

---

## Permissions

On first run, mappy walks you through:
- **Camera** (required)
- **Location while using app** (required)
- **Background location** (for track recording with screen off)
- **Notifications** (for the persistent track-recording notification)
- **Storage** (for writing exports to public Downloads on older Android versions)

Background location requires a second prompt on Android 11+ — the OS takes you into system settings. If you don't grant it, foreground-only tracking still works; just don't lock the screen.

---

## Release signing (optional)

To get same-key upgrades instead of full reinstalls:

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\.android\keystores\mappy.jks `
    -keyalg RSA -keysize 2048 -validity 10000 -alias mappy
```

Create `android/key.properties` (already gitignored):

```
storePassword=<your-store-pw>
keyPassword=<your-key-pw>
keyAlias=mappy
storeFile=C:/Users/<you>/.android/keystores/mappy.jks
```

And in `android/app/build.gradle`, after the bootstrap-generated default config, add a signingConfig pointing at that key.properties.

For a personal sideload, this is optional — Flutter's debug-signed release APK works fine.

---

## Testing

```powershell
flutter test
```

Covers:
- Drift DAO behavior (insert / soft-delete / restore / search / cascade on project delete).
- GeoJSON serializer round-trip.
- CSV serializer escapes commas and newlines.
- Measure-tool distance + area math.

---

## Verification checklist (before the field trip)

- [ ] `flutter test` is green.
- [ ] Cold-start app, grant permissions, GPS marker appears within 10 s.
- [ ] Pre-download a small region. Put phone in airplane mode. Confirm all three tile sources render at zooms 12–18.
- [ ] Create an observation with 3 photos → kill the app → reopen → photos + pin still there.
- [ ] Open one saved JPEG on a desktop. EXIF should carry GPS, altitude, and bearing.
- [ ] Long-press map far from current GPS → "Create observation here" produces a pin at the tapped spot.
- [ ] Start track recording → lock phone → walk 200 m → unlock → polyline shows the walk.
- [ ] Hit **Backup now** → unzip in `Downloads/mappy/` on a desktop → `observations.geojson` loads in QGIS, photo filenames in properties resolve against `photos/` in the zip.

---

## Repo layout

```
lib/
├─ main.dart
├─ app/
│  ├─ theme.dart                          # Material 3, warm-brown seed
│  └─ home_shell.dart                     # Bottom-nav: Map / List / Projects / Export
├─ core/
│  ├─ db/                                 # Drift schema + DAOs (codegen via build_runner)
│  ├─ db_provider.dart                    # Riverpod provider for AppDatabase
│  ├─ location/                           # geolocator + compass wrappers
│  ├─ permissions/                        # PermissionsGate + first-run screen
│  ├─ files/paths.dart                    # App-docs / Downloads dirs
│  └─ exif/exif_writer.dart               # GPS + bearing + altitude into JPEG EXIF
└─ features/
   ├─ map/                                # flutter_map + FMTC + region download + measure tool
   ├─ observations/                       # New obs flow, camera, list, detail, trash
   ├─ projects/                           # CRUD + active-project Riverpod state
   ├─ tracks/                             # flutter_background_geolocation recorder + polyline layer
   └─ export/                             # GeoJSON / CSV / ZIP backup + Export screen
```

---

## Attribution

Map tiles:
- © OpenStreetMap contributors (ODbL)
- OpenTopoMap (CC-BY-SA), © OpenStreetMap contributors
- Esri World Imagery — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community
