import 'dart:math';

import 'events.dart';
import 'player.dart';
import 'roles.dart';
import 'settings.dart';

enum Phase { lobby, night, witch, day, voting, hunter, ended }

/// The full, authoritative game state. Runs only on the host.
///
/// Every method that changes state takes `now` (ms since epoch) so the engine
/// has no hidden clock and is easy to test. Methods that reject an action
/// return an error code; null means success.
class GameEngine {
  GameEngine({required this.hostId, GameSettings? settings, Random? random})
      : settings = settings ?? GameSettings(),
        _rng = random ?? Random();

  final Random _rng;
  final String hostId;
  GameSettings settings;

  final Map<String, Player> players = {};
  Phase phase = Phase.lobby;

  /// Number of the current (or last) night. Day N follows night N.
  int round = 0;
  int? phaseEndsAt;
  int? _pausedRemaining;
  bool get paused => _pausedRemaining != null;

  bool locked = false;

  // Night state.
  final Map<String, String> wolfVotes = {};
  final Map<String, String> nightChoice = {}; // seer / guardian choices
  final Set<String> nightDone = {};
  String? lastProtected;
  String? nightVictim;
  bool witchHealUsed = false;
  bool witchPoisonUsed = false;
  bool _witchHeals = false;
  String? _witchPoison;

  /// Seer results: seer id -> {target id: role name}.
  final Map<String, Map<String, String>> seerResults = {};

  // Day vote: voter -> target id, or null to skip.
  final Map<String, String?> votes = {};

  // Hunters who still need to shoot, and where to go afterwards.
  final List<String> _pendingHunters = [];
  Phase _afterHunter = Phase.day;

  String? winner;
  final List<String> winnerIds = [];

  final List<GameEvent> events = [];
  int _eventSeq = 0;
  int _seatSeq = 0;

  /// Bumped on every change so the server knows when to broadcast.
  int version = 0;

  // ---------------------------------------------------------------- queries

  Iterable<Player> get seated => players.values.toList()..sort((a, b) => a.seat - b.seat);
  Iterable<Player> get roleHolders => players.values.where((p) => p.plays);
  Iterable<Player> get alivePlayers => roleHolders.where((p) => p.alive);
  Iterable<Player> aliveWith(Role r) => alivePlayers.where((p) => p.role == r);
  bool get inGame => phase != Phase.lobby && phase != Phase.ended;

  Player? get currentHunter =>
      phase == Phase.hunter && _pendingHunters.isNotEmpty ? players[_pendingHunters.first] : null;

  Player? get narrator => players.values.where((p) => p.isNarrator).firstOrNull;

  /// Remaining time in the current phase.
  int remainingMs(int now) {
    if (_pausedRemaining != null) return _pausedRemaining!;
    final end = phaseEndsAt;
    return end == null ? 0 : max(0, end - now);
  }

  // ----------------------------------------------------------------- lobby

  String? addPlayer(String id, Profile profile) {
    if (players.containsKey(id)) return null;
    if (phase != Phase.lobby) return 'gameInProgress';
    if (locked && id != hostId) return 'roomLocked';
    if (players.length >= GameSettings.maxPlayers + 1) return 'roomFull';
    players[id] = Player(id: id, profile: profile, isHost: id == hostId)..seat = _seatSeq++;
    _touch();
    return null;
  }

  void removePlayer(String id) {
    if (players.remove(id) != null) _touch();
  }

  void setConnected(String id, bool connected) {
    final p = players[id];
    if (p == null || p.connected == connected) return;
    p.connected = connected;
    _touch();
  }

  void updateProfile(String id, Profile profile) {
    final p = players[id];
    if (p == null) return;
    p.profile = profile;
    _touch();
  }

  String? updateSettings(GameSettings s) {
    if (phase != Phase.lobby && phase != Phase.ended) return 'gameInProgress';
    settings = s;
    _touch();
    return null;
  }

  void setLocked(bool value) {
    locked = value;
    _touch();
  }

  /// Number of players that would receive a role with the current settings.
  int get rolePlayerCount => settings.hostIsNarrator ? players.length - 1 : players.length;

  String? start(int now) {
    if (phase != Phase.lobby && phase != Phase.ended) return 'gameInProgress';
    final error = settings.validateFor(rolePlayerCount);
    if (error != null) return error;

    _reset();
    final pool = <Role>[
      for (final e in settings.roles.entries)
        if (e.key != Role.villager) ...List.filled(e.value, e.key),
    ];
    final holders = <Player>[];
    for (final p in seated) {
      p.isNarrator = settings.hostIsNarrator && p.isHost;
      p.alive = !p.isNarrator;
      p.role = null;
      if (p.plays) holders.add(p);
    }
    while (pool.length < holders.length) {
      pool.add(Role.villager);
    }
    pool.shuffle(_rng);
    for (var i = 0; i < holders.length; i++) {
      holders[i].role = pool[i];
    }

    _emit(Ev.gameStarted, now, {'players': holders.length});
    for (final p in holders) {
      _emit(Ev.roleAssigned, now, {'role': p.role!.name}, Audience.player(p.id));
    }
    _startNight(now);
    return null;
  }

  /// Sends everyone back to the lobby, keeping players and settings.
  String? backToLobby() {
    if (phase != Phase.ended) return 'gameInProgress';
    _reset();
    for (final p in players.values) {
      p.role = null;
      p.alive = true;
      p.isNarrator = false;
    }
    phase = Phase.lobby;
    events.clear();
    _touch();
    return null;
  }

  void _reset() {
    round = 0;
    phaseEndsAt = null;
    _pausedRemaining = null;
    wolfVotes.clear();
    nightChoice.clear();
    nightDone.clear();
    lastProtected = null;
    nightVictim = null;
    witchHealUsed = false;
    witchPoisonUsed = false;
    seerResults.clear();
    votes.clear();
    _pendingHunters.clear();
    winner = null;
    winnerIds.clear();
    events.clear();
  }

  // --------------------------------------------------------- host controls

  String? pause(int now) {
    if (!inGame || paused) return 'cannotPause';
    _pausedRemaining = remainingMs(now);
    _emit(Ev.paused, now);
    return null;
  }

  String? resume(int now) {
    if (!paused) return 'notPaused';
    phaseEndsAt = now + _pausedRemaining!;
    _pausedRemaining = null;
    _emit(Ev.resumed, now);
    return null;
  }

  /// Ends the current phase right away.
  String? skip(int now) {
    if (!inGame) return 'notInGame';
    if (paused) resume(now);
    _emit(Ev.skipped, now);
    _endPhase(now);
    return null;
  }

  /// Moves the game on when the phase timer runs out. Call about once a second.
  void tick(int now) {
    if (!inGame || paused) return;
    final end = phaseEndsAt;
    if (end != null && now >= end) _endPhase(now);
  }

  void _endPhase(int now) {
    switch (phase) {
      case Phase.night:
        _endNightActions(now);
      case Phase.witch:
        _resolveNight(now);
      case Phase.day:
        _startVoting(now);
      case Phase.voting:
        _resolveVote(now);
      case Phase.hunter:
        final h = _pendingHunters.removeAt(0);
        _emit(Ev.hunterMissed, now, {'player': h});
        _nextAfterDeaths(now);
      case Phase.lobby:
      case Phase.ended:
        break;
    }
  }

  // ------------------------------------------------------------------ night

  void _startNight(int now) {
    round++;
    phase = Phase.night;
    wolfVotes.clear();
    nightChoice.clear();
    nightDone.clear();
    nightVictim = null;
    _witchHeals = false;
    _witchPoison = null;
    phaseEndsAt = now + settings.nightSeconds * 1000;
    _emit(Ev.nightFalls, now, {'night': round});
    _maybeFinishNight(now);
  }

  /// Players whose input the night phase waits for.
  Iterable<Player> get _nightActors => alivePlayers.where((p) =>
      p.role!.nightAction == NightAction.wolfKill ||
      p.role!.nightAction == NightAction.inspect ||
      p.role!.nightAction == NightAction.protect);

  /// Valid targets for [actor]'s night action.
  List<String> nightTargets(Player actor) {
    final alive = alivePlayers.toList();
    switch (actor.role?.nightAction) {
      case NightAction.wolfKill:
        return [for (final p in alive) if (!p.role!.isWolf) p.id];
      case NightAction.inspect:
        return [for (final p in alive) if (p.id != actor.id) p.id];
      case NightAction.protect:
        return [for (final p in alive) if (p.id != lastProtected) p.id];
      default:
        return const [];
    }
  }

  String? nightAction(String playerId, String? target, int now) {
    if (phase != Phase.night || paused) return 'wrongPhase';
    final actor = players[playerId];
    if (actor == null || !actor.alive || !actor.plays) return 'notAllowed';
    final action = actor.role!.nightAction;
    if (action == NightAction.none || action == NightAction.witch) return 'notAllowed';
    if (action == NightAction.inspect && nightDone.contains(playerId)) return 'alreadyActed';
    if (target != null && !nightTargets(actor).contains(target)) return 'badTarget';

    switch (action) {
      case NightAction.wolfKill:
        if (target == null) {
          wolfVotes.remove(playerId);
          nightDone.remove(playerId);
        } else {
          wolfVotes[playerId] = target;
          nightDone.add(playerId);
        }
      case NightAction.inspect:
        if (target == null) return 'badTarget';
        nightChoice[playerId] = target;
        nightDone.add(playerId);
        final role = players[target]!.role!;
        (seerResults[playerId] ??= {})[target] = role.name;
        _emit(Ev.seerResult, now, {'target': target, 'role': role.name}, Audience.player(playerId));
      case NightAction.protect:
        if (target == null) {
          nightChoice.remove(playerId);
          nightDone.remove(playerId);
        } else {
          nightChoice[playerId] = target;
          nightDone.add(playerId);
        }
      default:
        break;
    }
    _touch();
    _maybeFinishNight(now);
    return null;
  }

  void _maybeFinishNight(int now) {
    if (phase != Phase.night) return;
    if (_nightActors.every((p) => nightDone.contains(p.id))) {
      _endNightActions(now);
    }
  }

  /// The victim the wolves have agreed on so far.
  String? get wolfTarget {
    if (wolfVotes.isEmpty) return null;
    final tally = <String, int>{};
    for (final t in wolfVotes.values) {
      tally[t] = (tally[t] ?? 0) + 1;
    }
    final top = tally.values.reduce(max);
    final leaders = [for (final e in tally.entries) if (e.value == top) e.key];
    return leaders.length == 1 ? leaders.first : null;
  }

  void _endNightActions(int now) {
    if (phase != Phase.night) return;
    // A tie between wolves is broken at random so a night is never wasted.
    var victim = wolfTarget;
    if (victim == null && wolfVotes.isNotEmpty) {
      final tally = <String, int>{};
      for (final t in wolfVotes.values) {
        tally[t] = (tally[t] ?? 0) + 1;
      }
      final top = tally.values.reduce(max);
      final leaders = [for (final e in tally.entries) if (e.value == top) e.key]..sort();
      victim = leaders[_rng.nextInt(leaders.length)];
    }
    nightVictim = victim;
    if (victim != null) {
      _emit(Ev.wolvesChose, now, {'target': victim}, Audience.wolves);
    }

    final witch = aliveWith(Role.witch).firstOrNull;
    final canHeal = !witchHealUsed && victim != null;
    if (witch != null && (canHeal || !witchPoisonUsed)) {
      phase = Phase.witch;
      phaseEndsAt = now + settings.witchSeconds * 1000;
      _emit(Ev.witchTurn, now, {'target': victim}, Audience.player(witch.id));
      _touch();
      return;
    }
    _resolveNight(now);
  }

  /// The witch's single decision for the night.
  String? witchAction(String playerId, {required bool heal, String? poison, required int now}) {
    if (phase != Phase.witch || paused) return 'wrongPhase';
    final witch = players[playerId];
    if (witch == null || !witch.alive || witch.role != Role.witch) return 'notAllowed';
    if (heal && (witchHealUsed || nightVictim == null)) return 'potionUsed';
    if (poison != null) {
      if (witchPoisonUsed) return 'potionUsed';
      final t = players[poison];
      if (t == null || !t.alive || !t.plays || t.id == playerId) return 'badTarget';
    }
    _witchHeals = heal;
    _witchPoison = poison;
    _resolveNight(now);
    return null;
  }

  void _resolveNight(int now) {
    final guardianTargets = {
      for (final g in aliveWith(Role.guardian))
        if (nightChoice[g.id] != null) nightChoice[g.id]!,
    };
    // One guardian keeps the "not the same person twice" rule simple.
    lastProtected = guardianTargets.length == 1 ? guardianTargets.first : null;

    final deaths = <String, String>{};
    final victim = nightVictim;
    if (victim != null && !guardianTargets.contains(victim) && !_witchHeals) {
      deaths[victim] = Cause.wolves;
    }
    if (_witchHeals) witchHealUsed = true;
    final poison = _witchPoison;
    if (poison != null) {
      witchPoisonUsed = true;
      deaths.putIfAbsent(poison, () => Cause.poison);
    }

    phase = Phase.day; // placeholder until we know where to go
    _emit(Ev.dawn, now, {'night': round});
    if (deaths.isEmpty) _emit(Ev.noDeaths, now);
    for (final e in deaths.entries) {
      _kill(e.key, e.value, now);
    }
    _afterHunter = Phase.day;
    _nextAfterDeaths(now);
  }

  // -------------------------------------------------------------------- day

  void _startDay(int now) {
    phase = Phase.day;
    phaseEndsAt = now + settings.discussionSeconds * 1000;
    _emit(Ev.discussion, now, {'day': round});
  }

  void _startVoting(int now) {
    phase = Phase.voting;
    votes.clear();
    phaseEndsAt = now + settings.votingSeconds * 1000;
    _emit(Ev.votingStarted, now, {'day': round});
  }

  /// [target] null means "skip". Voting again changes the vote.
  String? vote(String playerId, String? target, int now) {
    if (phase != Phase.voting || paused) return 'wrongPhase';
    final voter = players[playerId];
    if (voter == null || !voter.alive || !voter.plays) return 'notAllowed';
    if (target != null) {
      final t = players[target];
      if (t == null || !t.alive || !t.plays || t.id == playerId) return 'badTarget';
    }
    votes[playerId] = target;
    _touch();
    if (alivePlayers.every((p) => votes.containsKey(p.id))) _resolveVote(now);
    return null;
  }

  /// Vote weight per target id ("" for skip).
  Map<String, int> get voteTally {
    final tally = <String, int>{};
    for (final e in votes.entries) {
      final weight = players[e.key]?.role?.voteWeight ?? 1;
      final key = e.value ?? '';
      tally[key] = (tally[key] ?? 0) + weight;
    }
    return tally;
  }

  void _resolveVote(int now) {
    if (phase != Phase.voting) return;
    final tally = voteTally;
    String? out;
    if (tally.isNotEmpty) {
      final top = tally.values.reduce(max);
      final leaders = [for (final e in tally.entries) if (e.value == top) e.key];
      if (leaders.length == 1 && leaders.first.isNotEmpty) out = leaders.first;
    }

    if (out == null) {
      _emit(Ev.noElimination, now, {'tie': tally.isNotEmpty});
      _afterHunter = Phase.night;
      _nextAfterDeaths(now);
      return;
    }

    final p = players[out]!;
    _emit(Ev.votedOut, now, {
      'player': out,
      'votes': tally[out],
      if (settings.revealRoleOnDeath) 'role': p.role!.name,
    });
    if (p.role == Role.jester) {
      p.alive = false;
      _finish('jester', [p.id], now);
      return;
    }
    _kill(out, Cause.vote, now, announce: false);
    _afterHunter = Phase.night;
    _nextAfterDeaths(now);
  }

  // ----------------------------------------------------------------- hunter

  String? hunterShoot(String playerId, String target, int now) {
    if (phase != Phase.hunter || paused) return 'wrongPhase';
    if (currentHunter?.id != playerId) return 'notAllowed';
    final t = players[target];
    if (t == null || !t.alive || !t.plays) return 'badTarget';
    _pendingHunters.removeAt(0);
    _kill(target, Cause.hunter, now);
    _nextAfterDeaths(now);
    return null;
  }

  // ------------------------------------------------------------ transitions

  void _kill(String id, String cause, int now, {bool announce = true}) {
    final p = players[id];
    if (p == null || !p.alive) return;
    p.alive = false;
    if (announce) {
      _emit(Ev.killed, now, {
        'player': id,
        'cause': cause,
        if (settings.revealRoleOnDeath) 'role': p.role!.name,
      });
    }
    if (p.role == Role.hunter) _pendingHunters.add(id);
  }

  /// After deaths: check for a winner, let hunters shoot, then continue.
  void _nextAfterDeaths(int now) {
    if (_checkWin(now)) return;
    // A hunter shot by another hunter is queued by _kill and shoots next.
    if (_pendingHunters.isNotEmpty) {
      phase = Phase.hunter;
      phaseEndsAt = now + settings.hunterSeconds * 1000;
      _emit(Ev.hunterTurn, now, {'player': _pendingHunters.first});
      return;
    }
    if (_afterHunter == Phase.day) {
      _startDay(now);
    } else {
      _startNight(now);
    }
  }

  bool _checkWin(int now) {
    final alive = alivePlayers.toList();
    final wolves = alive.where((p) => p.role!.isWolf).length;
    final others = alive.length - wolves;
    if (wolves == 0) {
      _finish('village', [for (final p in roleHolders) if (p.role!.team == Team.village) p.id], now);
      return true;
    }
    if (wolves >= others) {
      _finish('wolves', [for (final p in roleHolders) if (p.role!.isWolf) p.id], now);
      return true;
    }
    return false;
  }

  void _finish(String team, List<String> ids, int now) {
    phase = Phase.ended;
    phaseEndsAt = null;
    _pausedRemaining = null;
    _pendingHunters.clear();
    winner = team;
    winnerIds
      ..clear()
      ..addAll(ids);
    _emit(Ev.gameOver, now, {'winner': team});
  }

  // ---------------------------------------------------------------- helpers

  void _emit(String type, int now, [Map<String, dynamic> params = const {}, String audience = Audience.all]) {
    events.add(GameEvent(id: ++_eventSeq, type: type, at: now, params: params, audience: audience));
    _touch();
  }

  void _touch() => version++;

  /// Whether [viewer] may know [target]'s role right now.
  bool canSeeRole(Player viewer, Player target) {
    if (target.isNarrator || target.role == null) return false;
    if (viewer.id == target.id) return true;
    if (phase == Phase.ended || viewer.isNarrator) return true;
    if (viewer.plays && !viewer.alive && settings.deadSeeRoles) return true;
    if (viewer.role?.isWolf == true && target.role!.isWolf) return true;
    if (!target.alive && settings.revealRoleOnDeath) return true;
    return false;
  }

  bool canSeeEvent(Player viewer, GameEvent e) {
    if (e.audience == Audience.all) return true;
    if (viewer.isNarrator || phase == Phase.ended) return true;
    if (e.audience == Audience.wolves) {
      return viewer.role?.isWolf == true || (!viewer.alive && settings.deadSeeRoles);
    }
    if (e.audience == Audience.dead) return !viewer.alive;
    return e.audience == Audience.player(viewer.id);
  }
}
