/// Teams a role can belong to. Decides who wins together.
enum Team { village, wolves, neutral }

/// What a role can do at night, if anything.
enum NightAction { none, wolfKill, inspect, protect, witch }

/// Every playable role.
///
/// Roles are stored by [name] in JSON, so renaming a value is a breaking
/// protocol change.
enum Role {
  villager(Team.village, NightAction.none),
  wolf(Team.wolves, NightAction.wolfKill),
  seer(Team.village, NightAction.inspect),
  guardian(Team.village, NightAction.protect),
  witch(Team.village, NightAction.witch),
  hunter(Team.village, NightAction.none),
  mayor(Team.village, NightAction.none),
  jester(Team.neutral, NightAction.none);

  const Role(this.team, this.nightAction);

  final Team team;
  final NightAction nightAction;

  bool get isWolf => team == Team.wolves;

  /// Weight of this role's day vote.
  int get voteWeight => this == Role.mayor ? 2 : 1;

  static Role fromName(String name) => Role.values.byName(name);
}
