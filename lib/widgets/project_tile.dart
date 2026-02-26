import 'package:flutter/material.dart';

import '../database/database.dart';

class ProjectTile extends StatefulWidget {
  final Project project;
  final bool selected;
  final bool hasUnread;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ProjectTile({
    super.key,
    required this.project,
    this.selected = false,
    this.hasUnread = false,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ProjectTile> createState() => _ProjectTileState();
}

class _ProjectTileState extends State<ProjectTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.selected
                ? cs.primary.withValues(alpha: 0.12)
                : _hovered
                    ? cs.onSurface.withValues(alpha: 0.04)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: widget.selected
                ? Border.all(color: cs.primary.withValues(alpha: 0.25), width: 0.5)
                : null,
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.only(left: 12, right: 4),
            leading: _Avatar(
              selected: widget.selected,
              hasUnread: widget.hasUnread,
            ),
            title: Text(
              widget.project.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                color: widget.selected ? cs.primary : cs.onSurface,
              ),
            ),
            subtitle: Text(
              widget.project.model,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: _hovered || widget.selected ? 1.0 : 0.0,
              child: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') widget.onEdit?.call();
                  if (v == 'delete') widget.onDelete?.call();
                },
                icon: Icon(Icons.more_horiz, size: 18, color: cs.onSurfaceVariant),
                iconSize: 18,
                padding: EdgeInsets.zero,
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        const Text('Edit'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: cs.error),
                        const SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: cs.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            onTap: widget.onTap,
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool selected;
  final bool hasUnread;

  const _Avatar({required this.selected, required this.hasUnread});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: selected
                ? cs.primary.withValues(alpha: 0.15)
                : cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.folder_outlined,
            color: selected ? cs.primary : cs.onSurfaceVariant,
            size: 18,
          ),
        ),
        if (hasUnread)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: cs.error,
                shape: BoxShape.circle,
                border: Border.all(color: cs.surface, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
