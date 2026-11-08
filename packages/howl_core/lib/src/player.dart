import 'roles.dart';

/// What a player chooses about themselves. Lives on their own device.
class Profile {
  Profile({
    required this.name,
    this.color = 0xFF7E57C2,
    this.icon = 'wolf',
    this.photo,
  });

  final String name;

  /// ARGB color for the avatar background.
  final int color;

  /// Key of a built-in avatar icon.
  final String icon;

  /// Optional small JPEG avatar, base64 encoded.
  final String? photo;

  static const int maxNameLength = 20;
  static const int maxPhotoLength = 60000;

  /// Cleans up values that came over the network.
  factory Profile.fromJson(Map<String, dynamic> j) {
    var name = (j['name'] as String? ?? '').trim();
    if (name.length > maxNameLength) name = name.substring(0, maxNameLength);
    if (name.isEmpty) name = '?';
    final photo = j['photo'] as String?;
    return Profile(
      name: name,
      color: j['color'] is int ? j['color'] as int : 0xFF7E57C2,
      icon: j['icon'] as String? ?? 'wolf',
      photo: (photo != null && photo.length <= maxPhotoLength) ? photo : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': color,
        'icon': icon,
        if (photo != null) 'photo': photo,
      };

  Profile copyWith({String? name, int? color, String? icon, String? photo, bool clearPhoto = false}) =>
      Profile(
        name: name ?? this.name,
        color: color ?? this.color,
        icon: icon ?? this.icon,
        photo: clearPhoto ? null : (photo ?? this.photo),
      );
}

/// A player seat in a room, as the host sees it.
class Player {
  Player({required this.id, required this.profile, this.isHost = false});

  final String id;
  Profile profile;
  final bool isHost;

  Role? role;
  bool alive = true;
  bool connected = true;

  /// True for a host who runs the game without playing.
  bool isNarrator = false;

  /// Order players were seated in; used for a stable list.
  int seat = 0;

  bool get plays => !isNarrator;
}
