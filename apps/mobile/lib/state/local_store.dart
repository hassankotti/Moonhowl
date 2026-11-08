import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:howl_core/howl_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lifetime stats kept on this device only.
class Stats {
  Stats({this.games = 0, this.wins = 0, Map<String, int>? roles}) : roles = roles ?? {};

  final int games;
  final int wins;

  /// Role name -> times played.
  final Map<String, int> roles;

  Role? get favoriteRole {
    if (roles.isEmpty) return null;
    final top = roles.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return Role.values.where((r) => r.name == top.key).firstOrNull;
  }

  Map<String, dynamic> toJson() => {'games': games, 'wins': wins, 'roles': roles};

  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
        games: j['games'] as int? ?? 0,
        wins: j['wins'] as int? ?? 0,
        roles: Map<String, int>.from(j['roles'] as Map? ?? const {}),
      );
}

/// A seat we can take back after the app was closed.
class SavedSeat {
  SavedSeat({required this.host, required this.port, required this.token, required this.room, this.password});

  final String host;
  final int port;
  final String token;
  final String room;
  final String? password;

  Map<String, dynamic> toJson() =>
      {'host': host, 'port': port, 'token': token, 'room': room, 'password': password};

  factory SavedSeat.fromJson(Map<String, dynamic> j) => SavedSeat(
        host: j['host'] as String,
        port: j['port'] as int,
        token: j['token'] as String,
        room: j['room'] as String,
        password: j['password'] as String?,
      );
}

/// Profile, stats and preferences saved with SharedPreferences.
/// No account and no server: everything stays on the phone.
class LocalStore extends ChangeNotifier {
  LocalStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> load() async => LocalStore._(await SharedPreferences.getInstance());

  Profile? get profile {
    final raw = _prefs.getString('profile');
    if (raw == null) return null;
    try {
      return Profile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveProfile(Profile p) async {
    await _prefs.setString('profile', jsonEncode(p.toJson()));
    notifyListeners();
  }

  Stats get stats {
    final raw = _prefs.getString('stats');
    return raw == null ? Stats() : Stats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> recordGame({required Role role, required bool won}) async {
    final s = stats;
    final roles = Map.of(s.roles);
    roles[role.name] = (roles[role.name] ?? 0) + 1;
    await _prefs.setString('stats', jsonEncode(Stats(games: s.games + 1, wins: s.wins + (won ? 1 : 0), roles: roles).toJson()));
    notifyListeners();
  }

  String get language => _prefs.getString('lang') ?? 'ar';
  Future<void> setLanguage(String lang) async {
    await _prefs.setString('lang', lang);
    notifyListeners();
  }

  bool get sound => _prefs.getBool('sound') ?? true;
  Future<void> setSound(bool v) async {
    await _prefs.setBool('sound', v);
    notifyListeners();
  }

  bool get vibration => _prefs.getBool('vibration') ?? true;
  Future<void> setVibration(bool v) async {
    await _prefs.setBool('vibration', v);
    notifyListeners();
  }

  /// Last settings this player used as host.
  GameSettings? get lastSettings {
    final raw = _prefs.getString('lastSettings');
    return raw == null ? null : GameSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveLastSettings(GameSettings s) => _prefs.setString('lastSettings', jsonEncode(s.toJson()));

  SavedSeat? get savedSeat {
    final raw = _prefs.getString('seat');
    return raw == null ? null : SavedSeat.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveSeat(SavedSeat? seat) async {
    if (seat == null) {
      await _prefs.remove('seat');
    } else {
      await _prefs.setString('seat', jsonEncode(seat.toJson()));
    }
    notifyListeners();
  }
}
