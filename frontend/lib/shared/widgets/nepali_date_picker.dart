import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../core/theme/app_theme.dart';

class NepaliDatePickerDialog extends StatefulWidget {
  final String title;
  final NepaliDateTime initial;
  final NepaliDateTime? minDate;
  final NepaliDateTime? maxDate;

  const NepaliDatePickerDialog({
    super.key,
    required this.title,
    required this.initial,
    this.minDate,
    this.maxDate,
  });

  @override
  State<NepaliDatePickerDialog> createState() => _NepaliDatePickerDialogState();
}

class _NepaliDatePickerDialogState extends State<NepaliDatePickerDialog> {
  late int _year;
  late int _month;
  late int _day;

  static const _months = [
    'Baishakh (बैशाख)',
    'Jestha (जेठ)',
    'Ashadh (असार)',
    'Shrawan (साउन)',
    'Bhadra (भदौ)',
    'Ashwin (असोज)',
    'Kartik (कार्तिक)',
    'Mangsir (मंसिर)',
    'Poush (पुस)',
    'Magh (माघ)',
    'Falgun (फागुन)',
    'Chaitra (चैत)',
  ];

  static const _weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
    _day = widget.initial.day;
  }

  int get _daysInMonth => NepaliDateTime(_year, _month).totalDays;

  bool _isDisabled(int y, int m, int d) {
    if (widget.minDate != null) {
      final min = widget.minDate!;
      if (y < min.year) return true;
      if (y == min.year && m < min.month) return true;
      if (y == min.year && m == min.month && d < min.day) return true;
    }
    if (widget.maxDate != null) {
      final max = widget.maxDate!;
      if (y > max.year) return true;
      if (y == max.year && m > max.month) return true;
      if (y == max.year && m == max.month && d > max.day) return true;
    }
    return false;
  }

  void _prevMonth() {
    setState(() {
      if (_month == 1) {
        _year--;
        _month = 12;
      } else {
        _month--;
      }
      if (_day > _daysInMonth) _day = _daysInMonth;
    });
  }

  void _nextMonth() {
    setState(() {
      if (_month == 12) {
        _year++;
        _month = 1;
      } else {
        _month++;
      }
      if (_day > _daysInMonth) _day = _daysInMonth;
    });
  }

  void _setToday() {
    final now = NepaliDateTime.now();
    setState(() {
      _year = now.year;
      _month = now.month;
      _day = now.day;
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = _daysInMonth;
    if (_day > maxDay) _day = maxDay;

    final firstDayOfMonth = NepaliDateTime(_year, _month, 1);
    final emptySlots = firstDayOfMonth.weekday - 1;
    final totalItems = emptySlots + maxDay;

    return Dialog(
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Iconsax.calendar_1, color: AppColors.primary, size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.title,
                          style: TextStyle(
                            color: context.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _setToday,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.border),
                        ),
                        child: const Text(
                          'Today',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: context.border, height: 1),
                const SizedBox(height: 10),

                // Year & Month Selectors with Arrow Navigation
                Row(
                  children: [
                    IconButton(
                      onPressed: _prevMonth,
                      icon: const Icon(Iconsax.arrow_left_2, size: 16),
                      tooltip: 'Previous Month',
                      visualDensity: VisualDensity.compact,
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _month,
                            isExpanded: true,
                            dropdownColor: context.surface,
                            style: TextStyle(color: context.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800),
                            icon: const Icon(Iconsax.arrow_down_1, size: 14),
                            items: List.generate(12, (index) {
                              return DropdownMenuItem(value: index + 1, child: Text(_months[index]));
                            }),
                            onChanged: (v) => setState(() {
                              _month = v!;
                              if (_day > _daysInMonth) _day = _daysInMonth;
                            }),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.border),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _year,
                            isExpanded: true,
                            dropdownColor: context.surface,
                            style: TextStyle(color: context.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w800),
                            icon: const Icon(Iconsax.arrow_down_1, size: 14),
                            items: List.generate(100, (index) => 2000 + index).map((y) {
                              return DropdownMenuItem(value: y, child: Text('$y B.S.'));
                            }).toList(),
                            onChanged: (v) => setState(() => _year = v!),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: const Icon(Iconsax.arrow_right_3, size: 16),
                      tooltip: 'Next Month',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Weekdays Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: _weekDays.map((wd) {
                    final isWeekend = wd == 'Sat';
                    return Expanded(
                      child: Center(
                        child: Text(
                          wd,
                          style: TextStyle(
                            color: isWeekend ? AppColors.error : AppColors.textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),

                // Calendar Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    if (index < emptySlots) return const SizedBox.shrink();

                    final day = index - emptySlots + 1;
                    final isSelected = day == _day;
                    final disabled = _isDisabled(_year, _month, day);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: disabled ? null : () => setState(() => _day = day),
                        onDoubleTap: disabled
                            ? null
                            : () => Navigator.of(context).pop(NepaliDateTime(_year, _month, day)),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            day.toString(),
                            style: TextStyle(
                              color: disabled
                                  ? context.textSecondary.withValues(alpha: 0.25)
                                  : isSelected
                                      ? Colors.white
                                      : context.textPrimary,
                              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Selected Date Display
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Center(
                    child: Text(
                      'Selected: $_year-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')} B.S.',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.w700)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isDisabled(_year, _month, _day)
                          ? null
                          : () => Navigator.of(context).pop(NepaliDateTime(_year, _month, _day)),
                      icon: const Icon(Iconsax.tick_circle, size: 16),
                      label: const Text('Confirm Date', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
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
