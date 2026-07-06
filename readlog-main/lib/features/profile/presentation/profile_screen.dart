import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../books/application/books_vm.dart';
import '../../books/domain/book.dart';
import '../../reading/application/reading_providers.dart';
import '../../reading/domain/reading_log.dart';
import '../application/profile_providers.dart';
import '../../../shared/widgets/book_scaffold.dart';
import '../application/streak_service.dart';
import 'widgets/reading_calendar_widget.dart';

enum StatsPeriod {
  month,
  year,
  all,
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  StatsPeriod _selectedPeriod = StatsPeriod.month;

  _ReadingStats _calculateStats(List<ReadingLog> allLogs, StatsPeriod period, List<Book> allBooks) {
    final now = DateTime.now();
    
    // 1. Periyot Filtreleme (Takvim için logları filtrele)
    List<ReadingLog> filteredLogs;
    if (period == StatsPeriod.month) {
      filteredLogs = allLogs.where((l) => l.date.month == now.month && l.date.year == now.year).toList();
    } else if (period == StatsPeriod.year) {
      filteredLogs = allLogs.where((l) => l.date.year == now.year).toList();
    } else {
      filteredLogs = allLogs;
    }

    // 2. İstatistikleri filtrelenmiş loglardan hesapla
    final int totalSeconds = filteredLogs.fold<int>(0, (sum, log) => sum + log.effectiveDurationSeconds);

    // Sayfa sayısı: Her kitap için o periyottaki en yüksek pageAtEnd'i al
    int totalPagesRead = 0;
    final bookIds = filteredLogs.map((l) => l.bookId).toSet();
    for (final bookId in bookIds) {
      final bookLogs = filteredLogs.where((l) => l.bookId == bookId).toList();
      if (bookLogs.isNotEmpty) {
        // O periyottaki en yüksek sayfa (son ulaşılan sayfa)
        final maxPage = bookLogs.map((l) => l.pageAtEnd).reduce((a, b) => a > b ? a : b);
        // O periyottan önceki en yüksek sayfayı bul (başlangıç noktası)
        final earliestDate = bookLogs.map((l) => l.date).reduce((a, b) => a.isBefore(b) ? a : b);
        final beforeLogs = allLogs.where((l) =>
          l.bookId == bookId &&
          !filteredLogs.contains(l) &&
          l.date.isBefore(earliestDate),
        ).toList();
        var startPage = beforeLogs.isEmpty
            ? 0
            : beforeLogs.map((l) => l.pageAtEnd).reduce((a, b) => a > b ? a : b);
        // Kitap yeniden okunmuşsa (önceki okumanın sayfası şimdikinden büyük),
        // sıfırdan başlamış demektir
        if (startPage > maxPage) startPage = 0;
        totalPagesRead += maxPage - startPage;
      }
    }

    final String totalHours = (totalSeconds / 3600).toStringAsFixed(1);

    // 3. Günlük Ortalama Hesaplama
    int pagesPerDay = 0;
    if (totalPagesRead > 0) {
        int days = 1;
        if (period == StatsPeriod.month) {
           days = now.day;
        } else if (period == StatsPeriod.year) {
           days = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
        } else {
            // All time: İlk log tarihinden bugüne veya ilk kitap ekleme tarihinden
            if (filteredLogs.isNotEmpty) {
                final first = filteredLogs.map((e) => e.date).reduce((a,b) => a.isBefore(b) ? a : b);
                days = now.difference(first).inDays + 1;
            } else if (allBooks.isNotEmpty) {
                // Eğer log yoksa, kitapların eklenme tarihini kullanamayız çünkü bu bilgi yok
                // Bu durumda bugünden itibaren 1 gün sayalım
                days = 1;
            }
        }

        if (days < 1) days = 1;
        pagesPerDay = (totalPagesRead / days).round();
    }

    return _ReadingStats(
       totalPagesRead: totalPagesRead,
       pagesPerDay: pagesPerDay,
       totalHours: totalHours,
       logs: filteredLogs,
    );
  }


  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final logs = ref.watch(readingLogsProvider);
    final booksState = ref.watch(booksVmProvider);
    final books = booksState.items;

    return BookScaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Profil', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                onPressed: () => context.push(Routes.editProfile),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded, size: 20),
                onPressed: () => context.push(Routes.settings),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                   const SizedBox(height: 8),
                   profileAsync.when(
                    data: (profile) => Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                            child: profile.avatarImagePath != null
                                ? ClipOval(
                                    child: Image.file(
                                      File(profile.avatarImagePath!),
                                      width: 96,
                                      height: 96,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(Icons.person_rounded, size: 44, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5));
                                      },
                                    ),
                                  )
                                : Icon(Icons.person_rounded, size: 44, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          profile.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profile.username}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    loading: () => const CircularProgressIndicator(),
                    error: (err, stack) => Text('Error: $err'),
                   ),
                   const SizedBox(height: 28),
                   
                   // Stats Header
                   Builder(
                     builder: (context) {
                        final streakService = ref.watch(streakServiceProvider);
                        final currentStreak = streakService.calculateCurrentStreak(logs);
                        final allTimeStats = _calculateStats(logs, StatsPeriod.all, books);
                        final completedBooksCount = books.where((b) => b.shelf == BookShelf.read).length;

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                             children: [
                               _MiniStat(
                                 value: completedBooksCount.toString(),
                                 label: 'Kitap',
                               ),
                               Container(
                                 height: 28,
                                 width: 1,
                                 color: Theme.of(context).dividerColor,
                               ),
                               _MiniStat(
                                 value: currentStreak.toString(),
                                 label: 'Gün Seri',
                               ),
                               Container(
                                 height: 28,
                                 width: 1,
                                 color: Theme.of(context).dividerColor,
                               ),
                               _MiniStat(
                                 value: allTimeStats.totalPagesRead.toString(),
                                 label: 'Sayfa',
                               ),
                             ],
                          ),
                        );
                     },
                   ),

                   const SizedBox(height: 16),

                   // T1.11: daily goal progress + entry point to the goal screen.
                   Builder(
                     builder: (context) {
                       final now = DateTime.now();
                       final todayStart = DateTime(now.year, now.month, now.day);
                       final todayEnd = DateTime(now.year, now.month, now.day + 1); // T2.5 DST-safe
                       final todaySeconds = logs
                           .where((l) => !l.date.isBefore(todayStart) && l.date.isBefore(todayEnd))
                           .fold<int>(0, (s, l) => s + l.effectiveDurationSeconds);
                       final todayMinutes = todaySeconds ~/ 60;
                       final goal = profileAsync.valueOrNull?.dailyGoalMinutes ?? 45;
                       final progress = goal > 0 ? (todayMinutes / goal).clamp(0.0, 1.0) : 0.0;

                       return Material(
                         color: Colors.transparent,
                         child: InkWell(
                           onTap: () => context.push(Routes.dailyGoal),
                           borderRadius: BorderRadius.circular(20),
                           child: Container(
                             padding: const EdgeInsets.all(16),
                             decoration: BoxDecoration(
                               color: Theme.of(context).cardColor,
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(
                                 color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                                 width: 1,
                               ),
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   children: [
                                     Icon(Icons.flag_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                                     const SizedBox(width: 8),
                                     Text(
                                       'Günlük Hedef',
                                       style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                     ),
                                     const Spacer(),
                                     Text(
                                       '$todayMinutes / $goal dk',
                                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                         fontWeight: FontWeight.w700,
                                         color: Theme.of(context).colorScheme.primary,
                                       ),
                                     ),
                                     const SizedBox(width: 4),
                                     Icon(Icons.chevron_right_rounded,
                                         size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                                   ],
                                 ),
                                 const SizedBox(height: 12),
                                 ClipRRect(
                                   borderRadius: BorderRadius.circular(8),
                                   child: LinearProgressIndicator(
                                     value: progress,
                                     minHeight: 8,
                                     backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                       );
                     },
                   ),

                   const SizedBox(height: 32),

                   // Period Selector
                   Container(
                     decoration: BoxDecoration(
                       color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                       borderRadius: BorderRadius.circular(16),
                     ),
                     padding: const EdgeInsets.all(4),
                     child: Row(
                       children: [
                         Expanded(
                           child: _PeriodButton(
                             label: 'Bu Ay',
                             isSelected: _selectedPeriod == StatsPeriod.month,
                             onTap: () => setState(() => _selectedPeriod = StatsPeriod.month),
                           ),
                         ),
                         Expanded(
                           child: _PeriodButton(
                             label: 'Bu Yıl',
                             isSelected: _selectedPeriod == StatsPeriod.year,
                             onTap: () => setState(() => _selectedPeriod = StatsPeriod.year),
                           ),
                         ),
                         Expanded(
                           child: _PeriodButton(
                             label: 'Tümü',
                             isSelected: _selectedPeriod == StatsPeriod.all,
                             onTap: () => setState(() => _selectedPeriod = StatsPeriod.all),
                           ),
                         ),
                       ],
                     ),
                   ),

                   const SizedBox(height: 16),
                   
                   Builder(
                      builder: (context) {
                         final streakService = ref.watch(streakServiceProvider); // Watch
                         final bestStreak = streakService.calculateBestStreak(logs);
                         
                         final stats = _calculateStats(logs, _selectedPeriod, books);

                         return Column(
                           children: [
                             Row(
                               children: [
                                 Expanded(
                                   child: _StatCard(
                                     title: 'Toplam Sayfa',
                                     value: stats.totalPagesRead.toString(),
                                     icon: Icons.auto_stories,
                                     color: const Color(0xFF6C63FF),
                                   ),
                                 ),
                                 const SizedBox(width: 12),
                                 Expanded(
                                   child: _StatCard(
                                     title: 'Günlük Ort.',
                                     value: stats.pagesPerDay.toString(),
                                     icon: Icons.trending_up,
                                     color: const Color(0xFF00BFA6),
                                   ),
                                 ),
                               ],
                             ),
                             const SizedBox(height: 12),
                             Row(
                               children: [
                                 Expanded(
                                   child: _StatCard(
                                     title: 'Toplam Saat',
                                     value: stats.totalHours,
                                     icon: Icons.schedule,
                                     color: const Color(0xFFFF9F1C),
                                   ),
                                 ),
                                 const SizedBox(width: 12),
                                 Expanded(
                                   child: _StatCard(
                                     title: 'En İyi Seri',
                                     value: '$bestStreak Gün',
                                     icon: Icons.emoji_events,
                                     color: const Color(0xFFFF4D4D),
                                   ),
                                 ),
                               ],
                             ),
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.transparent,
                                  expansionTileTheme: ExpansionTileThemeData(
                                    backgroundColor: Colors.transparent,
                                    collapsedBackgroundColor: Colors.transparent,
                                    iconColor: Theme.of(context).colorScheme.primary,
                                    collapsedIconColor: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                child: ExpansionTile(
                                  title: Text(
                                    'Okuma Takvimi',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  initiallyExpanded: true,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                      // T2.10: the calendar/chart always show ALL
                                      // logs; only the aggregate cards use the
                                      // period filter (stats.logs).
                                      child: ReadingCalendarWidget(logs: logs),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                           ],
                         );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.isSelected, required this.onTap});
  
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected 
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}





@immutable
class _ReadingStats {
  const _ReadingStats({
    required this.totalPagesRead,
    required this.pagesPerDay,
    required this.totalHours,
    required this.logs,
  });

  final int totalPagesRead;
  final int pagesPerDay;
  final String totalHours;
  final List<ReadingLog> logs;

  _ReadingStats copyWith({
    int? totalPagesRead,
    int? pagesPerDay,
    String? totalHours,
    List<ReadingLog>? logs,
  }) {
    return _ReadingStats(
      totalPagesRead: totalPagesRead ?? this.totalPagesRead,
      pagesPerDay: pagesPerDay ?? this.pagesPerDay,
      totalHours: totalHours ?? this.totalHours,
      logs: logs ?? this.logs,
    );
  }
}
