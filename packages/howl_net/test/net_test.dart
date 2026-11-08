import 'dart:async';

import 'package:howl_core/howl_core.dart';
import 'package:howl_net/howl_net.dart';
import 'package:test/test.dart';

Future<void> until(bool Function() cond, {Duration timeout = const Duration(seconds: 5)}) async {
  final end = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException('condition not met');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late HowlServer server;
  final clients = <HowlClient>[];

  Future<HowlClient> join(String name, {String? token, String? password}) async {
    final c = HowlClient(host: '127.0.0.1', port: server.port, profile: Profile(name: name), token: token, password: password);
    clients.add(c);
    await c.connect();
    return c;
  }

  setUp(() async {
    server = HowlServer(roomName: 'Test room', preferredPort: 0, password: 'pw');
    await server.start();
  });

  tearDown(() async {
    for (final c in clients) {
      await c.dispose();
    }
    clients.clear();
    await server.stop();
  });

  test('info endpoint', () async {
    final info = await HowlClient.probe('127.0.0.1', server.port);
    expect(info?['name'], 'Test room');
    expect(info?['hasPassword'], isTrue);
  });

  test('wrong password is refused, host needs none', () async {
    final bad = await join('Bad', password: 'nope');
    await until(() => bad.status == ConnectionStatus.closed);
    expect(bad.closeReason, 'wrongPassword');

    final host = await join('Host', token: server.hostToken);
    await until(() => host.view != null);
    expect(host.view!.isHost, isTrue);
  });

  test('full game over the network', () async {
    final host = await join('Host', token: server.hostToken);
    final others = [for (var i = 1; i <= 4; i++) await join('P$i', password: 'pw')];
    final all = [host, ...others];
    await until(() => all.every((c) => c.view?.players.length == 5));

    // Only the host may change settings.
    others.first.setSettings(GameSettings(roles: {Role.wolf: 3}));
    final err = await others.first.errors.first;
    expect(err, 'hostOnly');

    host.setSettings(GameSettings(roles: {Role.wolf: 1, Role.seer: 1}, nightSeconds: 30));
    host.startGame();
    await until(() => all.every((c) => c.view?.phase == Phase.night));

    // Everyone knows only their own role.
    for (final c in all) {
      final known = c.view!.players.where((p) => p.role != null).toList();
      expect(known.map((p) => p.id), [c.playerId]);
    }

    final wolf = all.firstWhere((c) => c.view!.myRole == Role.wolf);
    final seer = all.firstWhere((c) => c.view!.myRole == Role.seer);
    final victim = all.firstWhere((c) => c != wolf && c != seer);

    seer.nightAction(wolf.playerId);
    await until(() => seer.view!.seerResults[wolf.playerId] == Role.wolf);

    wolf.nightAction(victim.playerId);
    await until(() => all.every((c) => c.view?.phase == Phase.day));
    expect(host.view!.player(victim.playerId!)!.alive, isFalse);
    // Role revealed on death.
    expect(host.view!.player(victim.playerId!)!.role, isNotNull);

    // The dead victim cannot talk in public; the living can.
    victim.sendChat(Channels.public, 'I am dead');
    expect(await victim.errors.first, 'deadCannotTalk');
    seer.sendChat(Channels.public, 'It is ${wolf.view!.me.name}!');
    await until(() => all.every((c) => c.messages.any((m) => m.text.startsWith('It is'))));

    // Host skips the discussion, then the village votes the wolf out.
    host.skip();
    await until(() => all.every((c) => c.view?.phase == Phase.voting));
    for (final c in all) {
      if (c == victim) continue;
      c.vote(c == wolf ? seer.playerId : wolf.playerId);
    }
    await until(() => all.every((c) => c.view?.phase == Phase.ended));
    expect(host.view!.winner, 'village');
    // Everything is revealed at the end.
    expect(victim.view!.players.every((p) => p.role != null), isTrue);
  });

  test('reconnecting with the token keeps the seat and role', () async {
    final host = await join('Host', token: server.hostToken);
    final ps = [for (var i = 1; i <= 4; i++) await join('P$i', password: 'pw')];
    await until(() => host.view?.players.length == 5);
    host.setSettings(GameSettings(roles: {Role.wolf: 1}));
    host.startGame();
    await until(() => ps.first.view?.phase == Phase.night);

    final first = ps.first;
    final id = first.playerId!;
    final role = first.view!.myRole;
    final token = first.token;
    await first.dispose();
    await until(() => host.view!.player(id)!.connected == false);

    final again = await join('P1', token: token);
    await until(() => again.view != null);
    expect(again.playerId, id);
    expect(again.view!.myRole, role);
    await until(() => host.view!.player(id)!.connected);
  });

  test('new players cannot join a running game', () async {
    final host = await join('Host', token: server.hostToken);
    for (var i = 1; i <= 3; i++) {
      await join('P$i', password: 'pw');
    }
    await until(() => host.view?.players.length == 4);
    host.setSettings(GameSettings(roles: {Role.wolf: 1}));
    host.startGame();
    await until(() => host.view?.phase == Phase.night);
    final late = await join('Late', password: 'pw');
    await until(() => late.status == ConnectionStatus.closed);
    expect(late.closeReason, 'gameInProgress');
  });

  test('kick, rooms and DMs', () async {
    final host = await join('Host', token: server.hostToken);
    final a = await join('A', password: 'pw');
    final b = await join('B', password: 'pw');
    final c = await join('C', password: 'pw');
    await until(() => host.view?.players.length == 4);

    a.createRoom('secret', [b.playerId!]);
    await until(() => a.rooms.length == 1 && b.rooms.length == 1);
    expect(c.rooms, isEmpty);
    a.sendChat(a.rooms.first.channel, 'hello room');
    await until(() => b.messages.any((m) => m.text == 'hello room'));

    a.openDm(c.playerId!);
    final dm = await a.dmOpened.first;
    a.sendChat(dm, 'just you');
    await until(() => c.messages.any((m) => m.text == 'just you'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(b.messages.any((m) => m.text == 'just you'), isFalse);

    host.kick(c.playerId!);
    await until(() => c.status == ConnectionStatus.closed);
    expect(c.closeReason, 'kicked');
    await until(() => host.view!.players.length == 3);
  });
}
