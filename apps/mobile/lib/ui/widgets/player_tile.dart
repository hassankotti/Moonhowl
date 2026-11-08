import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';

import '../../l10n.dart';
import '../theme.dart';
import 'common.dart';

/// One player in a grid: avatar, name, what the viewer may know.
class PlayerTile extends StatelessWidget {
  const PlayerTile({
    super.key,
    required this.player,
    this.isYou = false,
    this.selectable = false,
    this.selected = false,
    this.badge,
    this.marks = const [],
    this.winner = false,
    this.onTap,
  });

  final PlayerInfo player;
  final bool isYou;

  /// Can be picked for the current action.
  final bool selectable;
  final bool selected;

  /// Small count in the corner, e.g. votes.
  final String? badge;

  /// Small emoji marks, e.g. 🐺 for each wolf who picked this player.
  final List<String> marks;
  final bool winner;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dead = !player.alive && !player.isNarrator;
    final ring = selected
        ? Palette.moon
        : (selectable ? Palette.violet : (winner ? Palette.forest : null));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: (!selectable && onTap == null && dead) ? .6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? Palette.moon.withValues(alpha: .12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AvatarView(profile: player.profile, size: 52, dead: dead, ring: ring),
                  if (dead) const Positioned(right: -4, bottom: -4, child: Text('💀', style: TextStyle(fontSize: 18))),
                  if (!player.connected)
                    const Positioned(left: -4, top: -4, child: Icon(Icons.wifi_off, size: 16, color: Palette.blood)),
                  if (player.isHost)
                    const Positioned(left: -4, bottom: -4, child: Text('👑', style: TextStyle(fontSize: 15))),
                  if (badge != null)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Palette.blood, borderRadius: BorderRadius.circular(10)),
                        child: Text(badge!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isYou ? '${player.name} (${s.t('you')})' : player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: isYou ? FontWeight.w700 : FontWeight.w500),
              ),
              if (player.isNarrator)
                Text(s.t('narrator'), style: const TextStyle(fontSize: 10, color: Palette.moon))
              else if (player.role != null)
                FittedBox(child: RoleChip(role: player.role!, small: true)),
              if (marks.isNotEmpty) Text(marks.join(), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
