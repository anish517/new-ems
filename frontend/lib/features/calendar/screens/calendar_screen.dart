import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late NepaliDateTime
      _viewedMonth; // day is always 1; year/month drive the view
  late final NepaliDateTime _today;
  List _events = [];
  List _holidays = [];
  bool _loading = false;
  String? _error;

  static const _monthNames = [
    '',
    'Baisakh',
    'Jestha',
    'Ashadh',
    'Shrawan',
    'Bhadra',
    'Ashwin',
    'Kartik',
    'Mangsir',
    'Poush',
    'Magh',
    'Falgun',
    'Chaitra',
  ];

  @override
  void initState() {
    super.initState();
    _today = NepaliDateTime.now();
    _viewedMonth = NepaliDateTime(_today.year, _today.month, 1);
    _loadEvents();
  }

  /// Days in the viewed BS month, derived from the library's AD conversion
  /// rather than a hand-maintained table — stays correct for any year the
  /// package supports, no manual updates needed.
  int get _daysInViewedMonth {
    final thisMonthStartAd = _viewedMonth.toDateTime();
    final nextMonth = _viewedMonth.month == 12
        ? NepaliDateTime(_viewedMonth.year + 1, 1, 1)
        : NepaliDateTime(_viewedMonth.year, _viewedMonth.month + 1, 1);
    return nextMonth.toDateTime().difference(thisMonthStartAd).inDays;
  }

  /// 0 = Sunday ... 6 = Saturday, matching the day-header row below.
  /// NOTE: assumes NepaliDateTime.weekday follows DateTime's convention
  /// (Monday=1...Sunday=7) — worth a quick print/debug check after adding
  /// the dependency, since this is the one piece I couldn't verify from docs.
  int get _startOffset => _viewedMonth.weekday % 7;

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eventsRes =
          await ApiService().get('${AppConstants.calendarBase}/events/');
      final holidaysRes =
          await ApiService().get('${AppConstants.calendarBase}/dates/');
      if (!mounted) return;
      setState(() {
        _events = eventsRes.data is List
            ? eventsRes.data
            : (eventsRes.data['results'] ?? []);
        _holidays = holidaysRes.data is List
            ? holidaysRes.data
            : (holidaysRes.data['results'] ?? []);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load calendar data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() {
      _viewedMonth = _viewedMonth.month == 1
          ? NepaliDateTime(_viewedMonth.year - 1, 12, 1)
          : NepaliDateTime(_viewedMonth.year, _viewedMonth.month - 1, 1);
    });
    _loadEvents();
  }

  void _nextMonth() {
    setState(() {
      _viewedMonth = _viewedMonth.month == 12
          ? NepaliDateTime(_viewedMonth.year + 1, 1, 1)
          : NepaliDateTime(_viewedMonth.year, _viewedMonth.month + 1, 1);
    });
    _loadEvents();
  }

  bool _matchesBsDay(dynamic item, int day) {
    final raw = (item['date'] ?? item['start_date'] ?? '').toString();
    // Assumes the API already returns BS-formatted dates (YYYY-MM-DD).
    // If it actually returns AD dates, convert first:
    // DateTime.parse(raw).toNepaliDateTime()
    return raw.endsWith('-$day') ||
        raw.endsWith('-${day.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final days = _daysInViewedMonth;
    final startOffset = _startOffset;
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppColors.surfaceDark,
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
            Expanded(
                child: Text(
              '${_monthNames[_viewedMonth.month]} ${_viewedMonth.year} BS',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            )),
            IconButton(
                icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
          ]),
        ),
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
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.error))),
              TextButton(onPressed: _loadEvents, child: const Text('Retry')),
            ]),
          ),
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
                    if (day < 1 || day > days) return const SizedBox();

                    final isSaturday = index % 7 == 6;
                    final isToday = _viewedMonth.year == _today.year &&
                        _viewedMonth.month == _today.month &&
                        day == _today.day;
                    final hasEvent = _events.any((e) => _matchesBsDay(e, day));
                    final isHoliday =
                        _holidays.any((h) => _matchesBsDay(h, day));

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
                          Text('$day',
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
                              )),
                          if (hasEvent)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
        if (_events.isNotEmpty) ...[
          const Divider(height: 1),
          Container(
            height: 140,
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Events',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              Expanded(
                  child: ListView.separated(
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
                      border: Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(e['name'] ?? e['title'] ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text(e['date'] ?? e['start_date'] ?? '',
                              style: const TextStyle(
                                  fontSize: 10,
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
