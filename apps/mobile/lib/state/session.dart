import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:howl_core/howl_core.dart';
import 'package:howl_net/howl_net.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/discovery.dart';
import '../services/sfx.dart';
import 'local_store.dart';

/// One trip into a room: the connection, the hosted server if we host,
/// unread chat counts, sounds and stats.
class Session extends ChangeNotifier {
  Session._({required this.client, required this.store, this.server, this.ips = const [], this.password}) {
    sfx
      ..soundOn = store.sound
      ..vibrationOn = store.vibration;
    _subs.add(client.changes.listen((_) => _onChange()));
    _subs.add(client.chatMessages.listen(_onChat));
    _subs.add(client.errors.listen(_errors.add));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    WakelockPlus.enable().catchError((_) {});
  }

  final HowlClient client;
  final HowlServer? server;
  final LocalStore store;
  final String? password;

  /// This device's LAN addresses, when hosting.
  final List<String> ips;
  final SoundBoard sfx = SoundBoard();
  final RoomAdvertiser _advertiser = RoomAdvertiser();

  final List<StreamSubscription<Object?>> _subs = [];
  final _errors = StreamController<String>.broadcast();
  Timer? _ticker;

  /// Error codes to show as messages.
  Stream<String> get errors => _errors.stream;
  Stream<String> get dmOpened => client.dmOpened;

  bool get isHosting => server != null;
  GameView? get view => client.view;
  String? get roomName => client.roomName;

  /// Channel the chat screen has open, so it doesn't count as unread.
  String? openChannel;
  bool chatVisible = false;
  final Map<String, int> unread = {};

  /// Direct chats opened this session, so they show before the first message.
  final Set<String> knownDms = {};
  int get totalUnread => unread.values.fold(0, (a, b) => a + b);

  Phase? _lastPhase;
  int _lastEventId = 0;
  bool _statsRecorded = false;
  int _lastTickSecond = -1;

  /// Opens a room on this phone and joins it as host.
  static Future<Session> host({
    required LocalStore store,
    required Profile profile,
    required String roomName,
    String? password,
  }) async {
    final server = HowlServer(roomName: roomName, password: (password ?? '').isEmpty ? null : password);
    await server.start();
    final last = store.lastSettings;
    if (last != null) server.game.settings = last;
    final ips = await localIpv4Addresses();
    final client = HowlClient(host: '127.0.0.1', port: server.port, profile: profile, token: server.hostToken);
    final s = Session._(client: client, store: store, server: server, ips: ips);
    await s._advertiser.start(roomName: roomName, port: server.port, ips: ips);
    await client.connect();
    return s;
  }

  /// Joins someone else's room.
  static Future<Session> join({
    required LocalStore store,
    required Profile profile,
    required String host,
    required int port,
    String? password,
    String? token,
  }) async {
    final client = HowlClient(host: host, port: port, profile: profile, password: password, token: token);
    final s = Session._(client: client, store: store, password: password);
    await client.connect();
    return s;
  }

  String get joinUri {
    final ip = ips.isNotEmpty ? ips.first : '127.0.0.1';
    return Net.joinUri(ip, server?.port ?? Net.defaultPort);
  }

  String get displayAddress => ips.isNotEmpty ? '${ips.first}:${server?.port}' : '';

  String nameOf(String? id) => id == null ? '?' : (view?.player(id)?.name ?? '?');

  void _onChange() {
    final v = client.view;
    if (client.status == ConnectionStatus.connected && client.token != null && !isHosting &&
        client.token != _savedToken) {
      _savedToken = client.token;
      store.saveSeat(SavedSeat(
        host: client.host,
        port: client.port,
        token: client.token!,
        room: client.roomName ?? '',
        password: password,
      ));
    }
    if (client.status == ConnectionStatus.closed && !isHosting && _savedToken != null) {
      _savedToken = null;
      store.saveSeat(null);
    }
    if (v != null) _react(v);
    notifyListeners();
  }

  void _react(GameView v) {
    if (_lastPhase != v.phase) {
      final first = _lastPhase == null;
      _lastPhase = v.phase;
      if (!first) {
        switch (v.phase) {
          case Phase.night:
            sfx.play(Sfx.night);
          case Phase.day:
            sfx.play(Sfx.day);
          case Phase.voting:
            sfx.play(Sfx.vote);
          case Phase.ended:
            final won = v.winnerIds.contains(v.you);
            sfx.play(won ? Sfx.win : Sfx.lose);
          default:
            break;
        }
      }
      if (v.phase == Phase.night && v.round == 1) _statsRecorded = false;
      if (v.phase == Phase.lobby) _statsRecorded = false;
    }

    // Deaths and my turn.
    for (final e in v.events.where((e) => e.id > _lastEventId)) {
      if (_lastEventId == 0) break;
      if (e.type == Ev.killed || e.type == Ev.votedOut) sfx.play(Sfx.death);
      if (e.params['player'] == v.you && (e.type == Ev.killed || e.type == Ev.votedOut)) {
        sfx.buzz(strong: true);
      }
    }
    if (v.events.isNotEmpty) _lastEventId = v.events.last.id;

    if (v.action != ActionKind.none && v.myChoice == null && _lastActionKey != '${v.phase}${v.round}') {
      _lastActionKey = '${v.phase}${v.round}';
      sfx.play(Sfx.turn);
      sfx.buzz();
    }

    if (v.phase == Phase.ended && !_statsRecorded) {
      _statsRecorded = true;
      final role = v.myRole;
      if (role != null && !v.me.isNarrator) {
        store.recordGame(role: role, won: v.winnerIds.contains(v.you));
      }
    }
  }

  String _lastActionKey = '';
  String? _savedToken;

  void _onTick() {
    final v = client.view;
    if (v == null || v.paused) return;
    final secs = (client.remainingMs() / 1000).ceil();
    if (secs != _lastTickSecond) {
      _lastTickSecond = secs;
      if (secs > 0 && secs <= 5 && v.action != ActionKind.none) sfx.play(Sfx.tick);
      notifyListeners(); // drives the countdown
    }
  }

  void _onChat(ChatMessage m) {
    if (m.from == client.playerId) return;
    if (chatVisible && openChannel == m.channel) return;
    unread[m.channel] = (unread[m.channel] ?? 0) + 1;
    sfx.play(Sfx.message);
  }

  void markRead(String channel) {
    if (unread.remove(channel) != null) notifyListeners();
  }

  /// Leaves the room (and closes it when hosting).
  Future<void> end() async {
    await store.saveSeat(null);
    if (isHosting) {
      final s = server!;
      await store.saveLastSettings(s.game.settings);
      await client.dispose();
      await _advertiser.stop();
      await s.stop();
    } else {
      await client.leave();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _errors.close();
    sfx.dispose();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }
}
