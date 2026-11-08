import 'package:flutter/material.dart';
import 'package:howl_core/howl_core.dart';
import 'package:howl_net/howl_net.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n.dart';
import '../../main.dart';
import '../../services/discovery.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'room_screen.dart';

/// Lists rooms on this Wi-Fi, or joins by QR code / typed address.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _scanner = RoomScanner();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scanner.start();
  }

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  Future<void> _joinAddress(String host, int port) async {
    final s = S.of(context);
    setState(() => _busy = true);
    try {
      final info = await HowlClient.probe(host, port);
      if (!mounted) return;
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('roomNotFound'))));
        return;
      }
      String? password;
      if (info['hasPassword'] == true) {
        password = await _askPassword();
        if (password == null) return;
      }
      await _connect(host, port, password);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _connect(String host, int port, String? password) async {
    final store = AppScope.read(context);
    final session = await Session.join(
      store: store,
      profile: store.profile!,
      host: host,
      port: port,
      password: password,
    );
    // Wait for the host to accept or refuse us.
    final client = session.client;
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (client.status != ConnectionStatus.connected &&
        client.status != ConnectionStatus.closed &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    if (client.status != ConnectionStatus.connected) {
      showError(context, client.closeReason ?? 'unreachable');
      await session.end();
      session.dispose();
      return;
    }
    await Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => RoomScreen(session: session)));
  }

  Future<String?> _askPassword() {
    final s = S.of(context);
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('password')),
        content: TextField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(s.t('connect'))),
        ],
      ),
    );
  }

  Future<void> _manual() async {
    final s = S.of(context);
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.t('manual')),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(hintText: s.t('address')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(s.t('connect'))),
        ],
      ),
    );
    if (text == null) return;
    final addr = Net.parseAddress(text);
    if (addr == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('roomNotFound'))));
      return;
    }
    await _joinAddress(addr.host, addr.port);
  }

  Future<void> _scan() async {
    final code = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _QrScanPage()));
    if (code == null) return;
    final addr = Net.parseAddress(code);
    if (addr != null) await _joinAddress(addr.host, addr.port);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('join'))),
      body: SafeArea(
        child: Column(
          children: [
            if (_busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _scan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(s.t('scanQr')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: _busy ? null : _manual,
                    icon: const Icon(Icons.keyboard),
                    tooltip: s.t('manual'),
                    iconSize: 26,
                    padding: const EdgeInsets.all(14),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _scanner,
                builder: (context, _) {
                  final rooms = _scanner.rooms;
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.t('searching'), style: const TextStyle(color: Palette.mist))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (rooms.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Column(
                            children: [
                              const Text('🌫️', style: TextStyle(fontSize: 54)),
                              const SizedBox(height: 10),
                              Text(s.t('noRooms'), textAlign: TextAlign.center, style: const TextStyle(color: Palette.mist)),
                            ],
                          ),
                        ),
                      for (final r in rooms) _RoomTile(room: r, onTap: _busy ? null : () => _joinAddress(r.host, r.port)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, this.onTap});

  final FoundRoom room;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final closed = room.inGame || room.locked;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: const CircleAvatar(backgroundColor: Palette.surfaceHigh, child: Text('🌕')),
          title: Text(room.name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text([
            s.t('playersCount', {'n': room.players}),
            if (room.inGame) s.t('inGame'),
            if (room.locked) s.t('locked'),
          ].join(' · ')),
          trailing: room.hasPassword ? const Icon(Icons.lock_outline) : const Icon(Icons.chevron_right),
          enabled: !closed,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _QrScanPage extends StatefulWidget {
  const _QrScanPage();

  @override
  State<_QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<_QrScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('scanQr'))),
      body: MobileScanner(
        errorBuilder: (context, error) => Center(child: Text(s.error('camera'))),
        onDetect: (capture) {
          if (_done) return;
          for (final b in capture.barcodes) {
            final v = b.rawValue;
            if (v != null && v.startsWith('${Net.scheme}://')) {
              _done = true;
              Navigator.pop(context, v);
              return;
            }
          }
        },
      ),
    );
  }
}
