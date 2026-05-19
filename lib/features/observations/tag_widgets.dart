import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db_provider.dart';

/// A pill-shaped tag chip. If [onRemove] is provided, a small ✕ button
/// appears so the user can dismiss the tag in edit contexts.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.name, this.onRemove});

  final String name;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 6, onRemove == null ? 12 : 4, 6),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  size: 16,
                  color: scheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable tags editor: shows the current tag chips with remove buttons and
/// a single autocomplete field suggesting tags already used within
/// [projectId]. Calls [onChanged] with the new tag-name list whenever the
/// user adds or removes a tag. Free text is allowed.
class TagsEditor extends ConsumerStatefulWidget {
  const TagsEditor({
    super.key,
    required this.projectId,
    required this.tags,
    required this.onChanged,
    this.hintText = 'Add a tag…',
  });

  final String projectId;
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String hintText;

  @override
  ConsumerState<TagsEditor> createState() => _TagsEditorState();
}

class _TagsEditorState extends ConsumerState<TagsEditor> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addTag(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final lower = trimmed.toLowerCase();
    if (widget.tags.any((t) => t.toLowerCase() == lower)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.tags, trimmed]);
    _controller.clear();
  }

  void _removeTag(String name) {
    widget.onChanged(widget.tags.where((t) => t != name).toList());
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.tags
                  .map((name) => TagChip(
                        name: name,
                        onRemove: () => _removeTag(name),
                      ))
                  .toList(),
            ),
          ),
        StreamBuilder<List<Tag>>(
          stream: db.tagDao.watchForProject(widget.projectId),
          builder: (ctx, snap) {
            final available = (snap.data ?? const <Tag>[])
                .map((t) => t.name)
                .where((n) => !widget.tags
                    .any((t) => t.toLowerCase() == n.toLowerCase()))
                .toList();
            return RawAutocomplete<String>(
              textEditingController: _controller,
              focusNode: _focusNode,
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return available
                    .where((n) => n.toLowerCase().contains(q))
                    .take(6);
              },
              onSelected: _addTag,
              fieldViewBuilder:
                  (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(CupertinoIcons.tag),
                    suffixIcon: IconButton(
                      icon: const Icon(CupertinoIcons.add_circled_solid),
                      onPressed: () => _addTag(controller.text),
                    ),
                  ),
                  onSubmitted: (v) {
                    _addTag(v);
                    focusNode.requestFocus();
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxHeight: 220, maxWidth: 320),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (ctx, i) {
                          final option = options.elementAt(i);
                          return ListTile(
                            dense: true,
                            title: Text(option),
                            onTap: () => onSelected(option),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
