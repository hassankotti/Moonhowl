import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

enum Sfx { night, day, death, turn, tick, vote, win, lose, message }

/// Short sound effects and vibration, both optional.
class SoundBoard {
  SoundBoard();

  bool soundOn = true;
  bool vibrationOn = true;

  final Map<Sfx, AudioPlayer> _players = {};

  Future<void> play(Sfx s) async {
    if (!soundOn) return;
    try {
      final p = _players.putIfAbsent(s, () => AudioPlayer()..setReleaseMode(ReleaseMode.stop));
      await p.stop();
      await p.play(AssetSource('sounds/${s.name}.wav'), volume: s == Sfx.tick ? 0.4 : 0.8);
    } catch (_) {
      // Sound is a nice-to-have; never let it break the game.
    }
  }

  void buzz({bool strong = false}) {
    if (!vibrationOn) return;
    strong ? HapticFeedback.heavyImpact() : HapticFeedback.mediumImpact();
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}
