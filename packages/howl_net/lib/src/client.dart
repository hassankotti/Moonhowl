import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:howl_core/howl_core.dart';

enum ConnectionStatus { connecting, connected, reconnecting, closed }

/// Errors after which retrying makes no sense.
const _fatalErrors = {'wrongPassword', 'roomLocked', 'gameInProgress', 'roomFull', 'versionMismatch'};

/// A player's connection to a host. Reconnects by itself when Wi-Fi drops
/// and keeps the latest [view] and chat history.
class HowlClient {
  HowlClient({
    required this.host,
    required this.port,
    required Profile profile,
    this.password,
    this.token,
  }) : _profile = profile;

  final String host;
  final int port;
  final String? password;
  Profile _profile;

  /// Seat token. Reusing it after a disconnect gets the same seat back.
  String? token;
  String? playerId;
  String? roomName;

  ConnectionStatus status = ConnectionStatus.connecting;

  /// Why the connection closed for good (an error code), if it did.
  String? closeReason;

  GameView? view;

  /// When [view] arrived, to run the countdown locally between updates.
  DateTime viewReceivedAt = DateTime.now();

  final List<ChatMessage> messages = [];
  List<ChatRoom> rooms = [];

  WebSocket? _socket;
  bool _disposed = false;
  int _attempt = 0;
  Timer? _retry;

  final _changes = StreamController<void>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final _chat = StreamController<ChatMessage>.broadcast();
  final _dms = StreamController<String>.broadcast();

  /// Fires whenever status, view, or chat changes.
  Stream<void> get changes => _changes.stream;

  /// Error codes sent by the host in reply to an action.
  Stream<String> get errors => _errors.stream;

  /// New chat messages as they arrive.
  Stream<ChatMessage> get chatMessages => _chat.stream;

  /// Channels of direct chats the host just opened for us.
  Stream<String> get dmOpened => _dms.stream;

  int remainingMs([DateTime? now]) {
    final v = view;
    if (v == null) return 0;
    if (v.paused) return v.remainingMs;
    final elapsed = (now ?? DateTime.now()).difference(viewReceivedAt).inMilliseconds;
    return (v.remainingMs - elapsed).clamp(0, v.remainingMs);
  }

  /// Fetches `/info` from a host to check it before joining.
  static Future<Map<String, dynamic>?> probe(String host, int port,
      {Duration timeout = const Duration(seconds: 3)}) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final req = await client.get(host, port, Net.infoPath).timeout(timeout);
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      final j = jsonDecode(body);
      return j is Map<String, dynamic> && j['app'] == 'moonhowl' ? j : null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> connect() async {
    if (_disposed) return;
    try {
      final ws = await WebSocket.connect('ws://$host:$port${Net.wsPath}')
          .timeout(const Duration(seconds: 5));
      if (_disposed) {
        await ws.close();
        return;
      }
      ws.pingInterval = const Duration(seconds: 4);
      _socket = ws;
      _attempt = 0;
      ws.listen(_onData, onDone: () => _onDone(ws), onError: (_) => _onDone(ws), cancelOnError: true);
      _sendRaw(Msg.hello, {
        'v': Msg.protocolVersion,
        'profile': _profile.toJson(),
        'token': ?token,
        'password': ?password,
      });
    } catch (_) {
      _scheduleRetry();
    }
  }

  void _onData(Object? raw) {
    final m = Msg.decode(raw);
    if (m == null) return;
    switch (m['t']) {
      case Msg.welcome:
        playerId = m['you'] as String;
        token = m['token'] as String?;
        roomName = m['room'] as String?;
        status = ConnectionStatus.connected;
      case Msg.state:
        view = GameView.fromJson(Map<String, dynamic>.from(m['view'] as Map));
        viewReceivedAt = DateTime.now();
      case Msg.chatSync:
        messages
          ..clear()
          ..addAll([for (final j in m['messages'] as List) ChatMessage.fromJson(Map<String, dynamic>.from(j as Map))]);
        rooms = [for (final j in m['rooms'] as List) ChatRoom.fromJson(Map<String, dynamic>.from(j as Map))];
      case Msg.chatMsg:
        final msg = ChatMessage.fromJson(Map<String, dynamic>.from(m['msg'] as Map));
        messages.add(msg);
        _chat.add(msg);
      case Msg.dmOpened:
        _dms.add(m['channel'] as String);
      case Msg.error:
        final code = m['code'] as String;
        if (_fatalErrors.contains(code) && status != ConnectionStatus.connected) {
          _close(code);
        }
        _errors.add(code);
      case Msg.kicked:
        _close('kicked');
    }
    if (!_changes.isClosed) _changes.add(null);
  }

  void _onDone(WebSocket ws) {
    if (_socket != ws) return;
    _socket = null;
    if (_disposed || status == ConnectionStatus.closed) return;
    if (ws.closeReason == 'hostClosed') {
      _close('hostClosed');
      _changes.add(null);
      return;
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed || status == ConnectionStatus.closed) return;
    status = playerId == null && _attempt >= 3 ? ConnectionStatus.closed : ConnectionStatus.reconnecting;
    if (status == ConnectionStatus.closed) {
      closeReason = 'unreachable';
      _changes.add(null);
      return;
    }
    _changes.add(null);
    _attempt++;
    final delay = Duration(milliseconds: (500 * _attempt).clamp(500, 3000));
    _retry?.cancel();
    _retry = Timer(delay, connect);
  }

  void _close(String reason) {
    status = ConnectionStatus.closed;
    closeReason = reason;
    _retry?.cancel();
    _socket?.close();
    _socket = null;
  }

  void _sendRaw(String type, [Map<String, dynamic> body = const {}]) {
    try {
      _socket?.add(Msg.encode(type, body));
    } catch (_) {}
  }

  // ------------------------------------------------------------- actions

  void setProfile(Profile p) {
    _profile = p;
    _sendRaw(Msg.setProfile, {'profile': p.toJson()});
  }

  void setSettings(GameSettings s) => _sendRaw(Msg.setSettings, {'settings': s.toJson()});
  void startGame() => _sendRaw(Msg.start);
  void backToLobby() => _sendRaw(Msg.backToLobby);
  void kick(String id) => _sendRaw(Msg.kick, {'id': id});
  void lock(bool value) => _sendRaw(Msg.lock, {'value': value});
  void pause() => _sendRaw(Msg.pause);
  void resume() => _sendRaw(Msg.resume);
  void skip() => _sendRaw(Msg.skip);
  void nightAction(String? target) => _sendRaw(Msg.nightAction, {'target': target});
  void witch({required bool heal, String? poison}) => _sendRaw(Msg.witch, {'heal': heal, 'poison': poison});
  void vote(String? target) => _sendRaw(Msg.vote, {'target': target});
  void shoot(String target) => _sendRaw(Msg.shoot, {'target': target});
  void sendChat(String channel, String text) => _sendRaw(Msg.chat, {'channel': channel, 'text': text});
  void openDm(String playerId) => _sendRaw(Msg.openDm, {'with': playerId});
  void createRoom(String name, List<String> members) =>
      _sendRaw(Msg.createRoom, {'name': name, 'members': members});
  void leaveRoom(String roomId) => _sendRaw(Msg.leaveRoom, {'room': roomId});

  /// Leaves the room for good.
  Future<void> leave() async {
    _sendRaw(Msg.leave);
    await dispose();
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    status = ConnectionStatus.closed;
    await _socket?.close();
    _socket = null;
    await _changes.close();
    await _errors.close();
    await _chat.close();
    await _dms.close();
  }
}
