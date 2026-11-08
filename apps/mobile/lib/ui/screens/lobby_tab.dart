import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/player_tile.dart';
import 'settings_sheet.dart';

/// Waiting room: who's in, the join code (host), and the game settings.
class LobbyTab extends StatelessWidget {
  const LobbyTab({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = session.view!;
    final settings = v.settings;
    final rolePlayers = settings.hostIsNarrator ? v.players.length - 1 : v.players.length;
    final roles = settings.rolesFor(rolePlayers);
    final villagers = rolePlayers - GameSettings.specialCount(roles);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (session.isHosting) _JoinCard(session: session),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Text('📜', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Text(s.guidance(v), style: const TextStyle(color: Palette.mist))),
              ],
            ),
          ),
        ),
        SectionTitle(
          '${s.t('players')} (${v.players.length})',
          trailing: v.isHost
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.t('lockRoom'), style: const TextStyle(color: Palette.mist, fontSize: 13)),
                    Switch(value: v.locked, onChanged: session.client.lock),
                  ],
                )
              : null,
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: .78,
          children: [
            for (final p in v.players)
              PlayerTile(
                player: p,
                isYou: p.id == v.you,
                onTap: v.isHost && p.id != v.you
                    ? () async {
                        if (await confirm(context, s.t('kickConfirm', {'p': p.name}))) {
                          session.client.kick(p.id);
                        }
                      }
                    : null,
              ),
          ],
        ),
        SectionTitle(
          s.t('roles'),
          trailing: v.isHost
              ? TextButton.icon(
                  onPressed: () => showSettingsSheet(context, session),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(s.t('settings')),
                )
              : null,
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final e in roles.entries)
              if (e.value > 0 && e.key != Role.villager) _RoleCount(role: e.key, count: e.value),
            if (villagers > 0) _RoleCount(role: Role.villager, count: villagers),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          [
            '${s.t('timer.night')} ${settings.nightSeconds}s',
            '${s.t('timer.discussion')} ${settings.discussionSeconds}s',
            '${s.t('timer.voting')} ${settings.votingSeconds}s',
            if (settings.hostIsNarrator) s.t('narrator'),
          ].join(' · '),
          style: const TextStyle(color: Palette.mist, fontSize: 12),
        ),
        const SizedBox(height: 24),
        if (v.isHost)
          FilledButton.icon(
            onPressed: () {
              final err = settings.validateFor(rolePlayers);
              if (err != null) {
                showError(context, err);
                return;
              }
              session.client.startGame();
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(s.t('startGame')),
          )
        else
          Center(child: Text(s.t('waitingHost'), style: const TextStyle(color: Palette.mist))),
      ],
    );
  }
}

class _RoleCount extends StatelessWidget {
  const _RoleCount({required this.role, required this.count});

  final Role role;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoleChip(role: role),
          if (count > 1) Text(' ×$count', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: QrImageView(data: session.joinUri, size: 120, padding: EdgeInsets.zero),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.roomName ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(s.t('shareRoom'), style: const TextStyle(color: Palette.mist, fontSize: 13)),
                    const SizedBox(height: 8),
                    SelectableText(
                      session.displayAddress,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: 'monospace', color: Palette.moon, fontSize: 15),
                    ),
                    if (session.password != null || session.server?.password != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline, size: 14, color: Palette.mist),
                            const SizedBox(width: 4),
                            Text(session.server?.password ?? '', style: const TextStyle(color: Palette.mist)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
