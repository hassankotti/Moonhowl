import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../main.dart';
import '../../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'room_screen.dart';

class HostSetupScreen extends StatefulWidget {
  const HostSetupScreen({super.key});

  @override
  State<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends State<HostSetupScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final s = S.of(context);
    final store = AppScope.read(context);
    final profile = store.profile!;
    setState(() => _busy = true);
    try {
      final name = _name.text.trim().isEmpty ? s.t('roomNameHint', {'name': profile.name}) : _name.text.trim();
      final session = await Session.host(
        store: store,
        profile: profile,
        roomName: name,
        password: _password.text.trim(),
      );
      if (!mounted) return;
      await Navigator.pushReplacement(context, MaterialPageRoute<void>(builder: (_) => RoomScreen(session: session)));
    } catch (_) {
      if (mounted) showError(context, 'hostFailed');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final profile = AppScope.of(context).profile!;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('host'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Center(child: Text('🌕', style: TextStyle(fontSize: 72))),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              maxLength: 30,
              decoration: InputDecoration(
                labelText: s.t('roomName'),
                hintText: s.t('roomNameHint', {'name': profile.name}),
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              maxLength: 20,
              decoration: InputDecoration(
                labelText: s.t('passwordOptional'),
                prefixIcon: const Icon(Icons.lock_outline),
                counterText: '',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Palette.mist, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(s.t('hostKeepOpen'), style: const TextStyle(color: Palette.mist))),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _open,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(s.t('startHosting')),
            ),
          ],
        ),
      ),
    );
  }
}
