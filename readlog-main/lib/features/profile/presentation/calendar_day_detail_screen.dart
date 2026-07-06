import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart';
import '../../../../shared/widgets/book_scaffold.dart';
import '../../books/application/books_vm.dart';
import '../../books/domain/book.dart';
import '../../reading/domain/reading_log.dart';

// Süre formatlama yardımcı fonksiyonu
String _formatDuration(int totalSeconds) {
  if (totalSeconds < 60) {
    return '$totalSeconds sn';
  } else if (totalSeconds < 3600) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (seconds == 0) return '$minutes dk';
    return '$minutes dk $seconds sn';
  } else {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (minutes == 0) return '$hours sa';
    return '$hours sa $minutes dk';
  }
}

class CalendarDayDetailScreen extends ConsumerWidget {
  const CalendarDayDetailScreen({
    super.key,
    required this.date,
    required this.logs,
  });

  final DateTime date;
  final List<ReadingLog> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksVm = ref.watch(booksVmProvider.notifier);
    final dateFormat = DateFormat('d MMMM yyyy, EEEE', 'tr_TR');
    
    // Sadece o güne ait logları filtrele (tarih kontrolü)
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dayLogs = logs.where((log) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);
      return logDate.isAtSameMomentAs(dayStart) || 
             (logDate.isAfter(dayStart) && logDate.isBefore(dayEnd));
    }).toList();
    
    // T1.12: include every session for the day regardless of the book's shelf,
    // and keep sessions whose book was deleted (shown as a "Silinmiş kitap"
    // placeholder) so calendar, streak and this detail view agree.
    final booksByLog = <String, Book>{};
    final logsByBook = <String, List<ReadingLog>>{};
    int totalMinutes = 0;

    for (final log in dayLogs) {
      final book = booksVm.byId(log.bookId) ??
          Book(
            id: log.bookId,
            title: 'Silinmiş kitap',
            author: '',
            totalPages: 0,
            shelf: BookShelf.read,
          );
      booksByLog[log.bookId] = book;
      logsByBook.putIfAbsent(log.bookId, () => []).add(log);
      totalMinutes += log.effectiveDurationSeconds;
    }
    
    // Sayfa hesaplama - o gün için okunan sayfa sayısı
    int totalPages = 0;
    final pagesByBook = <String, int>{};
    
    for (var entry in logsByBook.entries) {
      final bookId = entry.key;
      final bookLogs = entry.value;
      
      // O gün için bu kitapta okunan sayfa sayısını hesapla
      // Logları tarihe göre sırala
      bookLogs.sort((a, b) => a.date.compareTo(b.date));
      
      int pagesRead = 0;
      if (bookLogs.length == 1) {
        // Tek log varsa, sadece o sayfaya kadar okunmuş
        pagesRead = bookLogs.first.pageAtEnd;
      } else {
        // Birden fazla log varsa, ilk ve son sayfa arasındaki fark
        final firstPage = bookLogs.first.pageAtEnd;
        final lastPage = bookLogs.last.pageAtEnd;
        
        // Eğer ilk sayfa 0 ise, son sayfa kadar okunmuş
        // Değilse, son sayfa - ilk sayfa kadar okunmuş
        pagesRead = firstPage == 0 ? lastPage : (lastPage - firstPage);
        
        // Eğer negatif veya 0 ise, sadece son sayfayı al
        if (pagesRead <= 0) {
          pagesRead = lastPage;
        }
      }
      
      pagesByBook[bookId] = pagesRead;
      totalPages += pagesRead;
    }
    
    return BookScaffold(
      appBar: AppBar(
        title: Text(dateFormat.format(date)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: logsByBook.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bu tarihte okuma kaydı bulunamadı',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Özet Kartı
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryItem(
                            icon: Icons.menu_book,
                            label: 'Oturum',
                            value: '${logsByBook.values.fold<int>(0, (sum, logs) => sum + logs.length)}',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[300]),
                        Expanded(
                          child: _SummaryItem(
                            icon: Icons.access_time,
                            label: 'Toplam Süre',
                            value: _formatDuration(totalMinutes),
                            color: const Color(0xFFFF9800),
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.grey[300]),
                        Expanded(
                          child: _SummaryItem(
                            icon: Icons.auto_stories,
                            label: 'Sayfa',
                            value: '$totalPages',
                            color: const Color(0xFF6C63FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Okunan Kitaplar
                  Text(
                    'OKUNAN KİTAPLAR',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Kitaplara göre grupla
                  ...logsByBook.entries.map((entry) {
                    final bookId = entry.key;
                    final bookLogs = entry.value;
                    final book = booksByLog[bookId];
                    
                    if (book == null) return const SizedBox.shrink();
                    
                    // Bu kitap için toplam süre ve sayfa
                    final bookMinutes = bookLogs.fold<int>(0, (sum, log) => sum + log.effectiveDurationSeconds);
                    final bookPages = pagesByBook[bookId] ?? 0;
                    bookLogs.sort((a, b) => a.date.compareTo(b.date));
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () {
                          // O güne özel kayıtları göster
                          final dayFilteredLogs = bookLogs.where((log) {
                            final logDate = DateTime(log.date.year, log.date.month, log.date.day);
                            final dayStart = DateTime(date.year, date.month, date.day);
                            final dayEnd = dayStart.add(const Duration(days: 1));
                            return logDate.isAtSameMomentAs(dayStart) || 
                                   (logDate.isAfter(dayStart) && logDate.isBefore(dayEnd));
                          }).toList();
                          
                          context.push(
                            Routes.bookReadingLogs(bookId),
                            extra: {'filteredLogs': dayFilteredLogs, 'filterDate': date},
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Kitap Kapağı veya İkon
                                  if (book.coverImagePath != null) ...[
                                    Builder(
                                      builder: (context) {
                                        try {
                                          if (File(book.coverImagePath!).existsSync()) {
                                            return ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.file(
                                                File(book.coverImagePath!),
                                                width: 50,
                                                height: 70,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 50,
                                                    height: 70,
                                                    decoration: BoxDecoration(
                                                      color: Theme.of(context).colorScheme.primaryContainer,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Icon(
                                                      Icons.menu_book,
                                                      color: Theme.of(context).colorScheme.primary,
                                                      size: 30,
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          // Dosya erişim hatası
                                        }
                                        return Container(
                                          width: 50,
                                          height: 70,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primaryContainer,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            Icons.menu_book,
                                            color: Theme.of(context).colorScheme.primary,
                                            size: 30,
                                          ),
                                        );
                                      },
                                    ),
                                  ]
                                  else
                                    Container(
                                      width: 50,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primaryContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.menu_book,
                                        color: Theme.of(context).colorScheme.primary,
                                        size: 30,
                                      ),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          book.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          book.author,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDuration(bookMinutes),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(Icons.auto_stories, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$bookPages sayfa',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 16),
                  
                  // Oturum Detayları
                  Text(
                    'OTURUM DETAYLARI',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // T1.12: show every session for the day, including unfinished
                  // and deleted-book sessions (the book subtitle is omitted when
                  // the book no longer exists).
                  ...dayLogs.map((log) {
                    final book = booksVm.byId(log.bookId);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => context.push(Routes.readingLogDetail(log.id)),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.menu_book,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      log.title ?? 'Okuma Oturumu',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (book != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        book.title,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDuration(log.effectiveDurationSeconds),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(Icons.auto_stories, size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${log.pageAtEnd}. sayfa',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
