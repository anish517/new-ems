import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/providers/date_provider.dart';
import '../../core/theme/app_theme.dart';

class GlobalMonthYearPicker extends ConsumerWidget {
  const GlobalMonthYearPicker({super.key});

  static const nepaliMonths = {
    1: 'Baishakh (बैशाख)',
    2: 'Jestha (जेठ)',
    3: 'Ashadh (असार)',
    4: 'Shrawan (साउन)',
    5: 'Bhadra (भदौ)',
    6: 'Ashwin (असोज)',
    7: 'Kartik (कार्तिक)',
    8: 'Mangsir (मंसिर)',
    9: 'Poush (पुस)',
    10: 'Magh (माघ)',
    11: 'Falgun (फागुन)',
    12: 'Chaitra (चैत)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateState = ref.watch(nepaliDateProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.calendar_tick, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Fiscal Period',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => ref.read(nepaliDateProvider.notifier).resetToCurrent(),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Iconsax.rotate_left, size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      isExpanded: true,
                      value: dateState.month,
                      dropdownColor: context.surface,
                      icon: const Icon(Iconsax.arrow_down_1, size: 14),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Whole Year (वार्षिक)'),
                        ),
                        ...nepaliMonths.entries.map((e) {
                          return DropdownMenuItem<int?>(
                            value: e.key,
                            child: Text(e.value, overflow: TextOverflow.ellipsis),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        ref.read(nepaliDateProvider.notifier).setMonth(val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: dateState.year,
                      dropdownColor: context.surface,
                      icon: const Icon(Iconsax.arrow_down_1, size: 14),
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      items: List.generate(30, (index) => 2075 + index).map((year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text('$year'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) ref.read(nepaliDateProvider.notifier).setYear(val);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
