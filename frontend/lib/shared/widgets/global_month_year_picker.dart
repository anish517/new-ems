import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/date_provider.dart';
import '../../core/theme/app_theme.dart';

class GlobalMonthYearPicker extends ConsumerWidget {
  const GlobalMonthYearPicker({super.key});

  static const nepaliMonths = {
    1: 'Baishakh',
    2: 'Jestha',
    3: 'Ashadh',
    4: 'Shrawan',
    5: 'Bhadra',
    6: 'Ashwin',
    7: 'Kartik',
    8: 'Mangsir',
    9: 'Poush',
    10: 'Magh',
    11: 'Falgun',
    12: 'Chaitra',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateState = ref.watch(nepaliDateProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Data Period', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => ref.read(nepaliDateProvider.notifier).resetToCurrent(),
                child: const Icon(Icons.restore, size: 16, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: dateState.month,
                  dropdownColor: AppColors.surfaceDark,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  items: nepaliMonths.entries.map((e) {
                    return DropdownMenuItem<int>(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) ref.read(nepaliDateProvider.notifier).setMonth(val);
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: dateState.year,
                  dropdownColor: AppColors.surfaceDark,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  items: List.generate(30, (index) => 2075 + index).map((year) {
                    return DropdownMenuItem<int>(
                      value: year,
                      child: Text(year.toString()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) ref.read(nepaliDateProvider.notifier).setYear(val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
