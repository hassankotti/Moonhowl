import 'dart:async';

import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';
import 'package:howl_net/howl_net.dart';

import '../../l10n.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'chat_tab.dart';
import 'game_tab.dart';
import 'lobby_tab.dart';
import 'log_tab.dart';

/// Everything inside a room: lobby or game, chat, and the story so far.
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.session});

  final Session session;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  int _tab = 0;
  final List<StreamSubscription<Object?>> _subs = [];

  Session get session => widget.session;

  @override
  void initState() {
    super.initState();
    _subs.add(session.errors.listen((code) {
      if (mounted) showError(context, code);
    }));
    _subs.add(session.dmOpened.listen((channel) {
      if (!mounted) return;
      session.knownDms.add(channel);
      setState(() => _tab = 1);
      openConversation(context, session, channel);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    session.dispose();
    super.dispose();
  }

  Future<void> _leave() async {
    final s = S.of(context);
    final closed = session.client.status == ConnectionStatus.closed;
    if (!closed && !await confirm(context, s.t(session.isHosting ? 'closeRoomConfirm' : 'leaveConfirm'))) return;
    await session.end();
    if (mounted) Navigator.pop(context);
  }

  void _setTab(int i) {
    setState(() => _tab = i);
    session.chatVisible = i == 1;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final client = session.client;
          final view = session.view;
          if (client.status == ConnectionStatus.closed) {
            return _Closed(reason: client.closeReason ?? 'unreachable', onLeave: _leave);
          }
          if (view == null) {
            return Scaffold(
              appBar: AppBar(leading: CloseButton(onPressed: _leave)),
              body: Center(child: Text(s.t('connecting'))),
            );
          }
          final inGame = view.phase != Phase.lobby;
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(icon: const Icon(Icons.logout), tooltip: s.t('leave'), onPressed: _leave),
              title: Text(session.roomName ?? s.t('app'), overflow: TextOverflow.ellipsis),
              actions: [if (view.isHost && view.phase != Phase.lobby && view.phase != Phase.ended) _HostMenu(session: session)],
            ),
            body: Column(
              children: [
                if (client.status == ConnectionStatus.reconnecting)
                  MaterialBanner(
                    backgroundColor: Palette.blood.withValues(alpha: .25),
                    content: Text(s.t('reconnecting')),
                    leading: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    actions: const [SizedBox.shrink()],
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      inGame ? GameTab(session: session) : LobbyTab(session: session),
                      ChatTab(session: session),
                      LogTab(session: session),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _setTab,
              destinations: [
                NavigationDestination(
                  icon: Icon(inGame ? Icons.nightlight_outlined : Icons.groups_outlined),
                  label: inGame ? s.t('tab.game') : s.t('players'),
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: session.totalUnread > 0,
                    label: Text('${session.totalUnread}'),
                    child: const Icon(Icons.chat_bubble_outline),
                  ),
                  label: s.t('tab.chat'),
                ),
                NavigationDestination(icon: const Icon(Icons.auto_stories_outlined), label: s.t('tab.log')),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HostMenu extends StatelessWidget {
  const _HostMenu({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final paused = session.view!.paused;
    return Row(
      children: [
        IconButton(
          tooltip: s.t(paused ? 'resume' : 'pause'),
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          onPressed: paused ? session.client.resume : session.client.pause,
        ),
        IconButton(tooltip: s.t('skip'), icon: const Icon(Icons.skip_next), onPressed: session.client.skip),
      ],
    );
  }
}

class _Closed extends StatelessWidget {
  const _Closed({required this.reason, required this.onLeave});

  final String reason;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🌑', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(s.error(reason), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 28),
              FilledButton(onPressed: onLeave, child: Text(s.t('ok'))),
            ],
          ),
        ),
      ),
    );
  }
}
