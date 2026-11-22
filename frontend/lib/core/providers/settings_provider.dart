import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_service.dart';
import '../constants/app_constants.dart';

class OrgSettings {
  final bool enableDailyPerformance;
  final bool enableInOfficeAttendance;
  final bool enableRemoteAttendance;
  final double? officeLatitude;
  final double? officeLongitude;
  final int allowedAttendanceRadius;
  final int maxFreeCorrectionsPerMonth;
  final double correctionPenaltyPoints;
  final bool countRejectedCorrections;

  const OrgSettings({
    this.enableDailyPerformance = true,
    this.enableInOfficeAttendance = true,
    this.enableRemoteAttendance = true,
    this.officeLatitude,
    this.officeLongitude,
    this.allowedAttendanceRadius = 100,
    this.maxFreeCorrectionsPerMonth = 2,
    this.correctionPenaltyPoints = 0.5,
    this.countRejectedCorrections = false,
  });

  factory OrgSettings.fromJson(Map<String, dynamic> json) {
    return OrgSettings(
      enableDailyPerformance: json['enable_daily_performance'] ?? true,
      enableInOfficeAttendance: json['enable_in_office_attendance'] ?? true,
      enableRemoteAttendance: json['enable_remote_attendance'] ?? true,
      officeLatitude: json['office_latitude'] != null
          ? double.tryParse(json['office_latitude'].toString())
          : null,
      officeLongitude: json['office_longitude'] != null
          ? double.tryParse(json['office_longitude'].toString())
          : null,
      allowedAttendanceRadius: json['allowed_attendance_radius'] ?? 100,
      maxFreeCorrectionsPerMonth:
          (json['max_free_corrections_per_month'] as num?)?.toInt() ?? 2,
      correctionPenaltyPoints:
          (json['correction_penalty_points'] as num?)?.toDouble() ?? 0.5,
      countRejectedCorrections: json['count_rejected_corrections'] ?? false,
    );
  }
}

class OrgSettingsNotifier extends StateNotifier<OrgSettings> {
  OrgSettingsNotifier() : super(const OrgSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final res = await ApiService().get('${AppConstants.organizationBase}/settings/');
      if (res.data != null && res.data is Map<String, dynamic>) {
        state = OrgSettings.fromJson(res.data);
      }
    } catch (_) {}
  }

  void updateSettings(OrgSettings newSettings) {
    state = newSettings;
  }
}

final orgSettingsProvider =
    StateNotifierProvider<OrgSettingsNotifier, OrgSettings>((ref) {
  return OrgSettingsNotifier();
});
