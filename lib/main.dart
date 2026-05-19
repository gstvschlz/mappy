import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/home_shell.dart';
import 'app/theme.dart';
import 'core/permissions/permissions_gate.dart';
import 'features/map/fmtc_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FmtcInit.ensure();
  runApp(const ProviderScope(child: MappyApp()));
}

class MappyApp extends StatelessWidget {
  const MappyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mappy',
      theme: mappyTheme(),
      home: const _Bootstrap(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _checked = false;
  bool _canEnter = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final state = await PermissionsGate.check();
    if (!mounted) return;
    setState(() {
      _checked = true;
      _canEnter = state.minimumViable;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_canEnter) {
      return PermissionsScreen(
        onContinue: () => setState(() => _canEnter = true),
      );
    }
    return const HomeShell();
  }
}
