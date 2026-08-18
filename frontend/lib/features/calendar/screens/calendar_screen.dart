import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late NepaliDateTime _viewedMonth;
  late final NepaliDateTime _today;
  List<dynamic> _events = [];
  bool _loading = false;
  String? _error;
  int? _selectedDay;

  static const _monthNames = [
    '',
    'Baishakh',
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
    _selectedDay = _today.day;
    _loadEvents();
  }

  Future<void> _deleteEvent(dynamic event) async {
    final eventId = event['id'];
    final eventTitle = event['title'] ?? event['name'] ?? 'Event';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Calendar Event', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Are you sure you want to delete "$eventTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('${AppConstants.calendarBase}/events/$eventId/');
        _loadEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted successfully'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete event: ${ApiService.getErrorMessage(e)}'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  int get _daysInViewedMonth => _viewedMonth.totalDays;
  int get _startOffset => _viewedMonth.weekday - 1;

  Future<void> _loadEvents() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = '?year=${_viewedMonth.year}&month=${_viewedMonth.month}';
      final eventsRes =
          await ApiService().get('${AppConstants.calendarBase}/events/$params');
      if (!mounted) return;
      setState(() {
        _events = eventsRes.data is List
            ? (eventsRes.data as List).toList()
            : (eventsRes.data['events'] ?? []);
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
      _selectedDay = null;
    });
    _loadEvents();
  }

  void _nextMonth() {
    setState(() {
      _viewedMonth = _viewedMonth.month == 12
          ? NepaliDateTime(_viewedMonth.year + 1, 1, 1)
          : NepaliDateTime(_viewedMonth.year, _viewedMonth.month + 1, 1);
      _selectedDay = null;
    });
    _loadEvents();
  }

  void _goToToday() {
    setState(() {
      _viewedMonth = NepaliDateTime(_today.year, _today.month, 1);
      _selectedDay = _today.day;
    });
    _loadEvents();
  }

  bool _matchesBsDay(dynamic item, int day) {
    final raw =
        (item['start'] ?? item['date'] ?? item['start_date'] ?? '').toString();
    return raw.endsWith('-$day') ||
        raw.endsWith('-${day.toString().padLeft(2, '0')}');
  }

  List<dynamic> _getEventsForDay(int day) {
    return _events.where((e) => _matchesBsDay(e, day)).toList();
  }

  void _showAddEventDialog({int? day}) {
    final targetDay = day ?? _selectedDay ?? _today.day;
    final dateStr =
        '${_viewedMonth.year}-${_viewedMonth.month.toString().padLeft(2, '0')}-${targetDay.toString().padLeft(2, '0')}';
    final titleCtrl = TextEditingController();
    bool isImportant = false;
    bool isHoliday = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: ctx.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: ctx.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Iconsax.calendar_add,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Calendar Event',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: ctx.textPrimary,
                                ),
                              ),
                              Text(
                                'Date: $dateStr (B.S.)',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        hintText: 'e.g. Dashain Festival, Team Retrospective',
                        prefixIcon: Icon(Iconsax.edit_2, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: ctx.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: ctx.border),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            title: const Text('Mark as Important',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                            subtitle: const Text(
                              'Sends early push notifications to staff',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary),
                            ),
                            secondary: const Icon(Iconsax.star_1,
                                color: AppColors.warning, size: 20),
                            value: isImportant,
                            activeThumbColor: AppColors.warning,
                            onChanged: (val) =>
                                setDialogState(() => isImportant = val),
                          ),
                          Divider(height: 1, color: ctx.border),
                          SwitchListTile(
                            title: const Text('Public Holiday',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600)),
                            subtitle: const Text(
                              'Officially counted in monthly payroll issuance',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary),
                            ),
                            secondary: const Icon(Iconsax.sun,
                                color: AppColors.error, size: 20),
                            value: isHoliday,
                            activeThumbColor: AppColors.error,
                            onChanged: (val) =>
                                setDialogState(() => isHoliday = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final title = titleCtrl.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter an event title'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              try {
                                await ApiService().post(
                                    '${AppConstants.calendarBase}/events/',
                                    data: {
                                      'title': title,
                                      'start': dateStr,
                                      'end': dateStr,
                                      'is_important': isImportant,
                                      'is_holiday': isHoliday,
                                    });
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                _loadEvents();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(Iconsax.tick_circle,
                                              color: Colors.white, size: 20),
                                          const SizedBox(width: 12),
                                          Text('Added "$title" successfully'),
                                        ],
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to add event: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Save Event',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;
    final days = _daysInViewedMonth;
    final startOffset = _startOffset;
    final totalCells = days + startOffset;
    final rows = (totalCells / 7).ceil();

    final selectedDayEvents =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, screenConstraints) {
            final isTight = screenConstraints.maxWidth < 650;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTight ? 14 : 24,
                vertical: isTight ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Header & Month Navigator ──────────────────────────────
                  Container(
                    padding: EdgeInsets.all(isTight ? 14 : 20),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(isTight ? 9 : 12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(Iconsax.calendar_1,
                                        color: AppColors.primary, size: isTight ? 20 : 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_monthNames[_viewedMonth.month]} ${_viewedMonth.year} B.S.',
                                          style: TextStyle(
                                            fontSize: isTight ? 17 : 20,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.4,
                                            color: context.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Official Bikram Sambat Calendar',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Iconsax.refresh, size: 18),
                              onPressed: _loadEvents,
                              tooltip: 'Refresh',
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _goToToday,
                                  icon: const Icon(Iconsax.direct_right, size: 15),
                                  label: const Text('Today',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Iconsax.arrow_left_2, size: 16),
                                  onPressed: _prevMonth,
                                  tooltip: 'Previous Month',
                                  style: IconButton.styleFrom(
                                    backgroundColor: context.card,
                                    side: BorderSide(color: context.border),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Iconsax.arrow_right_3, size: 16),
                                  onPressed: _nextMonth,
                                  tooltip: 'Next Month',
                                  style: IconButton.styleFrom(
                                    backgroundColor: context.card,
                                    side: BorderSide(color: context.border),
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ),
                            if (isAdmin)
                              ElevatedButton.icon(
                                onPressed: () => _showAddEventDialog(),
                                icon: const Icon(Iconsax.add, size: 16, color: Colors.white),
                                label: const Text('Add Event',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.warning_2,
                              color: AppColors.error, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loadEvents,
                            child: const Text('Retry',
                                style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),

                  // ── Responsive Main Layout ────────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 960;

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Side: Full Calendar Grid
                            Expanded(
                              flex: 7,
                              child: _buildCalendarCard(
                                context,
                                days: days,
                                startOffset: startOffset,
                                rows: rows,
                                isAdmin: isAdmin,
                              ),
                            ),
                            const SizedBox(width: 24),

                            // Right Side: Selected Day Events & Monthly Agenda
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSelectedDayCard(
                                    context,
                                    selectedDayEvents: selectedDayEvents,
                                    isAdmin: isAdmin,
                                  ),
                                  const SizedBox(height: 20),
                                  _buildMonthAgendaCard(context, isAdmin: isAdmin),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // Mobile / Tablet View
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCalendarCard(
                            context,
                            days: days,
                            startOffset: startOffset,
                            rows: rows,
                            isAdmin: isAdmin,
                          ),
                          const SizedBox(height: 24),
                          _buildSelectedDayCard(
                            context,
                            selectedDayEvents: selectedDayEvents,
                            isAdmin: isAdmin,
                          ),
                          const SizedBox(height: 20),
                          _buildMonthAgendaCard(context, isAdmin: isAdmin),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Calendar Grid Container
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCalendarCard(
    BuildContext context, {
    required int days,
    required int startOffset,
    required int rows,
    required bool isAdmin,
  }) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header Row
          Row(
            children: const [
              'Sun',
              'Mon',
              'Tue',
              'Wed',
              'Thu',
              'Fri',
              'Sat'
            ].map((d) {
              final isSat = d == 'Sat';
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSat ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: context.border),
          const SizedBox(height: 12),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 1.0,
              ),
              itemCount: rows * 7,
              itemBuilder: (context, index) {
                final day = index - startOffset + 1;
                if (day < 1 || day > days) {
                  return const SizedBox();
                }

                final isSaturday = index % 7 == 6;
                final isToday = _viewedMonth.year == _today.year &&
                    _viewedMonth.month == _today.month &&
                    day == _today.day;
                final isSelected = day == _selectedDay;

                final dayEvents = _getEventsForDay(day);
                final hasEvents = dayEvents.isNotEmpty;
                final hasHoliday =
                    dayEvents.any((e) => e['is_holiday'] == true);
                final hasImportant =
                    dayEvents.any((e) => e['is_important'] == true);

                Color? cellBg;
                if (isSelected) {
                  cellBg = AppColors.primary;
                } else if (isToday) {
                  cellBg = AppColors.primary.withValues(alpha: 0.15);
                } else if (isSaturday || hasHoliday) {
                  cellBg = AppColors.error.withValues(alpha: 0.08);
                } else {
                  cellBg = context.card;
                }

                Color textColor;
                if (isSelected) {
                  textColor = Colors.white;
                } else if (isToday) {
                  textColor = AppColors.primary;
                } else if (isSaturday || hasHoliday) {
                  textColor = AppColors.error;
                } else {
                  textColor = context.textPrimary;
                }

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _selectedDay = day);
                    },
                    onDoubleTap: isAdmin ? () => _showAddEventDialog(day: day) : null,
                    borderRadius: BorderRadius.circular(14),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: cellBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : isToday
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : context.border,
                          width: isSelected || isToday ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          if (hasEvents)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasHoliday)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (hasImportant)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.warning,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  if (!hasHoliday && !hasImportant)
                                    Container(
                                      width: 5,
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          // Legend Row
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem(AppColors.primary, 'Today / Selected'),
              _buildLegendItem(AppColors.error, 'Saturday / Public Holiday'),
              _buildLegendItem(AppColors.warning, 'Important Event'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Selected Day Details Card
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSelectedDayCard(
    BuildContext context, {
    required List<dynamic> selectedDayEvents,
    required bool isAdmin,
  }) {
    final isDark = context.isDark;
    final day = _selectedDay ?? _today.day;
    final dateStr =
        '${_monthNames[_viewedMonth.month]} $day, ${_viewedMonth.year} B.S.';

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${selectedDayEvents.length} event(s) on this date',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (isAdmin)
                IconButton(
                  onPressed: () => _showAddEventDialog(day: day),
                  icon: const Icon(Iconsax.add_circle,
                      color: AppColors.primary, size: 22),
                  tooltip: 'Add event to this date',
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (selectedDayEvents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: Column(
                children: [
                  const Icon(Iconsax.calendar_tick,
                      size: 28, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    'No events scheduled for this day.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAdmin
                        ? 'Tap + to create a meeting, holiday, or reminder.'
                        : 'No scheduled company activities or holidays for this day.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedDayEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = selectedDayEvents[i];
                final isHoliday = e['is_holiday'] == true;
                final isImportant = e['is_important'] == true;

                Color tagColor = AppColors.primary;
                if (isHoliday) tagColor = AppColors.error;
                if (isImportant) tagColor = AppColors.warning;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: tagColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isHoliday
                              ? Iconsax.sun
                              : isImportant
                                  ? Iconsax.star_1
                                  : Iconsax.calendar_1,
                          color: tagColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e['title'] ?? e['name'] ?? 'Untitled Event',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (isHoliday)
                                  Container(
                                    margin: const EdgeInsets.only(right: 6),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.error
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Public Holiday',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ),
                                if (isImportant)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Important',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Iconsax.trash, size: 16, color: AppColors.error),
                          tooltip: 'Delete Event',
                          onPressed: () => _deleteEvent(e),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Month Highlights & Agenda
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildMonthAgendaCard(BuildContext context, {required bool isAdmin}) {
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.note_21, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Month Agenda (${_monthNames[_viewedMonth.month]})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_events.isEmpty)
            const Text(
              'No events or holidays registered for this month.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _events.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.border),
              itemBuilder: (context, i) {
                final e = _events[i];
                final dateRaw =
                    e['start'] ?? e['date'] ?? e['start_date'] ?? 'N/A';
                final isHoliday = e['is_holiday'] == true;
                final isImportant = e['is_important'] == true;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.border),
                        ),
                        child: Text(
                          dateRaw.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e['title'] ?? e['name'] ?? '',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      if (isHoliday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Holiday',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else if (isImportant)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Important',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Iconsax.trash, size: 15, color: AppColors.error),
                          tooltip: 'Delete event',
                          onPressed: () => _deleteEvent(e),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
