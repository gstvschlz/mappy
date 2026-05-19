import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/export/export_screen.dart';
import '../features/map/map_screen.dart';
import '../features/observations/observation_list.dart';
import '../features/projects/projects_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _tabs = <Widget>[
    MapScreen(),
    ObservationListScreen(),
    ProjectsScreen(),
    ExportScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final divider = Theme.of(context).dividerTheme.color ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: divider, width: 0.5)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(CupertinoIcons.map),
              selectedIcon: Icon(CupertinoIcons.map_fill),
              label: 'Map',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.list_bullet),
              label: 'Notes',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.folder),
              selectedIcon: Icon(CupertinoIcons.folder_fill),
              label: 'Projects',
            ),
            NavigationDestination(
              icon: Icon(CupertinoIcons.tray_arrow_up),
              label: 'Export',
            ),
          ],
        ),
      ),
    );
  }
}
