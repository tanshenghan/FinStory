import 'package:flutter/material.dart';

import 'data/ledger_store.dart';
import 'screens/ledger_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = LedgerStore();
  await store.load();
  runApp(LedgerApp(store: store));
}

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key, required this.store});
  final LedgerStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'finstory',
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    home: LedgerShell(store: store),
  );
}
