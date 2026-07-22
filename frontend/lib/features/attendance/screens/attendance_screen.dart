import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';

// ─── Date helper ─────────────────────────────────────────────────────────────
String _formatDate(String? raw, {String? fallback}) {
  DateTime? parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      if (s.contains('T')) return DateTime.parse(s);
      return NepaliDateTime.parse(s).toDateTime();
    } catch (_) {
      try {
        return DateTime.parse(s);
      } catch (_) {
        return null;
      }
    }
  }

  final date = parseDate(raw) ?? parseDate(fallback);
  if (date != null) return DateFormat('dd MMM yyyy').format(date);
  return DateFormat('dd MMM yyyy').format(DateTime.now());
}

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isCheckedIn = false;
  bool _isLoading = false;
  String? _checkInTime;
  String? _lastAction;
  Map<String, dynamic>? _stats;
  List _dailyHistory = [];
  List _orgLogs = [];
  bool _orgLogsLoading = false;
  late TabController _adminTabs;

  // Remote work permission state
  bool? _hasRemotePermission;
  List _remoteEmployees = [];
  bool _remoteLoading = false;

  Timer? _autoActionTimer;
  bool _autoInFlight = false;
  bool _hasPromptedAutoAttendance = false;

  @override
  void initState() {
    super.initState();
    _adminTabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadAll().then((_) => _attemptAutoAttendance());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoActionTimer?.cancel();
    _adminTabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attemptAutoAttendance();
    }
  }

  Future<void> _attemptAutoAttendance() async {
    if (_autoInFlight || _isLoading || _hasPromptedAutoAttendance) return;
    final isAdmin = ref.read(currentUserProvider)?.canManage ?? false;
    if (isAdmin) return; // keep this automatic for regular employees only

    _autoInFlight = true;
    try {
      if (!_isCheckedIn) {
        await _scheduleAutoAction(
          message: 'Checking you in at the office…',
          onFire: _performAutoCheckIn,
        );
      } else if (_hasBeenCheckedInLongEnough()) {
        await _scheduleAutoAction(
          message: 'Checking you out…',
          onFire: _performAutoCheckOut,
        );
      }
    } finally {
      _autoInFlight = false;
    }
  }

  bool _hasBeenCheckedInLongEnough() {
    if (_checkInTime == null) return false;
    try {
      final now = DateTime.now();
      
      // Handle both "10:30" and "10:30 AM" / "02:30 PM" formats safely
      String timeStr = _checkInTime!.trim().toUpperCase();
      bool isPM = timeStr.contains('PM');
      bool isAM = timeStr.contains('AM');
      
      timeStr = timeStr.replaceAll(' AM', '').replaceAll(' PM', '').replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = timeStr.split(':');
      
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      int second = 0;
      if (parts.length > 2) {
        // Handle microseconds like "37.201748"
        final secStr = parts[2].split('.')[0];
        second = int.parse(secStr);
      }
      
      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      final checkedInAt = DateTime(now.year, now.month, now.day, hour, minute, second);
      return now.difference(checkedInAt) >= const Duration(hours: 6);
    } catch (_) {
      // Very important: fail closed (false) to prevent accidental checkouts!
      return false;
    }
  }

  Future<void> _scheduleAutoAction({
    required String message,
    required Future<void> Function() onFire,
  }) async {
    _autoActionTimer?.cancel();
    bool cancelled = false;
    _hasPromptedAutoAttendance = true;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'CANCEL',
        onPressed: () => cancelled = true,
      ),
    ));

    final completer = Completer<void>();

    _autoActionTimer = Timer(const Duration(seconds: 5), () async {
      if (!cancelled && mounted) {
        await onFire();
      }
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
  }

  Future<void> _performAutoCheckIn() async {
    try {
      final pos = await _getLocation();
      final res = await ApiService().post(AppConstants.checkIn, data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      if (!mounted) return;
      setState(() {
        _isCheckedIn = true;
        _checkInTime = res.data['check_in_time']?.toString();
        _lastAction = 'Auto checked in at $_checkInTime';
      });
      _showSnack('✅ Auto checked-in — welcome!', AppColors.success);
      await _loadStats();
      await _loadDailyHistory();
    } catch (e) {
      final msg = ApiService.getErrorMessage(e);
      // Quietly ignore "not within radius" — expected when away from office.
      if (!msg.toLowerCase().contains('radius')) {
        _showSnack('⚠️ Auto check-in failed: $msg', AppColors.warning);
      }
    }
  }

  Future<void> _performAutoCheckOut() async {
    try {
      final pos = await _getLocation();
      final res = await ApiService().post(AppConstants.checkOut, data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      if (!mounted) return;
      setState(() {
        _isCheckedIn = false;
        _checkInTime = null;
        _lastAction = 'Auto checked out at ${res.data['check_out_time'] ?? res.data['check_in_time']}';
      });
      _showSnack('✅ Auto checked-out — see you next time!', AppColors.success);
      await _loadStats();
      await _loadDailyHistory();
    } catch (e) {
      final msg = ApiService.getErrorMessage(e);
      if (!msg.toLowerCase().contains('radius')) {
        _showSnack('⚠️ Auto check-out failed: $msg', AppColors.warning);
      }
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([
      _loadTodayStatus(),
      _loadStats(),
      _loadDailyHistory(),
      _loadMyRemoteStatus(),
    ]);
    final isAdmin = ref.read(currentUserProvider)?.canManage ?? false;
    if (isAdmin) {
      _loadOrgLogs();
      _loadRemoteList();
    }
  }

  Future<void> _loadTodayStatus() async {
    try {
      final res =
          await ApiService().get('${AppConstants.attendanceBase}/today-status/');
      if (mounted) {
        setState(() {
          _isCheckedIn = res.data['is_checked_in'] == true;
          _checkInTime = res.data['check_in_time'];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user?.employeeId == null) return;
      final res = await ApiService().get(
        '${AppConstants.attendanceBase}/total-working-hour/${user!.employeeId}/',
      );
      if (mounted) setState(() => _stats = res.data);
    } catch (_) {}
  }

  Future<void> _loadDailyHistory() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user?.employeeId == null) return;
      final res = await ApiService().get('${AppConstants.attendanceBase}/list/');
      if (!mounted) return;
      final all = res.data is List ? res.data as List : [];
      final myLogs =
          all.where((a) => a['employee_id'] == user?.employeeId).toList();
      setState(() => _dailyHistory = myLogs);
    } catch (_) {}
  }

  Future<void> _loadOrgLogs() async {
    setState(() => _orgLogsLoading = true);
    try {
      final res =
          await ApiService().get('${AppConstants.attendanceBase}/list/');
      if (mounted) {
        setState(() {
          _orgLogs = res.data is List ? res.data : [];
          _orgLogsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _orgLogsLoading = false);
    }
  }

  Future<void> _loadMyRemoteStatus() async {
    try {
      final res = await ApiService()
          .get('${AppConstants.attendanceBase}/remote-work-permission/me/');
      if (mounted) {
        setState(() =>
            _hasRemotePermission = res.data['has_remote_permission'] == true);
      }
    } catch (_) {}
  }

  Future<void> _loadRemoteList() async {
    setState(() => _remoteLoading = true);
    try {
      final res = await ApiService()
          .get('${AppConstants.attendanceBase}/remote-work-permission/list/');
      if (mounted) {
        setState(() {
          _remoteEmployees = res.data is List ? res.data : [];
          _remoteLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _remoteLoading = false);
    }
  }

  Future<void> _setRemoteLocation(int employeeId) async {
    try {
      final pos = await _getLocation();
      await ApiService().post(
        '${AppConstants.attendanceBase}/remote-work-permission/set/$employeeId/',
        data: {'latitude': pos.latitude, 'longitude': pos.longitude},
      );
      _showSnack('✅ Remote location set!', AppColors.success);
      _loadRemoteList();
    } catch (e) {
      _showSnack('❌ ${ApiService.getErrorMessage(e)}', AppColors.error);
    }
  }

  Future<void> _removeRemoteLocation(int employeeId) async {
    try {
      await ApiService().delete(
        '${AppConstants.attendanceBase}/remote-work-permission/set/$employeeId/',
      );
      _showSnack('✅ Remote access revoked', AppColors.success);
      _loadRemoteList();
    } catch (e) {
      _showSnack('❌ ${ApiService.getErrorMessage(e)}', AppColors.error);
    }
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception(
          'Location permission permanently denied. Please enable it in settings.');
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  Future<void> _checkIn() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check In'),
        content: const Text('Confirm you want to check in now?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Check In')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final pos = await _getLocation();
      final res = await ApiService().post(AppConstants.checkIn, data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      if (!mounted) return;
      setState(() {
        _isCheckedIn = true;
        _checkInTime = res.data['check_in_time']?.toString();
        _lastAction = 'Checked in at $_checkInTime';
      });
      _showSnack('✅ Checked in successfully!', AppColors.success);
      await _loadStats();
      await _loadDailyHistory();
    } catch (e) {
      if (!mounted) return;
      final msg = ApiService.getErrorMessage(e);
      if (msg.toLowerCase().contains('cannot check in again') ||
          msg.toLowerCase().contains('without checking out')) {
        _showSnack('⚠️ You are already checked in. Please check out first.',
            AppColors.warning);
      } else if (msg
          .toLowerCase()
          .contains('not within the office or remote work radius')) {
        _showSnack(
            '⚠️ You need to be at the office or your approved remote location to check in.',
            AppColors.warning);
      } else {
        _showSnack('❌ $msg', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check Out'),
        content: const Text('Confirm you want to check out now?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Check Out')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final pos = await _getLocation();
      final res = await ApiService().post(AppConstants.checkOut, data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      if (!mounted) return;
      setState(() {
        _isCheckedIn = false;
        _checkInTime = null;
        _lastAction = 'Checked out at ${res.data['check_in_time']}';
      });
      _showSnack('✅ Checked out successfully!', AppColors.success);
      await _loadStats();
      await _loadDailyHistory();
    } catch (e) {
      if (!mounted) return;
      final msg = ApiService.getErrorMessage(e);
      if (msg
          .toLowerCase()
          .contains('not within the office or remote work radius')) {
        _showSnack(
            '⚠️ You need to be at the office or your approved remote location to check out.',
            AppColors.warning);
      } else {
        _showSnack('❌ $msg', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _setOfficeLocation() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _getLocation();
      await ApiService().post('/api/organization/address/set/', data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      _showSnack('✅ Office Location configured successfully!', AppColors.success);
    } catch (e) {
      _showSnack(
          '❌ Failed to set office location: ${ApiService.getErrorMessage(e)}',
          AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    if (isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_location_alt_outlined),
              tooltip: 'Set Office Location',
              onPressed: _isLoading ? null : _setOfficeLocation,
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
          ],
          bottom: TabBar(
            controller: _adminTabs,
            tabs: const [
              Tab(text: 'Check In/Out'),
              Tab(text: 'All Staff Logs'),
              Tab(text: 'Remote Access'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _adminTabs,
          children: [
            _buildCheckInUI(),
            _buildOrgLogs(),
            _buildRemoteAccessTab(),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAll),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: _buildCheckInUI(),
      ),
    );
  }

  Widget _buildCheckInUI() => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          if (_stats != null) ...[
            Row(children: [
              Expanded(
                  child: _StatBox('Hours Worked',
                      '${_stats!['total_working_hour']}h', AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatBox('Days Present',
                      '${_stats!['total_no_of_days_present']}', AppColors.success)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatBox('Remaining',
                      '${_stats!['remaining_working_hour']}h', AppColors.warning)),
            ]),
            const SizedBox(height: 24),
          ],

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isCheckedIn
                    ? [AppColors.success, const Color(0xFF059669)]
                    : [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(children: [
              Icon(
                _isCheckedIn ? Iconsax.tick_circle : Iconsax.clock,
                color: Colors.white,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                _isCheckedIn ? 'Currently Checked In' : 'Not Checked In',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              if (_checkInTime != null) ...[
                const SizedBox(height: 4),
                Text('Since $_checkInTime',
                    style: const TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor:
                      _isCheckedIn ? AppColors.success : AppColors.primary,
                  minimumSize: const Size(200, 48),
                ),
                onPressed:
                    _isLoading ? null : (_isCheckedIn ? _checkOut : _checkIn),
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isCheckedIn ? Iconsax.logout : Iconsax.login),
                label: _isLoading
                    ? const Text('Please wait...',
                        style: TextStyle(fontWeight: FontWeight.bold))
                    : Text(_isCheckedIn ? 'Check Out' : 'Check In',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),

          if (_lastAction != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Iconsax.info_circle,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_lastAction!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ),
              ]),
            ),
          ],

          if (_hasRemotePermission != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_hasRemotePermission!
                        ? AppColors.success
                        : AppColors.textSecondary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(
                  _hasRemotePermission!
                      ? Iconsax.tick_circle
                      : Iconsax.close_circle,
                  size: 16,
                  color: _hasRemotePermission!
                      ? AppColors.success
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hasRemotePermission!
                        ? 'Remote work location approved ✓'
                        : 'No remote work location approved yet',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 24),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Attendance History',
                  style:
                      TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          const SizedBox(height: 12),

          if (_dailyHistory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No attendance records yet.',
                  style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ...(_dailyHistory).map((log) => _AttendanceLogTile(log: log)),

          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Note: Check-in and check-out both require you to be within 500m of your office or your approved remote location.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12))),
        ]),
      );

  Widget _buildOrgLogs() => _orgLogsLoading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _loadOrgLogs,
          child: _orgLogs.isEmpty
              ? const Center(
                  child: Text('No attendance logs found.',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orgLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _AttendanceLogTile(log: _orgLogs[i], showName: true),
                ),
        );

  Widget _buildRemoteAccessTab() => _remoteLoading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _loadRemoteList,
          child: _remoteEmployees.isEmpty
              ? const Center(
                  child: Text('No employees found.',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _remoteEmployees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final e = _remoteEmployees[i];
                    final hasPermission = e['has_remote_permission'] == true;
                    final employeeId = e['employee_id'] as int;
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: (hasPermission
                                    ? AppColors.success
                                    : AppColors.textSecondary)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            hasPermission
                                ? Iconsax.tick_circle
                                : Iconsax.close_circle,
                            color: hasPermission
                                ? AppColors.success
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                        title: Text(e['employee_name'] ?? 'Unknown'),
                        subtitle: Text(hasPermission
                            ? 'Remote location approved'
                            : 'No remote location set'),
                        trailing: hasPermission
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: AppColors.error),
                                tooltip: 'Revoke remote access',
                                onPressed: () =>
                                    _removeRemoteLocation(employeeId),
                              )
                            : IconButton(
                                icon: const Icon(
                                    Icons.add_location_alt_outlined,
                                    color: AppColors.primary),
                                tooltip: 'Set remote location (from here)',
                                onPressed: () => _setRemoteLocation(employeeId),
                              ),
                      ),
                    );
                  },
                ),
        );
}

class _AttendanceLogTile extends StatelessWidget {
  final Map log;
  final bool showName;
  const _AttendanceLogTile({required this.log, this.showName = false});

  @override
  Widget build(BuildContext context) {
    final checkedIn = log['check_in_time'] != null;
    final checkedOut = log['check_out_time'] != null;
    final isRemote = log['is_remote'] == true;
    final hours = log['total_hours'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: checkedIn
                  ? AppColors.success.withValues(alpha: 0.15)
                  : AppColors.error.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              checkedIn ? Iconsax.tick_circle : Iconsax.close_circle,
              color: checkedIn ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (showName)
                  Text(log['employee_name'] ?? 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                Text(_formatDate(log['date']?.toString()),
                    style: TextStyle(
                      fontWeight:
                          showName ? FontWeight.normal : FontWeight.w600,
                      fontSize: showName ? 12 : 14,
                      color: showName ? AppColors.textSecondary : null,
                    )),
                const SizedBox(height: 2),
                Wrap(children: [
                  if (checkedIn)
                    Text('In: ${log['check_in_time']}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.success)),
                  if (checkedIn && checkedOut)
                    const Text('  →  ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  if (checkedOut)
                    Text('Out: ${log['check_out_time']}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.error)),
                  if (!checkedIn)
                    const Text('Not checked in',
                        style: TextStyle(fontSize: 12, color: AppColors.error)),
                ]),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${hours}h',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            if (isRemote)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Remote',
                    style:
                        TextStyle(fontSize: 10, color: AppColors.accent)),
              ),
          ]),
        ]),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
              textAlign: TextAlign.center),
        ]),
      );
}
