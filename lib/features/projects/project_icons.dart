import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Curated set of icons a user can pick for a project. Stored on the
/// Projects row as the [id] string; rendered via [resolveIcon].
class ProjectIconChoice {
  const ProjectIconChoice(this.id, this.icon, this.label);
  final String id;
  final IconData icon;
  final String label;
}

const projectIconChoices = <ProjectIconChoice>[
  ProjectIconChoice('folder', CupertinoIcons.folder_fill, 'Folder'),
  ProjectIconChoice('map', CupertinoIcons.map_fill, 'Map'),
  ProjectIconChoice('compass', CupertinoIcons.compass_fill, 'Compass'),
  ProjectIconChoice('pin', CupertinoIcons.placemark_fill, 'Pin'),
  ProjectIconChoice('layers', Icons.layers_rounded, 'Layers'),
  ProjectIconChoice('mountain', Icons.landscape_rounded, 'Mountain'),
  ProjectIconChoice('terrain', Icons.terrain_rounded, 'Terrain'),
  ProjectIconChoice('volcano', Icons.volcano_rounded, 'Volcano'),
  ProjectIconChoice('hammer', Icons.handyman_rounded, 'Hammer'),
  ProjectIconChoice('rock', Icons.diamond_rounded, 'Crystal'),
  ProjectIconChoice('water', CupertinoIcons.drop_fill, 'Water'),
  ProjectIconChoice('sun', CupertinoIcons.sun_max_fill, 'Sun'),
  ProjectIconChoice('leaf', Icons.eco_rounded, 'Leaf'),
  ProjectIconChoice('forest', Icons.forest_rounded, 'Forest'),
  ProjectIconChoice('cave', Icons.tornado_rounded, 'Cave'),
  ProjectIconChoice('star', CupertinoIcons.star_fill, 'Star'),
  ProjectIconChoice('bookmark', CupertinoIcons.bookmark_fill, 'Bookmark'),
  ProjectIconChoice('flag', CupertinoIcons.flag_fill, 'Flag'),
];

/// Resolves a stored `iconName` to its [IconData]. Returns a sensible
/// folder default when the name is null or unknown.
IconData resolveProjectIcon(String? iconName) {
  if (iconName == null) return CupertinoIcons.folder_fill;
  return projectIconChoices
      .firstWhere(
        (c) => c.id == iconName,
        orElse: () => projectIconChoices.first,
      )
      .icon;
}

/// Bottom-sheet grid that lets the user pick a project icon. Returns the
/// id of the chosen icon, or `null` if dismissed.
Future<String?> pickProjectIcon(
  BuildContext context, {
  String? current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _IconPickerSheet(current: current),
  );
}

class _IconPickerSheet extends StatelessWidget {
  const _IconPickerSheet({this.current});
  final String? current;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Choose an icon',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: projectIconChoices.length,
              itemBuilder: (ctx, i) {
                final choice = projectIconChoices[i];
                final selected = choice.id == current;
                return InkWell(
                  onTap: () => Navigator.pop(ctx, choice.id),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primary.withValues(alpha: 0.16)
                          : scheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: selected
                          ? Border.all(color: scheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Icon(
                      choice.icon,
                      size: 22,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
