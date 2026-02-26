import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../providers/projects_provider.dart';
import '../providers/settings_provider.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  final Project? project; // null = create, non-null = edit

  const ProjectFormScreen({super.key, this.project});

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _dirController;
  late final TextEditingController _promptController;
  late final TextEditingController _modelController;

  bool get _isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _dirController =
        TextEditingController(text: widget.project?.workingDirectory ?? '');
    _promptController =
        TextEditingController(text: widget.project?.systemPrompt ?? '');
    _modelController = TextEditingController(
      text: widget.project?.model ?? ref.read(defaultModelProvider),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dirController.dispose();
    _promptController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    final notifier = ref.read(projectsNotifierProvider.notifier);

    if (_isEditing) {
      await notifier.updateProject(
        id: widget.project!.id,
        name: name,
        workingDirectory: _dirController.text.trim(),
        systemPrompt: _promptController.text.trim(),
        model: _modelController.text.trim(),
      );
    } else {
      await notifier.createProject(
        name: name,
        workingDirectory: _dirController.text.trim(),
        systemPrompt: _promptController.text.trim(),
        model: _modelController.text.trim(),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Project' : 'New Project'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Project Name',
              prefixIcon: Icon(Icons.label_outline, size: 18),
            ),
            autofocus: true,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Model',
              hintText: 'vllm/claude-sonnet-4-6',
              prefixIcon: Icon(Icons.smart_toy_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _dirController,
            decoration: const InputDecoration(
              labelText: 'Working Directory (optional)',
              hintText: '/path/to/project',
              prefixIcon: Icon(Icons.folder_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _promptController,
            decoration: const InputDecoration(
              labelText: 'System Prompt (optional)',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 48),
                child: Icon(Icons.description_outlined, size: 18),
              ),
            ),
            maxLines: 5,
            minLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: Icon(_isEditing ? Icons.check_rounded : Icons.add, size: 18),
            label: Text(_isEditing ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }
}
