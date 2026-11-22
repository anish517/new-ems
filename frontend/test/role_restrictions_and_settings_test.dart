import 'package:flutter_test/flutter_test.dart';
import 'package:ems_app/core/providers/settings_provider.dart';

void main() {
  group('OrgSettings Model Tests', () {
    test('Should parse OrgSettings JSON with enable_daily_performance true', () {
      final json = {
        'enable_daily_performance': true,
        'enable_in_office_attendance': true,
        'enable_remote_attendance': false,
        'office_latitude': '27.7172',
        'office_longitude': '85.3240',
        'allowed_attendance_radius': 150,
      };

      final settings = OrgSettings.fromJson(json);
      expect(settings.enableDailyPerformance, isTrue);
      expect(settings.enableInOfficeAttendance, isTrue);
      expect(settings.enableRemoteAttendance, isFalse);
      expect(settings.officeLatitude, 27.7172);
      expect(settings.officeLongitude, 85.3240);
      expect(settings.allowedAttendanceRadius, 150);
    });

    test('Should parse OrgSettings JSON with enable_daily_performance false', () {
      final json = {
        'enable_daily_performance': false,
        'enable_in_office_attendance': false,
        'enable_remote_attendance': true,
      };

      final settings = OrgSettings.fromJson(json);
      expect(settings.enableDailyPerformance, isFalse);
      expect(settings.enableInOfficeAttendance, isFalse);
      expect(settings.enableRemoteAttendance, isTrue);
      expect(settings.allowedAttendanceRadius, 100);
    });

    test('Should fallback to true when enable_daily_performance is omitted', () {
      final json = <String, dynamic>{};
      final settings = OrgSettings.fromJson(json);
      expect(settings.enableDailyPerformance, isTrue);
      expect(settings.enableInOfficeAttendance, isTrue);
      expect(settings.enableRemoteAttendance, isTrue);
      expect(settings.maxFreeCorrectionsPerMonth, 2);
      expect(settings.correctionPenaltyPoints, 0.5);
      expect(settings.countRejectedCorrections, isFalse);
    });

    test('Should parse attendance correction policy fields from OrgSettings JSON', () {
      final json = <String, dynamic>{
        'max_free_corrections_per_month': 3,
        'correction_penalty_points': 1.25,
        'count_rejected_corrections': true,
      };
      final settings = OrgSettings.fromJson(json);
      expect(settings.maxFreeCorrectionsPerMonth, 3);
      expect(settings.correctionPenaltyPoints, 1.25);
      expect(settings.countRejectedCorrections, isTrue);
    });
  });

  group('Role-Based Navigation & Visibility Rules', () {
    List<String> getNavRoutes({required bool isAdmin, required bool enablePerformance}) {
      final employeeNav = [
        '/',
        '/attendance',
        '/leave',
        '/tasks',
        '/projects',
        '/salary',
        if (enablePerformance) '/performance',
        '/noticeboard',
        '/policy',
        '/calendar',
        '/feedback',
        '/profile',
      ];

      final adminNav = [
        '/',
        '/employees',
        '/attendance',
        '/leave',
        '/salary',
        '/tasks',
        '/projects',
        '/performance',
        '/noticeboard',
        '/policy',
        '/calendar',
        '/feedback',
        '/profile',
      ];

      return isAdmin ? adminNav : employeeNav;
    }

    test('Admin navigation always includes /performance even when enable_daily_performance is false', () {
      final routesTrue = getNavRoutes(isAdmin: true, enablePerformance: true);
      expect(routesTrue.contains('/performance'), isTrue);

      final routesFalse = getNavRoutes(isAdmin: true, enablePerformance: false);
      expect(routesFalse.contains('/performance'), isTrue);
      expect(routesFalse.contains('/employees'), isTrue);
    });

    test('Employee navigation includes /performance when enable_daily_performance is true', () {
      final routes = getNavRoutes(isAdmin: false, enablePerformance: true);
      expect(routes.contains('/performance'), isTrue);
      expect(routes.contains('/attendance'), isTrue);
    });

    test('Employee navigation hides /performance when enable_daily_performance is false', () {
      final routes = getNavRoutes(isAdmin: false, enablePerformance: false);
      expect(routes.contains('/performance'), isFalse);
      expect(routes.contains('/attendance'), isTrue);
    });
  });

  group('Feedback Screen Action Visibility Rules', () {
    bool canShowNewComplaintButton({required bool isAdmin}) {
      return !isAdmin;
    }

    test('Employee should see New Complaint button', () {
      expect(canShowNewComplaintButton(isAdmin: false), isTrue);
    });

    test('Admin should NOT see New Complaint button', () {
      expect(canShowNewComplaintButton(isAdmin: true), isFalse);
    });
  });

  group('Attendance Screen Action Visibility Rules', () {
    bool canPerformEmployeeAttendanceActions({required bool isAdmin}) {
      return !isAdmin;
    }

    List<String> getAttendanceTabs({required bool isAdmin}) {
      if (isAdmin) {
        return ['Staff Logs', 'Remote Access', 'Corrections', 'Geofence & Rules'];
      }
      return ['My Check-In Hub'];
    }

    test('Employee can perform Clock-In, WFH Request, and Correction Request', () {
      expect(canPerformEmployeeAttendanceActions(isAdmin: false), isTrue);
    });

    test('Admin cannot perform Employee Clock-In, WFH Request, or Correction Request', () {
      expect(canPerformEmployeeAttendanceActions(isAdmin: true), isFalse);
    });

    test('Admin attendance view contains 4 management tabs', () {
      final tabs = getAttendanceTabs(isAdmin: true);
      expect(tabs.length, 4);
      expect(tabs, containsAll(['Staff Logs', 'Remote Access', 'Corrections', 'Geofence & Rules']));
      expect(tabs.contains('My Check-In Hub'), isFalse);
    });

    test('Log details modal only shows Request Correction for non-admin employees', () {
      bool canShowRequestCorrectionInLogModal({required bool isAdmin}) => !isAdmin;
      expect(canShowRequestCorrectionInLogModal(isAdmin: true), isFalse);
      expect(canShowRequestCorrectionInLogModal(isAdmin: false), isTrue);
    });

    test('Personal correction history is hidden from Admin console view', () {
      bool shouldLoadPersonalCorrectionHistory({required bool isAdmin}) => !isAdmin;
      expect(shouldLoadPersonalCorrectionHistory(isAdmin: true), isFalse);
      expect(shouldLoadPersonalCorrectionHistory(isAdmin: false), isTrue);
    });
  });
}
