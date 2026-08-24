import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/date_provider.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});
  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  int _employeeCount = 0;
  int _pendingLeaves = 0;
  int _onTimeToday = 0;
  List<Map<String, dynamic>> _todayAttendanceStatus = []; // replaces _onTimeTodayNames
  List<Map<String, dynamic>> _punctualityChampions = [];
  String _championsMonthName = '';
  List<double> _weeklyAttendance = List.filled(7, 0.0);
  List<dynamic> _monthlyAttendanceLogs = [];
  int _analyticsTab = 0; // 0: Weekly Activity, 1: Today's Punch Timeline
  List<dynamic> _pendingRemoteRequests = [];
  List<dynamic> _pendingProfileChangeRequests = [];
  List<dynamic> _pendingLeaveRequests = [];
  List<dynamic> _pendingCorrectionRequests = [];
  List<dynamic> _pendingFeedbacks = [];
  int _pendingFeedbackCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  String _fmtDate(NepaliDateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatNepaliHeaderDate(NepaliDateTime d) {
    const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = [
      '', 'Baishakh', 'Jestha', 'Ashadh', 'Shrawan', 'Bhadra',
      'Ashwin', 'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra'
    ];
    final wName = weekdays[(d.weekday - 1).clamp(0, 6)];
    final mName = months[d.month.clamp(1, 12)];
    return '$wName, ${d.day.toString().padLeft(2, '0')} $mName, ${d.year}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _fieldLabel(String fieldName) {
    const labels = {
      'phone_no': 'Phone Number',
      'personal_email': 'Personal Email',
      'emergency_phone_number': 'Emergency Contact',
    };
    return labels[fieldName] ?? fieldName.replaceAll('_', ' ').toUpperCase();
  }

  String _formatGps(dynamic val) {
    if (val == null) return 'N/A';
    final d = double.tryParse(val.toString());
    if (d != null) {
      return d.toStringAsFixed(5);
    }
    return val.toString();
  }

  String _formatRawDateToNepali(dynamic raw) {
    if (raw == null) return '';
    final str = raw.toString().trim();
    if (str.isEmpty || str == 'null') return '';
    try {
      final dt = DateTime.parse(str);
      // If year is > 2050 (e.g. 2083 BS), it is ALREADY a Nepali Bikram Sambat date
      if (dt.year > 2050) {
        final nepaliDt = NepaliDateTime(dt.year, dt.month, dt.day);
        return NepaliDateFormat('dd MMM yyyy').format(nepaliDt);
      }
      final nepaliDt = dt.toNepaliDateTime();
      return NepaliDateFormat('dd MMM yyyy').format(nepaliDt);
    } catch (_) {
      try {
        final nepaliDt = NepaliDateTime.parse(str.split('T').first);
        return NepaliDateFormat('dd MMM yyyy').format(nepaliDt);
      } catch (_) {
        return str.split('T').first;
      }
    }
  }

  Widget _buildEmptyPendingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.tick_circle, size: 12, color: color),
                const SizedBox(width: 4),
                Text(
                  'All Clear',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPanelBox({
    required IconData headerIcon,
    required Color headerColor,
    required String title,
    required int count,
    required String actionLabel,
    required VoidCallback onActionTap,
    required Widget content,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: headerColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(headerIcon, size: 18, color: headerColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: context.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: count > 0
                              ? headerColor.withValues(alpha: 0.14)
                              : (isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.12)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: count > 0 ? headerColor : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: onActionTap,
                  icon: const Icon(Iconsax.arrow_right_3, size: 13, color: AppColors.primary),
                  label: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.border),
          // Content inside Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: content,
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveRequestsSection(bool isDark) {
    String fmtNepali(String raw) {
      if (raw.isEmpty) return '-';
      try {
        return NepaliDateFormat('dd MMM yyyy').format(NepaliDateTime.parse(raw));
      } catch (_) {
        return raw;
      }
    }

    final count = _pendingLeaveRequests.length;

    Widget content;
    if (count == 0) {
      content = _buildEmptyPendingCard(
        icon: Iconsax.calendar_tick,
        title: 'No Pending Leave Requests Found',
        subtitle: 'All employee leave applications have been reviewed and processed.',
        color: AppColors.warning,
      );
    } else {
      final listWidget = ListView.separated(
        shrinkWrap: count <= 2,
        physics: count <= 2 ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => Divider(height: 1, color: context.border),
        itemBuilder: (_, i) {
          final req = _pendingLeaveRequests[i];
          final employeeName = req['employee_name']?.toString() ?? 'Staff Member';
          final subject = req['subject']?.toString() ?? '-';
          final fromDate = req['from_date']?.toString() ?? '';
          final tillDate = req['till_date']?.toString() ?? '';
          final noDays = req['no_days']?.toString() ?? '?';
          final isPaid = req['is_paid'] as bool? ?? false;
          final isHalfDay = req['half_day'] as bool? ?? false;
          final appliedAt = _formatRawDateToNepali(req['created_at']);
          final int reqId = req['id'] is int
              ? req['id'] as int
              : (int.tryParse('${req['id']}') ?? 0);

          final leaveTypeLabel = isHalfDay
              ? 'Half Day'
              : (isPaid ? 'Paid Leave' : 'Unpaid Leave');
          final leaveTypeColor = isHalfDay
              ? AppColors.info
              : (isPaid ? AppColors.success : AppColors.error);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.calendar_remove, size: 17, color: AppColors.warning),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            employeeName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: leaveTypeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              leaveTypeLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: leaveTypeColor,
                              ),
                            ),
                          ),
                          Text(
                            '• $noDays day${noDays == '1' ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (appliedAt.isNotEmpty)
                      Text(
                        appliedAt,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    children: [
                      const Icon(Iconsax.calendar_1, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        '${fmtNepali(fromDate)} → ${fmtNepali(tillDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      if (subject.isNotEmpty && subject != '-') ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '• $subject',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showRejectLeaveDialog(reqId),
                        icon: const Icon(Iconsax.close_circle, size: 13, color: AppColors.error),
                        label: const Text('Reject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _actionLeaveRequest(reqId, true),
                        icon: const Icon(Iconsax.tick_circle, size: 13, color: Colors.white),
                        label: const Text('Approve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (count > 2) {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: Scrollbar(
                thumbVisibility: true,
                child: listWidget,
              ),
            ),
            if (count > 3) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => context.go('/leave'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'View all $count leave requests in Leaves →',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else {
        content = listWidget;
      }
    }

    return _buildPendingPanelBox(
      headerIcon: Iconsax.calendar_remove,
      headerColor: AppColors.warning,
      title: 'Pending Leave Requests',
      count: count,
      actionLabel: 'View All',
      onActionTap: () => context.go('/leave'),
      content: content,
      isDark: isDark,
    );
  }

  Widget _buildRemoteRequestsSection(bool isDark) {
    final count = _pendingRemoteRequests.length;

    Widget content;
    if (count == 0) {
      content = _buildEmptyPendingCard(
        icon: Iconsax.home_wifi,
        title: 'No Pending Remote Work Requests Found',
        subtitle: 'No work-from-home or remote check-in applications are pending approval.',
        color: AppColors.accent,
      );
    } else {
      final listWidget = ListView.separated(
        shrinkWrap: count <= 2,
        physics: count <= 2 ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => Divider(height: 1, color: context.border),
        itemBuilder: (_, i) {
          final req = _pendingRemoteRequests[i];
          final appliedAt = _formatRawDateToNepali(req['created_at']);
          final lat = req['latitude'];
          final lng = req['longitude'];

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.home_wifi, size: 17, color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['employee_name'] ?? 'Unknown Employee',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            req['reason'] != null && req['reason'].toString().isNotEmpty
                                ? 'Reason: ${req['reason']}'
                                : 'No reason specified',
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (appliedAt.isNotEmpty)
                      Text(
                        appliedAt,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (lat != null || lng != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Row(
                      children: [
                        const Icon(Iconsax.location, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'GPS: ${_formatGps(lat)}, ${_formatGps(lng)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (lat != null && lng != null) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () async {
                              final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                              if (await canLaunchUrlString(url)) {
                                await launchUrlString(url);
                              }
                            },
                            child: const Text(
                              '(View Map)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                // Action Buttons on dedicated row
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _actionRemoteRequest(req['id'], 'rejected'),
                        icon: const Icon(Iconsax.close_circle, size: 13, color: AppColors.error),
                        label: const Text('Reject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _actionRemoteRequest(req['id'], 'approved'),
                        icon: const Icon(Iconsax.tick_circle, size: 13, color: Colors.white),
                        label: const Text('Approve WFH', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (count > 2) {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: Scrollbar(
                thumbVisibility: true,
                child: listWidget,
              ),
            ),
            if (count > 3) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => context.go('/attendance'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'View all $count requests in Attendance →',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else {
        content = listWidget;
      }
    }

    return _buildPendingPanelBox(
      headerIcon: Iconsax.home_wifi,
      headerColor: AppColors.accent,
      title: 'Pending Remote Work',
      count: count,
      actionLabel: 'Attendance',
      onActionTap: () => context.go('/attendance'),
      content: content,
      isDark: isDark,
    );
  }

  Widget _buildProfileRequestsSection(bool isDark) {
    final count = _pendingProfileChangeRequests.length;

    Widget content;
    if (count == 0) {
      content = _buildEmptyPendingCard(
        icon: Iconsax.user_tick,
        title: 'No Pending Profile Update Requests Found',
        subtitle: 'All employee profile detail updates have been reviewed and verified.',
        color: const Color(0xFFF59E0B),
      );
    } else {
      final listWidget = ListView.separated(
        shrinkWrap: count <= 2,
        physics: count <= 2 ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => Divider(height: 1, color: context.border),
        itemBuilder: (_, i) {
          final req = _pendingProfileChangeRequests[i];
          final field = req['field_name'] ?? '';
          final val = req['new_value']?.toString() ?? '-';
          final oldVal = req['old_value']?.toString() ?? '';
          final employeeName = req['employee_name']?.toString() ?? 'Staff Member';
          final employeeCode = req['employee_code']?.toString() ?? '';
          final int reqId = (req['id'] is int)
              ? (req['id'] as int)
              : (int.tryParse('${req['id']}') ?? 0);
          final createdAt = _formatRawDateToNepali(req['created_at']);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.user_edit, size: 17, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            employeeName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (employeeCode.isNotEmpty)
                            Text(
                              '#$employeeCode',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _fieldLabel(field),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (createdAt.isNotEmpty)
                      Text(
                        createdAt,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (oldVal.isNotEmpty)
                        Text(
                          'Current: $oldVal',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textPrimary.withValues(alpha: 0.6),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Requested New: ',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            val,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _actionProfileChangeRequest(reqId, 'rejected'),
                        icon: const Icon(Iconsax.close_circle, size: 13, color: Color(0xFFEF4444)),
                        label: const Text('Reject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _actionProfileChangeRequest(reqId, 'approved'),
                        icon: const Icon(Iconsax.tick_circle, size: 13, color: Colors.white),
                        label: const Text('Approve Update', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (count > 2) {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: Scrollbar(
                thumbVisibility: true,
                child: listWidget,
              ),
            ),
            if (count > 3) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => context.go('/employees'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'View all $count update requests in Employees →',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else {
        content = listWidget;
      }
    }

    return _buildPendingPanelBox(
      headerIcon: Iconsax.user_edit,
      headerColor: const Color(0xFFF59E0B),
      title: 'Pending Profile Updates',
      count: count,
      actionLabel: 'Employees',
      onActionTap: () => context.go('/employees'),
      content: content,
      isDark: isDark,
    );
  }

  Widget _buildCorrectionRequestsSection(bool isDark) {
    String fmtNepali(String raw) {
      if (raw.isEmpty) return '-';
      try {
        return NepaliDateFormat('dd MMM yyyy').format(NepaliDateTime.parse(raw));
      } catch (_) {
        return raw;
      }
    }

    final count = _pendingCorrectionRequests.length;

    Widget content;
    if (count == 0) {
      content = _buildEmptyPendingCard(
        icon: Iconsax.timer_1,
        title: 'No Pending Attendance Corrections Found',
        subtitle: 'All employee missed punch and time adjustment requests have been reviewed.',
        color: const Color(0xFFF59E0B),
      );
    } else {
      final listWidget = ListView.separated(
        shrinkWrap: count <= 2,
        physics: count <= 2 ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => Divider(height: 1, color: context.border),
        itemBuilder: (_, i) {
          final req = _pendingCorrectionRequests[i];
          final rawName = req['employee_name']?.toString() ??
              req['employee']?['full_name']?.toString() ??
              req['employee']?['name']?.toString() ??
              '';
          final employeeName = (rawName.isNotEmpty && rawName != 'null') ? rawName : 'Staff Member';
          final employeeEmail = req['employee_email']?.toString();
          final targetDate = req['requested_date']?.toString() ?? '-';
          final checkIn = req['requested_check_in']?.toString() ?? '--:--';
          final checkOut = req['requested_check_out']?.toString() ?? '--:--';
          final reason = req['reason']?.toString() ?? 'No reason provided';
          final appliedAt = _formatRawDateToNepali(req['created_at']);
          final int reqId = req['id'] is int
              ? req['id'] as int
              : (int.tryParse('${req['id']}') ?? 0);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.timer_1, size: 17, color: Color(0xFFF59E0B)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            employeeName,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (employeeEmail != null && employeeEmail.isNotEmpty && employeeEmail != 'null')
                            Text(
                              '($employeeEmail)',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Target Date: ${fmtNepali(targetDate)}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (appliedAt.isNotEmpty)
                      Text(
                        appliedAt,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Shift times and Reason (clean typography, no box!)
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.clock, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          const Text('Requested: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          Text(
                            'In: $checkIn',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(width: 6),
                          Text(
                            'Out: $checkOut',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.info,
                            ),
                          ),
                        ],
                      ),
                      if (reason.isNotEmpty && reason != 'No reason provided')
                        Text(
                          '• "$reason"',
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _showRejectCorrectionDialog(reqId),
                        icon: const Icon(Iconsax.close_circle, size: 13, color: AppColors.error),
                        label: const Text('Reject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _actionCorrectionRequest(reqId, 'approved', ''),
                        icon: const Icon(Iconsax.tick_circle, size: 13, color: Colors.white),
                        label: const Text('Approve & Update', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (count > 2) {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: Scrollbar(
                thumbVisibility: true,
                child: listWidget,
              ),
            ),
            if (count > 3) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => context.go('/attendance'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'View all $count requests in Attendance →',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else {
        content = listWidget;
      }
    }

    return _buildPendingPanelBox(
      headerIcon: Iconsax.timer_1,
      headerColor: const Color(0xFFF59E0B),
      title: 'Attendance Corrections',
      count: count,
      actionLabel: 'View All',
      onActionTap: () => context.go('/attendance'),
      content: content,
      isDark: isDark,
    );
  }

  Widget _buildFeedbackSection(bool isDark) {
    final count = _pendingFeedbacks.length;

    Widget content;
    if (count == 0) {
      content = _buildEmptyPendingCard(
        icon: Iconsax.message_tick,
        title: 'No Pending Feedback or Grievances Found',
        subtitle: 'All employee feedback and grievance submissions have been resolved.',
        color: const Color(0xFFFB923C),
      );
    } else {
      final listWidget = ListView.separated(
        shrinkWrap: count <= 2,
        physics: count <= 2 ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => Divider(height: 1, color: context.border),
        itemBuilder: (_, i) {
          final c = _pendingFeedbacks[i];
          final id = c['id'] as int? ?? 0;
          final title = c['title']?.toString() ?? 'Untitled';
          final desc = c['description']?.toString() ?? '';
          final ownerName = c['owner_name']?.toString() ?? 'Anonymous';
          final catName = c['category_name']?.toString() ?? 'General';
          final isAnonymous = (c['visibility'] ?? 'anonymous') == 'anonymous';
          final dateStr = _formatRawDateToNepali(c['created_at']);
          final repliesCount = (c['replies'] as List?)?.length ?? 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFB923C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.message_text, size: 17, color: Color(0xFFFB923C)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              catName,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isAnonymous
                                  ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                                  : AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAnonymous ? 'Anonymous' : ownerName,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isAnonymous ? const Color(0xFF8B5CF6) : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 48),
                    child: Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textPrimary.withValues(alpha: 0.8),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (repliesCount > 0)
                        Text(
                          '$repliesCount repl${repliesCount == 1 ? 'y' : 'ies'}',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        )
                      else
                        const SizedBox.shrink(),
                      ElevatedButton.icon(
                        onPressed: () => _resolveFeedback(id),
                        icon: const Icon(Iconsax.tick_circle, size: 13, color: Colors.white),
                        label: const Text('Resolve', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          minimumSize: Size.zero,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

      if (count > 2) {
        content = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 440),
              child: Scrollbar(
                thumbVisibility: true,
                child: listWidget,
              ),
            ),
            if (count > 3) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => context.go('/feedback'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    'View all $count grievances in Feedback →',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else {
        content = listWidget;
      }
    }

    return _buildPendingPanelBox(
      headerIcon: Iconsax.messages_3,
      headerColor: AppColors.error,
      title: 'Pending Feedback & Grievances',
      count: count,
      actionLabel: 'View All',
      onActionTap: () => context.go('/feedback'),
      content: content,
      isDark: isDark,
    );
  }

  Future<void> _actionProfileChangeRequest(int id, String status) async {
    try {
      await ApiService().post(
        '${AppConstants.organizationBase}/profile-change-requests/$id/action/',
        data: {'status': status},
      );
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  status == 'approved' ? Iconsax.tick_circle : Iconsax.close_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text('Profile change request $status successfully'),
              ],
            ),
            backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.warning_2, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating profile request: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _actionRemoteRequest(int id, String status) async {
    try {
      await ApiService().post(
        '${AppConstants.attendanceBase}/remote-requests/$id/action/',
        data: {'status': status},
      );
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  status == 'approved' ? Iconsax.tick_circle : Iconsax.close_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text('Request $status successfully'),
              ],
            ),
            backgroundColor: status == 'approved' ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.warning_2, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating request: $e')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _actionLeaveRequest(int id, bool approve, [String reason = 'Rejected by administrator']) async {
    try {
      await ApiService().patch(
        '${AppConstants.leaveBase}/update/$id/',
        data: {
          'action': approve ? 'final_approve' : 'reject',
          'is_approved': approve,
          'is_reviewed': true,
          'rejection_reason': reason,
        },
      );
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  approve ? Iconsax.tick_circle : Iconsax.close_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(approve ? 'Leave request approved' : 'Leave request rejected'),
              ],
            ),
            backgroundColor: approve ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.warning_2, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text('Error updating leave request: ${ApiService.getErrorMessage(e)}')),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _showRejectLeaveDialog(int id) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Iconsax.close_circle, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Reject Leave Request',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ctx.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejecting this leave request:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. Inadequate leave balance / Team shortage',
                filled: true,
                fillColor: ctx.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: ctx.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = controller.text.trim();
              Navigator.pop(ctx, reason.isNotEmpty ? reason : 'Rejected by administrator');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reject Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null) {
      await _actionLeaveRequest(id, false, result);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final empRes =
          await ApiService().get('${AppConstants.organizationBase}/employees/');
      final employees =
          empRes.data is List ? empRes.data : (empRes.data['results'] ?? []);
      if (!mounted) return;
      setState(() => _employeeCount = (employees as List).length);

      final leaveRes =
          await ApiService().get('${AppConstants.leaveBase}/leave-requests/');
      final leaves = leaveRes.data is List
          ? leaveRes.data
          : (leaveRes.data['results'] ?? []);
      if (!mounted) return;
      setState(() {
        final pending = (leaves as List)
            .where((l) => l['is_approved'] != true && l['is_reviewed'] != true)
            .toList();
        _pendingLeaves = pending.length;
        _pendingLeaveRequests = pending;
      });

      // Load remote requests
      try {
        final remoteRes = await ApiService().get('${AppConstants.attendanceBase}/remote-requests/');
        final remoteData = remoteRes.data is List ? remoteRes.data : (remoteRes.data['results'] ?? []);
        if (mounted) {
          setState(() {
            _pendingRemoteRequests = (remoteData as List).toList();
          });
        }
      } catch (_) {}

      // Load pending profile change requests
      try {
        final profileRes = await ApiService().get('${AppConstants.organizationBase}/profile-change-requests/?status=pending');
        final profileData = profileRes.data is List ? profileRes.data : (profileRes.data['results'] ?? []);
        if (mounted) {
          setState(() {
            _pendingProfileChangeRequests = (profileData as List).toList();
          });
        }
      } catch (_) {}

      // Load pending attendance correction requests
      try {
        final corrRes = await ApiService().get(
            '${AppConstants.attendanceBase}/correction-requests/?status=pending');
        final corrData = corrRes.data is List
            ? corrRes.data
            : (corrRes.data['results'] ?? []);
        if (mounted) {
          final list = corrData is List ? corrData : [];
          setState(() {
            _pendingCorrectionRequests = list.toList();
          });
        }
      } catch (_) {}

      // Load attendance data for weekly chart
      try {
        final attRes =
            await ApiService().get('${AppConstants.attendanceBase}/list/');
        final attData =
            attRes.data is List ? attRes.data : (attRes.data['results'] ?? []);
        if (attData is List && attData.isNotEmpty) {
          final now = NepaliDateTime.now();

          final daysSinceMonday = now.weekday == 1 ? 6 : now.weekday - 2;
          final weekStart = now.subtract(Duration(days: daysSinceMonday));
          final weekEnd = weekStart.add(const Duration(days: 6));
          final weekStartStr = _fmtDate(weekStart);
          final weekEndStr = _fmtDate(weekEnd);

          final weekCounts = List<int>.filled(7, 0); // Mon=0..Sun=6

          for (final log in attData) {
            final dateStr = log['date']?.toString() ?? '';
            if (dateStr.isEmpty) continue;

            if (dateStr.compareTo(weekStartStr) >= 0 &&
                dateStr.compareTo(weekEndStr) <= 0) {
              try {
                final d = NepaliDateTime.parse(dateStr);
                final index = (d.weekday == 1) ? 6 : d.weekday - 2;
                weekCounts[index]++;
              } catch (_) {}
            }
          }

          final maxCount = weekCounts.reduce((a, b) => a > b ? a : b);
          final normalized = weekCounts
              .map((c) => maxCount > 0 ? (c / maxCount) * 90.0 : 0.0)
              .toList();

          if (mounted) {
            setState(() {
              _monthlyAttendanceLogs = attData;
              _weeklyAttendance = normalized;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _monthlyAttendanceLogs = [];
            });
          }
        }
      } catch (_) {}

      // Load monthly Punctuality Champions
      try {
        final champRes = await ApiService().get(AppConstants.punctualityChampions);
        if (champRes.data is Map) {
          final data = champRes.data as Map<String, dynamic>;
          final list = data['champions'] as List? ?? [];
          if (mounted) {
            setState(() {
              _championsMonthName = data['month_name']?.toString() ?? '';
              _punctualityChampions = list.cast<Map<String, dynamic>>();
            });
          }
        }
      } catch (_) {}

      // Load pending feedback & complaints
      try {
        final fbRes = await ApiService().get('${AppConstants.feedbackBase}/');
        final fbData = fbRes.data is List ? fbRes.data as List : (fbRes.data['results'] as List? ?? []);
        if (mounted) {
          final pendingOnly = fbData.where((c) {
            final s = (c['status'] ?? 'pending').toString().toLowerCase();
            return s != 'resolved' && s != 'reviewed';
          }).toList();
          setState(() {
            _pendingFeedbacks = pendingOnly;
            _pendingFeedbackCount = pendingOnly.length;
          });
        }
      } catch (_) {}

      // Load today's attendance status (present / absent per employee)
      try {
        final todayRes = await ApiService().get(AppConstants.todayAttendanceStatus);
        final todayData = todayRes.data is List ? todayRes.data as List : [];
        if (mounted) {
          setState(() {
            _todayAttendanceStatus = todayData.cast<Map<String, dynamic>>();
            _onTimeToday = _todayAttendanceStatus.where((e) => e['is_present'] == true).length;
          });
        }
      } catch (_) {}
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resolveFeedback(int id) async {
    try {
      await ApiService().patch('${AppConstants.feedbackBase}/$id/', data: {'status': 'resolved'});
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Feedback marked as resolved'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _actionCorrectionRequest(
      int id, String action, String adminNote) async {
    try {
      await ApiService().patch(
        '${AppConstants.attendanceBase}/correction-requests/$id/action/',
        data: {'status': action, 'admin_note': adminNote},
      );
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text('Correction request ${action == 'approved' ? 'approved & updated' : 'rejected'}'),
            ]),
            backgroundColor: action == 'approved' ? AppColors.success : AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    }
  }

  Future<void> _showRejectCorrectionDialog(int id) async {
    final noteCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Iconsax.close_circle, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Reject Correction',
                style: TextStyle(color: ctx.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter optional remark for this rejection:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Reason for rejection (e.g. invalid time logs)...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Request',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      await _actionCorrectionRequest(id, 'rejected', noteCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadStats());
    final user = ref.watch(currentUserProvider);
    final isDark = context.isDark;
    final nowNepali = NepaliDateTime.now();

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 600;
            final isDesktop = constraints.maxWidth >= 900;
            return RefreshIndicator(
              onRefresh: _loadStats,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: isTight ? 14 : 24,
                  vertical: isTight ? 16 : 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -- Top Header Section ------------------------------------------
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${_getGreeting()}, ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Admin Portal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.fullName ?? 'Executive Admin',
                                style: TextStyle(
                                  fontSize: isTight ? 21 : 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.6,
                                  color: context.textPrimary,
                                ),
                              ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Iconsax.calendar_1,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                _formatNepaliHeaderDate(nowNepali),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        if (!isTight) ...[
                          const ThemeToggleBtn(),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Iconsax.notification, size: 20),
                            tooltip: 'Notifications',
                            onPressed: () => context.go('/notifications'),
                            style: IconButton.styleFrom(
                              backgroundColor: context.surface,
                              padding: const EdgeInsets.all(10),
                              side: BorderSide(color: context.border, width: 1),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        GestureDetector(
                          onTap: () => context.go('/profile'),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.accent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.25),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: context.surface,
                              backgroundImage: user?.profilePicture != null
                                  ? NetworkImage(user!.profilePicture!)
                                  : null,
                              child: user?.profilePicture == null
                                  ? Text(
                                      user?.firstName.isNotEmpty == true
                                          ? user!.firstName[0].toUpperCase()
                                          : 'A',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // -- KPI Summary Cards ------------------------------------------─
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 680;

                      if (isMobile) {
                        return Column(
                          children: [
                            _KpiCard(
                              title: 'Total Employees',
                              value: '$_employeeCount',
                              subtitle: 'Active staff members',
                              icon: Iconsax.people,
                              color: AppColors.primary,
                              onTap: () => context.go('/employees'),
                            ),
                            const SizedBox(height: 14),
                            _KpiCard(
                              title: 'Pending Leaves',
                              value: '$_pendingLeaves',
                              subtitle: 'Requires review',
                              icon: Iconsax.calendar_remove,
                              color: AppColors.warning,
                              onTap: () => context.go('/leave'),
                            ),
                            const SizedBox(height: 14),
                            _KpiCard(
                              title: 'Present Today',
                              value: '$_onTimeToday',
                              subtitle: 'Employees checked in',
                              icon: Iconsax.people,
                              color: AppColors.success,
                              onTap: null,
                            ),
                            const SizedBox(height: 14),
                            _KpiCard(
                              title: 'Pending Feedback',
                              value: '$_pendingFeedbackCount',
                              subtitle: 'Unresolved grievances',
                              icon: Iconsax.messages_3,
                              color: AppColors.error,
                              onTap: () => context.go('/feedback'),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _KpiCard(
                              title: 'Total Employees',
                              value: '$_employeeCount',
                              subtitle: 'Active staff members',
                              icon: Iconsax.people,
                              color: AppColors.primary,
                              onTap: () => context.go('/employees'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'Pending Leaves',
                              value: '$_pendingLeaves',
                              subtitle: 'Requires review',
                              icon: Iconsax.calendar_remove,
                              color: AppColors.warning,
                              onTap: () => context.go('/leave'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'Present Today',
                              value: '$_onTimeToday',
                              subtitle: 'Employees checked in',
                              icon: Iconsax.people,
                              color: AppColors.success,
                              onTap: null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _KpiCard(
                              title: 'Pending Feedback',
                              value: '$_pendingFeedbackCount',
                              subtitle: 'Unresolved grievances',
                              icon: Iconsax.messages_3,
                              color: AppColors.error,
                              onTap: () => context.go('/feedback'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 28),

                // -- Attendance Chart & Quick Actions Row ------------------------─
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 900;
                    final timeBuckets = _getTodayTimeBuckets();
                    final presentCount = _todayAttendanceStatus
                        .where((e) => e['is_present'] == true)
                        .length;

                    return Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Attendance & Punch Time Analytics Card
                        Expanded(
                          flex: isMobile ? 0 : 9,
                          child: Container(
                            height: isMobile ? null : 390,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: context.border, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.25 : 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with Title and Segmented View Switch
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: const Icon(Iconsax.chart_21,
                                                    size: 16,
                                                    color: AppColors.primary),
                                              ),
                                              const SizedBox(width: 8),
                                              Flexible(
                                                child: Text(
                                                  'Attendance & Punch Analytics',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: -0.3,
                                                    color: context.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          const Text(
                                            'Live check-in patterns, punctuality & time distribution',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // View Mode Toggle
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: context.card,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: context.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () => setState(() => _analyticsTab = 0),
                                            borderRadius: BorderRadius.circular(9),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: _analyticsTab == 0
                                                    ? AppColors.primary
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(9),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Iconsax.chart_2,
                                                    size: 13,
                                                    color: _analyticsTab == 0
                                                        ? Colors.white
                                                        : AppColors.textSecondary,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'Weekly Activity',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: _analyticsTab == 0
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      color: _analyticsTab == 0
                                                          ? Colors.white
                                                          : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () => setState(() => _analyticsTab = 1),
                                            borderRadius: BorderRadius.circular(9),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                              decoration: BoxDecoration(
                                                color: _analyticsTab == 1
                                                    ? AppColors.primary
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(9),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Iconsax.clock,
                                                    size: 13,
                                                    color: _analyticsTab == 1
                                                        ? Colors.white
                                                        : AppColors.textSecondary,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    "Today's Punch Time",
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: _analyticsTab == 1
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                      color: _analyticsTab == 1
                                                          ? Colors.white
                                                          : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                // KPI Summary Strip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: context.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: context.border),
                                  ),
                                  child: Wrap(
                                    spacing: 16,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Iconsax.timer_1, size: 13, color: AppColors.primary),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'Avg Check-in: ',
                                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            _getTodayAvgCheckIn(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Iconsax.tick_circle, size: 13, color: AppColors.success),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'On-Time Rate: ',
                                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            _getTodayOnTimeRate(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.success,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Iconsax.user_tick, size: 13, color: AppColors.accent),
                                          const SizedBox(width: 5),
                                          const Text(
                                            'Present: ',
                                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                          ),
                                          Text(
                                            '$presentCount / $_employeeCount Staff',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Iconsax.info_circle, size: 11, color: AppColors.primary),
                                            SizedBox(width: 3),
                                            Text(
                                              'Tap any column/bar to view staff names',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                // Body of Tab
                                Expanded(
                                  child: _analyticsTab == 0
                                      // Tab 0: Weekly Activity BarChart
                                      ? BarChart(
                                          BarChartData(
                                            alignment: BarChartAlignment.spaceAround,
                                            maxY: 120,
                                            barTouchData: BarTouchData(
                                              enabled: true,
                                              touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
                                                if (!event.isInterestedForInteractions ||
                                                    response == null ||
                                                    response.spot == null) {
                                                  return;
                                                }
                                                if (event is FlTapUpEvent) {
                                                  final groupIndex = response.spot!.touchedBarGroupIndex;
                                                  const days = [
                                                    'Monday',
                                                    'Tuesday',
                                                    'Wednesday',
                                                    'Thursday',
                                                    'Friday',
                                                    'Saturday',
                                                    'Sunday'
                                                  ];
                                                  final dayName = days[groupIndex.clamp(0, 6)];
                                                  final emps = _getWeeklyDayEmployees(groupIndex);
                                                  _showEmployeePunchInspector(
                                                    title: '$dayName Check-ins',
                                                    subtitle: 'Employees logged on $dayName (Current Week)',
                                                    employees: emps,
                                                    themeColor: AppColors.primary,
                                                  );
                                                }
                                              },
                                              touchTooltipData: BarTouchTooltipData(
                                                getTooltipColor: (_) => isDark
                                                    ? const Color(0xFF1E293B)
                                                    : Colors.white,
                                                tooltipPadding: const EdgeInsets.symmetric(
                                                    horizontal: 12, vertical: 8),
                                                tooltipMargin: 8,
                                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                  const days = [
                                                    'Monday',
                                                    'Tuesday',
                                                    'Wednesday',
                                                    'Thursday',
                                                    'Friday',
                                                    'Saturday',
                                                    'Sunday'
                                                  ];
                                                  final dayName = days[group.x.toInt().clamp(0, 6)];
                                                  final emps = _getWeeklyDayEmployees(group.x.toInt());
                                                  return BarTooltipItem(
                                                    '$dayName\n',
                                                    TextStyle(
                                                      color: context.textPrimary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: '${emps.length} Checked In (${rod.toY.toStringAsFixed(0)}%)\n',
                                                        style: const TextStyle(
                                                          color: AppColors.primary,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w700,
                                                        ),
                                                      ),
                                                      const TextSpan(
                                                        text: 'Tap to view employee list',
                                                        style: TextStyle(
                                                          color: AppColors.textSecondary,
                                                          fontSize: 9.5,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                            titlesData: FlTitlesData(
                                              show: true,
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget: (v, meta) {
                                                    const days = [
                                                      'Mon',
                                                      'Tue',
                                                      'Wed',
                                                      'Thu',
                                                      'Fri',
                                                      'Sat',
                                                      'Sun'
                                                    ];
                                                    final i = v.toInt();
                                                    final isToday = (NepaliDateTime.now().weekday == 1
                                                            ? 6
                                                            : NepaliDateTime.now().weekday - 2) ==
                                                        i;
                                                    return SideTitleWidget(
                                                      axisSide: meta.axisSide,
                                                      child: Text(
                                                        i >= 0 && i < 7 ? days[i] : '',
                                                        style: TextStyle(
                                                          color: isToday
                                                              ? AppColors.primary
                                                              : AppColors.textSecondary,
                                                          fontWeight: isToday
                                                              ? FontWeight.w900
                                                              : FontWeight.w600,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                              leftTitles: const AxisTitles(
                                                  sideTitles: SideTitles(showTitles: false)),
                                              topTitles: const AxisTitles(
                                                  sideTitles: SideTitles(showTitles: false)),
                                              rightTitles: const AxisTitles(
                                                  sideTitles: SideTitles(showTitles: false)),
                                            ),
                                            gridData: const FlGridData(show: false),
                                            borderData: FlBorderData(show: false),
                                            barGroups: List.generate(7, (i) {
                                              final val = i < _weeklyAttendance.length
                                                  ? _weeklyAttendance[i]
                                                  : 0.0;
                                              final isWeekend = i >= 5;
                                              return _bar(i, val, isWeekend: isWeekend);
                                            }),
                                          ),
                                        )
                                      // Tab 1: Today's Punch Time Windows Breakdown
                                      : Builder(
                                          builder: (ctx) {
                                            final totalCount = _todayAttendanceStatus.isEmpty
                                                ? 1
                                                : _todayAttendanceStatus.length;
                                            if (isMobile) {
                                              return Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[0], totalCount, ctx)),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[1], totalCount, ctx)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[2], totalCount, ctx)),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[3], totalCount, ctx)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[4], totalCount, ctx)),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[5], totalCount, ctx)),
                                                    ],
                                                  ),
                                                ],
                                              );
                                            }
                                            return Column(
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[0], totalCount, ctx)),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[1], totalCount, ctx)),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[2], totalCount, ctx)),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[3], totalCount, ctx)),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[4], totalCount, ctx)),
                                                      const SizedBox(width: 10),
                                                      Expanded(child: _buildTimeSlotCard(timeBuckets[5], totalCount, ctx)),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (isMobile)
                          const SizedBox(height: 20)
                        else
                          const SizedBox(width: 18),

                        // Quick Actions & Reports (Decreased width: flex 3 vs flex 9)
                        Expanded(
                          flex: isMobile ? 0 : 3,
                          child: Container(
                            height: isMobile ? null : 390,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: context.border, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.25 : 0.04),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Iconsax.flash_1,
                                        size: 18, color: AppColors.accent),
                                    const SizedBox(width: 7),
                                    Text(
                                      'Quick Exports',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.3,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                const Text(
                                  'Download monthly CSV reports',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _QuickActionBtn(
                                  icon: Iconsax.document_download,
                                  title: 'Attendance Report',
                                  subtitle: 'Monthly check-ins & hours CSV',
                                  color: AppColors.info,
                                  onTap: () => _showReportDialog('attendance'),
                                ),
                                const SizedBox(height: 10),
                                _QuickActionBtn(
                                  icon: Iconsax.wallet_money,
                                  title: 'Payroll Report',
                                  subtitle: 'Monthly payslip & tax breakdown',
                                  color: AppColors.success,
                                  onTap: () => _showReportDialog('salary'),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Iconsax.info_circle,
                                          size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Reports include Bikram Sambat & SSF deductions.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),

                // -- Attendance Status + Punctuality Champions ---------------------
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 700;

                    // -- Attendance Status card ----------------------------------
                    final attendanceCard = Builder(builder: (ctx) {
                      if (_todayAttendanceStatus.isEmpty) return const SizedBox.shrink();
                      final presentList = _todayAttendanceStatus
                          .where((e) => e['is_present'] == true)
                          .toList();
                      final absentList = _todayAttendanceStatus
                          .where((e) => e['is_present'] != true)
                          .toList();
                      presentList.sort((a, b) => (a['check_in_time'] ?? '')
                          .toString()
                          .compareTo((b['check_in_time'] ?? '').toString()));
                      absentList.sort((a, b) => (a['employee_name'] ?? '')
                          .toString()
                          .compareTo((b['employee_name'] ?? '').toString()));
                      final allSorted = [...presentList, ...absentList];

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: ctx.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: ctx.border, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: isDark ? 0.25 : 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Iconsax.people,
                                          color: AppColors.primary, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Attendance Status',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: ctx.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          _fmtDate(NepaliDateTime.now()),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.success
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${presentList.length} Present',
                                        style: const TextStyle(
                                          color: AppColors.success,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.error
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${absentList.length} Absent',
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Employee list (capped height to keep cards balanced)
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 320),
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: allSorted.length,
                                  separatorBuilder: (_, __) =>
                                      Divider(height: 1, color: ctx.border),
                                  itemBuilder: (_, i) {
                                final emp = allSorted[i];
                                final isPresent = emp['is_present'] == true;
                                final name =
                                    emp['employee_name']?.toString() ?? 'Unknown';
                                final rawTime = emp['check_in_time']?.toString();
                                String checkInDisplay = 'Not checked in';
                                if (rawTime != null && rawTime.isNotEmpty) {
                                  try {
                                    final parts = rawTime.split(':');
                                    final h = int.parse(parts[0]);
                                    final m = int.parse(parts[1]);
                                    final period = h >= 12 ? 'PM' : 'AM';
                                    final h12 = h % 12 == 0 ? 12 : h % 12;
                                    checkInDisplay =
                                        '$h12:${m.toString().padLeft(2, '0')} $period';
                                  } catch (_) {
                                    checkInDisplay = rawTime;
                                  }
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isPresent
                                              ? AppColors.success
                                                  .withValues(alpha: 0.12)
                                              : AppColors.error
                                                  .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isPresent
                                              ? Iconsax.tick_circle
                                              : Iconsax.close_circle,
                                          size: 16,
                                          color: isPresent
                                              ? AppColors.success
                                              : AppColors.error,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: ctx.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPresent
                                              ? AppColors.success
                                                  .withValues(alpha: 0.10)
                                              : AppColors.error
                                                  .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPresent
                                                  ? Iconsax.timer_1
                                                  : Iconsax.slash,
                                              size: 12,
                                              color: isPresent
                                                  ? AppColors.success
                                                  : AppColors.error,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isPresent
                                                  ? checkInDisplay
                                                  : 'Absent',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isPresent
                                                    ? AppColors.success
                                                    : AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    });

                    // -- Punctuality Champions card ------------------------------
                    final punctualityCard = Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.border, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.warning
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Iconsax.medal_star,
                                    color: AppColors.warning, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _championsMonthName.isNotEmpty
                                          ? 'Punctuality Champion - $_championsMonthName'
                                          : 'Punctuality Champions',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: context.textPrimary,
                                      ),
                                    ),
                                    const Text(
                                      'Perfect attendance - on-time check-ins - zero corrections',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_punctualityChampions.isEmpty)
                            Row(
                              children: [
                                const Icon(Iconsax.emoji_sad,
                                    size: 16,
                                    color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Text(
                                  'No champions yet this month',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _punctualityChampions.map((c) {
                                final name =
                                    c['employee_name']?.toString() ?? 'Unknown';
                                final days = c['attended_days'] as int? ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.warning
                                            .withValues(alpha: 0.14),
                                        AppColors.warning
                                            .withValues(alpha: 0.06),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('\u{1F3C6}',
                                          style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '$days days - 100% on-time',
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    );

                    // -- Responsive layout -----------------------------------------
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: attendanceCard),
                          const SizedBox(width: 20),
                          Expanded(child: punctualityCard),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          attendanceCard,
                          const SizedBox(height: 20),
                          punctualityCard,
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 28),


                // -- Pending Approvals & Requests Grid -------------------------
                if (isDesktop) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildLeaveRequestsSection(isDark)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildRemoteRequestsSection(isDark)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCorrectionRequestsSection(isDark)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildProfileRequestsSection(isDark)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFeedbackSection(isDark),
                ] else ...[
                  _buildLeaveRequestsSection(isDark),
                  const SizedBox(height: 24),
                  _buildRemoteRequestsSection(isDark),
                  const SizedBox(height: 24),
                  _buildCorrectionRequestsSection(isDark),
                  const SizedBox(height: 24),
                  _buildProfileRequestsSection(isDark),
                  const SizedBox(height: 24),
                  _buildFeedbackSection(isDark),
                ],
                const SizedBox(height: 32),

                // -- Enterprise Management Modules ------------------------------─
                Row(
                  children: [
                    const Icon(Iconsax.grid_5,
                        size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Management Modules',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 3;
                    if (constraints.maxWidth < 600) {
                      crossAxisCount = 1;
                    } else if (constraints.maxWidth < 980) {
                      crossAxisCount = 2;
                    }

                    final childAspectRatio = constraints.maxWidth < 600 ? 3.2 : 2.5;

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: childAspectRatio,
                      children: [
                        _ModuleTile(
                          icon: Iconsax.people,
                          title: 'Employees',
                          subtitle: 'Profiles, documents & contracts',
                          color: const Color(0xFF3B82F6),
                          onTap: () => context.go('/employees'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.clock,
                          title: 'Attendance',
                          subtitle: 'GPS geofencing & time logs',
                          color: const Color(0xFF10B981),
                          onTap: () => context.go('/attendance'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.calendar_remove,
                          title: 'Leaves',
                          subtitle: 'Quota balance & requests',
                          color: const Color(0xFFF59E0B),
                          onTap: () => context.go('/leave'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.money_recive,
                          title: 'Salary & Payroll',
                          subtitle: 'B.S. payroll & payslips',
                          color: const Color(0xFF14B8A6),
                          onTap: () => context.go('/salary'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.task_square,
                          title: 'Tasks & Projects',
                          subtitle: 'Assignments & progress',
                          color: const Color(0xFF8B5CF6),
                          onTap: () => context.go('/tasks'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.star1,
                          title: 'Performance',
                          subtitle: 'KPIs & appraisal reports',
                          color: const Color(0xFFF43F5E),
                          onTap: () => context.go('/performance'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.message_text,
                          title: 'Notices',
                          subtitle: 'Broadcasts & announcements',
                          color: const Color(0xFF6366F1),
                          onTap: () => context.go('/noticeboard'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.calendar,
                          title: 'Nepali Calendar',
                          subtitle: 'Holidays, events & B.S. dates',
                          color: const Color(0xFF0EA5E9),
                          onTap: () => context.go('/calendar'),
                        ),
                        _ModuleTile(
                          icon: Iconsax.message_question,
                          title: 'Feedback',
                          subtitle: 'Staff inquiries & grievances',
                          color: const Color(0xFFFB923C),
                          onTap: () => context.go('/feedback'),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    ),
  ),
);
  }

  String _getTodayAvgCheckIn() {
    final present = _todayAttendanceStatus
        .where((e) => e['is_present'] == true && e['check_in_time'] != null)
        .toList();
    if (present.isEmpty) return '--:--';
    int totalMinutes = 0;
    int count = 0;
    for (final p in present) {
      final raw = p['check_in_time']?.toString() ?? '';
      try {
        final parts = raw.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        totalMinutes += h * 60 + m;
        count++;
      } catch (_) {}
    }
    if (count == 0) return '--:--';
    final avgMin = totalMinutes ~/ count;
    final h = avgMin ~/ 60;
    final m = avgMin % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }

  String _getTodayOnTimeRate() {
    final present = _todayAttendanceStatus
        .where((e) => e['is_present'] == true)
        .toList();
    if (present.isEmpty) return '100%';
    int onTime = 0;
    for (final p in present) {
      final raw = p['check_in_time']?.toString() ?? '';
      try {
        final parts = raw.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        if (h * 60 + m <= 10 * 60 + 15) {
          onTime++;
        }
      } catch (_) {
        onTime++;
      }
    }
    final pct = (onTime / present.length) * 100;
    return '${pct.toStringAsFixed(0)}%';
  }

  List<Map<String, dynamic>> _getTodayTimeBuckets() {
    final bEarly = <Map<String, dynamic>>[]; // < 09:30 AM
    final bOnTime = <Map<String, dynamic>>[]; // 09:30 - 10:00 AM
    final bBuffer = <Map<String, dynamic>>[]; // 10:00 - 10:30 AM
    final bLate = <Map<String, dynamic>>[]; // 10:30 - 11:00 AM
    final bDelayed = <Map<String, dynamic>>[]; // > 11:00 AM
    final bAbsent = <Map<String, dynamic>>[]; // Not checked in

    for (final emp in _todayAttendanceStatus) {
      final isPresent = emp['is_present'] == true;
      if (!isPresent) {
        bAbsent.add(emp);
        continue;
      }
      final raw = emp['check_in_time']?.toString() ?? '';
      try {
        final parts = raw.split(':');
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final mins = h * 60 + m;
        if (mins < 9 * 60 + 30) {
          bEarly.add(emp);
        } else if (mins <= 10 * 60) {
          bOnTime.add(emp);
        } else if (mins <= 10 * 60 + 30) {
          bBuffer.add(emp);
        } else if (mins <= 11 * 60) {
          bLate.add(emp);
        } else {
          bDelayed.add(emp);
        }
      } catch (_) {
        bOnTime.add(emp);
      }
    }

    return [
      {
        'title': '< 9:30 AM',
        'subtitle': 'Early Bird',
        'color': const Color(0xFF3B82F6),
        'icon': Iconsax.sun_1,
        'employees': bEarly,
      },
      {
        'title': '9:30 – 10:00 AM',
        'subtitle': 'On-Time Primary',
        'color': const Color(0xFF10B981),
        'icon': Iconsax.tick_circle,
        'employees': bOnTime,
      },
      {
        'title': '10:00 – 10:30 AM',
        'subtitle': 'Standard Buffer',
        'color': const Color(0xFF06B6D4),
        'icon': Iconsax.clock,
        'employees': bBuffer,
      },
      {
        'title': '10:30 – 11:00 AM',
        'subtitle': 'Late Arrival',
        'color': const Color(0xFFF59E0B),
        'icon': Iconsax.timer,
        'employees': bLate,
      },
      {
        'title': '> 11:00 AM',
        'subtitle': 'Delayed',
        'color': const Color(0xFFEF4444),
        'icon': Iconsax.warning_2,
        'employees': bDelayed,
      },
      {
        'title': 'Not Checked In',
        'subtitle': 'Absent / Pending',
        'color': const Color(0xFF94A3B8),
        'icon': Iconsax.user_minus,
        'employees': bAbsent,
      },
    ];
  }

  List<Map<String, dynamic>> _getWeeklyDayEmployees(int dayIndex) {
    final now = NepaliDateTime.now();
    final daysSinceMonday = now.weekday == 1 ? 6 : now.weekday - 2;
    final weekStart = now.subtract(Duration(days: daysSinceMonday));
    final targetDate = weekStart.add(Duration(days: dayIndex));
    final targetDateStr = _fmtDate(targetDate);
    final todayStr = _fmtDate(now);

    // If viewing today's day bar, use today's live attendance status for instant real-time punch info
    if (targetDateStr == todayStr && _todayAttendanceStatus.isNotEmpty) {
      final presentToday = _todayAttendanceStatus
          .where((e) => e['is_present'] == true)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      if (presentToday.isNotEmpty) {
        return presentToday;
      }
    }

    final results = <Map<String, dynamic>>[];
    for (final log in _monthlyAttendanceLogs) {
      final d = log['date']?.toString() ?? '';
      if (d == targetDateStr) {
        final emp = log['employee'];
        String name = '';
        dynamic empId;
        if (emp is Map<String, dynamic>) {
          final first = emp['first_name']?.toString() ?? '';
          final last = emp['last_name']?.toString() ?? '';
          final full = '$first $last'.trim();
          name = full.isNotEmpty ? full : (emp['email']?.toString() ?? emp['name']?.toString() ?? '');
          empId = emp['id'];
        } else if (emp is String) {
          name = emp;
        }
        if (name.isEmpty) {
          name = log['employee_name']?.toString() ?? 'Staff Member';
        }

        final cioList = log['check_ins_outs'] as List? ?? [];
        String? checkInTime = log['check_in_time']?.toString() ?? log['check_in']?.toString();
        String? checkOutTime = log['check_out_time']?.toString() ?? log['check_out']?.toString();
        if (cioList.isNotEmpty) {
          final firstCio = cioList.first as Map<String, dynamic>?;
          final lastCio = cioList.last as Map<String, dynamic>?;
          checkInTime ??= firstCio?['check_in']?.toString();
          checkOutTime ??= lastCio?['check_out']?.toString();
        }
        results.add({
          'employee_id': empId ?? log['employee_id'],
          'employee_name': name,
          'is_present': true,
          'check_in_time': checkInTime,
          'check_out_time': checkOutTime,
          'is_remote': log['is_remote'] == true,
          'total_working_hours': log['total_working_hours'],
          'date': targetDateStr,
        });
      }
    }
    return results;
  }

  Widget _buildTimeSlotCard(
    Map<String, dynamic> b,
    int totalCount,
    BuildContext context,
  ) {
    final bTitle = b['title'] as String;
    final bSubtitle = b['subtitle'] as String;
    final bColor = b['color'] as Color;
    final bIcon = b['icon'] as IconData;
    final bEmps = b['employees'] as List<Map<String, dynamic>>;
    final ratio = (bEmps.length / totalCount).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showEmployeePunchInspector(
            title: 'Time Window: $bTitle',
            subtitle: '$bSubtitle • Today\'s staff check-in records',
            employees: bEmps,
            themeColor: bColor,
          );
        },
        borderRadius: BorderRadius.circular(14),
        hoverColor: bColor.withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: bColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(bIcon, size: 13, color: bColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      bTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: bColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${bEmps.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: bColor,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                bSubtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 4,
                  backgroundColor: context.border,
                  valueColor: AlwaysStoppedAnimation<Color>(bColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmployeePunchInspector({
    required String title,
    required String subtitle,
    required List<Map<String, dynamic>> employees,
    required Color themeColor,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = ctx.isDark;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 620,
              maxWidth: 620,
            ),
            decoration: BoxDecoration(
              color: ctx.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: ctx.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Iconsax.user_search,
                            color: themeColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: ctx.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${employees.length} Staff',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: themeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Iconsax.close_circle, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(32, 32),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: ctx.border),
                // List of employees
                Flexible(
                  child: employees.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 48, horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Iconsax.calendar_tick,
                                  size: 44,
                                  color: themeColor.withValues(alpha: 0.6)),
                              const SizedBox(height: 14),
                              Text(
                                'No check-in records found',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: ctx.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'No employees were logged during this specific time window or day.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(18),
                          itemCount: employees.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final emp = employees[i];
                            final name =
                                emp['employee_name']?.toString() ??
                                    'Staff Member';
                            final isPresent = emp['is_present'] == true;
                            final rawCheckIn =
                                emp['check_in_time']?.toString();
                            final rawCheckOut =
                                emp['check_out_time']?.toString();
                            final isRemote = emp['is_remote'] == true;
                            final hours = emp['total_working_hours'];

                            String fmtTime(String? raw) {
                              if (raw == null || raw.isEmpty) return '--:--';
                              try {
                                final parts = raw.split(':');
                                final h = int.parse(parts[0]);
                                final m = int.parse(parts[1]);
                                final period = h >= 12 ? 'PM' : 'AM';
                                final h12 = h % 12 == 0 ? 12 : h % 12;
                                return '$h12:${m.toString().padLeft(2, '0')} $period';
                              } catch (_) {
                                return raw;
                              }
                            }

                            // Punctuality tag
                            String punctualityLabel = 'On-Time';
                            Color punctualityColor = AppColors.success;
                            if (!isPresent) {
                              punctualityLabel = 'Absent / Not Punched';
                              punctualityColor = const Color(0xFF6B7280);
                            } else if (rawCheckIn != null) {
                              try {
                                final parts = rawCheckIn.split(':');
                                final h = int.parse(parts[0]);
                                final m = int.parse(parts[1]);
                                final mins = h * 60 + m;
                                if (mins < 9 * 60 + 30) {
                                  punctualityLabel = 'Early Bird';
                                  punctualityColor = const Color(0xFF3B82F6);
                                } else if (mins <= 10 * 60 + 15) {
                                  punctualityLabel = 'On-Time';
                                  punctualityColor = const Color(0xFF10B981);
                                } else if (mins <= 10 * 60 + 30) {
                                  punctualityLabel = 'Grace Period';
                                  punctualityColor = const Color(0xFF06B6D4);
                                } else if (mins <= 11 * 60) {
                                  punctualityLabel = 'Late Arrival';
                                  punctualityColor = const Color(0xFFF59E0B);
                                } else {
                                  punctualityLabel = 'Delayed';
                                  punctualityColor = const Color(0xFFEF4444);
                                }
                              } catch (_) {}
                            }

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: ctx.card,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: ctx.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: punctualityColor
                                        .withValues(alpha: 0.14),
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : 'E',
                                      style: TextStyle(
                                        color: punctualityColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: ctx.textPrimary,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isRemote) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 5,
                                                        vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'Remote',
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        Color(0xFF8B5CF6),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 2,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: punctualityColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                punctualityLabel,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: punctualityColor,
                                                ),
                                              ),
                                            ),
                                            if (hours != null)
                                              Text(
                                                'Hours: ${hours}h',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: isPresent
                                              ? AppColors.primary
                                                  .withValues(alpha: 0.08)
                                              : ctx.surface,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isPresent
                                                ? AppColors.primary
                                                    .withValues(alpha: 0.2)
                                                : ctx.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPresent
                                                  ? Iconsax.clock
                                                  : Iconsax.slash,
                                              size: 11,
                                              color: isPresent
                                                  ? AppColors.primary
                                                  : AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isPresent
                                                  ? 'In: ${fmtTime(rawCheckIn)}'
                                                  : 'Not Punched',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isPresent
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (rawCheckOut != null &&
                                          rawCheckOut.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          'Out: ${fmtTime(rawCheckOut)}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color:
                                                AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  BarChartGroupData _bar(int x, double y, {bool isWeekend = false}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          gradient: isWeekend
              ? LinearGradient(
                  colors: [
                    AppColors.textSecondary.withValues(alpha: 0.3),
                    AppColors.textSecondary.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                )
              : const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }


  Future<void> _showReportDialog(String type) async {
    final now = NepaliDateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: ctx.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: ctx.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (type == 'attendance'
                                      ? AppColors.info
                                      : AppColors.success)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Iconsax.document_download,
                              color: type == 'attendance'
                                  ? AppColors.info
                                  : AppColors.success,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Generate ${type == 'attendance' ? 'Attendance' : 'Salary'} Report',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: ctx.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Select Bikram Sambat period',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<int>(
                        initialValue: selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Year (B.S.)',
                          prefixIcon: Icon(Iconsax.calendar_1, size: 20),
                        ),
                        items: List.generate(11, (index) {
                          final y = (now.year - 5) + index;
                          return DropdownMenuItem(
                              value: y, child: Text('$y B.S.'));
                        }),
                        onChanged: (val) =>
                            setDialogState(() => selectedYear = val!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          prefixIcon: Icon(Iconsax.calendar_2, size: 20),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('Baishakh (01)')),
                          DropdownMenuItem(value: 2, child: Text('Jestha (02)')),
                          DropdownMenuItem(value: 3, child: Text('Ashadh (03)')),
                          DropdownMenuItem(value: 4, child: Text('Shrawan (04)')),
                          DropdownMenuItem(value: 5, child: Text('Bhadra (05)')),
                          DropdownMenuItem(value: 6, child: Text('Ashwin (06)')),
                          DropdownMenuItem(value: 7, child: Text('Kartik (07)')),
                          DropdownMenuItem(value: 8, child: Text('Mangsir (08)')),
                          DropdownMenuItem(value: 9, child: Text('Poush (09)')),
                          DropdownMenuItem(value: 10, child: Text('Magh (10)')),
                          DropdownMenuItem(value: 11, child: Text('Falgun (11)')),
                          DropdownMenuItem(value: 12, child: Text('Chaitra (12)')),
                        ],
                        onChanged: (val) =>
                            setDialogState(() => selectedMonth = val!),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: type == 'attendance'
                                    ? AppColors.info
                                    : AppColors.success,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Download',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true) {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: AppConstants.accessTokenKey) ?? '';
      const baseUrl = AppConstants.baseUrl;
      final endpoint = type == 'attendance'
          ? AppConstants.attendanceBase
          : AppConstants.salaryBase;
      final url =
          '$baseUrl$endpoint/generate-report/?year=$selectedYear&month=$selectedMonth&token=$token';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.document_download,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Downloading $type report for $selectedYear / $selectedMonth...'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
      launchUrlString(url, mode: LaunchMode.externalApplication);
    }
  }
}

// ----------------------------------------------------------------------------─
// Subcomponents
// ----------------------------------------------------------------------------─

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        letterSpacing: -0.5,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textSecondary.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Iconsax.arrow_right_3, size: 16, color: context.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionBtn({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.direct_down, color: color, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Iconsax.arrow_right_3,
                  color: AppColors.textSecondary, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
