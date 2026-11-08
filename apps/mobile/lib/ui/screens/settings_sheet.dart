import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';

import '../../l10n.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showSettingsSheet(BuildContext context, Session session) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SettingsSheet(session: session),
    );

/// Host-only editor for roles, timers and rules.
class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.session});

  final Session session;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late GameSettings _s = widget.session.view!.settings;

  int get _players {
    final v = widget.session.view!;
    return _s.hostIsNarrator ? v.players.length - 1 : v.players.length;
  }

  Map<Role, int> get _roles => _s.rolesFor(_players);

  void _setRole(Role r, int n) {
    final roles = Map.of(_roles);
    if (n <= 0) {
      roles.remove(r);
    } else {
      roles[r] = n;
    }
    setState(() => _s = _s.copyWith(roles: roles));
  }

  void _apply() {
    widget.session.client.setSettings(_s);
    widget.session.store.saveLastSettings(_s);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final villagers = _players - GameSettings.specialCount(_roles);
    final error = _s.validateFor(_players);

    Widget timer(String key, int value, GameSettings Function(int) update, {int min = 10, int max = 300}) => Row(
          children: [
            SizedBox(width: 90, child: Text(s.t(key))),
            Expanded(
              child: Slider(
                value: value.clamp(min, max).toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: (max - min) ~/ 5,
                label: '$value',
                onChanged: (x) => setState(() => _s = update(x.round())),
              ),
            ),
            SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.end)),
          ],
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .9,
      maxChildSize: .95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Palette.mist.withValues(alpha: .4), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          SectionTitle(
            s.t('roles'),
            trailing: TextButton(
              onPressed: _s.autoRoles ? null : () => setState(() => _s = _s.copyWith(autoRoles: true)),
              child: Text(s.t('autoRoles')),
            ),
          ),
          for (final r in Role.values.where((r) => r != Role.villager))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(roleEmoji[r]!, style: const TextStyle(fontSize: 26)),
              title: Text(s.role(r)),
              subtitle: Text(s.roleDesc(r), style: const TextStyle(fontSize: 12, color: Palette.mist)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: (_roles[r] ?? 0) > 0 ? () => _setRole(r, (_roles[r] ?? 0) - 1) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(width: 20, child: Text('${_roles[r] ?? 0}', textAlign: TextAlign.center)),
                  IconButton(
                    onPressed: () => _setRole(r, (_roles[r] ?? 0) + 1),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
          Text(
            '${roleEmoji[Role.villager]} ${s.t('villagersFill', {'n': villagers < 0 ? 0 : villagers})}',
            style: const TextStyle(color: Palette.mist),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s.error(error), style: const TextStyle(color: Palette.blood)),
            ),
          SectionTitle(s.t('timers')),
          timer('timer.night', _s.nightSeconds, (x) => _s.copyWith(nightSeconds: x)),
          timer('timer.witch', _s.witchSeconds, (x) => _s.copyWith(witchSeconds: x), max: 120),
          timer('timer.discussion', _s.discussionSeconds, (x) => _s.copyWith(discussionSeconds: x), max: 600),
          timer('timer.voting', _s.votingSeconds, (x) => _s.copyWith(votingSeconds: x)),
          timer('timer.hunter', _s.hunterSeconds, (x) => _s.copyWith(hunterSeconds: x), max: 120),
          SectionTitle(s.t('settings')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.t('opt.narrator')),
            value: _s.hostIsNarrator,
            onChanged: (x) => setState(() => _s = _s.copyWith(hostIsNarrator: x)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.t('opt.reveal')),
            value: _s.revealRoleOnDeath,
            onChanged: (x) => setState(() => _s = _s.copyWith(revealRoleOnDeath: x)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.t('opt.deadSee')),
            value: _s.deadSeeRoles,
            onChanged: (x) => setState(() => _s = _s.copyWith(deadSeeRoles: x)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.t('opt.publicVotes')),
            value: _s.publicVotes,
            onChanged: (x) => setState(() => _s = _s.copyWith(publicVotes: x)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.t('opt.private')),
            value: _s.allowPrivateChats,
            onChanged: (x) => setState(() => _s = _s.copyWith(allowPrivateChats: x)),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _apply, child: Text(s.t('save'))),
        ],
      ),
    );
  }
}
