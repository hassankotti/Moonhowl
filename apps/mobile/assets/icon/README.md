# Moon Howl — app icons

## iOS (Xcode 15+/16)
Replace `ios/App/App/Assets.xcassets/AppIcon.appiconset` (Capacitor) or your project's
`Assets.xcassets/AppIcon.appiconset` with `ios/AppIcon.appiconset`.
Single 1024 px source with Default, Dark and Tinted appearances (iOS 18). Xcode generates every size.
`ios/legacy-sizes/` holds fixed PNGs if you need them for older tooling.

## Android
Copy the contents of `android/res/` into `android/app/src/main/res/` (overwrite existing `mipmap-*`).
- Android 8+: adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml`) with background, foreground
  (parallax: moon behind, wolf in front) and monochrome layer for Android 13+ themed icons.
- Older devices: `ic_launcher.png` / `ic_launcher_round.png` per density.
Make sure `AndroidManifest.xml` has `android:icon="@mipmap/ic_launcher"` and
`android:roundIcon="@mipmap/ic_launcher_round"`.
`android/play-store-icon-512.png` is for the Google Play Console listing.

## Source
`source-svg/` has the vector masters to edit or re-export.
