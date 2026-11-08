import 'dart:math';

import 'package:howl_core/howl_core.dart';
import 'package:test/test.dart';

/// Starts a game where player `pN` gets `roles[N]`.
GameEngine setup(List<Role> roles, {GameSettings? settings, int now = 0}) {
  final g = GameEngine(hostId: 'p0', random: Random(1), settings: settings);
  for (var i = 0; i < roles.length; i++) {
    expect(g.addPlayer('p$i', Profile(name: 'P$i')), isNull);
  }
  // Settings must be valid for the player count; roles are overridden below.
  g.settings = (settings ?? GameSettings()).copyWith(roles: {Role.wolf: 1});
  expect(g.start(now), isNull);
  for (var i = 0; i < roles.length; i++) {
    g.players['p$i']!.role = roles[i];
  }
  // start() may have finished the night early with the random roles; restart
  // the night with our roles in place.
  g.phase = Phase.night;
  g.wolfVotes.clear();
  g.nightChoice.clear();
  g.nightDone.clear();
  g.phaseEndsAt = now + g.settings.nightSeconds * 1000;
  return g;
}

const v = Role.villager;

void main() {
  group('lobby', () {
    test('rejects starting with too few players', () {
      final g = GameEngine(hostId: 'a');
      g.addPlayer('a', Profile(name: 'A'));
      g.addPlayer('b', Profile(name: 'B'));
      expect(g.start(0), 'notEnoughPlayers');
    });

    test('assigns every special role and fills with villagers', () {
      final g = GameEngine(hostId: 'p0', random: Random(3));
      for (var i = 0; i < 8; i++) {
        g.addPlayer('p$i', Profile(name: 'P$i'));
      }
      g.settings = GameSettings(roles: {Role.wolf: 2, Role.seer: 1, Role.witch: 1});
      expect(g.start(0), isNull);
      final roles = g.players.values.map((p) => p.role).toList();
      expect(roles.where((r) => r == Role.wolf).length, 2);
      expect(roles.where((r) => r == Role.seer).length, 1);
      expect(roles.where((r) => r == Role.villager).length, 4);
      expect(g.phase, Phase.night);
    });

    test('narrator host gets no role', () {
      final g = GameEngine(hostId: 'p0', random: Random(3));
      for (var i = 0; i < 6; i++) {
        g.addPlayer('p$i', Profile(name: 'P$i'));
      }
      g.settings = GameSettings(roles: {Role.wolf: 1}, hostIsNarrator: true);
      expect(g.start(0), isNull);
      expect(g.players['p0']!.isNarrator, isTrue);
      expect(g.players['p0']!.role, isNull);
      expect(g.alivePlayers.length, 5);
    });

    test('locked room refuses new players', () {
      final g = GameEngine(hostId: 'a')..addPlayer('a', Profile(name: 'A'));
      g.setLocked(true);
      expect(g.addPlayer('b', Profile(name: 'B')), 'roomLocked');
    });
  });

  group('night', () {
    test('wolves kill their target at dawn', () {
      final g = setup([Role.wolf, v, v, v, v]);
      expect(g.nightAction('p0', 'p1', 1000), isNull);
      // Only one night actor, so the night ends immediately.
      expect(g.phase, Phase.day);
      expect(g.players['p1']!.alive, isFalse);
      expect(g.events.any((e) => e.type == Ev.killed && e.params['player'] == 'p1'), isTrue);
    });

    test('wolves cannot target a wolf', () {
      final g = setup([Role.wolf, Role.wolf, v, v, v, v, v]);
      expect(g.nightAction('p0', 'p1', 0), 'badTarget');
    });

    test('guardian saves the victim and cannot repeat a target', () {
      final g = setup([Role.wolf, Role.guardian, v, v, v]);
      g.nightAction('p1', 'p2', 0);
      g.nightAction('p0', 'p2', 0);
      expect(g.players['p2']!.alive, isTrue);
      expect(g.events.any((e) => e.type == Ev.noDeaths), isTrue);
      expect(g.lastProtected, 'p2');

      g.skip(1); // day -> voting
      g.skip(2); // voting -> night (no votes)
      expect(g.phase, Phase.night);
      expect(g.nightAction('p1', 'p2', 3), 'badTarget');
    });

    test('seer learns a role privately', () {
      final g = setup([Role.wolf, Role.seer, v, v, v]);
      expect(g.nightAction('p1', 'p0', 0), isNull);
      expect(g.seerResults['p1'], {'p0': 'wolf'});
      final seerEvent = g.events.lastWhere((e) => e.type == Ev.seerResult);
      expect(g.canSeeEvent(g.players['p1']!, seerEvent), isTrue);
      expect(g.canSeeEvent(g.players['p2']!, seerEvent), isFalse);
      expect(g.nightAction('p1', 'p2', 0), 'alreadyActed');
    });

    test('a tie between wolves still kills one of the targets', () {
      final g = setup([Role.wolf, Role.wolf, v, v, v, v, v]);
      g.nightAction('p0', 'p2', 0);
      g.nightAction('p1', 'p3', 0);
      final dead = g.roleHolders.where((p) => !p.alive).map((p) => p.id).toList();
      expect(dead.length, 1);
      expect(['p2', 'p3'], contains(dead.single));
    });

    test('night ends on timer if someone does not act', () {
      final g = setup([Role.wolf, Role.seer, v, v, v]);
      g.nightAction('p0', 'p2', 0);
      expect(g.phase, Phase.night);
      g.tick(g.settings.nightSeconds * 1000);
      expect(g.phase, Phase.day);
      expect(g.players['p2']!.alive, isFalse);
    });
  });

  group('witch', () {
    test('heals the wolf victim once', () {
      final g = setup([Role.wolf, Role.witch, v, v, v]);
      g.nightAction('p0', 'p2', 0);
      expect(g.phase, Phase.witch);
      expect(g.nightVictim, 'p2');
      expect(g.witchAction('p1', heal: true, now: 0), isNull);
      expect(g.players['p2']!.alive, isTrue);
      expect(g.witchHealUsed, isTrue);
    });

    test('poison kills even a protected player', () {
      final g = setup([Role.wolf, Role.witch, Role.guardian, v, v, v, v]);
      g.nightAction('p2', 'p3', 0);
      g.nightAction('p0', 'p4', 0);
      expect(g.witchAction('p1', heal: false, poison: 'p3', now: 0), isNull);
      expect(g.players['p3']!.alive, isFalse);
      expect(g.players['p4']!.alive, isFalse);
    });

    test('witch with no potions left is skipped', () {
      final g = setup([Role.wolf, Role.witch, v, v, v, v, v]);
      g.witchHealUsed = true;
      g.witchPoisonUsed = true;
      g.nightAction('p0', 'p2', 0);
      expect(g.phase, Phase.day);
    });
  });

  group('voting', () {
    GameEngine toVoting(List<Role> roles) {
      final g = setup(roles);
      g.skip(0); // night -> day (no kill)
      g.skip(0); // day -> voting
      expect(g.phase, Phase.voting);
      return g;
    }

    test('majority eliminates and village wins when last wolf goes', () {
      final g = toVoting([Role.wolf, v, v, v, v]);
      for (final id in ['p1', 'p2', 'p3', 'p4']) {
        g.vote(id, 'p0', 0);
      }
      g.vote('p0', 'p1', 0);
      expect(g.phase, Phase.ended);
      expect(g.winner, 'village');
      expect(g.winnerIds, containsAll(['p1', 'p2', 'p3', 'p4']));
    });

    test('a tie eliminates nobody', () {
      final g = toVoting([Role.wolf, v, v, v, v, v]);
      g.vote('p0', 'p1', 0);
      g.vote('p1', 'p0', 0);
      g.vote('p2', 'p1', 0);
      g.vote('p3', 'p0', 0);
      g.vote('p4', null, 0);
      g.vote('p5', null, 0);
      expect(g.phase, Phase.night);
      expect(g.alivePlayers.length, 6);
    });

    test('mayor vote counts double', () {
      final g = toVoting([Role.wolf, Role.mayor, v, v, v, v]);
      g.vote('p1', 'p2', 0); // 2
      g.vote('p3', 'p4', 0); // 1
      g.tick(g.settings.votingSeconds * 1000);
      expect(g.players['p2']!.alive, isFalse);
    });

    test('jester wins when voted out', () {
      final g = toVoting([Role.wolf, Role.jester, v, v, v]);
      for (final id in ['p0', 'p2', 'p3', 'p4']) {
        g.vote(id, 'p1', 0);
      }
      g.vote('p1', 'p0', 0);
      expect(g.winner, 'jester');
      expect(g.winnerIds, ['p1']);
    });

    test('cannot vote for yourself or when dead', () {
      final g = toVoting([Role.wolf, v, v, v, v]);
      expect(g.vote('p1', 'p1', 0), 'badTarget');
      g.players['p2']!.alive = false;
      expect(g.vote('p2', 'p1', 0), 'notAllowed');
    });
  });

  group('hunter', () {
    test('shoots when killed at night, then day starts', () {
      final g = setup([Role.wolf, Role.hunter, v, v, v, v]);
      g.nightAction('p0', 'p1', 0);
      expect(g.phase, Phase.hunter);
      expect(g.currentHunter?.id, 'p1');
      expect(g.hunterShoot('p2', 'p0', 0), 'notAllowed');
      expect(g.hunterShoot('p1', 'p3', 0), isNull);
      expect(g.players['p3']!.alive, isFalse);
      expect(g.phase, Phase.day);
    });

    test('shooting the last wolf wins for the village', () {
      final g = setup([Role.wolf, Role.hunter, v, v, v, v]);
      g.nightAction('p0', 'p1', 0);
      g.hunterShoot('p1', 'p0', 0);
      expect(g.winner, 'village');
    });

    test('hunter turn times out', () {
      final g = setup([Role.wolf, Role.hunter, v, v, v, v]);
      g.nightAction('p0', 'p1', 0);
      g.tick(g.settings.hunterSeconds * 1000);
      expect(g.phase, Phase.day);
      expect(g.events.any((e) => e.type == Ev.hunterMissed), isTrue);
    });
  });

  test('wolves win at parity', () {
    final g = setup([Role.wolf, v, v, v]);
    g.nightAction('p0', 'p1', 0);
    expect(g.phase, Phase.day);
    g.skip(0);
    g.vote('p0', 'p2', 0);
    g.vote('p2', 'p0', 0);
    g.vote('p3', 'p2', 0);
    // p2 out -> 1 wolf vs 1 villager.
    expect(g.winner, 'wolves');
  });

  test('pause freezes the timer', () {
    final g = setup([Role.wolf, Role.seer, v, v, v]);
    g.pause(10000);
    final left = g.remainingMs(10000);
    g.tick(999999);
    expect(g.phase, Phase.night);
    expect(g.remainingMs(500000), left);
    g.resume(500000);
    expect(g.remainingMs(500000), left);
  });

  test('back to lobby keeps players', () {
    final g = setup([Role.wolf, v, v, v]);
    g.nightAction('p0', 'p1', 0);
    g.skip(0);
    g.vote('p0', 'p2', 0);
    g.vote('p2', 'p0', 0);
    g.vote('p3', 'p2', 0);
    expect(g.phase, Phase.ended);
    expect(g.backToLobby(), isNull);
    expect(g.players.length, 4);
    expect(g.players.values.every((p) => p.alive && p.role == null), isTrue);
  });

  group('visibility', () {
    test('wolves see each other, villagers see nobody', () {
      final g = setup([Role.wolf, Role.wolf, v, v, v, v, v]);
      final w0 = g.players['p0']!, w1 = g.players['p1']!, v2 = g.players['p2']!;
      expect(g.canSeeRole(w0, w1), isTrue);
      expect(g.canSeeRole(v2, w0), isFalse);
      expect(g.canSeeRole(w0, v2), isFalse);
    });

    test('view for a villager hides other roles', () {
      final g = setup([Role.wolf, v, v, v, v]);
      final view = GameView.fromJson(GameView.build(g, 'p1', 0));
      expect(view.myRole, Role.villager);
      expect(view.player('p0')!.role, isNull);
      expect(view.action, ActionKind.none);
    });

    test('view for a wolf has kill targets', () {
      final g = setup([Role.wolf, v, v, v, v]);
      final view = GameView.fromJson(GameView.build(g, 'p0', 0));
      expect(view.action, ActionKind.wolfKill);
      expect(view.targets, ['p1', 'p2', 'p3', 'p4']);
    });
  });

  group('chat', () {
    test('only wolves read the wolf channel', () {
      final g = setup([Role.wolf, v, v, v, v]);
      final hub = ChatHub(g);
      expect(hub.post(g.players['p0']!, Channels.wolves, 'hi', 0), isNotNull);
      expect(hub.historyFor(g.players['p1']!), isEmpty);
      expect(hub.historyFor(g.players['p0']!).length, 1);
    });

    test('public chat is silent at night and closed to the dead', () {
      final g = setup([Role.wolf, Role.seer, v, v, v]);
      final hub = ChatHub(g);
      String? err;
      hub.post(g.players['p2']!, Channels.public, 'x', 0, onError: (e) => err = e);
      expect(err, 'nightSilence');
      g.nightAction('p0', 'p2', 0);
      g.nightAction('p1', 'p3', 0);
      expect(g.phase, Phase.day);
      hub.post(g.players['p2']!, Channels.public, 'x', 0, onError: (e) => err = e);
      expect(err, 'deadCannotTalk');
      expect(hub.post(g.players['p2']!, Channels.dead, 'boo', 0), isNotNull);
      expect(hub.historyFor(g.players['p3']!).where((m) => m.channel == Channels.dead), isEmpty);
    });

    test('rooms and DMs are private to members', () {
      final g = setup([Role.wolf, v, v, v, v]);
      final hub = ChatHub(g);
      final room = hub.createRoom(g.players['p1']!, 'team', ['p2'])!;
      expect(hub.post(g.players['p2']!, room.channel, 'yo', 0), isNotNull);
      expect(hub.canRead(g.players['p3']!, room.channel), isFalse);
      final dm = hub.openDm(g.players['p1']!, 'p4')!;
      expect(hub.post(g.players['p4']!, dm, 'psst', 0), isNotNull);
      expect(hub.canRead(g.players['p2']!, dm), isFalse);
    });
  });

  test('address parsing', () {
    expect(Net.parseAddress('moonhowl://10.0.0.2:5000'), (host: '10.0.0.2', port: 5000));
    expect(Net.parseAddress('10.0.0.2'), (host: '10.0.0.2', port: Net.defaultPort));
    expect(Net.parseAddress('bad:port'), isNull);
  });
}
