import 'engine.dart';
import 'player.dart';

/// Chat channel ids.
///
/// * `public`  – everyone; during the game only the living (and narrator)
///               may write, and not at night.
/// * `wolves`  – the wolf pack.
/// * `dead`    – the dead and the narrator.
/// * `dm:a|b`  – private chat between two players (ids sorted).
/// * `room:x`  – a group room created by a player.
abstract final class Channels {
  static const public = 'public';
  static const wolves = 'wolves';
  static const dead = 'dead';

  static String dm(String a, String b) {
    final ids = [a, b]..sort();
    return 'dm:${ids[0]}|${ids[1]}';
  }

  static List<String>? dmMembers(String channel) {
    if (!channel.startsWith('dm:')) return null;
    final parts = channel.substring(3).split('|');
    return parts.length == 2 ? parts : null;
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.channel,
    required this.from,
    required this.text,
    required this.at,
  });

  final int id;
  final String channel;
  final String from;
  final String text;
  final int at;

  static const int maxLength = 500;

  Map<String, dynamic> toJson() => {'id': id, 'channel': channel, 'from': from, 'text': text, 'at': at};

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as int,
        channel: j['channel'] as String,
        from: j['from'] as String,
        text: j['text'] as String,
        at: j['at'] as int,
      );
}

class ChatRoom {
  ChatRoom({required this.id, required this.name, required this.owner, required this.members});

  final String id;
  final String name;
  final String owner;
  final Set<String> members;

  String get channel => 'room:$id';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'owner': owner, 'members': members.toList()};

  factory ChatRoom.fromJson(Map<String, dynamic> j) => ChatRoom(
        id: j['id'] as String,
        name: j['name'] as String,
        owner: j['owner'] as String,
        members: {...(j['members'] as List).cast<String>()},
      );
}

/// Chat history and permission rules. Runs on the host.
class ChatHub {
  ChatHub(this.game);

  final GameEngine game;
  final Map<String, List<ChatMessage>> _history = {};
  final Map<String, ChatRoom> rooms = {};
  int _msgSeq = 0;
  int _roomSeq = 0;

  static const int historyPerChannel = 200;
  static const int maxRoomsPerPlayer = 5;

  Set<String>? _privateMembers(String channel) {
    final dm = Channels.dmMembers(channel);
    if (dm != null) return dm.toSet();
    if (channel.startsWith('room:')) return rooms[channel.substring(5)]?.members;
    return null;
  }

  bool canRead(Player p, String channel) {
    final ended = game.phase == Phase.ended || game.phase == Phase.lobby;
    switch (channel) {
      case Channels.public:
        return true;
      case Channels.wolves:
        return ended || p.isNarrator || p.role?.isWolf == true || (!p.alive && game.settings.deadSeeRoles);
      case Channels.dead:
        return ended || p.isNarrator || (p.plays && !p.alive);
    }
    final members = _privateMembers(channel);
    return members != null && members.contains(p.id);
  }

  /// Returns an error code, or null if [p] may write to [channel].
  String? canWrite(Player p, String channel) {
    final inGame = game.inGame;
    if (!canRead(p, channel)) return 'noAccess';
    if (!inGame) {
      // Lobby and after the game: anything readable is writable.
      return null;
    }
    if (p.isNarrator) return null;
    final dead = !p.alive;
    switch (channel) {
      case Channels.public:
        if (dead) return 'deadCannotTalk';
        if (game.phase == Phase.night || game.phase == Phase.witch) return 'nightSilence';
        return null;
      case Channels.wolves:
        return dead ? 'deadCannotTalk' : null;
      case Channels.dead:
        return null;
    }
    // Private chats during the game.
    if (!game.settings.allowPrivateChats) return 'privateChatsOff';
    if (dead) return 'deadCannotTalk';
    final members = _privateMembers(channel)!;
    final anyDead = members.map((id) => game.players[id]).any((m) => m != null && m.plays && !m.alive);
    if (anyDead) return 'memberDead';
    return null;
  }

  /// Stores a message. Returns it, or an error code via [onError].
  ChatMessage? post(Player p, String channel, String text, int now, {void Function(String)? onError}) {
    final clean = text.trim();
    if (clean.isEmpty) {
      onError?.call('emptyMessage');
      return null;
    }
    final error = canWrite(p, channel);
    if (error != null) {
      onError?.call(error);
      return null;
    }
    final msg = ChatMessage(
      id: ++_msgSeq,
      channel: channel,
      from: p.id,
      text: clean.length > ChatMessage.maxLength ? clean.substring(0, ChatMessage.maxLength) : clean,
      at: now,
    );
    final list = _history.putIfAbsent(channel, () => []);
    list.add(msg);
    if (list.length > historyPerChannel) list.removeAt(0);
    return msg;
  }

  /// Opens (or returns) a direct-message channel between two players.
  String? openDm(Player a, String otherId) {
    if (a.id == otherId || !game.players.containsKey(otherId)) return null;
    return Channels.dm(a.id, otherId);
  }

  ChatRoom? createRoom(Player owner, String name, Iterable<String> memberIds) {
    final owned = rooms.values.where((r) => r.owner == owner.id).length;
    if (owned >= maxRoomsPerPlayer) return null;
    var clean = name.trim();
    if (clean.isEmpty) clean = '#${_roomSeq + 1}';
    if (clean.length > 30) clean = clean.substring(0, 30);
    final members = {owner.id, ...memberIds.where(game.players.containsKey)};
    final room = ChatRoom(id: '${++_roomSeq}', name: clean, owner: owner.id, members: members);
    rooms[room.id] = room;
    return room;
  }

  void leaveRoom(Player p, String roomId) {
    final room = rooms[roomId];
    if (room == null) return;
    room.members.remove(p.id);
    if (room.members.isEmpty) {
      rooms.remove(roomId);
      _history.remove(room.channel);
    }
  }

  void removePlayer(String id) {
    for (final room in rooms.values.toList()) {
      if (room.members.contains(id)) {
        room.members.remove(id);
        if (room.members.isEmpty) {
          rooms.remove(room.id);
          _history.remove(room.channel);
        }
      }
    }
  }

  /// Clears game-only channels when a new game starts.
  void resetForNewGame() {
    _history.remove(Channels.wolves);
    _history.remove(Channels.dead);
  }

  List<ChatRoom> roomsFor(Player p) => [for (final r in rooms.values) if (r.members.contains(p.id)) r];

  /// All messages [p] may read, oldest first.
  List<ChatMessage> historyFor(Player p) {
    final out = <ChatMessage>[];
    for (final e in _history.entries) {
      if (canRead(p, e.key)) out.addAll(e.value);
    }
    out.sort((a, b) => a.id - b.id);
    return out;
  }
}
