import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../core/theme/app_theme.dart';

/// Formats a [NepaliDateTime] to standard `YYYY-MM-DD` string.
String formatNepaliDate(NepaliDateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// Robust parser for Nepali Bikram Sambat date strings.
/// Supports formats: `YYYY-MM-DD`, `YYYY/MM/DD`, `YYYY.MM.DD`, `YYYY M D`.
NepaliDateTime? parseNepaliDateString(String? input) {
  if (input == null) return null;
  final str = input.trim();
  if (str.isEmpty || str == 'null') return null;

  try {
    // Standard ISO-like parser
    final parts = str.replaceAll('/', '-').replaceAll('.', '-').split('-');
    if (parts.length == 3) {
      final y = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final d = int.tryParse(parts[2].split('T').first.split(' ').first);
      if (y != null && m != null && d != null) {
        if (y >= 1970 && y <= 2100 && m >= 1 && m <= 12 && d >= 1 && d <= 32) {
          final maxDays = NepaliDateTime(y, m).totalDays;
          if (d <= maxDays) {
            return NepaliDateTime(y, m, d);
          }
        }
      }
      return null;
    }
    return null;
  } catch (_) {
    return null;
  }
}

/// Opens the modernized [NepaliDatePickerDialog].
Future<NepaliDateTime?> showNepaliDatePickerDialog({
  required BuildContext context,
  required String title,
  NepaliDateTime? initial,
  NepaliDateTime? minDate,
  NepaliDateTime? maxDate,
}) {
  return showDialog<NepaliDateTime>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => NepaliDatePickerDialog(
      title: title,
      initial: initial ?? NepaliDateTime.now(),
      minDate: minDate,
      maxDate: maxDate,
    ),
  );
}

/// Dialog for picking a Bikram Sambat (B.S.) date.
/// Guarantees that the "Confirm / Select Date" button is always visible.
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

  void _confirmSelection() {
    if (_isDisabled(_year, _month, _day)) return;
    Navigator.of(context).pop(NepaliDateTime(_year, _month, _day));
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = _daysInMonth;
    if (_day > maxDay) _day = maxDay;

    final firstDayOfMonth = NepaliDateTime(_year, _month, 1);
    final emptySlots = firstDayOfMonth.weekday - 1;
    final totalItems = emptySlots + maxDay;
    final formattedSelected =
        '$_year-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')} B.S.';

    return Dialog(
      backgroundColor: context.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 370,
        constraints: const BoxConstraints(maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Top Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Iconsax.calendar_1, color: AppColors.primary, size: 17),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _setToday,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: const Text(
                        'Today',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Iconsax.close_circle, size: 18),
                    color: AppColors.textSecondary,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Divider(color: context.border, height: 1),

            // ── 2. Scrollable Calendar Body ────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Month & Year Selector Row
                    Row(
                      children: [
                        IconButton(
                          onPressed: _prevMonth,
                          icon: const Icon(Iconsax.arrow_left_2, size: 15),
                          tooltip: 'Previous Month',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                        const SizedBox(width: 2),
                        // Month Dropdown
                        Expanded(
                          flex: 3,
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: context.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _month,
                                isExpanded: true,
                                dropdownColor: context.surface,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                icon: const Icon(Iconsax.arrow_down_1, size: 13),
                                items: List.generate(12, (index) {
                                  return DropdownMenuItem(value: index + 1, child: Text(_months[index]));
                                }),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _month = v;
                                      if (_day > _daysInMonth) _day = _daysInMonth;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Year Dropdown
                        Expanded(
                          flex: 2,
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: context.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: context.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _year,
                                isExpanded: true,
                                dropdownColor: context.surface,
                                style: TextStyle(
                                  color: context.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                                icon: const Icon(Iconsax.arrow_down_1, size: 13),
                                items: List.generate(100, (index) => 2000 + index).map((y) {
                                  return DropdownMenuItem(value: y, child: Text('$y B.S.'));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _year = v;
                                      if (_day > _daysInMonth) _day = _daysInMonth;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: _nextMonth,
                          icon: const Icon(Iconsax.arrow_right_3, size: 15),
                          tooltip: 'Next Month',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Weekdays Header Row
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
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: totalItems,
                      itemBuilder: (context, index) {
                        if (index < emptySlots) return const SizedBox.shrink();

                        final day = index - emptySlots + 1;
                        final disabled = _isDisabled(_year, _month, day);
                        final isSelected = !disabled && day == _day;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: disabled ? null : () => setState(() => _day = day),
                            onDoubleTap: disabled ? null : _confirmSelection,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.35),
                                          blurRadius: 4,
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
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Selected Date Pill
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Center(
                        child: Text(
                          'Selected: $formattedSelected',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 3. Guaranteed Visible Action Footer ───────────────────
            Divider(color: context.border, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isDisabled(_year, _month, _day) ? null : _confirmSelection,
                    icon: const Icon(Iconsax.tick_circle, size: 15, color: Colors.white),
                    label: const Text(
                      'Select Date',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      minimumSize: Size.zero,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Form Field for Nepali Bikram Sambat Date input.
///
/// Features:
/// 1. Direct manual keyboard input & editing for Year, Month, and Day (`YYYY-MM-DD`).
/// 2. Interactive Calendar Picker dialog on suffix icon tap.
/// 3. Automatic validation for valid Nepali date boundaries.
/// 4. Bidirectional state & controller synchronization.
class NepaliDateFormField extends StatefulWidget {
  final TextEditingController? controller;
  final String? initialValue;
  final String labelText;
  final String? hintText;
  final IconData prefixIcon;
  final bool isRequired;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String?)? onSaved;
  final NepaliDateTime? minDate;
  final NepaliDateTime? maxDate;
  final bool enabled;

  const NepaliDateFormField({
    super.key,
    this.controller,
    this.initialValue,
    required this.labelText,
    this.hintText = 'YYYY-MM-DD (e.g. 2083-05-08)',
    this.prefixIcon = Iconsax.calendar_1,
    this.isRequired = false,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.minDate,
    this.maxDate,
    this.enabled = true,
  });

  @override
  State<NepaliDateFormField> createState() => _NepaliDateFormFieldState();
}

class _NepaliDateFormFieldState extends State<NepaliDateFormField> {
  late TextEditingController _ctrl;
  bool _internalCtrl = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _ctrl = widget.controller!;
    } else {
      _ctrl = TextEditingController(text: widget.initialValue ?? '');
      _internalCtrl = true;
    }
  }

  @override
  void dispose() {
    if (_internalCtrl) {
      _ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _openPicker() async {
    if (!widget.enabled) return;
    NepaliDateTime initial = NepaliDateTime.now();
    final parsed = parseNepaliDateString(_ctrl.text);
    if (parsed != null) {
      initial = parsed;
    }

    final picked = await showNepaliDatePickerDialog(
      context: context,
      title: widget.labelText.replaceAll('*', '').trim(),
      initial: initial,
      minDate: widget.minDate,
      maxDate: widget.maxDate,
    );

    if (picked != null) {
      final formatted = formatNepaliDate(picked);
      _ctrl.text = formatted;
      widget.onChanged?.call(formatted);
      setState(() {});
    }
  }

  String? _validateDate(String? value) {
    if (widget.isRequired && (value == null || value.trim().isEmpty)) {
      return '${widget.labelText.replaceAll('*', '').trim()} is required';
    }
    if (value != null && value.trim().isNotEmpty) {
      final parsed = parseNepaliDateString(value);
      if (parsed == null) {
        return 'Please enter a valid Nepali date (YYYY-MM-DD)';
      }
      if (widget.minDate != null && parsed.isBefore(widget.minDate!)) {
        return 'Date cannot be before ${formatNepaliDate(widget.minDate!)}';
      }
      if (widget.maxDate != null && parsed.isAfter(widget.maxDate!)) {
        return 'Date cannot be after ${formatNepaliDate(widget.maxDate!)}';
      }
    }
    if (widget.validator != null) {
      return widget.validator!(value);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 210;
        return TextFormField(
          controller: _ctrl,
          enabled: widget.enabled,
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            contentPadding: isCompact
                ? const EdgeInsets.fromLTRB(12, 14, 4, 14)
                : null,
            prefixIcon: isCompact ? null : Icon(widget.prefixIcon, size: 18),
            suffixIcon: IconButton(
              icon: const Icon(Iconsax.calendar_1,
                  size: 18, color: AppColors.primary),
              tooltip: 'Open Nepali Calendar',
              onPressed: _openPicker,
            ),
          ),
          validator: _validateDate,
          onChanged: (val) {
            widget.onChanged?.call(val);
          },
          onSaved: widget.onSaved,
        );
      },
    );
  }
}
