import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../reading/domain/reading_log.dart';
import 'package:go_router/go_router.dart';

class ReadingCalendarWidget extends StatefulWidget {
  const ReadingCalendarWidget({
    super.key,
    required this.logs,
  });

  final List<ReadingLog> logs;

  @override
  State<ReadingCalendarWidget> createState() => _ReadingCalendarWidgetState();
}

class _ReadingCalendarWidgetState extends State<ReadingCalendarWidget> {
  late DateTime _focusedMonth;
  bool _isWeeklyView = false;

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime.now();
  }

  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      color: Theme.of(context).cardColor,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                    'OKUMA AKTİVİTESİ',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.grey,
                    ),
                  ),
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ToggleButtons(
                      isSelected: [_isWeeklyView, !_isWeeklyView],
                      onPressed: (index) {
                        setState(() {
                           _isWeeklyView = index == 0;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      selectedColor: Theme.of(context).colorScheme.primary,
                      fillColor: Theme.of(context).colorScheme.primaryContainer,
                      color: Colors.grey,
                      constraints: const BoxConstraints(minHeight: 32, minWidth: 40),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      children: const [
                        Text('Hafta'),
                        Text('Ay'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isWeeklyView
                    ? _WeeklyChart(logs: widget.logs, key: const ValueKey('weekly'))
                    : _MonthlyCalendar(
                        logs: widget.logs,
                        focusedMonth: _focusedMonth,
                        onMonthChanged: _changeMonth,
                        key: const ValueKey('monthly'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _WeeklyChart extends ConsumerWidget {
  const _WeeklyChart({super.key, required this.logs});

  final List<ReadingLog> logs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    // Son 7 günü bul
    final weekDays = List.generate(7, (index) {
      // T2.5: DST-safe day stepping.
      return DateTime(now.year, now.month, now.day - (6 - index));
    });

    // T2.11: logs of deleted books count everywhere (streak already includes
    // them), so don't filter them out of the weekly chart.
    final validLogs = logs;

    // Günlük logları grupla
    final logsByDay = <DateTime, List<ReadingLog>>{};
    final pagesByDay = <DateTime, int>{};
    for (var log in validLogs) {
       final date = DateTime(log.date.year, log.date.month, log.date.day);
       logsByDay.putIfAbsent(date, () => []).add(log);
       final current = pagesByDay[date] ?? 0;
       pagesByDay[date] = current + log.minutes;
    }

    // Maksimum değeri bul (grafik ölçekleme için)
    int maxMinutes = 1;
    for (var m in pagesByDay.values) {
      if (m > maxMinutes) maxMinutes = m;
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: weekDays.map((date) {
          final minutes = pagesByDay[date] ?? 0;
          final dayLogs = logsByDay[date] ?? [];
          final heightFactor = minutes / maxMinutes;
           
          final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
          
          return InkWell(
            onTap: dayLogs.isNotEmpty ? () {
              context.pushNamed('calendar_day_detail', extra: {'date': date, 'logs': dayLogs});
            } : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                 if (minutes > 0)
                  Text(
                    '$minutes\ndk',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                 const SizedBox(height: 4),
                 Flexible(
                   child: Container(
                     width: 12, // İnce barlar
                     height: 140 * heightFactor,
                     constraints: const BoxConstraints(minHeight: 4),
                     decoration: BoxDecoration(
                       color: isToday 
                          ? Theme.of(context).colorScheme.primary 
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                       borderRadius: BorderRadius.circular(4),
                     ),
                   ),
                 ),
                 const SizedBox(height: 8),
                 Text(
                   _weekDayName(date.weekday),
                   style: TextStyle(
                     fontSize: 12, 
                     fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                     color: isToday ? Theme.of(context).colorScheme.primary : Colors.grey,
                   ),
                 ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  String _weekDayName(int weekday) {
    const days = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[weekday];
  }
}

class _MonthlyCalendar extends ConsumerWidget {
  const _MonthlyCalendar({
    super.key,
    required this.logs,
    required this.focusedMonth,
    required this.onMonthChanged,
  });

  final List<ReadingLog> logs;
  final DateTime focusedMonth;
  final ValueChanged<int> onMonthChanged;

  String _monthName(int month) {
    const months = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
      final now = DateTime.now();
      final isCurrentMonth = focusedMonth.year == now.year && focusedMonth.month == now.month;
      
      final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
      final daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
      
      // T2.11: include deleted books' logs (consistent with streak/day-detail).
      final validLogs = logs;

      final logsByDate = <DateTime, List<ReadingLog>>{};
      for (var log in validLogs) {
        final date = DateTime(log.date.year, log.date.month, log.date.day);
        logsByDate.putIfAbsent(date, () => []).add(log);
      }

      return Column(
        children: [
           // Month Navigator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onMonthChanged(-1),
                ),
                const SizedBox(width: 8),
                Text(
                  _monthName(focusedMonth.month) + (focusedMonth.year != now.year ? ' ${focusedMonth.year}' : ''),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrentMonth ? null : () => onMonthChanged(1),
                  color: isCurrentMonth ? Colors.grey[300] : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final itemSize = (width - (6 * 8)) / 7;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'].map((day) => SizedBox(
                      width: itemSize,
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )),
                    ...List.generate(daysInMonth + firstDayOfMonth.weekday - 1, (index) {
                      if (index < firstDayOfMonth.weekday - 1) {
                        return SizedBox(width: itemSize, height: itemSize);
                      }
                      final day = index - (firstDayOfMonth.weekday - 1) + 1;
                      final date = DateTime(focusedMonth.year, focusedMonth.month, day);
                      final dayLogs = logsByDate[date];
                      final isRead = dayLogs != null && dayLogs.isNotEmpty;
                      final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
                      
                      return InkWell(
                        onTap: isRead ? () {
                             context.pushNamed('calendar_day_detail', extra: {'date': date, 'logs': dayLogs});
                        } : null,
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          width: itemSize,
                          height: itemSize,
                          decoration: BoxDecoration(
                            color: isRead 
                                ? Theme.of(context).colorScheme.primary 
                                : isToday 
                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: isToday && !isRead 
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                color: isRead 
                                    ? Colors.white 
                                    : Theme.of(context).textTheme.bodySmall?.color,
                                fontWeight: isRead || isToday ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
        ],
      );
  }
}
