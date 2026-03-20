
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/theme_manager.dart';
import '../../../app/theme/theme_color_palette.dart';
import '../../../shared/widgets/book_scaffold.dart';
import '../application/notification_providers.dart';
import '../../../shared/services/data_backup_service.dart';
import '../../books/application/books_providers.dart';
import '../../reading/application/reading_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BookScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Ayarlar'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'UYGULAMA AYARLARI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                  Consumer(
                    builder: (context, ref, child) {
                      final notificationSettings = ref.watch(notificationSettingsProvider);
                      final notificationNotifier = ref.read(notificationSettingsProvider.notifier);
                      
                      return Column(
                        children: [
                          _SwitchItem(
                            icon: Icons.notifications_outlined,
                            iconColor: Theme.of(context).colorScheme.primary,
                            title: 'Günlük Hatırlatıcı',
                            value: notificationSettings.enabled,
                            onChanged: (v) {
                              notificationNotifier.setEnabled(v);
                            },
                          ),
                          if (notificationSettings.enabled)
                            ListTile(
                              leading: const SizedBox(width: 40), // Indent to align with text
                              title: const Text('Hatırlatma Saati'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${notificationSettings.hour.toString().padLeft(2, '0')}:${notificationSettings.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              onTap: () async {
                                final TimeOfDay? picked = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay(
                                    hour: notificationSettings.hour,
                                    minute: notificationSettings.minute,
                                  ),
                                  builder: (context, child) {
                                    return MediaQuery(
                                      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  notificationNotifier.setTime(picked.hour, picked.minute);
                                }
                              },
                            ),
                            const Divider(height: 1),
                        ],
                      );
                    },
                  ),
                  // Renk Paleti Seçimi
                  Consumer(
                    builder: (context, ref, child) {
                      final currentPalette = ref.watch(colorPaletteProvider);
                      
                      return _SettingsItem(
                        icon: Icons.palette_outlined,
                        iconColor: const Color(0xFF9B51E0),
                        title: 'Renk Paleti',
                        subtitle: currentPalette.displayName,
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (context) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text(
                                      'Renk Paletini Seç',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  ...ColorPalette.values.map((palette) {
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: palette.previewColor,
                                        child: Icon(
                                          palette.icon,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(palette.displayName),
                                      trailing: currentPalette == palette ? const Icon(Icons.check, color: Colors.green) : null,
                                      onTap: () {
                                        ref.read(colorPaletteProvider.notifier).setPalette(palette);
                                        Navigator.pop(context);
                                      },
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  // Koyu Mod Switch
                  Consumer(
                    builder: (context, ref, child) {
                      final currentTheme = ref.watch(themeProvider);
                      final isDarkMode = currentTheme == ThemeMode.dark;
                      
                      return _SwitchItem(
                        icon: Icons.dark_mode_outlined,
                        iconColor: const Color(0xFF9B51E0),
                        title: 'Koyu Mod',
                        value: isDarkMode,
                        onChanged: (value) {
                          ref.read(themeProvider.notifier).setTheme(
                            value ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'DESTEK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _SettingsItem(
                      icon: Icons.help_outline,
                      iconColor: const Color(0xFF2BC4AD),
                      title: 'Yardım & Destek',
                      trailing: const Icon(Icons.open_in_new, size: 18),
                      onTap: () {
                        // Yardım & Destek (ileride implement edilecek)
                      },
                    ),
                    const Divider(height: 1),
                    _SettingsItem(
                      icon: Icons.info_outline,
                      iconColor: Colors.grey,
                      title: 'Gizlilik ve Güvenlik',
                      subtitle: 'Uygulamayı nasıl kullandığını öğren',
                      onTap: () {
                         // Gizlilik politikası (web view veya dialog)
                      },
                    ),
                    const Divider(height: 1),
                    Consumer(
                      builder: (context, ref, child) {
                        return _SettingsItem(
                          icon: Icons.download_rounded,
                          iconColor: Colors.blue,
                          title: 'Verileri Dışa Aktar',
                          subtitle: 'Kitaplar, kayıtlar, sesler ve fotoğraflar dahil',
                          onTap: () async {
                            try {
                              await ref.read(dataBackupServiceProvider).exportData();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Veriler başarıyla dışa aktarıldı'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Hata: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                    const Divider(height: 1),
                    Consumer(
                      builder: (context, ref, child) {
                        return _SettingsItem(
                          icon: Icons.upload_rounded,
                          iconColor: Colors.green,
                          title: 'Verileri İçe Aktar',
                          subtitle: 'ZIP veya JSON yedek dosyasını içe aktar',
                          onTap: () async {
                            // Loading göster
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            try {
                              // Varsayılan olarak merge yap (replaceExisting: false)
                              await ref.read(dataBackupServiceProvider).importData(
                                    replaceExisting: false,
                                  );

                              // Provider'ları yenile
                              ref.invalidate(readingLogsRepositoryProvider);
                              ref.invalidate(booksRepositoryProvider);
                              ref.invalidate(booksVmProvider);
                              ref.invalidate(readingLogsProvider);

                              if (context.mounted) {
                                Navigator.of(context).pop(); // Loading dialog'u kapat
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Veriler başarıyla içe aktarıldı ve mevcut verilerle birleştirildi'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                Navigator.of(context).pop(); // Loading dialog'u kapat
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Hata: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      context.go(Routes.login);
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.red),
                    label: const Text(
                      'Çıkış Yap',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Center(
                child: Column(
                  children: [
                    Text(
                      'Versiyon 1.0.2',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Design for Calmness',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  const _SettingsItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.1),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.1),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

