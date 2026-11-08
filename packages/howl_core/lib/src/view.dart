import 'engine.dart';
import 'events.dart';
import 'player.dart';
import 'roles.dart';
import 'settings.dart';

/// What a client should be asked to do right now.
enum ActionKind { none, wolfKill, inspect, protect, witch, vote, hunterShoot }

/// A player as one particular viewer is allowed to see them.
class PlayerInfo {
  PlayerInfo({
    required this.id,
    required this.profile,
    required this.alive,
    required this.connected,
    required this.isHost,
    required this.isNarrator,
    this.role,
  });

  final String id;
  final Profile profile;
  final bool alive;
  final bool connected;
  final bool isHost;
  final bool isNarrator;

  /// Null when the viewer may not know it.
  final Role? role;

  String get name => profile.name;

  Map<String, dynamic> toJson() => {
        'id': id,
        'profile': profile.toJson(),
        'alive': alive,
        'connected': connected,
        'isHost': isHost,
        'isNarrator': isNarrator,
        if (role != null) 'role': role!.name,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
        id: j['id'] as String,
        profile: Profile.fromJson(Map<String, dynamic>.from(j['profile'] as Map)),
        alive: j['alive'] as bool,
        connected: j['connected'] as bool,
        isHost: j['isHost'] as bool,
        isNarrator: j['isNarrator'] as bool,
        role: j['role'] == null ? null : Role.fromName(j['role'] as String),
      );
}

/// Everything one player is allowed to know, sent after every change.
class GameView {
  GameView({
    required this.you,
    required this.hostId,
    required this.phase,
    required this.round,
    required this.remainingMs,
    required this.paused,
    required this.locked,
    required this.settings,
    required this.players,
    required this.events,
    required this.action,
    required this.targets,
    this.myChoice,
    this.wolfVotes = const {},
    this.votes = const {},
    this.voteTally = const {},
    this.seerResults = const {},
    this.witchVictim,
    this.witchHealAvailable = false,
    this.witchPoisonAvailable = false,
    this.currentHunter,
    this.winner,
    this.winnerIds = const [],
  });

  final String you;
  final String hostId;
  final Phase phase;
  final int round;
  final int remainingMs;
  final bool paused;
  final bool locked;
  final GameSettings settings;
  final List<PlayerInfo> players;
  final List<GameEvent> events;

  final ActionKind action;
  final List<String> targets;
  final String? myChoice;

  /// Wolves only: wolf id -> target id.
  final Map<String, String> wolfVotes;

  /// Voter -> target ("" = skip). Only when votes are public or it's yours.
  final Map<String, String> votes;
  final Map<String, int> voteTally;

  /// Seer only: target id -> role.
  final Map<String, Role> seerResults;

  final String? witchVictim;
  final bool witchHealAvailable;
  final bool witchPoisonAvailable;
  final String? currentHunter;
  final String? winner;
  final List<String> winnerIds;

  PlayerInfo? player(String id) => players.where((p) => p.id == id).firstOrNull;
  PlayerInfo get me => player(you)!;
  bool get isHost => you == hostId;
  Role? get myRole => me.role;

  static Map<String, dynamic> build(GameEngine g, String viewerId, int now) {
    final viewer = g.players[viewerId]!;
    final players = [
      for (final p in g.seated)
        PlayerInfo(
          id: p.id,
          profile: p.profile,
          alive: p.alive,
          connected: p.connected,
          isHost: p.isHost,
          isNarrator: p.isNarrator,
          role: g.canSeeRole(viewer, p) ? p.role : null,
        ).toJson(),
    ];

    var action = ActionKind.none;
    var targets = const <String>[];
    String? myChoice;
    final role = viewer.role;
    final active = viewer.alive && viewer.plays && !g.paused;

    if (active && g.phase == Phase.night && role != null) {
      switch (role.nightAction) {
        case NightAction.wolfKill:
          action = ActionKind.wolfKill;
          myChoice = g.wolfVotes[viewerId];
        case NightAction.inspect:
          action = g.nightDone.contains(viewerId) ? ActionKind.none : ActionKind.inspect;
          myChoice = g.nightChoice[viewerId];
        case NightAction.protect:
          action = ActionKind.protect;
          myChoice = g.nightChoice[viewerId];
        default:
          break;
      }
      if (action != ActionKind.none) targets = g.nightTargets(viewer);
    } else if (active && g.phase == Phase.witch && role == Role.witch) {
      action = ActionKind.witch;
      targets = [for (final p in g.alivePlayers) if (p.id != viewerId) p.id];
    } else if (active && g.phase == Phase.voting) {
      action = ActionKind.vote;
      targets = [for (final p in g.alivePlayers) if (p.id != viewerId) p.id];
      myChoice = g.votes.containsKey(viewerId) ? (g.votes[viewerId] ?? '') : null;
    } else if (g.phase == Phase.hunter && g.currentHunter?.id == viewerId && !g.paused) {
      action = ActionKind.hunterShoot;
      targets = [for (final p in g.alivePlayers) p.id];
    }

    final seesAll = viewer.isNarrator || g.phase == Phase.ended;
    final seesWolves = seesAll || role?.isWolf == true || (!viewer.alive && g.settings.deadSeeRoles);
    final showVotes = g.settings.publicVotes || seesAll;

    return {
      'you': viewerId,
      'hostId': g.hostId,
      'phase': g.phase.name,
      'round': g.round,
      'remainingMs': g.remainingMs(now),
      'paused': g.paused,
      'locked': g.locked,
      'settings': g.settings.toJson(),
      'players': players,
      'events': [for (final e in g.events) if (g.canSeeEvent(viewer, e)) e.toJson()],
      'action': action.name,
      'targets': targets,
      'myChoice': ?myChoice,
      if (seesWolves && (g.phase == Phase.night || g.phase == Phase.witch)) 'wolfVotes': g.wolfVotes,
      if (g.phase == Phase.voting)
        'votes': {
          for (final e in g.votes.entries)
            if (showVotes || e.key == viewerId) e.key: e.value ?? '',
        },
      if (g.phase == Phase.voting && showVotes) 'voteTally': g.voteTally,
      if (g.seerResults[viewerId] != null) 'seerResults': g.seerResults[viewerId],
      if (action == ActionKind.witch) ...{
        'witchVictim': g.nightVictim,
        'witchHeal': !g.witchHealUsed && g.nightVictim != null,
        'witchPoison': !g.witchPoisonUsed,
      },
      'currentHunter': ?g.currentHunter?.id,
      if (g.winner != null) 'winner': g.winner,
      'winnerIds': g.winnerIds,
    };
  }

  factory GameView.fromJson(Map<String, dynamic> j) {
    Map<String, String> strMap(Object? o) =>
        o == null ? const {} : Map<String, String>.from(o as Map);
    return GameView(
      you: j['you'] as String,
      hostId: j['hostId'] as String,
      phase: Phase.values.byName(j['phase'] as String),
      round: j['round'] as int,
      remainingMs: j['remainingMs'] as int,
      paused: j['paused'] as bool,
      locked: j['locked'] as bool,
      settings: GameSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)),
      players: [for (final p in j['players'] as List) PlayerInfo.fromJson(Map<String, dynamic>.from(p as Map))],
      events: [for (final e in j['events'] as List) GameEvent.fromJson(Map<String, dynamic>.from(e as Map))],
      action: ActionKind.values.byName(j['action'] as String),
      targets: (j['targets'] as List).cast<String>(),
      myChoice: j['myChoice'] as String?,
      wolfVotes: strMap(j['wolfVotes']),
      votes: strMap(j['votes']),
      voteTally: j['voteTally'] == null ? const {} : Map<String, int>.from(j['voteTally'] as Map),
      seerResults: {
        for (final e in strMap(j['seerResults']).entries) e.key: Role.fromName(e.value),
      },
      witchVictim: j['witchVictim'] as String?,
      witchHealAvailable: j['witchHeal'] == true,
      witchPoisonAvailable: j['witchPoison'] == true,
      currentHunter: j['currentHunter'] as String?,
      winner: j['winner'] as String?,
      winnerIds: (j['winnerIds'] as List? ?? const []).cast<String>(),
    );
  }
}
