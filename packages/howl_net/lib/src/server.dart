import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:howl_core/howl_core.dart';

/// The game host. Runs inside the host's app and serves players on the LAN
/// over WebSocket. Holds the only real copy of the game.
class HowlServer {
  HowlServer({
    required this.roomName,
    this.password,
    this.preferredPort = Net.defaultPort,
    Random? random,
    int Function()? clock,
  })  : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
        _secure = Random.secure() {
    hostId = _newId();
    hostToken = _newToken();
    game = GameEngine(hostId: hostId, random: random);
    chat = ChatHub(game);
  }

  final String roomName;
  final String? password;
  final int preferredPort;
  final int Function() _clock;
  final Random _secure;

  late final String hostId;

  /// The host's own client uses this token to claim the host seat.
  late final String hostToken;
  late final GameEngine game;
  late final ChatHub chat;

  HttpServer? _http;
  Timer? _ticker;
  final Map<String, String> _tokens = {}; // token -> player id
  final Map<String, _Conn> _conns = {}; // player id -> live connection
  int _sentVersion = -1;

  int get port => _http?.port ?? 0;
  bool get running => _http != null;

  Future<void> start() async {
    _tokens[hostToken] = hostId;
    try {
      _http = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
    } on SocketException {
      _http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    _http!.listen(_onRequest, onError: (_) {});
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      game.tick(_clock());
      _flush();
    });
  }

  Future<void> stop() async {
    _ticker?.cancel();
    for (final c in _conns.values.toList()) {
      await c.socket.close(WebSocketStatus.goingAway, 'hostClosed');
    }
    _conns.clear();
    await _http?.close(force: true);
    _http = null;
  }

  /// Summary served at `/info`, used to check an address before joining.
  Map<String, dynamic> get info => {
        'app': 'moonhowl',
        'v': Msg.protocolVersion,
        'name': roomName,
        'players': game.players.length,
        'inGame': game.inGame,
        'locked': game.locked,
        'hasPassword': password != null && password!.isNotEmpty,
      };

  // ------------------------------------------------------------- transport

  Future<void> _onRequest(HttpRequest req) async {
    final path = req.uri.path;
    if (path == Net.infoPath) {
      req.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(info));
      await req.response.close();
      return;
    }
    if (path == Net.wsPath && WebSocketTransformer.isUpgradeRequest(req)) {
      final socket = await WebSocketTransformer.upgrade(req);
      socket.pingInterval = const Duration(seconds: 4);
      final conn = _Conn(socket);
      socket.listen(
        (raw) => _onMessage(conn, raw),
        onDone: () => _onClosed(conn),
        onError: (_) => _onClosed(conn),
        cancelOnError: true,
      );
      return;
    }
    req.response.statusCode = HttpStatus.notFound;
    await req.response.close();
  }

  void _onClosed(_Conn conn) {
    final id = conn.playerId;
    if (id == null || _conns[id] != conn) return;
    _conns.remove(id);
    if (game.players.containsKey(id)) {
      game.setConnected(id, false);
      _flush();
    }
  }

  void _send(_Conn conn, String type, [Map<String, dynamic> body = const {}]) {
    try {
      conn.socket.add(Msg.encode(type, body));
    } catch (_) {}
  }

  void _error(_Conn conn, String code) => _send(conn, Msg.error, {'code': code});

  // -------------------------------------------------------------- messages

  void _onMessage(_Conn conn, Object? raw) {
    final m = Msg.decode(raw);
    if (m == null) return;
    final type = m['t'] as String;
    if (type == Msg.ping) {
      _send(conn, Msg.pong);
      return;
    }
    if (conn.playerId == null) {
      if (type == Msg.hello) _hello(conn, m);
      return;
    }
    final player = game.players[conn.playerId];
    if (player == null) {
      _send(conn, Msg.kicked);
      conn.socket.close();
      return;
    }
    try {
      _handle(conn, player, type, m);
    } catch (_) {
      _error(conn, 'badRequest');
    }
    _flush();
  }

  void _hello(_Conn conn, Map<String, dynamic> m) {
    if (m['v'] != Msg.protocolVersion) {
      _error(conn, 'versionMismatch');
      conn.socket.close();
      return;
    }
    final profileJson = m['profile'];
    if (profileJson is! Map) return;
    final profile = Profile.fromJson(Map<String, dynamic>.from(profileJson));

    final token = m['token'] as String?;
    var id = token == null ? null : _tokens[token];
    if (id != null && !game.players.containsKey(id) && id != hostId) {
      // Token from a removed player.
      id = null;
    }

    if (id == null) {
      final pw = password;
      if (pw != null && pw.isNotEmpty && m['password'] != pw) {
        _error(conn, 'wrongPassword');
        conn.socket.close();
        return;
      }
      id = _newId();
      final err = game.addPlayer(id, profile);
      if (err != null) {
        _error(conn, err);
        conn.socket.close();
        return;
      }
      final newToken = _newToken();
      _tokens[newToken] = id;
      conn.token = newToken;
    } else {
      if (!game.players.containsKey(id)) {
        final err = game.addPlayer(id, profile);
        if (err != null) {
          _error(conn, err);
          conn.socket.close();
          return;
        }
      } else if (game.phase == Phase.lobby) {
        game.updateProfile(id, profile);
      }
      conn.token = token;
      game.setConnected(id, true);
    }

    final old = _conns[id];
    if (old != null && old != conn) {
      old.playerId = null;
      old.socket.close(WebSocketStatus.normalClosure, 'replaced');
    }
    conn.playerId = id;
    _conns[id] = conn;
    _send(conn, Msg.welcome, {'you': id, 'token': conn.token, 'room': roomName});
    _syncChat(conn, force: true);
    _sentVersion = -1; // everyone gets the new player list
    _flush();
  }

  void _handle(_Conn conn, Player p, String type, Map<String, dynamic> m) {
    final now = _clock();
    final isHost = p.id == hostId;
    String? err;

    void hostOnly(String? Function() f) => err = isHost ? f() : 'hostOnly';

    switch (type) {
      case Msg.setProfile:
        final j = m['profile'];
        if (j is Map) {
          if (game.phase == Phase.lobby || game.phase == Phase.ended) {
            game.updateProfile(p.id, Profile.fromJson(Map<String, dynamic>.from(j)));
          } else {
            err = 'gameInProgress';
          }
        }
      case Msg.setSettings:
        hostOnly(() => game.updateSettings(GameSettings.fromJson(Map<String, dynamic>.from(m['settings'] as Map))));
      case Msg.start:
        hostOnly(() {
          final e = game.start(now);
          if (e == null) chat.resetForNewGame();
          return e;
        });
      case Msg.backToLobby:
        hostOnly(() {
          final e = game.backToLobby();
          if (e == null) _dropDisconnected();
          return e;
        });
      case Msg.kick:
        hostOnly(() {
          final target = m['id'] as String?;
          if (target == null || target == hostId) return 'badTarget';
          if (game.inGame) return 'gameInProgress';
          _removePlayer(target, kicked: true);
          return null;
        });
      case Msg.lock:
        hostOnly(() {
          game.setLocked(m['value'] == true);
          return null;
        });
      case Msg.pause:
        hostOnly(() => game.pause(now));
      case Msg.resume:
        hostOnly(() => game.resume(now));
      case Msg.skip:
        hostOnly(() => game.skip(now));
      case Msg.nightAction:
        err = game.nightAction(p.id, m['target'] as String?, now);
      case Msg.witch:
        err = game.witchAction(p.id, heal: m['heal'] == true, poison: m['poison'] as String?, now: now);
      case Msg.vote:
        err = game.vote(p.id, m['target'] as String?, now);
      case Msg.shoot:
        err = game.hunterShoot(p.id, m['target'] as String, now);
      case Msg.chat:
        final msg = chat.post(p, m['channel'] as String, m['text'] as String? ?? '', now,
            onError: (e) => err = e);
        if (msg != null) _deliverChat(msg);
      case Msg.openDm:
        final ch = chat.openDm(p, m['with'] as String);
        if (ch == null) {
          err = 'badTarget';
        } else {
          _send(conn, Msg.dmOpened, {'channel': ch});
        }
      case Msg.createRoom:
        final room = chat.createRoom(
            p, m['name'] as String? ?? '', (m['members'] as List? ?? const []).cast<String>());
        if (room == null) {
          err = 'tooManyRooms';
        } else {
          for (final id in room.members) {
            final c = _conns[id];
            if (c != null) _syncChat(c, force: true);
          }
        }
      case Msg.leaveRoom:
        final roomId = m['room'] as String;
        final members = {...?chat.rooms[roomId]?.members};
        chat.leaveRoom(p, roomId);
        for (final id in members) {
          final c = _conns[id];
          if (c != null) _syncChat(c, force: true);
        }
      case Msg.leave:
        if (game.inGame) {
          game.setConnected(p.id, false);
        } else if (p.id != hostId) {
          _removePlayer(p.id, kicked: false);
        }
    }
    if (err != null) _error(conn, err!);
  }

  void _removePlayer(String id, {required bool kicked}) {
    final c = _conns.remove(id);
    if (c != null) {
      if (kicked) _send(c, Msg.kicked);
      c.playerId = null;
      c.socket.close();
    }
    _tokens.removeWhere((_, pid) => pid == id);
    game.removePlayer(id);
    chat.removePlayer(id);
  }

  /// Players who left during a game are removed once it is over.
  void _dropDisconnected() {
    for (final p in game.players.values.toList()) {
      if (!p.connected && p.id != hostId) _removePlayer(p.id, kicked: false);
    }
  }

  // ------------------------------------------------------------- broadcast

  void _deliverChat(ChatMessage msg) {
    for (final c in _conns.values) {
      final p = game.players[c.playerId];
      if (p != null && chat.canRead(p, msg.channel)) {
        _send(c, Msg.chatMsg, {'msg': msg.toJson()});
      }
    }
  }

  /// What decides which channels a player can read. A change means the
  /// player needs a fresh chat history.
  String _chatAccessKey(Player p) =>
      '${p.alive}|${p.isNarrator}|${p.role?.name}|${game.inGame}|${chat.roomsFor(p).length}';

  void _syncChat(_Conn conn, {bool force = false}) {
    final p = game.players[conn.playerId];
    if (p == null) return;
    final key = _chatAccessKey(p);
    if (!force && key == conn.chatKey) return;
    conn.chatKey = key;
    _send(conn, Msg.chatSync, {
      'messages': [for (final m in chat.historyFor(p)) m.toJson()],
      'rooms': [for (final r in chat.roomsFor(p)) r.toJson()],
    });
  }

  /// Sends each player their own view if anything changed.
  void _flush() {
    if (game.version == _sentVersion) return;
    _sentVersion = game.version;
    final now = _clock();
    for (final c in _conns.values) {
      final id = c.playerId;
      if (id == null || !game.players.containsKey(id)) continue;
      _send(c, Msg.state, {'view': GameView.build(game, id, now)});
      _syncChat(c);
    }
  }

  String _newId() => List.generate(8, (_) => _secure.nextInt(16).toRadixString(16)).join();
  String _newToken() => List.generate(32, (_) => _secure.nextInt(16).toRadixString(16)).join();
}

class _Conn {
  _Conn(this.socket);
  final WebSocket socket;
  String? playerId;
  String? token;
  String? chatKey;
}
