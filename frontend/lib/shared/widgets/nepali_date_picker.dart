import 'package:flutter/material.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../core/theme/app_theme.dart';

class NepaliDatePickerDialog extends StatefulWidget {
  final String title;
  final NepaliDateTime initial;
  final NepaliDateTime? minDate;

  const NepaliDatePickerDialog({
    super.key,
    required this.title,
    required this.initial,
    this.minDate,
  });

  @override
  State<NepaliDatePickerDialog> createState() => _NepaliDatePickerDialogState();
}

class _NepaliDatePickerDialogState extends State<NepaliDatePickerDialog> {
  late int _year;
  late int _month;
  late int _day;

  static const _months = [
    'Baishakh', 'Jestha', 'Ashadh', 'Shrawan', 'Bhadra', 'Ashwin',
    'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra',
  ];

  static const _weekDays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
    _day = widget.initial.day;
  }

  int get _daysInMonth => NepaliDateTime(_year, _month).totalDays;

  bool _isBeforeMin(int y, int m, int d) {
    if (widget.minDate == null) return false;
    final min = widget.minDate!;
    if (y < min.year) return true;
    if (y == min.year && m < min.month) return true;
    if (y == min.year && m == min.month && d < min.day) return true;
    return false;
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              
              // Year and Month Selectors
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: DropdownButton<int>(
                      value: _year,
                      isExpanded: true,
                      dropdownColor: context.bg,
                      style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down, size: 24),
                      items: List.generate(100, (index) => 2000 + index).map((y) {
                        return DropdownMenuItem(value: y, child: Text(y.toString()));
                      }).toList(),
                      onChanged: (v) => setState(() => _year = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButton<int>(
                      value: _month,
                      isExpanded: true,
                      dropdownColor: context.bg,
                      style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      underline: const SizedBox.shrink(),
                      icon: const Icon(Icons.arrow_drop_down, size: 24),
                      items: List.generate(12, (index) {
                        return DropdownMenuItem(value: index + 1, child: Text(_months[index]));
                      }).toList(),
                      onChanged: (v) => setState(() {
                        _month = v!;
                        if (_day > _daysInMonth) _day = _daysInMonth;
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Weekdays Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _weekDays.map((wd) => Expanded(
                  child: Center(
                    child: Text(wd, style: TextStyle(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 8),
              
              // Calendar Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: totalItems,
                  itemBuilder: (context, index) {
                    if (index < emptySlots) return const SizedBox.shrink();
                    
                    final day = index - emptySlots + 1;
                    final isSelected = day == _day;
                    final isDisabled = _isBeforeMin(_year, _month, day);
                    
                    return InkWell(
                      onTap: isDisabled ? null : () {
                        setState(() => _day = day);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          day.toString(),
                          style: TextStyle(
                            color: isDisabled 
                                ? context.textSecondary.withValues(alpha: 0.3)
                                : isSelected 
                                    ? Colors.white 
                                    : context.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
              
              // Selected Date Text
              Text(
                '$_year-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')}',
                style: TextStyle(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 20),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel',
                        style: TextStyle(color: context.textSecondary, fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: _isBeforeMin(_year, _month, _day)
                        ? null
                        : () {
                            Navigator.of(context)
                                .pop(NepaliDateTime(_year, _month, _day));
                          },
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(100, 44), 
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('Select', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
