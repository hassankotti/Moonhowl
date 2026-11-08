import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';

import '../../l10n.dart';
import '../../state/session.dart';
import '../theme.dart';

/// The narrator's story of the game so far, newest first.
class LogTab extends StatelessWidget {
  const LogTab({super.key, required this.session});

  final Session session;

  static String _icon(String type) => switch (type) {
        Ev.nightFalls => '🌙',
        Ev.dawn => '🌅',
        Ev.killed => '💀',
        Ev.votedOut => '⚖️',
        Ev.noDeaths => '🕊️',
        Ev.discussion => '💬',
        Ev.votingStarted => '🗳️',
        Ev.noElimination => '🤝',
        Ev.hunterTurn || Ev.hunterMissed => '🏹',
        Ev.seerResult => '🔮',
        Ev.wolvesChose => '🐺',
        Ev.witchTurn => '🧪',
        Ev.gameOver => '🏁',
        Ev.paused || Ev.resumed || Ev.skipped => '⏯️',
        _ => '📜',
      };

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final events = session.view!.events.reversed.toList();
    if (events.isEmpty) {
      return Center(child: Text(s.t('log.empty'), style: const TextStyle(color: Palette.mist)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final e = events[i];
        final big = e.type == Ev.nightFalls || e.type == Ev.dawn || e.type == Ev.gameOver;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: big ? Palette.surfaceHigh : Palette.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_icon(e.type), style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.event(e, session.nameOf),
                    style: TextStyle(fontWeight: big ? FontWeight.w700 : FontWeight.w400)),
              ),
            ],
          ),
        );
      },
    );
  }
}
