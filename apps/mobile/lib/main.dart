import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/local_store.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await LocalStore.load();
  runApp(MoonhowlApp(store: store));
}

/// Gives every screen the device's [LocalStore].
class AppScope extends InheritedNotifier<LocalStore> {
  const AppScope({super.key, required LocalStore store, required super.child}) : super(notifier: store);

  static LocalStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static LocalStore read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class MoonhowlApp extends StatelessWidget {
  const MoonhowlApp({super.key, required this.store});

  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Moonhowl',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: Locale(store.language),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: store.profile == null ? const ProfileScreen(firstRun: true) : const HomeScreen(),
        ),
      ),
    );
  }
}
