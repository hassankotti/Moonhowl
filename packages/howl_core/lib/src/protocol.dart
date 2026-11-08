import 'dart:convert';

/// Wire protocol shared by host and clients. Every message is a JSON object
/// with a `t` field naming its type.
abstract final class Msg {
  static const protocolVersion = 1;

  // Client -> host.
  static const hello = 'hello'; // profile, token?, password?, v
  static const setProfile = 'setProfile'; // profile
  static const setSettings = 'setSettings'; // settings (host)
  static const start = 'start'; // (host)
  static const backToLobby = 'backToLobby'; // (host)
  static const kick = 'kick'; // id (host)
  static const lock = 'lock'; // value (host)
  static const pause = 'pause'; // (host)
  static const resume = 'resume'; // (host)
  static const skip = 'skip'; // (host)
  static const nightAction = 'nightAction'; // target?
  static const witch = 'witch'; // heal, poison?
  static const vote = 'vote'; // target? (null = skip)
  static const shoot = 'shoot'; // target
  static const chat = 'chat'; // channel, text
  static const openDm = 'openDm'; // with
  static const createRoom = 'createRoom'; // name, members
  static const leaveRoom = 'leaveRoom'; // room
  static const leave = 'leave';
  static const ping = 'ping';

  // Host -> client.
  static const welcome = 'welcome'; // you, token, room
  static const state = 'state'; // view
  static const chatMsg = 'chatMsg'; // msg
  static const chatSync = 'chatSync'; // messages, rooms
  static const dmOpened = 'dmOpened'; // channel
  static const error = 'error'; // code
  static const kicked = 'kicked';
  static const pong = 'pong';

  static String encode(String type, [Map<String, dynamic> body = const {}]) =>
      jsonEncode({'t': type, ...body});

  /// Returns null for anything that isn't a JSON object with a type.
  static Map<String, dynamic>? decode(Object? raw) {
    if (raw is! String || raw.length > 200000) return null;
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic> && v['t'] is String) return v;
    } catch (_) {}
    return null;
  }
}

/// Network constants.
abstract final class Net {
  static const defaultPort = 47474;
  static const wsPath = '/ws';
  static const infoPath = '/info';

  /// Bonjour / NSD service type used for discovery.
  static const serviceType = '_moonhowl._tcp';

  /// QR codes and deep links look like `moonhowl://192.168.1.5:47474`.
  static const scheme = 'moonhowl';

  static String joinUri(String host, int port) => '$scheme://$host:$port';

  /// Parses a QR code or typed address. Accepts `moonhowl://ip:port`,
  /// `ip:port` or just `ip`.
  static ({String host, int port})? parseAddress(String input) {
    var s = input.trim();
    if (s.startsWith('$scheme://')) s = s.substring(scheme.length + 3);
    final slash = s.indexOf('/');
    if (slash >= 0) s = s.substring(0, slash);
    if (s.isEmpty) return null;
    final colon = s.lastIndexOf(':');
    if (colon < 0) return (host: s, port: defaultPort);
    final port = int.tryParse(s.substring(colon + 1));
    final host = s.substring(0, colon);
    if (port == null || port <= 0 || port > 65535 || host.isEmpty) return null;
    return (host: host, port: port);
  }
}
