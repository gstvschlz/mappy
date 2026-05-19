# Mappy — one-time bootstrap script.
#
# Run this once after installing the Flutter SDK and cloning this repo.
# It will:
#   1. Verify Flutter is installed
#   2. Generate the Android scaffold (android/) via `flutter create`
#   3. Patch AndroidManifest.xml with the permissions Mappy needs
#   4. Bump minSdkVersion to 26
#   5. Run `flutter pub get`
#   6. Run drift codegen (build_runner)
#
# After this runs successfully:
#   flutter run                          # debug build via USB / wireless ADB
#   flutter build apk --release          # release APK in build/app/outputs/flutter-apk/

$ErrorActionPreference = 'Stop'

# 1. Verify Flutter
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter is not installed or not on PATH. Install from https://docs.flutter.dev/get-started/install/windows"
    exit 1
}
flutter --version

# 2. Generate the Android scaffold WITHOUT overwriting our lib/ or pubspec.yaml.
# `flutter create .` skips files that already exist.
Write-Host "`n>> Generating platform scaffold (android only)..." -ForegroundColor Cyan
flutter create . --project-name mappy --org com.scholze --platforms android --description "Offline geological field-mapping app."

# 3. Patch AndroidManifest.xml
$manifest = "android/app/src/main/AndroidManifest.xml"
if (-not (Test-Path $manifest)) {
    Write-Error "AndroidManifest.xml not found at $manifest"
    exit 1
}

Write-Host ">> Patching AndroidManifest.xml..." -ForegroundColor Cyan
$content = Get-Content $manifest -Raw

$permissions = @'
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"/>
    <uses-feature android:name="android.hardware.camera" android:required="true"/>
    <uses-feature android:name="android.hardware.location.gps" android:required="true"/>
'@

if ($content -notmatch 'ACCESS_FINE_LOCATION') {
    $content = $content -replace '(<manifest[^>]*>)', "`$1`r`n$permissions"
}

# Set application label.
$content = $content -replace 'android:label="mappy"', 'android:label="Mappy"'

Set-Content $manifest -Value $content -Encoding utf8

# 4. Bump minSdkVersion to 26
$gradle = "android/app/build.gradle"
if (-not (Test-Path $gradle)) { $gradle = "android/app/build.gradle.kts" }

if (Test-Path $gradle) {
    Write-Host ">> Bumping minSdkVersion to 26 in $gradle..." -ForegroundColor Cyan
    $g = Get-Content $gradle -Raw
    $g = $g -replace 'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 26'
    $g = $g -replace 'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 26'
    $g = $g -replace 'minSdkVersion\s+\d+', 'minSdkVersion 26'
    $g = $g -replace 'minSdk\s*=\s*\d+', 'minSdk = 26'
    Set-Content $gradle -Value $g -Encoding utf8
}

# 5. flutter pub get
Write-Host "`n>> flutter pub get..." -ForegroundColor Cyan
flutter pub get

# 6. drift codegen
Write-Host "`n>> Running build_runner for drift codegen (this can take a minute)..." -ForegroundColor Cyan
flutter pub run build_runner build --delete-conflicting-outputs

Write-Host "`nBootstrap complete." -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  flutter run                       # debug on a connected device"
Write-Host "  flutter build apk --release       # release APK -> build/app/outputs/flutter-apk/app-release.apk"
