import 'roles.dart';

/// Room settings chosen by the host before the game starts.
class GameSettings {
  GameSettings({
    Map<Role, int>? roles,
    this.nightSeconds = 45,
    this.witchSeconds = 20,
    this.discussionSeconds = 90,
    this.votingSeconds = 45,
    this.hunterSeconds = 20,
    this.hostIsNarrator = false,
    this.revealRoleOnDeath = true,
    this.deadSeeRoles = true,
    this.allowPrivateChats = true,
    this.publicVotes = true,
    bool? autoRoles,
  })  : roles = roles ?? const {},
        autoRoles = autoRoles ?? roles == null;

  /// Count of each special role chosen by the host. Players left over
  /// become villagers. Ignored while [autoRoles] is on.
  final Map<Role, int> roles;

  /// Pick a balanced role set for however many players are in the room.
  final bool autoRoles;

  /// The roles a game with [players] players would actually use.
  Map<Role, int> rolesFor(int players) => autoRoles ? defaultRolesFor(players) : roles;
  final int nightSeconds;
  final int witchSeconds;
  final int discussionSeconds;
  final int votingSeconds;
  final int hunterSeconds;

  /// When true the host runs the game and gets no role.
  final bool hostIsNarrator;
  final bool revealRoleOnDeath;

  /// Dead players can see every role (they can only talk to other dead).
  final bool deadSeeRoles;
  final bool allowPrivateChats;

  /// Everyone sees who voted for whom during the day vote.
  final bool publicVotes;

  static const int minPlayers = 4;
  static const int maxPlayers = 16;

  /// A balanced default role set for [players] players.
  static Map<Role, int> defaultRolesFor(int players) {
    final wolves = players >= 12 ? 3 : (players >= 7 ? 2 : 1);
    return {
      Role.wolf: wolves,
      Role.seer: 1,
      Role.guardian: players >= 6 ? 1 : 0,
      Role.witch: players >= 8 ? 1 : 0,
      Role.hunter: players >= 7 ? 1 : 0,
      Role.mayor: players >= 10 ? 1 : 0,
      Role.jester: players >= 9 ? 1 : 0,
    }..removeWhere((_, n) => n == 0);
  }

  static int specialCount(Map<Role, int> roles) =>
      roles.entries.where((e) => e.key != Role.villager).fold(0, (s, e) => s + e.value);

  /// Returns an error code if these settings cannot start a game for
  /// [playerCount] role-holding players, or null when they can.
  String? validateFor(int playerCount) {
    if (playerCount < minPlayers) return 'notEnoughPlayers';
    if (playerCount > maxPlayers) return 'tooManyPlayers';
    final roles = rolesFor(playerCount);
    final wolves = roles[Role.wolf] ?? 0;
    if (wolves < 1) return 'needWolf';
    if (specialCount(roles) > playerCount) return 'tooManyRoles';
    if (wolves * 2 >= playerCount) return 'tooManyWolves';
    return null;
  }

  GameSettings copyWith({
    Map<Role, int>? roles,
    int? nightSeconds,
    int? witchSeconds,
    int? discussionSeconds,
    int? votingSeconds,
    int? hunterSeconds,
    bool? hostIsNarrator,
    bool? revealRoleOnDeath,
    bool? deadSeeRoles,
    bool? allowPrivateChats,
    bool? publicVotes,
    bool? autoRoles,
  }) =>
      GameSettings(
        roles: roles ?? Map.of(this.roles),
        autoRoles: autoRoles ?? (roles != null ? false : this.autoRoles),
        nightSeconds: nightSeconds ?? this.nightSeconds,
        witchSeconds: witchSeconds ?? this.witchSeconds,
        discussionSeconds: discussionSeconds ?? this.discussionSeconds,
        votingSeconds: votingSeconds ?? this.votingSeconds,
        hunterSeconds: hunterSeconds ?? this.hunterSeconds,
        hostIsNarrator: hostIsNarrator ?? this.hostIsNarrator,
        revealRoleOnDeath: revealRoleOnDeath ?? this.revealRoleOnDeath,
        deadSeeRoles: deadSeeRoles ?? this.deadSeeRoles,
        allowPrivateChats: allowPrivateChats ?? this.allowPrivateChats,
        publicVotes: publicVotes ?? this.publicVotes,
      );

  Map<String, dynamic> toJson() => {
        'roles': {for (final e in roles.entries) e.key.name: e.value},
        'autoRoles': autoRoles,
        'nightSeconds': nightSeconds,
        'witchSeconds': witchSeconds,
        'discussionSeconds': discussionSeconds,
        'votingSeconds': votingSeconds,
        'hunterSeconds': hunterSeconds,
        'hostIsNarrator': hostIsNarrator,
        'revealRoleOnDeath': revealRoleOnDeath,
        'deadSeeRoles': deadSeeRoles,
        'allowPrivateChats': allowPrivateChats,
        'publicVotes': publicVotes,
      };

  factory GameSettings.fromJson(Map<String, dynamic> j) {
    int sec(String k, int def, {int min = 5, int max = 600}) {
      final v = j[k];
      return v is int ? v.clamp(min, max) : def;
    }

    final rolesJson = (j['roles'] as Map?) ?? const {};
    final roles = <Role, int>{};
    for (final e in rolesJson.entries) {
      final role = Role.values.where((r) => r.name == e.key).firstOrNull;
      final n = e.value;
      if (role != null && n is int && n > 0) roles[role] = n.clamp(0, 16);
    }
    final d = GameSettings();
    return GameSettings(
      roles: roles,
      autoRoles: j['autoRoles'] == true,
      nightSeconds: sec('nightSeconds', d.nightSeconds),
      witchSeconds: sec('witchSeconds', d.witchSeconds),
      discussionSeconds: sec('discussionSeconds', d.discussionSeconds),
      votingSeconds: sec('votingSeconds', d.votingSeconds),
      hunterSeconds: sec('hunterSeconds', d.hunterSeconds),
      hostIsNarrator: j['hostIsNarrator'] == true,
      revealRoleOnDeath: j['revealRoleOnDeath'] != false,
      deadSeeRoles: j['deadSeeRoles'] != false,
      allowPrivateChats: j['allowPrivateChats'] != false,
      publicVotes: j['publicVotes'] != false,
    );
  }
}
