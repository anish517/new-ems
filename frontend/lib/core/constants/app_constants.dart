class AppConstants {
  // ─── API Base URL ──────────────────────────────────────────────────────────
  static const String baseUrl =
      'http://192.168.1.12:8000'; // Change to your server IP

  // ─── Endpoints ─────────────────────────────────────────────────────────────
  static const String tokenEndpoint = '/api/auth/token/';
  static const String tokenRefreshEndpoint = '/api/auth/token/refresh/';
  static const String meEndpoint = '/api/auth/me/';

  static const String attendanceBase = '/api/attendance';
  static const String checkIn = '/api/attendance/check-in/';
  static const String checkOut = '/api/attendance/check-out/';

  static const String leaveBase = '/api/leave-tracker';
  static const String salaryBase = '/api/salary-management';
  static const String taskBase = '/api/task-management';
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
  static const String roleEmployee = 'employee';

  // ─── GPS ───────────────────────────────────────────────────────────────────
  static const double attendanceRadiusMeters = 500.0;

  // ─── Pagination ────────────────────────────────────────────────────────────
  static const int pageSize = 20;
}
