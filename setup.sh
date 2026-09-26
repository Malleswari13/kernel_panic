#!/usr/bin/env bash
# Generates the iOS + Android platform folders and adds location permissions.
set -e
cd "$(dirname "$0")"

flutter create . --org com.agri --project-name plotwise --platforms=android,ios

# Android: internet + location permissions
M=android/app/src/main/AndroidManifest.xml
if ! grep -q ACCESS_FINE_LOCATION "$M"; then
  perl -0pi -e 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n    <application#' "$M"
fi

# iOS: location permission prompt text
P=ios/Runner/Info.plist
if [ -f "$P" ] && ! grep -q NSLocationWhenInUseUsageDescription "$P"; then
  perl -0pi -e 's#<dict>#<dict>\n\t<key>NSLocationWhenInUseUsageDescription</key>\n\t<string>PlotWise uses your location to find and outline your plot.</string>#' "$P"
fi

flutter pub get
echo "Done. Run: flutter run"
