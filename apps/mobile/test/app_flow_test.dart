import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:howl_core/howl_core.dart';
import 'package:howl_net/howl_net.dart';
import 'package:moonhowl/main.dart';
import 'package:moonhowl/state/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets real sockets make progress, then lets the UI catch up.
Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> settleUntil(WidgetTester tester, bool Function() cond) async {
  for (var i = 0; i < 60 && !cond(); i++) {
    await settle(tester, rounds: 1);
  }
  expect(cond(), isTrue);
}

void main() {
  testWidgets('first run asks for a profile', (tester) async {
    SharedPreferences.setMockInitialValues({'lang': 'en'});
    final store = await LocalStore.load();
    await tester.pumpWidget(MoonhowlApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Moonhowl'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Layla');
    await tester.scrollUntilVisible(find.text('Save'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Host a game'), findsOneWidget);
    expect(store.profile?.name, 'Layla');
  });

  testWidgets('host a room, bots join, play through every phase (Arabic UI)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    SharedPreferences.setMockInitialValues({
      'lang': 'ar',
      'sound': false, // no audio plugin in widget tests
      'profile': jsonEncode(Profile(name: 'المضيف').toJson()),
    });
    final store = await LocalStore.load();
    await tester.pumpWidget(MoonhowlApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('استضافة لعبة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الغرفة'));
    await settle(tester);
    expect(find.textContaining('المضيف'), findsWidgets);

    // Four bots join over the real network.
    final bots = <HowlClient>[];
    await tester.runAsync(() async {
      for (var i = 1; i <= 4; i++) {
        final c = HowlClient(host: '127.0.0.1', port: Net.defaultPort, profile: Profile(name: 'بوت $i'));
        bots.add(c);
        await c.connect();
      }
    });
    await settleUntil(tester, () => bots.every((b) => b.view?.players.length == 5));
    expect(find.text('بوت 4'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('ابدأ اللعبة'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('ابدأ اللعبة'));
    await settleUntil(tester, () => bots.first.view?.phase == Phase.night);
    await settle(tester);
    expect(find.text('الليل'), findsOneWidget);

    // Reveal the role card.
    await tester.tap(find.text('اضغط لكشف دورك'));
    await settle(tester, rounds: 2);
    expect(find.text('دورك'), findsOneWidget);

    // Host skips through the phases; each screen must build.
    Future<void> skipTo(Phase phase) async {
      await tester.tap(find.byIcon(Icons.skip_next));
      await settleUntil(tester, () => bots.first.view?.phase == phase || bots.first.view?.phase == Phase.ended);
      await settle(tester, rounds: 2);
    }

    await skipTo(Phase.day); // nobody acted -> peaceful night (or witch)
    if (bots.first.view!.phase == Phase.witch) await skipTo(Phase.day);
    expect(find.text('النهار · النقاش'), findsOneWidget);

    await skipTo(Phase.voting);
    expect(find.text('النهار · التصويت'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('امتناع'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('امتناع'), findsOneWidget);

    // Chat tab and public chat.
    await tester.tap(find.text('الدردشة'));
    await settle(tester, rounds: 2);
    await tester.tap(find.text('ساحة القرية'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'مرحبا يا قرية');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await settleUntil(tester, () => bots.first.messages.any((m) => m.text == 'مرحبا يا قرية'));
    expect(find.text('مرحبا يا قرية'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    // Story tab shows narrator lines.
    await tester.tap(find.text('الحكاية'));
    await settle(tester, rounds: 2);
    expect(find.textContaining('حلّت الليلة 1'), findsOneWidget);

    await tester.tap(find.text('اللعبة'));
    await settle(tester, rounds: 2);

    await tester.runAsync(() async {
      for (final b in bots) {
        await b.dispose();
      }
    });
    // Leave and close the room.
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حسنًا'));
    await settle(tester);
    expect(find.text('استضافة لعبة'), findsOneWidget);

    // Let closed sockets drop their keep-alive timers.
    await settle(tester, rounds: 5);
    await tester.pump(const Duration(seconds: 10));
    await settle(tester, rounds: 5);
  });
}
