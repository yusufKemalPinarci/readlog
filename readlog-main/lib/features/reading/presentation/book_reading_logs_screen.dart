import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/app_router.dart';
import '../../books/application/books_vm.dart';
import '../../../shared/widgets/book_scaffold.dart';
import '../../books/domain/book.dart';
import '../application/reading_providers.dart';
import '../domain/reading_log.dart';
import '../../../shared/widgets/book_loading_widget.dart';

// Süre formatlama yardımcı fonksiyonu (saniye cinsinden alır)
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

class BookReadingLogsScreen extends ConsumerStatefulWidget {
  const BookReadingLogsScreen({
    super.key,
    required this.bookId,
    this.filteredLogs,
    this.filterDate,
  });

  final String bookId;
  final List<ReadingLog>? filteredLogs;
  final DateTime? filterDate;

  @override
  ConsumerState<BookReadingLogsScreen> createState() => _BookReadingLogsScreenState();
}

class _BookReadingLogsScreenState extends ConsumerState<BookReadingLogsScreen> {
  @override
  Widget build(BuildContext context) {
    final booksVm = ref.watch(booksVmProvider.notifier);
    final book = booksVm.byId(widget.bookId);
    
    // Eğer filtrelenmiş loglar varsa onları kullan, yoksa tüm logları yükle
    final logsAsync = widget.filteredLogs != null
        ? AsyncValue.data(widget.filteredLogs!)
        : ref.watch(_bookLogsProvider(widget.bookId));

    if (book == null) {
      return BookScaffold(
        appBar: AppBar(title: const Text('Kitap Bulunamadı')),
        body: const Center(child: Text('Kitap bulunamadı.')),
      );
    }

    return logsAsync.when(
      data: (logs) {
        final totalSeconds = logs.fold<int>(0, (sum, log) => sum + log.effectiveDurationSeconds);
        final sessionCount = logs.length;
        
        final totalDurationText = _formatDuration(totalSeconds);

        return _Content(
          book: book,
          logs: logs,
          totalDurationText: totalDurationText,
          sessionCount: sessionCount,
        );
      },
      loading: () => BookScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Okuma Kayıtlarım'),
        ),
        body: const BookLoadingWidget(message: 'Okuma kayıtları yükleniyor...'),
      ),
      error: (err, stack) => BookScaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Okuma Kayıtlarım'),
        ),
        body: Center(child: Text('Hata: $err')),
      ),
    );
  }
}

class _Content extends ConsumerStatefulWidget {
  const _Content({
    required this.book,
    required this.logs,
    required this.totalDurationText,
    required this.sessionCount,
    this.filterDate,
  });

  final Book book;
  final List<ReadingLog> logs;
  final String totalDurationText;
  final int sessionCount;
  final DateTime? filterDate;

  @override
  ConsumerState<_Content> createState() => _ContentState();
}

enum _LogFilter { all, withAudio, withNote }

class _ContentState extends ConsumerState<_Content> {
  _LogFilter _filter = _LogFilter.all;

  List<ReadingLog> get _filteredLogs {
    // Eğer filterDate varsa, önce o güne ait logları filtrele
    List<ReadingLog> logsToFilter = widget.logs;
    
    if (widget.filterDate != null) {
      final dayStart = DateTime(
        widget.filterDate!.year,
        widget.filterDate!.month,
        widget.filterDate!.day,
      );
      final dayEnd = DateTime(dayStart.year, dayStart.month, dayStart.day + 1); // T2.5 DST-safe

      logsToFilter = widget.logs.where((log) {
        final logDate = DateTime(log.date.year, log.date.month, log.date.day);
        return logDate.isAtSameMomentAs(dayStart) || 
               (logDate.isAfter(dayStart) && logDate.isBefore(dayEnd));
      }).toList();
    }
    
    // Sort logs by date, newest first
    final sorted = List<ReadingLog>.from(logsToFilter)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    switch (_filter) {
      case _LogFilter.all:
        return sorted;
      case _LogFilter.withAudio:
        return sorted.where((l) => l.audioFilePath != null).toList();
      case _LogFilter.withNote:
        return sorted.where((l) => (l.note != null && l.note!.isNotEmpty) || l.noteFilePath != null).toList();
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs;
    
    return BookScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Okuma Kayıtlarım'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BookHeader(book: widget.book),
              const SizedBox(height: 16),
              _StatsCards(
                totalDurationText: widget.totalDurationText,
                sessionCount: widget.sessionCount,
              ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Geçmiş Oturumlar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  PopupMenuButton<_LogFilter>(
                    icon: Icon(
                      Icons.filter_list,
                      color: _filter != _LogFilter.all ? Theme.of(context).colorScheme.primary : null,
                    ),
                    onSelected: (filter) {
                      setState(() {
                        _filter = filter;
                      });
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: _LogFilter.all,
                        child: Row(
                          children: [
                            Icon(Icons.list, color: _filter == _LogFilter.all ? Theme.of(context).colorScheme.primary : null),
                            const SizedBox(width: 12),
                            const Text('Tümü'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _LogFilter.withAudio,
                        child: Row(
                          children: [
                            Icon(Icons.mic, color: _filter == _LogFilter.withAudio ? Theme.of(context).colorScheme.primary : null),
                            const SizedBox(width: 12),
                            const Text('Sesli Kayıtlar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _LogFilter.withNote,
                        child: Row(
                          children: [
                            Icon(Icons.note, color: _filter == _LogFilter.withNote ? Theme.of(context).colorScheme.primary : null),
                            const SizedBox(width: 12),
                            const Text('Notlu Kayıtlar'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (logs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    _filter == _LogFilter.all
                        ? 'Henüz okuma kaydı yok.'
                        : _filter == _LogFilter.withAudio
                            ? 'Sesli kayıt bulunamadı.'
                            : 'Notlu kayıt bulunamadı.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...logs.map((log) => _LogItem(
                    log: log,
                    formatDuration: _formatDuration,
                    onTap: () => GoRouter.of(context).push(Routes.readingLogDetail(log.id)),
                  )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

final _bookLogsProvider = FutureProvider.autoDispose.family<List<ReadingLog>, String>((ref, bookId) async {
  // readingLogsProvider'ı izle → loglar değişince bu provider da yenilensin
  ref.watch(readingLogsProvider);
  final repo = ref.watch(readingLogsRepositoryProvider);
  return repo.listByBookId(bookId);
});

class _BookHeader extends StatelessWidget {
  const _BookHeader({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book, size: 40, color: Colors.grey),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  book.author,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Tag(label: 'Klasikler'),
                    _Tag(label: '${book.totalPages} Sayfa'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _StatsCards extends StatelessWidget {
  const _StatsCards({
    required this.totalDurationText,
    required this.sessionCount,
  });

  final String totalDurationText;
  final int sessionCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              value: totalDurationText,
              label: 'TOPLAM SÜRE',
              icon: Icons.access_time,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              value: '$sessionCount',
              label: 'OTURUM',
              icon: Icons.bookmark_outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(icon, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  const _LogItem({
    required this.log,
    required this.onTap,
    this.formatDuration,
  });

  final ReadingLog log;
  final VoidCallback onTap;
  final String Function(int)? formatDuration;

  @override
  Widget build(BuildContext context) {
    String dateStr;
    try {
      dateStr = DateFormat('d MMMM yyyy, HH:mm', 'tr_TR').format(log.date);
    } catch (e) {
      dateStr = DateFormat('d MMMM yyyy, HH:mm').format(log.date);
    }
    
    final durationText = formatDuration?.call(log.effectiveDurationSeconds) ?? _formatDuration(log.effectiveDurationSeconds);
    final title = log.title ?? "Okuma Oturumu";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        log.audioFilePath != null ? Icons.mic : Icons.menu_book,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Title and Date
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12, 
                              color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Duration
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            durationText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page Info
                    if (log.pageAtEnd > 0)
                      Row(
                        children: [
                          Icon(Icons.bookmark_outline, size: 16, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            '${log.pageAtEnd}. Sayfaya gelindi',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      )
                    else 
                      const Text('Sayfa bilgisi yok', style: TextStyle(fontSize: 12, color: Colors.grey)),

                    // Attachments icons
                    if (log.noteFilePath != null || (log.note != null && log.note!.isNotEmpty) || log.audioFilePath != null)
                      Row(
                        children: [
                          if (log.audioFilePath != null)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.mic, size: 16, color: Colors.grey),
                            ),
                          if (log.noteFilePath != null || (log.note != null && log.note!.isNotEmpty))
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(Icons.note, size: 16, color: Colors.grey),
                            ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

