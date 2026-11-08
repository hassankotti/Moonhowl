import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';

import '../../l10n.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// A chat the player can open, with a display name.
class _Channel {
  _Channel(this.id, this.title, this.icon, {this.room});

  final String id;
  final String title;
  final Widget icon;
  final ChatRoom? room;
}

List<_Channel> _channelsFor(BuildContext context, Session session) {
  final s = S.of(context);
  final v = session.view!;
  final me = v.me;
  final inGame = v.phase != Phase.lobby && v.phase != Phase.ended;
  final out = <_Channel>[
    _Channel(Channels.public, s.t('chan.public'), const Text('🏘️', style: TextStyle(fontSize: 24))),
  ];
  final seesWolves = !inGame || me.isNarrator || me.role?.isWolf == true || (!me.alive && v.settings.deadSeeRoles);
  final hasWolfMessages = session.client.messages.any((m) => m.channel == Channels.wolves);
  if (inGame ? seesWolves : hasWolfMessages) {
    out.add(_Channel(Channels.wolves, s.t('chan.wolves'), const Text('🐺', style: TextStyle(fontSize: 24))));
  }
  final seesDead = inGame ? (me.isNarrator || (!me.alive && !me.isNarrator)) : session.client.messages.any((m) => m.channel == Channels.dead);
  if (seesDead) {
    out.add(_Channel(Channels.dead, s.t('chan.dead'), const Text('🪦', style: TextStyle(fontSize: 24))));
  }
  for (final r in session.client.rooms) {
    out.add(_Channel(r.channel, r.name, const Text('👥', style: TextStyle(fontSize: 24)), room: r));
  }
  final dms = {
    ...session.knownDms,
    ...session.client.messages.map((m) => m.channel).where((c) => c.startsWith('dm:')),
  };
  for (final dm in dms) {
    final other = Channels.dmMembers(dm)?.firstWhere((id) => id != v.you, orElse: () => v.you);
    final p = other == null ? null : v.player(other);
    if (p == null) continue;
    out.add(_Channel(dm, p.name, AvatarView(profile: p.profile, size: 36)));
  }
  return out;
}

void openConversation(BuildContext context, Session session, String channel) {
  Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ConversationPage(session: session, channel: channel)));
}

class ChatTab extends StatelessWidget {
  const ChatTab({super.key, required this.session});

  final Session session;

  Future<void> _newDm(BuildContext context) async {
    final v = session.view!;
    final others = v.players.where((p) => p.id != v.you).toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final p in others)
              ListTile(
                leading: AvatarView(profile: p.profile, size: 36, dead: !p.alive && !p.isNarrator),
                title: Text(p.name),
                onTap: () => Navigator.pop(c, p.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null) session.client.openDm(picked);
  }

  Future<void> _newRoom(BuildContext context) async {
    final result = await showDialog<(String, List<String>)>(
      context: context,
      builder: (_) => _NewRoomDialog(view: session.view!),
    );
    if (result != null) session.client.createRoom(result.$1, result.$2);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final channels = _channelsFor(context, session);
    final privateOk = session.view!.settings.allowPrivateChats || session.view!.phase == Phase.lobby;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final c in channels)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: SizedBox(width: 40, child: Center(child: c.icon)),
                title: Text(c.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: _lastLine(context, c.id),
                trailing: (session.unread[c.id] ?? 0) > 0
                    ? Badge(label: Text('${session.unread[c.id]}'))
                    : const Icon(Icons.chevron_right),
                onTap: () => openConversation(context, session, c.id),
              ),
            ),
          ),
        if (privateOk) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _newDm(context),
                  icon: const Icon(Icons.person_outline),
                  label: Text(s.t('newDm')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _newRoom(context),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(s.t('newRoom')),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget? _lastLine(BuildContext context, String channel) {
    final last = session.client.messages.where((m) => m.channel == channel).lastOrNull;
    if (last == null) return null;
    return Text('${session.nameOf(last.from)}: ${last.text}', maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

class _NewRoomDialog extends StatefulWidget {
  const _NewRoomDialog({required this.view});

  final GameView view;

  @override
  State<_NewRoomDialog> createState() => _NewRoomDialogState();
}

class _NewRoomDialogState extends State<_NewRoomDialog> {
  final _name = TextEditingController();
  final Set<String> _members = {};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final others = widget.view.players.where((p) => p.id != widget.view.you).toList();
    return AlertDialog(
      title: Text(s.t('newRoom')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, maxLength: 30, decoration: InputDecoration(hintText: s.t('groupName'), counterText: '')),
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerStart, child: Text(s.t('members'))),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in others)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: AvatarView(profile: p.profile, size: 32),
                      title: Text(p.name),
                      value: _members.contains(p.id),
                      onChanged: (on) => setState(() => on == true ? _members.add(p.id) : _members.remove(p.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.t('cancel'))),
        TextButton(
          onPressed: _members.isEmpty ? null : () => Navigator.pop(context, (_name.text, _members.toList())),
          child: Text(s.t('create')),
        ),
      ],
    );
  }
}

/// One open chat.
class ConversationPage extends StatefulWidget {
  const ConversationPage({super.key, required this.session, required this.channel});

  final Session session;
  final String channel;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final _input = TextEditingController();

  Session get session => widget.session;

  @override
  void initState() {
    super.initState();
    session.openChannel = widget.channel;
    session.chatVisible = true;
    session.markRead(widget.channel);
  }

  @override
  void dispose() {
    session.openChannel = null;
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    session.client.sendChat(widget.channel, text);
    _input.clear();
  }

  String _title(BuildContext context) {
    final s = S.of(context);
    switch (widget.channel) {
      case Channels.public:
        return '🏘️ ${s.t('chan.public')}';
      case Channels.wolves:
        return '🐺 ${s.t('chan.wolves')}';
      case Channels.dead:
        return '🪦 ${s.t('chan.dead')}';
    }
    final room = session.client.rooms.where((r) => r.channel == widget.channel).firstOrNull;
    if (room != null) return '👥 ${room.name}';
    final other = Channels.dmMembers(widget.channel)?.firstWhere((id) => id != session.view?.you, orElse: () => '');
    return session.nameOf(other);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final v = session.view;
        final msgs = session.client.messages.where((m) => m.channel == widget.channel).toList().reversed.toList();
        final room = session.client.rooms.where((r) => r.channel == widget.channel).firstOrNull;
        return Scaffold(
          appBar: AppBar(
            title: Text(_title(context)),
            actions: [
              if (room != null)
                IconButton(
                  tooltip: s.t('leaveGroup'),
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: () {
                    session.client.leaveRoom(room.id);
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (room != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Text(room.members.map(session.nameOf).join('، '),
                        style: const TextStyle(color: Palette.mist, fontSize: 12)),
                  ),
                Expanded(
                  child: msgs.isEmpty
                      ? Center(child: Text(s.t('noMessages'), style: const TextStyle(color: Palette.mist)))
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.all(12),
                          itemCount: msgs.length,
                          itemBuilder: (context, i) {
                            final m = msgs[i];
                            final mine = m.from == v?.you;
                            final p = v?.player(m.from);
                            return _Bubble(message: m, mine: mine, author: p);
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          maxLength: ChatMessage.maxLength,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(hintText: s.t('typeMessage'), counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(onPressed: _send, icon: const Icon(Icons.send_rounded)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine, this.author});

  final ChatMessage message;
  final bool mine;
  final PlayerInfo? author;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.fromMillisecondsSinceEpoch(message.at);
    final hhmm = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final a = author;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine && a != null) ...[AvatarView(profile: a.profile, size: 30), const SizedBox(width: 6)],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: mine ? Palette.violet.withValues(alpha: .35) : Palette.surfaceHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!mine)
                    Text(
                      a?.isNarrator == true ? '📜 ${a!.name}' : (a?.name ?? '?'),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(a?.profile.color ?? 0xFFFFFFFF)),
                    ),
                  Text(message.text, style: const TextStyle(fontSize: 15)),
                  Text(hhmm, style: const TextStyle(fontSize: 10, color: Palette.mist)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
