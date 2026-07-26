import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../services/api_service.dart';

class NepaliDateState {
  final int year;
  final int month;

  NepaliDateState({required this.year, required this.month});

  NepaliDateState copyWith({int? year, int? month}) {
    return NepaliDateState(
      year: year ?? this.year,
      month: month ?? this.month,
    );
  }
}

class NepaliDateNotifier extends StateNotifier<NepaliDateState> {
  NepaliDateNotifier()
      : super(NepaliDateState(
          year: NepaliDateTime.now().year,
          month: NepaliDateTime.now().month,
        )) {
    ApiService.globalNepaliYear = state.year;
    ApiService.globalNepaliMonth = state.month;
  }

  void setYear(int year) {
    ApiService.globalNepaliYear = year;
    state = state.copyWith(year: year);
  }

  void setMonth(int month) {
    ApiService.globalNepaliMonth = month;
    state = state.copyWith(month: month);
  }

  void setDate(int year, int month) {
    ApiService.globalNepaliYear = year;
    ApiService.globalNepaliMonth = month;
    state = state.copyWith(year: year, month: month);
  }

  void resetToCurrent() {
    final now = NepaliDateTime.now();
    ApiService.globalNepaliYear = now.year;
    ApiService.globalNepaliMonth = now.month;
    state = state.copyWith(year: now.year, month: now.month);
  }
}

final nepaliDateProvider =
    StateNotifierProvider<NepaliDateNotifier, NepaliDateState>((ref) {
  return NepaliDateNotifier();
});
