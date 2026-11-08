import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';

import '../../l10n.dart';
import '../theme.dart';

/// A round avatar: emoji on a color, or the player's photo.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.profile, this.size = 48, this.dead = false, this.ring});

  final Profile profile;
  final double size;
  final bool dead;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final photo = profile.photo;
    Widget inner = photo != null
        ? ClipOval(child: Image.memory(base64Decode(photo), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true))
        : Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Color(profile.color), shape: BoxShape.circle),
            child: Text(profile.icon, style: TextStyle(fontSize: size * 0.5)),
          );
    if (dead) {
      inner = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2, 0.2, 0.2, 0, 0, //
          0.2, 0.2, 0.2, 0, 0,
          0.2, 0.2, 0.2, 0, 0,
          0, 0, 0, 0.7, 0,
        ]),
        child: inner,
      );
    }
    return Container(
      padding: EdgeInsets.all(ring == null ? 0 : 2.5),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
      child: inner,
    );
  }
}

/// Role badge: emoji and name.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.role, this.small = false});

  final Role role;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final color = role.isWolf ? Palette.blood : (role.team == Team.neutral ? Palette.violet : Palette.forest);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
      child: Text('${roleEmoji[role]} ${s.role(role)}',
          style: TextStyle(fontSize: small ? 11 : 13, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

Future<bool> confirm(BuildContext context, String message) async {
  final s = S.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(s.t('ok')),
        ),
      ],
    ),
  );
  return ok == true;
}

void showError(BuildContext context, String code) {
  final s = S.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(s.error(code)), duration: const Duration(seconds: 3)));
}

/// "1:05" style countdown text.
String formatSeconds(int ms) {
  final total = (ms / 1000).ceil();
  final m = total ~/ 60;
  final sec = total % 60;
  return '$m:${sec.toString().padLeft(2, '0')}';
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.mist, letterSpacing: .3)),
            ),
            ?trailing,
          ],
        ),
      );
}
