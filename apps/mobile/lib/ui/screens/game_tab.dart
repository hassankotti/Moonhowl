import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';

import '../../l10n.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/player_tile.dart';

/// The game itself: phase and timer, narrator line, your role, actions.
class GameTab extends StatelessWidget {
  const GameTab({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final v = session.view!;
    if (v.phase == Phase.ended) return _EndView(session: session);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        _PhaseHeader(session: session),
        const SizedBox(height: 12),
        if (!v.me.isNarrator) _RoleCard(view: v),
        if (v.action == ActionKind.witch) ...[
          const SizedBox(height: 12),
          _WitchPanel(session: session),
        ],
        const SizedBox(height: 4),
        _PlayersGrid(session: session),
        if (v.action == ActionKind.vote) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => session.client.vote(null),
            icon: Icon(v.myChoice == '' ? Icons.check_circle : Icons.do_not_disturb_alt),
            label: Text(v.myChoice == '' ? S.of(context).t('youVotedSkip') : S.of(context).t('skipVote')),
          ),
        ],
      ],
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = session.view!;
    final night = v.phase == Phase.night || v.phase == Phase.witch;
    final (icon, color) = switch (v.phase) {
      Phase.night => ('🌙', Palette.violet),
      Phase.witch => ('🧪', Palette.violet),
      Phase.day => ('☀️', Palette.day),
      Phase.voting => ('🗳️', Palette.moon),
      Phase.hunter => ('🏹', Palette.blood),
      _ => ('🌕', Palette.moon),
    };
    final ms = session.client.remainingMs();
    final urgent = ms <= 5000 && !v.paused;
    final lastEvent = v.events.where((e) => e.type != Ev.roleAssigned).lastOrNull;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: night
              ? [const Color(0xFF221C4A), Palette.surface]
              : [const Color(0xFF4A3420), Palette.surface],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.phase(v.phase), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
                    Text('#${v.round}', style: const TextStyle(color: Palette.mist, fontSize: 12)),
                  ],
                ),
              ),
              v.paused
                  ? Chip(label: Text(s.t('paused')), avatar: const Icon(Icons.pause, size: 16))
                  : Text(
                      formatSeconds(ms),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: urgent ? Palette.blood : Colors.white,
                      ),
                    ),
            ],
          ),
          if (lastEvent != null) ...[
            const Divider(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📜 ', style: TextStyle(fontSize: 16)),
                Expanded(child: Text(s.event(lastEvent, session.nameOf), style: const TextStyle(fontSize: 15))),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .2), borderRadius: BorderRadius.circular(12)),
            child: Text(s.guidance(v), style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Your role, hidden until tapped so neighbours can't peek.
class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.view});

  final GameView view;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = widget.view;
    final role = v.myRole;
    if (role == null) return const SizedBox.shrink();
    final pack = role.isWolf ? v.players.where((p) => p.role?.isWolf == true && p.id != v.you).toList() : const [];

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _shown = !_shown),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: !_shown
                ? Row(
                    children: [
                      const Text('🂠', style: TextStyle(fontSize: 30)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(s.t('tapReveal'), style: const TextStyle(fontWeight: FontWeight.w600))),
                      const Icon(Icons.visibility_outlined, color: Palette.mist),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(roleEmoji[role]!, style: const TextStyle(fontSize: 40)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.t('yourRole'), style: const TextStyle(color: Palette.mist, fontSize: 12)),
                                Text(s.role(role), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                                Text(s.t('teamLabel', {'team': s.team(role.team)}),
                                    style: const TextStyle(color: Palette.mist, fontSize: 12)),
                              ],
                            ),
                          ),
                          const Icon(Icons.visibility_off_outlined, color: Palette.mist),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s.roleDesc(role)),
                      if (pack.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('${s.t('wolfPack')}: ${pack.map((p) => p.name).join('، ')}',
                            style: const TextStyle(color: Palette.blood, fontWeight: FontWeight.w600)),
                      ],
                      if (v.seerResults.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(s.t('seerKnown'), style: const TextStyle(color: Palette.mist, fontSize: 12)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final e in v.seerResults.entries)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${v.player(e.key)?.name ?? '?'}: '),
                                  RoleChip(role: e.value, small: true),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PlayersGrid extends StatelessWidget {
  const _PlayersGrid({required this.session});

  final Session session;

  Future<void> _onPick(BuildContext context, PlayerInfo p) async {
    final s = S.of(context);
    final v = session.view!;
    final c = session.client;
    switch (v.action) {
      case ActionKind.wolfKill:
      case ActionKind.protect:
        c.nightAction(v.myChoice == p.id ? null : p.id);
      case ActionKind.inspect:
        if (await confirm(context, '🔮 ${p.name}?')) c.nightAction(p.id);
      case ActionKind.vote:
        c.vote(p.id);
      case ActionKind.hunterShoot:
        if (await confirm(context, '🏹 ${s.t('shoot')} ${p.name}?')) c.shoot(p.id);
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = session.view!;
    final targets = v.targets.toSet();
    final picking = v.action != ActionKind.none && v.action != ActionKind.witch;

    // Wolf picks and votes shown as marks / badges.
    final wolfMarks = <String, int>{};
    for (final t in v.wolfVotes.values) {
      wolfMarks[t] = (wolfMarks[t] ?? 0) + 1;
    }

    final players = v.players.where((p) => !p.isNarrator).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(picking ? s.t('chooseTarget') : s.t('players')),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: .7,
          children: [
            for (final p in players)
              PlayerTile(
                player: p,
                isYou: p.id == v.you,
                selectable: picking && targets.contains(p.id),
                selected: v.myChoice == p.id,
                badge: v.phase == Phase.voting && (v.voteTally[p.id] ?? 0) > 0 ? '${v.voteTally[p.id]}' : null,
                marks: [
                  ...List.filled(wolfMarks[p.id] ?? 0, '🐺'),
                  if (v.phase == Phase.voting && v.settings.publicVotes)
                    ...v.votes.entries.where((e) => e.value == p.id).map((_) => '✋'),
                ],
                onTap: picking && targets.contains(p.id) ? () => _onPick(context, p) : null,
              ),
          ],
        ),
        if (v.phase == Phase.voting && v.votes.isNotEmpty && v.settings.publicVotes) ...[
          SectionTitle(s.t('votes')),
          for (final e in v.votes.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${v.player(e.key)?.name ?? '?'} ← ${e.value.isEmpty ? s.t('skipVote') : (v.player(e.value)?.name ?? '?')}',
                style: const TextStyle(color: Palette.mist),
              ),
            ),
        ],
      ],
    );
  }
}

class _WitchPanel extends StatefulWidget {
  const _WitchPanel({required this.session});

  final Session session;

  @override
  State<_WitchPanel> createState() => _WitchPanelState();
}

class _WitchPanelState extends State<_WitchPanel> {
  bool _heal = false;
  String? _poison;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = widget.session.view!;
    final victim = v.witchVictim;
    return Card(
      color: const Color(0xFF2A1F4D),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              victim == null ? s.t('noVictim') : s.t('healQuestion', {'p': v.player(victim)?.name ?? '?'}),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (v.witchHealAvailable)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('💚 ${s.t('heal')}'),
                value: _heal,
                onChanged: (x) => setState(() => _heal = x),
              ),
            if (v.witchPoisonAvailable) ...[
              const SizedBox(height: 6),
              Text(s.t('poisonPick'), style: const TextStyle(color: Palette.mist)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final id in v.targets)
                    ChoiceChip(
                      label: Text(v.player(id)?.name ?? '?'),
                      selected: _poison == id,
                      onSelected: (on) => setState(() => _poison = on ? id : null),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => widget.session.client.witch(heal: false),
                    child: Text(s.t('doNothing')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: (_heal || _poison != null)
                        ? () => widget.session.client.witch(heal: _heal, poison: _poison)
                        : null,
                    child: Text(s.t('confirm')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EndView extends StatelessWidget {
  const _EndView({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final v = session.view!;
    final won = v.winnerIds.contains(v.you);
    final emoji = switch (v.winner) {
      'wolves' => '🐺',
      'jester' => '🃏',
      _ => '🏡',
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(s.t('gameOver'), style: const TextStyle(color: Palette.mist)),
                const SizedBox(height: 6),
                Text(s.winner(v.winner),
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                if (!v.me.isNarrator) ...[
                  const SizedBox(height: 10),
                  Text(won ? '🎉' : '🥀', style: const TextStyle(fontSize: 30)),
                ],
              ],
            ),
          ),
        ),
        SectionTitle(s.t('allRoles')),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: .72,
          children: [
            for (final p in v.players.where((p) => !p.isNarrator))
              PlayerTile(player: p, isYou: p.id == v.you, winner: v.winnerIds.contains(p.id)),
          ],
        ),
        const SizedBox(height: 20),
        if (v.isHost)
          FilledButton.icon(
            onPressed: session.client.backToLobby,
            icon: const Icon(Icons.replay),
            label: Text(s.t('backToLobby')),
          ),
      ],
    );
  }
}
