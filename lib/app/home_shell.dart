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
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'List'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined), label: 'Projects'),
          NavigationDestination(
              icon: Icon(Icons.archive_outlined), label: 'Export'),
        ],
      ),
    );
  }
}
