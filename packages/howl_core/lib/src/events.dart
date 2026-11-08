/// Event types. Clients turn these into narrator lines in their language.
abstract final class Ev {
  static const gameStarted = 'gameStarted';
  static const roleAssigned = 'roleAssigned'; // private: role
  static const nightFalls = 'nightFalls'; // night
  static const wolvesChose = 'wolvesChose'; // wolves: target
  static const seerResult = 'seerResult'; // private: target, role
  static const witchTurn = 'witchTurn'; // private: target (may be null)
  static const dawn = 'dawn'; // night
  static const killed = 'killed'; // player, cause, role?
  static const noDeaths = 'noDeaths';
  static const discussion = 'discussion';
  static const votingStarted = 'votingStarted';
  static const votedOut = 'votedOut'; // player, role?, votes
  static const noElimination = 'noElimination'; // tie: bool
  static const hunterTurn = 'hunterTurn'; // player
  static const hunterMissed = 'hunterMissed'; // player
  static const gameOver = 'gameOver'; // winner
  static const paused = 'paused';
  static const resumed = 'resumed';
  static const skipped = 'skipped';
}

/// Why a player died.
abstract final class Cause {
  static const wolves = 'wolves';
  static const poison = 'poison';
  static const vote = 'vote';
  static const hunter = 'hunter';
}

/// Who may see an event.
abstract final class Audience {
  static const all = 'all';
  static const wolves = 'wolves';
  static const dead = 'dead';
  static String player(String id) => 'p:$id';
}

class GameEvent {
  GameEvent({
    required this.id,
    required this.type,
    required this.at,
    this.params = const {},
    this.audience = Audience.all,
  });

  final int id;
  final String type;
  final int at;
  final Map<String, dynamic> params;
  final String audience;

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'at': at, 'params': params};

  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
        id: j['id'] as int,
        type: j['type'] as String,
        at: j['at'] as int,
        params: Map<String, dynamic>.from(j['params'] as Map? ?? const {}),
      );
}
