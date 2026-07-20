import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

/// Nepali BS Calendar months have fixed day counts per year pattern.
/// This is a simplified static mapping for demonstration.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Current BS date (approximate conversion from AD)
  late int _bsYear;
  late int _bsMonth;
  List _events = [];
  List _holidays = [];
  bool _loading = false;

  // BS month names
  static const _monthNames = [
    '', 'Baisakh', 'Jestha', 'Ashadh', 'Shrawan',
    'Bhadra', 'Ashwin', 'Kartik', 'Mangsir',
    'Poush', 'Magh', 'Falgun', 'Chaitra',
  ];

  // Days in each month for BS year 2081 (approximate)
  static const Map<int, List<int>> _bsDaysInMonth = {
    2079: [0, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 31],
    2080: [0, 31, 31, 32, 32, 31, 30, 30, 30, 29, 30, 29, 30],
    2081: [0, 31, 31, 32, 31, 31, 31, 30, 29, 30, 29, 30, 30],
    2082: [0, 31, 32, 31, 32, 31, 30, 30, 30, 29, 30, 29, 30],
  };

  @override
  void initState() {
    super.initState();
    // Approximate: AD 2025 ≈ BS 2082, current month shift ~3.5 months
    final now = DateTime.now();
    // Simple approximation: BS year = AD year + 56 or 57
    _bsYear = now.month <= 4 ? now.year + 56 : now.year + 56;
    _bsMonth = ((now.month + 8) % 12) + 1; // rough offset
    // Clamp to valid range
    _bsYear = _bsYear.clamp(2079, 2082);
    _bsMonth = _bsMonth.clamp(1, 12);
    _loadEvents();
  }

  int get _daysInCurrentMonth {
    final yearData = _bsDaysInMonth[_bsYear];
    if (yearData == null) return 30;
    return yearData[_bsMonth];
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final eventsRes = await ApiService().get('${AppConstants.calendarBase}/events/');
      final holidaysRes = await ApiService().get('${AppConstants.calendarBase}/dates/');
      if (!mounted) return;
      setState(() {
        _events = eventsRes.data is List
            ? eventsRes.data
            : (eventsRes.data['results'] ?? []);
        _holidays = holidaysRes.data is List
            ? holidaysRes.data
            : (holidaysRes.data['results'] ?? []);
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _prevMonth() {
    setState(() {
      if (_bsMonth == 1) { _bsMonth = 12; _bsYear--; }
      else { _bsMonth--; }
    });
    _loadEvents();
  }

  void _nextMonth() {
    setState(() {
      if (_bsMonth == 12) { _bsMonth = 1; _bsYear++; }
      else { _bsMonth++; }
    });
    _loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInCurrentMonth;
    // BS week starts on Sunday. Day 1 of the month offset — simplified to 0
    const startOffset = 0;
    final totalCells = days + startOffset;
    final rows = (totalCells / 7).ceil();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadEvents),
        ],
      ),
      body: Column(children: [
        // Month navigation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.surfaceDark,
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prevMonth,
            ),
            Expanded(child: Text(
              '${_monthNames[_bsMonth]} $_bsYear BS',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextMonth,
            ),
          ]),
        ),

        // Day headers
        Container(
          color: AppColors.surfaceDark,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(d,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: d == 'Sat'
                                    ? AppColors.error
                                    : AppColors.textSecondary)),
                      ),
                    ))
                .toList(),
          ),
        ),
        const Divider(height: 1),

        // Calendar grid
        _loading
            ? const Expanded(child: Center(child: CircularProgressIndicator()))
            : Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: rows * 7,
                  itemBuilder: (_, index) {
                    final day = index - startOffset + 1;
                    if (day < 1 || day > days) {
                      return const SizedBox();
                    }
                    final isSaturday = index % 7 == 6;
                    final isToday = day == 15; // placeholder — no real today mapping
                    final hasEvent = _events.any((e) {
                      final d = e['date'] ?? e['start_date'] ?? '';
                      return d.toString().endsWith('-$day') ||
                          d.toString().endsWith('-${day.toString().padLeft(2, '0')}');
                    });
                    final isHoliday = _holidays.any((h) {
                      final d = h['date'] ?? '';
                      return d.toString().endsWith('-$day') ||
                          d.toString().endsWith('-${day.toString().padLeft(2, '0')}');
                    });

                    return Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppColors.primary
                            : isHoliday
                                ? AppColors.error.withValues(alpha: 0.1)
                                : null,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? null
                            : Border.all(
                                color: AppColors.surfaceDark, width: 0.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? Colors.white
                                  : isSaturday || isHoliday
                                      ? AppColors.error
                                      : null,
                            ),
                          ),
                          if (hasEvent)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

        // Events this month
        if (_events.isNotEmpty) ...[
          const Divider(height: 1),
          Container(
            height: 140,
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Events',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Expanded(child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _events.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final e = _events[i];
                  return Container(
                    width: 140,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(e['name'] ?? e['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w600,
                              fontSize: 12),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(e['date'] ?? e['start_date'] ?? '',
                          style: const TextStyle(fontSize: 10,
                              color: AppColors.textSecondary)),
                    ]),
                  );
                },
              )),
            ]),
          ),
        ],
      ]),
    );
  }
}
