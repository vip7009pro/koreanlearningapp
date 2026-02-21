import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';

class ThemePickerScreen extends ConsumerWidget {
  const ThemePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final current = settings.themeId;
    final currentMode = settings.themeMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn theme'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  const ListTile(
                    title: Text(
                      'Chế độ giao diện',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.system,
                    groupValue: currentMode,
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(appSettingsProvider.notifier).setThemeMode(v);
                    },
                    title: const Text('Theo hệ thống'),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: currentMode,
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(appSettingsProvider.notifier).setThemeMode(v);
                    },
                    title: const Text('Light mode'),
                  ),
                  RadioListTile<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                    onChanged: (v) {
                      if (v == null) return;
                      ref.read(appSettingsProvider.notifier).setThemeMode(v);
                    },
                    title: const Text('Dark mode'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...AppSettingsNotifier.themes.map((t) {
            final selected = t.id == current;
            return InkWell(
              onTap: () => ref.read(appSettingsProvider.notifier).setTheme(t.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: t.gradient,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: t.gradient
                                .map(
                                  (c) => Container(
                                    width: 18,
                                    height: 18,
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: c,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.black12,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
