import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../shared/widgets/nepali_date_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:universal_html/html.dart' as html;
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/date_provider.dart';
import '../../../core/constants/app_constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import 'add_employee_sheet.dart';

class EmployeeDetailScreen extends ConsumerStatefulWidget {
  final int id;
  const EmployeeDetailScreen({super.key, required this.id});

  @override
  ConsumerState<EmployeeDetailScreen> createState() =>
      _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _employee;
  Map<String, dynamic>? _attendanceStats;
  List<dynamic> _attendanceLogs = [];
  NepaliDateTime? _startDate;
  NepaliDateTime? _endDate;

  double _avgPerformance = 0.0;
  num _approvedLeaves = 0;
  double _latestSalary = 0.0;
  int _taskCount = 0;
  List<dynamic> _addresses = [];
  List<dynamic> _bankDetails = [];
  List<dynamic> _documents = [];
  List<dynamic> _pendingChangeRequests = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _loading = true);
    try {
      final bytes = await pickedFile.readAsBytes();
      final user = _employee?['user'];
      if (user == null) return;

      FormData formData = FormData.fromMap({
        'profile_picture':
            MultipartFile.fromBytes(bytes, filename: pickedFile.name),
      });

      await ApiService().patch(
        '/api/auth/accounts/${user['id']}/',
        data: formData,
      );

      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Profile photo updated successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Failed to update picture: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = NepaliDateTime.now();
    final NepaliDateTime? start = await showDialog<NepaliDateTime>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: 'Select Start Date (B.S.)',
        initial: _startDate ?? now,
      ),
    );
    if (start == null) return;

    if (!mounted) return;
    final NepaliDateTime? end = await showDialog<NepaliDateTime>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: 'Select End Date (B.S.)',
        initial: _endDate ?? start,
        minDate: start,
      ),
    );
    if (end == null) return;

    setState(() {
      _startDate = start;
      _endDate = end;
      _loading = true;
    });
    _loadAll();
  }

  Future<void> _downloadReport() async {
    try {
      String startStr = '';
      String endStr = '';
      if (_startDate != null && _endDate != null) {
        startStr =
            '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}';
        endStr =
            '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}';
      } else {
        final dateProv = ref.read(nepaliDateProvider);
        final y = dateProv.year;
        final m = dateProv.month;
        if (m == null) {
          startStr = '$y-01-01';
          endStr = '$y-12-${NepaliDateTime(y, 12).totalDays}';
        } else {
          final d = NepaliDateTime(y, m).totalDays;
          startStr = '$y-${m.toString().padLeft(2, '0')}-01';
          endStr = '$y-${m.toString().padLeft(2, '0')}-$d';
        }
      }

      final url =
          '${AppConstants.organizationBase}/employees/${widget.id}/report/?start_date=$startStr&end_date=$endStr';
      final response = await ApiService().get(url);

      final String csv = response.data.toString();
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: blobUrl)
        ..setAttribute("download", "employee_report_${widget.id}.csv")
        ..click();
      html.Url.revokeObjectUrl(blobUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.document_download, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Employee performance & attendance report exported!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download report: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _loadAll() async {
    try {
      final res = await ApiService()
          .get('${AppConstants.organizationBase}/employees/${widget.id}/');

      Map<String, dynamic>? stats;
      final dateProv = ref.read(nepaliDateProvider);
      String startStr = '';
      String endStr = '';
      if (_startDate != null && _endDate != null) {
        startStr =
            '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}';
        endStr =
            '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}';
      } else {
        final y = dateProv.year;
        final m = dateProv.month;
        if (m == null) {
          startStr = '$y-01-01';
          endStr = '$y-12-${NepaliDateTime(y, 12).totalDays}';
        } else {
          final d = NepaliDateTime(y, m).totalDays;
          startStr = '$y-${m.toString().padLeft(2, '0')}-01';
          endStr = '$y-${m.toString().padLeft(2, '0')}-$d';
        }
      }

      final dateQuery = '&start_date=$startStr&end_date=$endStr';

      setState(() {
        _latestSalary = 0.0;
        _avgPerformance = 0.0;
        _attendanceLogs = [];
        _approvedLeaves = 0;
        _taskCount = 0;
        _documents = [];
        _loading = true;
      });

      try {
        final statRes = await ApiService().get(
            '${AppConstants.attendanceBase}/total-working-hour/${widget.id}/?start_date=$startStr&end_date=$endStr');
        stats = statRes.data;
      } catch (_) {}

      try {
        final listRes = await ApiService().get(
            '${AppConstants.attendanceBase}/list/?employee=${widget.id}$dateQuery');
        final listData = listRes.data is List
            ? listRes.data
            : (listRes.data['results'] ?? []);
        if (listData is List) {
          _attendanceLogs = listData.where((log) {
            final emp = log['employee'];
            final empId = emp is Map ? emp['id'] : emp;
            return log['employee_id'] == widget.id || empId == widget.id;
          }).toList();
        }
      } catch (_) {}

      try {
        final perfRes = await ApiService()
            .get('/api/performance/reviews/?employee=${widget.id}$dateQuery');
        final perfData = perfRes.data is List
            ? perfRes.data
            : (perfRes.data['results'] ?? []);
        if (perfData is List) {
          final myReviews = perfData
              .where((r) =>
                  r['employee'] == widget.id || r['employee_id'] == widget.id)
              .toList();
          if (myReviews.isNotEmpty) {
            double total = 0;
            for (var r in myReviews) {
              total += (r['score'] ?? 0).toDouble();
            }
            _avgPerformance = total;
          }
        }
      } catch (_) {}

      try {
        final leaveRes = await ApiService().get(
            '${AppConstants.leaveBase}/leave-requests/?employee=${widget.id}$dateQuery');
        final leaveData = leaveRes.data is List
            ? leaveRes.data
            : (leaveRes.data['results'] ?? leaveRes.data);
        if (leaveData is List) {
          final myLeaves = leaveData
              .where((l) =>
                  (l['employee'] == widget.id ||
                      l['employee_id'] == widget.id) &&
                  l['is_approved'] == true)
              .toList();
          num sum = 0;
          for (var l in myLeaves) {
            sum += (l['no_days'] as num?) ?? 0;
          }
          _approvedLeaves = sum;
        }
      } catch (_) {}

      try {
        final salRes = await ApiService().get(
            '${AppConstants.salaryBase}/transactions/organization/?employee=${widget.id}$dateQuery');
        final salData = salRes.data is List
            ? salRes.data
            : (salRes.data['results'] ?? salRes.data);
        if (salData is List) {
          final mySalaries = salData
              .where((s) =>
                  s['employee'] == widget.id || s['employee_id'] == widget.id)
              .toList();
          if (mySalaries.isNotEmpty) {
            double totalSal = 0.0;
            for (var s in mySalaries) {
              totalSal += double.tryParse(s['net_salary']?.toString() ?? '0') ?? 0.0;
            }
            _latestSalary = totalSal;
          }
        }
      } catch (_) {}

      try {
        final taskRes = await ApiService()
            .get('${AppConstants.taskBase}/tasks/?assigned_to=${widget.id}$dateQuery');
        final taskData = taskRes.data is List
            ? taskRes.data
            : (taskRes.data['results'] ?? taskRes.data);
        if (taskData is List) {
          final myTasks = taskData.where((t) {
            final assignedId = t['assigned_to'] is Map
                ? t['assigned_to']['id']
                : t['assigned_to'];
            final isMyTask =
                assignedId == widget.id || t['employee'] == widget.id;
            final isActive = t['status'] != 'done';
            return isMyTask && isActive;
          }).toList();
          _taskCount = myTasks.length;
        }
      } catch (_) {}

      // Fetch address
      List<dynamic> addresses = [];
      try {
        final addrRes = await ApiService().get(
            '${AppConstants.organizationBase}/addresses/?employee=${widget.id}');
        if (addrRes.data is List) {
          addresses = addrRes.data as List;
        } else if (addrRes.data['results'] != null) {
          addresses = addrRes.data['results'];
        }
      } catch (_) {}

      // Fetch bank details
      List<dynamic> bankDetails = [];
      try {
        final bankRes = await ApiService().get(
            '${AppConstants.organizationBase}/bank-details/?employee=${widget.id}');
        if (bankRes.data is List) {
          bankDetails = bankRes.data as List;
        } else if (bankRes.data['results'] != null) {
          bankDetails = bankRes.data['results'];
        }
      } catch (_) {}

      // Fetch documents
      List<dynamic> docs = [];
      try {
        final docRes = await ApiService().get(
            '${AppConstants.organizationBase}/documents/?employee=${widget.id}');
        if (docRes.data is List) {
          docs = docRes.data as List;
        } else if (docRes.data['results'] != null) {
          docs = docRes.data['results'];
        }
      } catch (_) {}

      // Fetch profile change requests (pending only)
      List<dynamic> changeReqs = [];
      try {
        final changeRes = await ApiService().get(
            '${AppConstants.organizationBase}/profile-change-requests/?employee=${widget.id}&status=pending');
        if (changeRes.data is List) {
          changeReqs = changeRes.data as List;
        } else if (changeRes.data['results'] != null) {
          changeReqs = changeRes.data['results'];
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _employee = res.data;
        _attendanceStats = stats;
        _addresses = addresses;
        _bankDetails = bankDetails;
        _documents = docs;
        _pendingChangeRequests = changeReqs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to load employee details: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error));
    }
  }

  Future<void> _actionChangeRequest(int requestId, String action) async {
    try {
      await ApiService().patch(
        '${AppConstants.organizationBase}/profile-change-requests/$requestId/action/',
        data: {'status': action},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(
            children: [
              Icon(action == 'approved' ? Iconsax.tick_circle : Iconsax.close_circle,
                  color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(action == 'approved'
                  ? 'Change request approved & applied!'
                  : 'Change request rejected.'),
            ],
          ),
          backgroundColor:
              action == 'approved' ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _openEditModal() {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: ctx.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: ctx.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: AddEmployeeSheet(
              onSuccess: _loadAll,
              employee: _employee,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => AddEmployeeSheet(
          onSuccess: _loadAll,
          employee: _employee,
        ),
      );
    }
  }

  void _showAttendanceLogs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.surface,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Iconsax.calendar_1,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Full Attendance Logs',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Iconsax.close_circle, size: 20),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_attendanceLogs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No attendance logs recorded for this period.',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: _attendanceLogs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final log = _attendanceLogs[index];
                          final date = log['date'] ?? 'N/A';
                          final checkIn = log['check_in_time']?.toString().split('.')[0] ?? '--:--';
                          final checkOut = log['check_out_time']?.toString().split('.')[0] ?? '--:--';
                          final isRemote = log['is_remote'] == true;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: context.bg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (isRemote ? AppColors.accent : AppColors.primary)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isRemote ? Iconsax.home : Iconsax.building,
                                    color: isRemote ? AppColors.accent : AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        date,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'In: $checkIn  •  Out: $checkOut',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Iconsax.location, size: 16),
                                  label: const Text('View Proof',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  onPressed: () => _showLogDetails(log),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadAll());
    final isDark = context.isDark;

    if (_loading) {
      return Scaffold(
        backgroundColor: context.bg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_employee == null) {
      return Scaffold(
        backgroundColor: context.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.user_remove, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Text('Employee Record Not Found',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final user = _employee!['user'] ?? {};
    final fname = (user['first_name'] ?? '').toString();
    final lname = (user['last_name'] ?? '').toString();
    final fullName = '$fname $lname'.trim().isNotEmpty
        ? '$fname $lname'.trim()
        : (_employee!['official_email'] ?? 'Employee Profile');
    final email = user['email'] ?? _employee!['official_email'] ?? '';
    final designation = _employee!['designation_title'] ??
        (_employee!['post'] is Map ? _employee!['post']['title'] : null) ??
        'Staff Member';
    final empType = _employee!['employee_type'] ?? 'full_time';
    final isActive = _employee!['is_active'] == true;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - 48;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: availableWidth > 0 ? availableWidth : 0,
                  maxWidth: availableWidth > 0 ? availableWidth : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // ── Top Navigation & Filters Bar ──────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 700;

                  return Container(
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
                    child: Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: isMobile
                          ? CrossAxisAlignment.stretch
                          : CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Iconsax.arrow_left, size: 20),
                              onPressed: () => context.pop(),
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Employee Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Text(
                                  'Staff ID: ${_employee!['get_id'] ?? 'EMP_${widget.id}'}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isMobile) const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: isMobile ? WrapAlignment.start : WrapAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.calendar_1,
                                      size: 15, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    _startDate != null && _endDate != null
                                        ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')} to ${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}'
                                        : 'Current Month (B.S.)',
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Iconsax.calendar_search, size: 16),
                              label: const Text('Filter Dates'),
                              onPressed: _pickDateRange,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Iconsax.document_download,
                                  size: 16, color: Colors.white),
                              label: const Text('Export Report',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                              onPressed: _downloadReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── Hero Profile Card ─────────────────────────────────────────
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top Accent Banner
                    Container(
                      height: 80,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    // Profile Info & Avatar Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Avatar floating over banner
                          Transform.translate(
                            offset: const Offset(0, -35),
                            child: Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: context.surface,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 44,
                                    backgroundColor:
                                        AppColors.primary.withValues(alpha: 0.15),
                                    backgroundImage: user['profile_picture'] != null
                                        ? NetworkImage(user['profile_picture'])
                                        : null,
                                    child: user['profile_picture'] == null
                                        ? Text(
                                            fname.isNotEmpty
                                                ? fname[0].toUpperCase()
                                                : 'E',
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.primary,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: _updateProfilePicture,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: context.surface, width: 2.5),
                                      ),
                                      child: const Icon(Iconsax.camera,
                                          size: 15, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: LayoutBuilder(
                                builder: (context, c) {
                                  final isTight = c.maxWidth < 500;

                                  return Flex(
                                    direction: isTight ? Axis.vertical : Axis.horizontal,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: isTight
                                        ? CrossAxisAlignment.start
                                        : CrossAxisAlignment.center,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                fullName,
                                                style: TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.4,
                                                  color: context.textPrimary,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: (isActive
                                                          ? AppColors.success
                                                          : AppColors.error)
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  isActive ? 'Active' : 'Inactive',
                                                  style: TextStyle(
                                                    color: isActive
                                                        ? AppColors.success
                                                        : AppColors.error,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$designation · ${empType == 'full_time' ? 'Full-Time' : empType == 'part_time' ? 'Part-Time' : 'Intern'}',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 12,
                                            runSpacing: 4,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Iconsax.sms,
                                                      size: 14, color: AppColors.primary),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    email,
                                                    style: const TextStyle(
                                                      fontSize: 12.5,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withValues(alpha: 0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  empType == 'full_time'
                                                      ? 'Full Time'
                                                      : empType == 'part_time'
                                                          ? 'Part Time'
                                                          : 'Intern',
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (isTight) const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                        onPressed: _openEditModal,
                                        icon: const Icon(Iconsax.edit_2, size: 16),
                                        label: const Text('Edit Profile'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── KPI Metrics Grid ──────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  int crossAxisCount = 6;
                  if (width < 600) {
                    crossAxisCount = 2;
                  } else if (width < 900) {
                    crossAxisCount = 3;
                  }

                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: width < 600 ? 1.35 : 1.25,
                    children: [
                      _buildKpiCard(
                        'Performance',
                        _avgPerformance.toStringAsFixed(0),
                        'Points',
                        Iconsax.star1,
                        AppColors.primary,
                      ),
                      GestureDetector(
                        onTap: _showAttendanceLogs,
                        child: _buildKpiCard(
                          'Attendance',
                          '${_attendanceStats?['total_no_of_days_present'] ?? 0}',
                          'Days Present',
                          Iconsax.calendar_1,
                          AppColors.warning,
                        ),
                      ),
                      _buildKpiCard(
                        'Working Hours',
                        '${_attendanceStats?['total_working_hour'] ?? 0}',
                        'Total Hours',
                        Iconsax.clock,
                        AppColors.accent,
                      ),
                      _buildKpiCard(
                        'Leaves',
                        '$_approvedLeaves',
                        'Days Approved',
                        Iconsax.calendar_remove,
                        AppColors.warning,
                      ),
                      _buildKpiCard(
                        'Compensations',
                        'Rs. ${_latestSalary.toStringAsFixed(0)}',
                        'Net Paid',
                        Iconsax.wallet_money,
                        AppColors.success,
                      ),
                      _buildKpiCard(
                        'Active Tasks',
                        '$_taskCount',
                        'In Progress',
                        Iconsax.task_square,
                        AppColors.error,
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // ── Calendar & Agenda Overview ────────────────────────────────
              _buildAttendanceCalendarCard(context),

              const SizedBox(height: 24),

              // ── Pending Profile Change Requests (if any) ───────────────────
              if (_pendingChangeRequests.isNotEmpty) ...[
                _buildChangeRequestsSection(context),
                const SizedBox(height: 24),
              ],

              // ── Personal & Organizational Info ────────────────────────────
              _buildPersonalInfoSection(context),

              const SizedBox(height: 24),

              // ── Verification Documents ────────────────────────────────────
              _buildDocumentsSection(context),

              const SizedBox(height: 24),

              // ── Recent Attendance Logs Table ──────────────────────────────
              _buildAttendanceTable(context),
            ],
          ),
        ),
      );
    },
  ),
),
);
  }

  Widget _buildKpiCard(
      String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: context.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCalendarCard(BuildContext context) {
    final now = NepaliDateTime.now();
    final year = ApiService.globalNepaliYear ?? now.year;
    final month = ApiService.globalNepaliMonth ?? now.month;
    final presentDates =
        _attendanceLogs.map((e) => e['date'].toString()).toSet();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.calendar_tick,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Monthly Attendance Visualizer (B.S. $year/$month)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(AppColors.success, 'Present'),
                  const SizedBox(width: 14),
                  _legendDot(AppColors.primary, 'Today'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: 32,
            itemBuilder: (context, index) {
              final day = index + 1;
              String dateStr =
                  '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              bool isValid = true;
              try {
                NepaliDateTime.parse(dateStr);
              } catch (_) {
                isValid = false;
              }

              if (!isValid) return const SizedBox();

              final isPresent = presentDates.contains(dateStr);
              final isToday =
                  (day == now.day && month == now.month && year == now.year);

              return Container(
                decoration: BoxDecoration(
                  color: isPresent
                      ? AppColors.success.withValues(alpha: 0.15)
                      : context.bg,
                  border: Border.all(
                    color: isToday
                        ? AppColors.primary
                        : (isPresent
                            ? AppColors.success.withValues(alpha: 0.5)
                            : context.border),
                    width: isToday ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    color: isPresent
                        ? AppColors.success
                        : (isToday ? AppColors.primary : context.textPrimary),
                    fontWeight:
                        isToday || isPresent ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildChangeRequestsSection(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.info_circle, color: AppColors.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pending Profile Update Requests (${_pendingChangeRequests.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._pendingChangeRequests.map((req) {
            final field = req['field_name'] ?? '';
            final val = req['new_value']?.toString() ?? '-';
            final oldVal = req['old_value']?.toString() ?? '';
            final employeeName = (req['employee_name']?.toString().isNotEmpty == true && req['employee_name'] != 'Staff Member')
                ? req['employee_name'].toString()
                : (_employee?['user']?['full_name']?.toString() ??
                    _employee?['full_name']?.toString() ??
                    'Staff Member');
            final employeeCode = (req['employee_code']?.toString().isNotEmpty == true)
                ? req['employee_code'].toString()
                : (_employee?['employee_id']?.toString() ?? '');
            final int reqId = (req['id'] is int)
                ? (req['id'] as int)
                : (int.tryParse('${req['id']}') ?? 0);
            final createdAt = req['created_at'] != null
                ? req['created_at'].toString().split('T').first
                : '';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Requester & Field Badge Row ────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.user_edit, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    employeeName,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (employeeCode.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: context.card,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: context.border),
                                    ),
                                    child: Text(
                                      employeeCode,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _fieldLabel(field),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                if (createdAt.isNotEmpty)
                                  Text(
                                    'Requested: $createdAt',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PENDING REVIEW',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Value Diff Box ──────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.border),
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (oldVal.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Current: ',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                oldVal,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textPrimary.withValues(alpha: 0.7),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Requested: ',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              val,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // ── Actions ────────────────────────────────────────────────
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _actionChangeRequest(reqId, 'rejected'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEF4444), width: 1.2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.close_circle, size: 16, color: Color(0xFFEF4444)),
                                SizedBox(width: 6),
                                Text(
                                  'Reject',
                                  style: TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _actionChangeRequest(reqId, 'approved'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.tick_circle, size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Approve Update',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection(BuildContext context) {
    final emp = _employee!;
    final designation = emp['designation_title'] ??
        (emp['post'] is Map ? emp['post']['title'] : null) ??
        'Staff Member';
    final permanent = _addresses.firstWhere(
      (a) => a['type'] == 'permanent',
      orElse: () => _addresses.isNotEmpty ? _addresses.first : null,
    );
    final bank = _bankDetails.isNotEmpty ? _bankDetails.first : null;

    final permanentAddress = permanent != null
        ? [
            permanent['street']?.toString().trim(),
            permanent['district']?.toString().trim(),
            permanent['state']?.toString().trim(),
          ]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ')
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.user_octagon,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Personal & Statutory Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 24,
            runSpacing: 18,
            children: [
              _infoTile(Iconsax.call, 'Primary Phone', emp['phone_no'] ?? 'N/A'),
              _infoTile(Iconsax.user, "Father's Name", emp['father_name'] ?? 'N/A'),
              _infoTile(Iconsax.user, "Grandfather's Name",
                  emp['grandfather_name'] ?? 'N/A'),
              _infoTile(Iconsax.health, 'Blood Group', emp['blood_group'] ?? 'N/A'),
              _infoTile(Iconsax.call_calling, 'Emergency Contact',
                  emp['emergency_phone_number'] ??
                      emp['alternative_contact_number'] ??
                      'N/A'),
              _infoTile(Iconsax.sms_tracking, 'Personal Email',
                  emp['personal_email'] ?? 'N/A'),
              _infoTile(Iconsax.man, 'Gender',
                  (emp['gender'] ?? 'N/A').toString().toUpperCase()),
              _infoTile(Iconsax.calendar_1, 'Date of Birth (B.S.)',
                  emp['date_of_birth'] ?? 'N/A'),
              _infoTile(
                Iconsax.location,
                'Permanent Address',
                permanentAddress.isNotEmpty ? permanentAddress : 'N/A',
              ),
              _infoTile(Iconsax.award, 'Designation', designation),
              _infoTile(Iconsax.bank, 'Bank Name',
                  bank != null ? bank['bank_name'] ?? 'N/A' : 'N/A'),
              _infoTile(Iconsax.user_tag, 'Account Holder Name',
                  bank != null ? (bank['account_name'] ?? 'N/A') : 'N/A'),
              _infoTile(Iconsax.card, 'Bank Account No.',
                  bank != null ? bank['account_number'] ?? 'N/A' : 'N/A'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return SizedBox(
      width: 250,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadNewDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.first;
    final baseName = file.name.contains('.')
        ? file.name.substring(0, file.name.lastIndexOf('.'))
        : file.name;

    final nameCtrl = TextEditingController(text: baseName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Iconsax.document_upload, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Text('Attach Verification Document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected: ${file.name} (${(file.size / 1024).toStringAsFixed(1)} KB)',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Document Name / Label',
                hintText: 'e.g. Citizenship Card, Resume, PAN Document',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Upload Document',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        List<int> fileBytes;
        if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else if (file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        } else {
          return;
        }

        final docName = nameCtrl.text.trim().isNotEmpty
            ? nameCtrl.text.trim()
            : file.name;

        final formData = FormData.fromMap({
          'employee': widget.id,
          'name': docName,
          'file': MultipartFile.fromBytes(fileBytes, filename: file.name),
        });

        await ApiService().post(
          '${AppConstants.organizationBase}/documents/',
          data: formData,
        );

        _loadAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document uploaded successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload document'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _renameDocument(Map<String, dynamic> doc) {
    final ctrl = TextEditingController(text: doc['name'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Iconsax.edit_2, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Text('Rename Document',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Document Name',
            hintText: 'e.g. Citizenship Card, Offer Letter, Academic Certificate',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                try {
                  await ApiService().patch(
                    '${AppConstants.organizationBase}/documents/${doc['id']}/',
                    data: {'name': newName},
                  );
                  setState(() => doc['name'] = newName);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Document renamed successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to rename document'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save Name',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDocument(int docId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Document',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Are you sure you want to permanently delete this verification document?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService()
            .delete('${AppConstants.organizationBase}/documents/$docId/');
        setState(() {
          _documents.removeWhere((d) => d['id'] == docId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document deleted successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete document'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  void _previewDocument(Map<String, dynamic> doc) async {
    final String url = doc['file'] ?? '';
    final String name = doc['name'] ?? 'Document';
    final bool isImage = url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.webp');

    if (isImage && url.isNotEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: ctx.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 650),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: ctx.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Iconsax.document_download, size: 20),
                            onPressed: () async {
                              final uri = Uri.parse(url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            },
                            tooltip: 'Open in new tab / Download',
                            color: AppColors.primary,
                          ),
                          IconButton(
                            icon: const Icon(Iconsax.close_circle, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(child: Text('Failed to load image')),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (url.isNotEmpty) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Widget _buildDocumentsSection(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.document_upload,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Verification Documents (${_documents.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: _uploadNewDocument,
                icon: const Icon(Iconsax.document_upload, size: 16),
                label: const Text('Add Document',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_documents.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No documents uploaded for this employee.',
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _documents.map((doc) {
                final String name = doc['name'] ?? 'Document';
                final String url = doc['file'] ?? '';
                final bool isImage = url.toLowerCase().endsWith('.png') ||
                    url.toLowerCase().endsWith('.jpg') ||
                    url.toLowerCase().endsWith('.jpeg') ||
                    url.toLowerCase().endsWith('.webp');

                return Container(
                  width: 220,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isImage ? Iconsax.gallery : Iconsax.document_text,
                            color: isImage
                                ? AppColors.primary
                                : AppColors.accent,
                            size: 24,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isImage ? 'IMG' : 'DOC',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _renameDocument(doc),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Iconsax.edit_2,
                                size: 13, color: AppColors.accent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        url.split('/').last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () => _previewDocument(doc),
                            icon: const Icon(Iconsax.eye, size: 16),
                            tooltip: 'Preview Document',
                            visualDensity: VisualDensity.compact,
                            color: AppColors.primary,
                          ),
                          IconButton(
                            onPressed: () => _renameDocument(doc),
                            icon: const Icon(Iconsax.edit_2, size: 16),
                            tooltip: 'Rename Document',
                            visualDensity: VisualDensity.compact,
                            color: AppColors.accent,
                          ),
                          IconButton(
                            onPressed: () => _deleteDocument(doc['id']),
                            icon: const Icon(Iconsax.trash, size: 16),
                            tooltip: 'Delete Document',
                            visualDensity: VisualDensity.compact,
                            color: AppColors.error,
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
  }

  Widget _buildAttendanceTable(BuildContext context) {
    String formatTime(String? t) {
      if (t == null || t.isEmpty) return '-';
      return t.split('.')[0];
    }

    String formatDate(String? d) {
      if (d == null || d.isEmpty) return '-';
      try {
        return NepaliDateFormat('dd MMMM yyyy').format(NepaliDateTime.parse(d));
      } catch (_) {
        return d;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.clock,
                        color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Recent Attendance Logs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_attendanceLogs.isNotEmpty)
                TextButton.icon(
                  onPressed: _showAttendanceLogs,
                  icon: const Icon(Iconsax.eye, size: 16),
                  label: const Text('View All Logs'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_attendanceLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No attendance logs recorded.',
                  style: TextStyle(color: context.textSecondary),
                ),
              ),
            )
          else
            ...List.generate(
              _attendanceLogs.length > 5 ? 5 : _attendanceLogs.length,
              (index) {
                final log = _attendanceLogs[index];
                final isRemote = log['is_remote'] == true;
                final inTime = formatTime(log['check_in_time']?.toString());
                final outTime = formatTime(log['check_out_time']?.toString());

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.border),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (isRemote
                                      ? AppColors.accent
                                      : AppColors.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isRemote ? Iconsax.home : Iconsax.building,
                              color: isRemote
                                  ? AppColors.accent
                                  : AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatDate(log['date']?.toString()),
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'In: $inTime  •  Out: $outTime',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Iconsax.location, size: 14),
                        label: const Text('View Proof',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        onPressed: () => _showLogDetails(log),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showLogDetails(Map log) {
    String formatTime(String? t) {
      if (t == null || t.isEmpty) return '-';
      return t.split('.')[0];
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ctx.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Log: ${log['date']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: ctx.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'In: ${formatTime(log['check_in_time']?.toString())}  •  Out: ${formatTime(log['check_out_time']?.toString())}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Iconsax.close_circle, size: 20),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Divider(color: ctx.border),
                  const SizedBox(height: 12),

                  const Text(
                    'Biometric / Selfie Check-In Photos',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Check-In Photo',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: log['check_in_photo'] != null
                                  ? Image.network(log['check_in_photo'],
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover)
                                  : Container(
                                      height: 140,
                                      color: ctx.bg,
                                      child: const Center(
                                          child: Text('No photo',
                                              style: TextStyle(
                                                  color: AppColors
                                                      .textSecondary))),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Check-Out Photo',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: log['check_out_photo'] != null
                                  ? Image.network(log['check_out_photo'],
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover)
                                  : Container(
                                      height: 140,
                                      color: ctx.bg,
                                      child: const Center(
                                          child: Text('No photo',
                                              style: TextStyle(
                                                  color: AppColors
                                                      .textSecondary))),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'GPS Geo-Location Verification',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: Builder(
                      builder: (context) {
                        double? lat = double.tryParse(
                            log['check_in_lat']?.toString() ?? '');
                        double? lng = double.tryParse(
                            log['check_in_lng']?.toString() ?? '');
                        if (lat != null && lng != null) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(lat, lng),
                                zoom: 15,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('checkin'),
                                  position: LatLng(lat, lng),
                                  infoWindow: const InfoWindow(
                                      title: 'Check-In Location'),
                                ),
                              },
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                            ),
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: ctx.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: ctx.border),
                          ),
                          child: const Center(
                            child: Text(
                              'No GPS coordinates recorded for this check-in.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _fieldLabel(String fieldName) {
    const labels = {
      'phone_no': 'Phone Number',
      'personal_email': 'Personal Email',
      'emergency_phone_number': 'Emergency Contact',
    };
    return labels[fieldName] ?? fieldName.replaceAll('_', ' ').toUpperCase();
  }
}
