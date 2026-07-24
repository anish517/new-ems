import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

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

  double _avgPerformance = 0.0;
  num _approvedLeaves = 0;
  double _latestSalary = 0.0;
  int _taskCount = 0;
  List<dynamic> _addresses = [];
  List<dynamic> _bankDetails = [];

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Failed to update picture: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ));
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadAll() async {
    try {
      final res = await ApiService()
          .get('${AppConstants.organizationBase}/employees/${widget.id}/');

      Map<String, dynamic>? stats;
      try {
        final statRes = await ApiService().get(
            '${AppConstants.attendanceBase}/total-working-hour/${widget.id}/');
        stats = statRes.data;
      } catch (_) {}

      try {
        final listRes =
            await ApiService().get('${AppConstants.attendanceBase}/list/');
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
        final perfRes = await ApiService().get('/api/performance/reviews/');
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
            _avgPerformance = total / myReviews.length;
          }
        }
      } catch (_) {}

      try {
        final leaveRes =
            await ApiService().get('${AppConstants.leaveBase}/leave-requests/');
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
            '${AppConstants.salaryBase}/transactions/organization/?employee=${widget.id}');
        final salData = salRes.data is List
            ? salRes.data
            : (salRes.data['results'] ?? salRes.data);
        if (salData is List) {
          final mySalaries = salData
              .where((s) =>
                  s['employee'] == widget.id || s['employee_id'] == widget.id)
              .toList();
          if (mySalaries.isNotEmpty) {
            mySalaries.sort((a, b) => (b['id'] ?? 0).compareTo(a['id'] ?? 0));
            _latestSalary = double.tryParse(
                    mySalaries.first['net_salary']?.toString() ?? '0') ??
                0.0;
          }
        }
      } catch (_) {}

      try {
        final taskRes =
            await ApiService().get('${AppConstants.taskBase}/tasks/');
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
            // Only count active (non-done) tasks
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

      if (!mounted) return;
      setState(() {
        _employee = res.data;
        _attendanceStats = stats;
        _addresses = addresses;
        _bankDetails = bankDetails;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to load employee details'),
          backgroundColor: AppColors.error));
    }
  }

  void _showAttendanceLogs() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attendance Logs',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_attendanceLogs.isEmpty)
                    const Center(child: Text('No attendance logs found.'))
                  else
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _attendanceLogs.length,
                        itemBuilder: (context, index) {
                          final log = _attendanceLogs[index];
                          final date = log['date'] ?? 'N/A';
                          final checkIn = log['check_in_time'] ?? '--:--';
                          final checkOut = log['check_out_time'] ?? '--:--';
                          return Card(
                            color: AppColors.bgDark,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(Iconsax.calendar_1,
                                  color: AppColors.primary),
                              title: Text('Date: $date'),
                              subtitle: Text('In: $checkIn  |  Out: $checkOut'),
                            ),
                          );
                        },
                      ),
                    )
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_employee == null) {
      return const Scaffold(body: Center(child: Text("Employee not found")));
    }

    final user = _employee!['user'] ?? {};
    final name = "${user['first_name'] ?? ''} ${user['last_name'] ?? ''}";
    final email = user['email'] ?? '';
    final role = user['role'] ?? 'employee';

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top breadcrumb and back button
            Row(
              children: [
                IconButton(
                  icon: const Icon(Iconsax.arrow_left),
                  onPressed: () => context.pop(),
                ),
                Text('Organization > Employees > Detail',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 16),

            // Profile Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: user['profile_picture'] != null
                            ? NetworkImage(user['profile_picture'])
                            : null,
                        child: user['profile_picture'] == null
                            ? const Icon(Iconsax.user, size: 40)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _updateProfilePicture,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Iconsax.camera,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(role.toString().toUpperCase(),
                            style: const TextStyle(color: AppColors.primary)),
                        const SizedBox(height: 4),
                        Text(email,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                          icon: const Icon(Iconsax.printer,
                              color: AppColors.primary),
                          onPressed: () {}),
                      IconButton(
                          icon: const Icon(Iconsax.card,
                              color: AppColors.success),
                          onPressed: () {}),
                      IconButton(
                          icon: const Icon(Iconsax.setting,
                              color: AppColors.accent),
                          onPressed: () {}),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Grid of KPI Cards & Calendar
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      _buildKpiCard(
                          'Performance',
                          _avgPerformance.toStringAsFixed(1),
                          Iconsax.chart_2,
                          AppColors.primary),
                      GestureDetector(
                        onTap: _showAttendanceLogs,
                        child: _buildKpiCard(
                            'Attendance',
                            '${_attendanceStats?['total_no_of_days_present'] ?? 0} days',
                            Iconsax.calendar_1,
                            AppColors.warning),
                      ),
                      _buildKpiCard(
                          'Average working hour',
                          '${_attendanceStats?['total_working_hour'] ?? 0} Hrs',
                          Iconsax.clock,
                          AppColors.warning),
                      _buildKpiCard('Leaves', '$_approvedLeaves days',
                          Iconsax.cloud_drizzle, AppColors.accent),
                      _buildKpiCard(
                          'Salary',
                          'Rs. ${_latestSalary.toStringAsFixed(0)}',
                          Iconsax.money,
                          AppColors.success),
                      _buildKpiCard('Tasks', 'Active: $_taskCount',
                          Iconsax.task_square, AppColors.error),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Mini Calendar Widget mock
                Expanded(
                  flex: 1,
                  child: _buildCalendar(),
                )
              ],
            ),

            const SizedBox(height: 32),

            // Personal Information Section
            const Text('Personal Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: LayoutBuilder(builder: (ctx, c) {
                final emp = _employee!;
                final permanent = _addresses.firstWhere(
                    (a) => a['type'] == 'permanent',
                    orElse: () =>
                        _addresses.isNotEmpty ? _addresses.first : null);
                final bank =
                    _bankDetails.isNotEmpty ? _bankDetails.first : null;
                return Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    _infoChip(
                        Iconsax.mobile, 'Phone', emp['phone_no'] ?? 'N/A'),
                    _infoChip(
                        Iconsax.profile_circle,
                        'Gender',
                        (emp['gender'] as String? ?? 'N/A').isNotEmpty
                            ? ((emp['gender'] as String)
                                    .substring(0, 1)
                                    .toUpperCase() +
                                (emp['gender'] as String).substring(1))
                            : 'N/A'),
                    _infoChip(Iconsax.calendar, 'Date of Birth',
                        emp['date_of_birth'] ?? 'N/A'),
                    _infoChip(Iconsax.briefcase, 'Employee Type', (() {
                      final t = (emp['employee_type'] ?? 'N/A')
                          .toString()
                          .replaceAll('_', ' ');
                      return t.isNotEmpty
                          ? t.substring(0, 1).toUpperCase() + t.substring(1)
                          : t;
                    })()),
                    _infoChip(
                        Iconsax.location,
                        'Address',
                        permanent != null
                            ? '${permanent['street'] ?? ''}, ${permanent['district'] ?? ''}, ${permanent['state'] ?? ''}'
                                .replaceAll(RegExp(r'^,\s*|,\s*$'), '')
                                .trim()
                            : 'N/A'),
                    _infoChip(Iconsax.bank, 'Bank',
                        bank != null ? bank['bank_name'] ?? 'N/A' : 'N/A'),
                    _infoChip(Iconsax.card, 'Account Number',
                        bank != null ? bank['account_number'] ?? 'N/A' : 'N/A'),
                  ],
                );
              }),
            ),

            const SizedBox(height: 32),
            const Text('Recent Attendance Logs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildAttendanceTable(context),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, String value) {
    return SizedBox(
      width: 240,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAttendanceTable(BuildContext context) {
    if (_attendanceLogs.isEmpty) {
      return const Center(
          child: Text("No attendance records found.",
              style: TextStyle(color: AppColors.textSecondary)));
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _attendanceLogs.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.borderDark),
        itemBuilder: (context, index) {
          final log = _attendanceLogs[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(log['is_remote'] == true ? Iconsax.home : Iconsax.building,
                    color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log['date'] ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                          'In: ${log['check_in_time']?.toString().split('.')[0] ?? '-'} | Out: ${log['check_out_time']?.toString().split('.')[0] ?? '-'}',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Iconsax.map),
                  label: const Text("View Map/Photos"),
                  onPressed: () => _showLogDetails(log),
                ),
              ],
            ),
          );
        },
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
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance Log: ${log['date']}'),
            const SizedBox(height: 4),
            Text(
              'In: ${formatTime(log['check_in_time']?.toString())} | Out: ${formatTime(log['check_out_time']?.toString())}',
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Photos",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Check-In"),
                          const SizedBox(height: 4),
                          log['check_in_photo'] != null
                              ? Image.network(log['check_in_photo'],
                                  height: 150, fit: BoxFit.cover)
                              : const Text("No photo",
                                  style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          const Text("Check-Out"),
                          const SizedBox(height: 4),
                          log['check_out_photo'] != null
                              ? Image.network(log['check_out_photo'],
                                  height: 150, fit: BoxFit.cover)
                              : const Text("No photo",
                                  style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text("Map View",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 250,
                  child: Builder(
                    builder: (context) {
                      double? lat = double.tryParse(
                          log['check_in_lat']?.toString() ?? '');
                      double? lng = double.tryParse(
                          log['check_in_lng']?.toString() ?? '');
                      if (lat != null && lng != null) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
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
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderDark),
                        ),
                        child: const Center(
                            child: Text(
                                "No location data recorded for this check-in.")),
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final now = NepaliDateTime.now();
    final presentDates =
        _attendanceLogs.map((e) => e['date'].toString()).toSet();

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Attendance Calendar (${now.year}-${now.month.toString().padLeft(2, '0')})',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: 32, // simplified max days, typically enough for visual
              itemBuilder: (context, index) {
                final day = index + 1;
                // Since exact days in month varies, we'll try to parse, if it fails it's out of month
                String dateStr =
                    '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                bool isValid = true;
                try {
                  NepaliDateTime.parse(dateStr);
                } catch (_) {
                  isValid = false;
                }

                if (!isValid) return const SizedBox();

                final isPresent = presentDates.contains(dateStr);
                final isToday = day == now.day;

                return Container(
                  decoration: BoxDecoration(
                    color: isPresent
                        ? AppColors.success.withValues(alpha: 0.2)
                        : AppColors.bgDark,
                    border: isToday
                        ? Border.all(color: AppColors.primary, width: 2)
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      color:
                          isPresent ? AppColors.success : AppColors.textPrimary,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
