import 'package:flutter/services.dart';

/// Finds the music and pictures bundled in the app.
///
/// Drop files into assets/music/ or assets/images/ and they appear here
/// automatically; no code changes needed.
class MediaLibrary {
  MediaLibrary._();

  static List<String> music = [];
  static List<String> images = [];

  static Future<void> load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final all = manifest.listAssets();
      music = all
          .where((a) => a.startsWith('assets/music/') && _isAudio(a))
          .toList()
        ..sort();
      images = all
          .where((a) => a.startsWith('assets/images/') && _isImage(a))
          .toList()
        ..sort();
    } catch (_) {
      music = [];
      images = [];
    }
  }

  static bool _isAudio(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.mp3') || p.endsWith('.m4a') || p.endsWith('.aac') || p.endsWith('.ogg');
  }

  static bool _isImage(String path) {
    final p = path.toLowerCase();
    return p.endsWith('.jpg') || p.endsWith('.jpeg') || p.endsWith('.png') || p.endsWith('.webp');
  }
}
