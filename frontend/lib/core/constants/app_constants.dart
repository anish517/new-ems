class AppConstants {
  // ─── API Base URL ──────────────────────────────────────────────────────────
  // Defaults to production. For local development against a dev server, pass
  // the address at run/build time instead of editing this file:
  //   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.16.113:8000',
  );

  // ─── Endpoints ─────────────────────────────────────────────────────────────
  static const String tokenEndpoint = '/api/auth/token/';
  static const String tokenRefreshEndpoint = '/api/auth/token/refresh/';
  static const String meEndpoint = '/api/auth/me/';

  static const String attendanceBase = '/api/attendance';
  static const String checkIn = '/api/attendance/check-in/';
  static const String checkOut = '/api/attendance/check-out/';
  static const String todayAttendanceStatus =
      '/api/attendance/today-attendance-status/';
  static const String punctualityChampions =
      '/api/attendance/punctuality-champions/';

  static const String leaveBase = '/api/leave-tracker';
  static const String salaryBase = '/api/salary-management';
  static const String taskBase = '/api/task-management';
  static const String projectsBase = '/api/task-management/projects';
  static const String taskProgressBase = '/api/task-management/tasks';
  static const String progressEndpoint = '/api/task-management/progress';

  static const String calendarBase = '/api/calendar';
  static const String noticeboardBase = '/api/noticeboard';
  static const String noticesEndpoint = '/api/noticeboard/notices/';
  static const String notificationsBase = '/api/notifications';
  static const String feedbackBase = '/api/feedback';
  static const String organizationBase = '/api/organization';
  static const String fiscalYearBase = '/api/fiscal-year';

  // ─── Storage Keys ──────────────────────────────────────────────────────────
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  // ─── Roles ─────────────────────────────────────────────────────────────────
  static const String roleSuperAdmin = 'super_admin';
  static const String roleOrgAdmin = 'org_admin';
  static const String roleHr = 'hr';
  static const String roleEmployee = 'employee';

  // ─── GPS ───────────────────────────────────────────────────────────────────
  static const double attendanceRadiusMeters = 500.0;

  // ─── Pagination ────────────────────────────────────────────────────────────
  static const int pageSize = 20;

  // ─── Session & Inactivity Configuration ──────────────────────────────────
  /// Admin session inactivity timeout in minutes (default: 15 minutes)
  static const int adminInactivityTimeoutMinutes = 15;

  /// Employee inactivity timeout outside working hours or on off-days in minutes (default: 5 minutes)
  static const int employeeOffHoursInactivityTimeoutMinutes = 5;

  /// Employee inactivity timeout during active working hours in minutes (default: 60 minutes)
  static const int employeeWorkHoursInactivityTimeoutMinutes = 60;

  /// Shift start time: 10:00 AM
  static const int workHourStartHour = 10;
  static const int workHourStartMinute = 0;

  /// Shift end time: 5:30 PM (17:30)
  static const int workHourEndHour = 17;
  static const int workHourEndMinute = 30;

  /// Working days of the week (Sunday through Friday; Saturday is off-day in Nepal)
  static const List<int> workDays = [
    DateTime.sunday,
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  ];
}
