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
  late final TextEditingController _maxTurnsController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsServiceProvider);
    _urlController = TextEditingController(text: settings.serverUrl);
    _modelController = TextEditingController(text: settings.model);
    _maxTurnsController = TextEditingController(text: settings.maxTurns.toString());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _modelController.dispose();
    _maxTurnsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = ref.read(settingsServiceProvider);
    await settings.setServerUrl(_urlController.text.trim());
    await settings.setDefaultModel(_modelController.text.trim());
    final maxTurns = int.tryParse(_maxTurnsController.text.trim()) ?? SettingsService.defaultMaxTurns;
    await settings.setMaxTurns(maxTurns);
    ref.read(serverUrlProvider.notifier).state = _urlController.text.trim();
    ref.read(defaultModelProvider.notifier).state = _modelController.text.trim();
    ref.read(maxTurnsProvider.notifier).state = maxTurns;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
          // ── Connection section ──────────────────────────────────
          _SectionHeader(title: 'Connection'),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://localhost:50009',
              prefixIcon: Icon(Icons.dns_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: 'Default Model',
              hintText: 'vllm/claude-sonnet-4-6',
              prefixIcon: Icon(Icons.smart_toy_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _maxTurnsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Max Turns',
              hintText: '200',
              prefixIcon: Icon(Icons.repeat_rounded, size: 18),
              helperText: 'Maximum tool-use turns per response (default: 200)',
            ),
          ),

          const SizedBox(height: 28),

          // ── Appearance section ──────────────────────────────────
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Theme Mode',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _ThemeModeSelector(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Save button ────────────────────────────────────────
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
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
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined, size: 16),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined, size: 16),
          label: Text('System'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 16),
          label: Text('Dark'),
        ),
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
