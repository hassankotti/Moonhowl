import 'package:flutter/services.dart';

/// Family name the app uses for the optional Thmanyah Sans font.
const thmanyahFamily = 'Thmanyah Sans';

/// Registers any .ttf/.otf files placed in `assets/fonts/` as the
/// Thmanyah Sans family. The font's license is personal use only, so the
/// files are not committed; see the README. Returns the family name when
/// fonts were found, or null so the app falls back to the system font.
Future<String?> loadThmanyahFont() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest
        .listAssets()
        .where((a) => a.startsWith('assets/fonts/') && (a.endsWith('.ttf') || a.endsWith('.otf')))
        .toList();
    if (files.isEmpty) return null;
    final loader = FontLoader(thmanyahFamily);
    for (final f in files) {
      loader.addFont(rootBundle.load(f));
    }
    await loader.load();
    return thmanyahFamily;
  } catch (_) {
    return null;
  }
}
