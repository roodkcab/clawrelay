import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../services/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _urlController;
  late final TextEditingController _modelController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _urlController = TextEditingController(text: settings.serverUrl);
    _modelController = TextEditingController(text: settings.model);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setServerUrl(_urlController.text.trim());
    await settings.setDefaultModel(_modelController.text.trim());
    ref.read(serverUrlProvider.notifier).state = _urlController.text.trim();
    ref.read(defaultModelProvider.notifier).state = _modelController.text.trim();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://localhost:50009',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Default Model',
              hintText: 'vllm/claude-sonnet-4-6',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          const Text('Theme', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          _ThemeModeSelector(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
        ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
        ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
      ],
      selected: {current},
      onSelectionChanged: (set) async {
        final mode = set.first;
        ref.read(themeModeProvider.notifier).state = mode;
        await ref.read(settingsServiceProvider).setThemeMode(mode);
      },
    );
  }
}
