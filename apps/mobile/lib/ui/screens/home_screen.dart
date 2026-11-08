import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../main.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'host_setup_screen.dart';
import 'join_screen.dart';
import 'profile_screen.dart';
import 'room_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _rejoin(BuildContext context) async {
    final store = AppScope.read(context);
    final seat = store.savedSeat;
    final profile = store.profile;
    if (seat == null || profile == null) return;
    final session = await Session.join(
      store: store,
      profile: profile,
      host: seat.host,
      port: seat.port,
      password: seat.password,
      token: seat.token,
    );
    if (!context.mounted) return;
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => RoomScreen(session: session)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final store = AppScope.of(context);
    final profile = store.profile!;
    final stats = store.stats;
    final seat = store.savedSeat;
    final fav = stats.favoriteRole;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s.t('app'),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Palette.moon)),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: s.t('settings'),
                  onPressed: () => showModalBottomSheet<void>(context: context, builder: (_) => const _SettingsSheet()),
                ),
              ],
            ),
            Text(s.t('tagline'), style: const TextStyle(color: Palette.mist)),
            const SizedBox(height: 20),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const ProfileScreen())),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      AvatarView(profile: profile, size: 64),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(profile.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(s.t('editProfile'), style: const TextStyle(color: Palette.mist)),
                          ],
                        ),
                      ),
                      const Icon(Icons.edit_outlined, color: Palette.mist),
                    ],
                  ),
                ),
              ),
            ),
            SectionTitle(s.t('stats')),
            Row(
              children: [
                _Stat(label: s.t('gamesPlayed'), value: '${stats.games}'),
                const SizedBox(width: 10),
                _Stat(label: s.t('wins'), value: '${stats.wins}'),
                const SizedBox(width: 10),
                _Stat(
                  label: s.t('winRate'),
                  value: stats.games == 0 ? '–' : '${(stats.wins * 100 / stats.games).round()}%',
                ),
              ],
            ),
            if (fav != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('${s.t('favoriteRole')}: ', style: const TextStyle(color: Palette.mist)),
                  RoleChip(role: fav),
                ],
              ),
            ],
            const SizedBox(height: 28),
            if (seat != null) ...[
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: () => _rejoin(context),
                icon: const Icon(Icons.replay),
                label: Text('${s.t('rejoin')} · ${seat.room}'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const HostSetupScreen())),
              icon: const Icon(Icons.nightlight_round),
              label: Text(s.t('host')),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const JoinScreen())),
              icon: const Icon(Icons.wifi_find),
              label: Text(s.t('join')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: Palette.mist, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final store = AppScope.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(s.t('language')),
              trailing: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'ar', label: Text(s.t('lang.ar'))),
                  ButtonSegment(value: 'en', label: Text(s.t('lang.en'))),
                ],
                selected: {store.language},
                onSelectionChanged: (v) => store.setLanguage(v.first),
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.volume_up_outlined),
              title: Text(s.t('sound')),
              value: store.sound,
              onChanged: store.setSound,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.vibration),
              title: Text(s.t('vibration')),
              value: store.vibration,
              onChanged: store.setVibration,
            ),
          ],
        ),
      ),
    );
  }
}
