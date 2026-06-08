import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_settings_controller.dart';
import '../../../app/providers.dart';
import '../domain/app_settings.dart';
import 'all_habits_screen.dart';
import 'archived_habits_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appSettingsControllerProvider);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: <Widget>[
              _Section(
                title: 'Daily reset',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('Reset time'),
                  subtitle: Text(settings.resetTimeLabel),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _pickResetTime(context, controller, settings),
                ),
              ),
              const SizedBox(height: 10),
              _Section(
                title: 'Appearance',
                child: SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: <ThemeMode>{settings.themeMode},
                  onSelectionChanged: (value) {
                    controller.update(
                      settings.copyWith(themeMode: value.first),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              _Section(
                title: 'Analytics',
                child: Column(
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.analyticsEnabled,
                      onChanged: (value) {
                        controller.update(
                          settings.copyWith(analyticsEnabled: value),
                        );
                      },
                      title: const Text('Analytics summaries'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: settings.showLifeBalanceScore,
                      onChanged: (value) {
                        controller.update(
                          settings.copyWith(showLifeBalanceScore: value),
                        );
                      },
                      title: const Text('Life balance score'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Section(
                title: 'Smart notifications',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.smartNotificationsEnabled,
                  onChanged: (value) {
                    controller.update(
                      settings.copyWith(smartNotificationsEnabled: value),
                    );
                  },
                  title: const Text('Optional weak-pattern nudges'),
                  subtitle: const Text(
                    'Local-only suggestions based on your history.',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _Section(
                title: 'Habit management',
                child: Column(
                  children: <Widget>[
                    _ActionTile(
                      icon: Icons.list_alt_outlined,
                      label: 'All habits',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const AllHabitsScreen(),
                        ),
                      ),
                    ),
                    _ActionTile(
                      icon: Icons.inventory_2_outlined,
                      label: 'Archived habits',
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const ArchivedHabitsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Section(
                title: 'Import and export',
                child: Column(
                  children: <Widget>[
                    _ActionTile(
                      icon: Icons.file_upload_outlined,
                      label: 'Export JSON backup',
                      onTap: () => _exportJson(context, ref),
                    ),
                    _ActionTile(
                      icon: Icons.table_chart_outlined,
                      label: 'Export CSV',
                      onTap: () => _exportCsv(context, ref),
                    ),
                    _ActionTile(
                      icon: Icons.file_download_outlined,
                      label: 'Import backup',
                      onTap: () => _importBackup(context, ref),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Section(
                title: 'Data management',
                child: Column(
                  children: <Widget>[
                    _ActionTile(
                      icon: Icons.restart_alt,
                      label: 'Reset statistics only',
                      onTap: () => _resetStatistics(context, ref),
                    ),
                    _ActionTile(
                      icon: Icons.delete_sweep_outlined,
                      label: 'Clear all history',
                      onTap: () => _clearHistory(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickResetTime(
    BuildContext context,
    AppSettingsController controller,
    AppSettings settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.resetMinutes ~/ 60,
        minute: settings.resetMinutes % 60,
      ),
    );
    if (picked == null) {
      return;
    }
    await controller.update(
      settings.copyWith(resetMinutes: picked.hour * 60 + picked.minute),
    );
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final file = await ref.read(backupServiceProvider).exportJson();
    if (!context.mounted) {
      return;
    }
    _showMessage(context, 'Backup saved to ${file.path}');
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final file = await ref.read(backupServiceProvider).exportCsv();
    if (!context.mounted) {
      return;
    }
    _showMessage(context, 'CSV saved to ${file.path}');
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    final path = result?.files.single.path;
    if (path == null) {
      return;
    }
    await ref.read(backupServiceProvider).importJson(File(path));
    final importedSettings = await ref.read(settingsRepositoryProvider).load();
    await ref.read(appSettingsControllerProvider).update(importedSettings);
    if (!context.mounted) {
      return;
    }
    _showMessage(context, 'Backup imported.');
  }

  Future<void> _resetStatistics(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Reset statistics?',
      body: 'Habit definitions and archived habits stay in place.',
    );
    if (confirmed) {
      await ref.read(dataManagementServiceProvider).resetStatisticsOnly();
      if (!context.mounted) {
        return;
      }
      _showMessage(context, 'Statistics reset.');
    }
  }

  Future<void> _clearHistory(BuildContext context, WidgetRef ref) async {
    final confirmed = await _confirm(
      context,
      title: 'Clear all history?',
      body: 'Entries, timer sessions, and revisions will be cleared locally.',
    );
    if (confirmed) {
      await ref.read(dataManagementServiceProvider).clearAllHistory();
      if (!context.mounted) {
        return;
      }
      _showMessage(context, 'History cleared.');
    }
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
