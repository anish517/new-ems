import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/providers/date_provider.dart';

// ─── Date helper ─────────────────────────────────────────────────────────────
String _formatDate(String? raw, {String? fallback}) {
  NepaliDateTime? parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      if (s.contains('T')) return DateTime.parse(s).toNepaliDateTime();
      return NepaliDateTime.parse(s);
    } catch (_) {
      try {
        return DateTime.parse(s).toNepaliDateTime();
      } catch (_) {
        return null;
      }
    }
  }

  final dt = parseDate(raw);
  if (dt == null) return fallback ?? 'Unknown date';
  return NepaliDateFormat('dd MMM yyyy').format(dt);
}

String _formatRemoteDate(String? isoString) {
  if (isoString == null) return 'N/A';
  try {
    final nd = DateTime.parse(isoString).toNepaliDateTime();
    return '${nd.year}-${nd.month.toString().padLeft(2, '0')}-${nd.day.toString().padLeft(2, '0')}';
  } catch (_) {
    return isoString.split('T')[0];
  }
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
  List _pendingRemoteRequests = [];
  bool _remoteLoading = false;

  // Attendance correction requests
  List _myCorrectionRequests = [];
  List _pendingCorrectionRequests = [];
  bool _correctionLoading = false;

  Timer? _autoActionTimer;
  bool _autoInFlight = false;
  bool _hasPromptedAutoAttendance = true; // start true so we don't auto-prompt before data loads

  // Live location for map
  Position? _currentPosition;
  GoogleMapController? _liveMapController;

  @override
  void initState() {
    super.initState();
    _adminTabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadAll().then((_) {
      _hasPromptedAutoAttendance = false;
      _attemptAutoAttendance();
    });
    _startLiveLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoActionTimer?.cancel();
    _liveMapController?.dispose();
    _adminTabs.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attemptAutoAttendance();
      _startLiveLocation();
    }
  }

  Future<void> _startLiveLocation() async {
    try {
      final pos = await _getLocation();
      if (mounted) setState(() => _currentPosition = pos);
      _liveMapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
    } catch (_) {}
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
    final completer = Completer<void>();
    _hasPromptedAutoAttendance = true;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'CANCEL',
        onPressed: () {
          cancelled = true;
          _autoActionTimer?.cancel();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    ));

    _autoActionTimer = Timer(const Duration(seconds: 5), () async {
      if (!cancelled && mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
        'latitude': pos.latitude.toString(),
        'longitude': pos.longitude.toString(),
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
        'latitude': pos.latitude.toString(),
        'longitude': pos.longitude.toString(),
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
    setState(() => _isLoading = true);
    await Future.wait([
      _loadTodayStatus(),
      _loadStats(),
      _loadDailyHistory(),
      _loadMyRemoteStatus(),
      _loadMyCorrectionRequests(),
    ]);
    final isAdmin = ref.read(currentUserProvider)?.canManage ?? false;
    if (isAdmin) {
      _loadOrgLogs();
      _loadRemoteList();
      _loadPendingCorrections();
    }
    if (mounted) setState(() => _isLoading = false);
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
      final all = res.data is List ? res.data as List : (res.data['results'] ?? []);
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
          _orgLogs = res.data is List ? res.data : (res.data['results'] ?? []);
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
      
      final reqRes = await ApiService()
          .get('${AppConstants.attendanceBase}/remote-requests/');
          
      if (mounted) {
        setState(() {
          _remoteEmployees = res.data is List ? res.data : [];
          _pendingRemoteRequests = reqRes.data is List ? reqRes.data : [];
          _remoteLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _remoteLoading = false);
    }
  }

  Future<void> _requestRemoteWork(String reason) async {
    try {
      final pos = await _getLocation();
      await ApiService().post(
        '${AppConstants.attendanceBase}/remote-requests/',
        data: {
          'latitude': pos.latitude.toString(),
          'longitude': pos.longitude.toString(),
          'reason': reason,
        },
      );
      _showSnack('✅ Remote work request submitted successfully!', AppColors.success);
      _loadRemoteList();
    } catch (e) {
      _showSnack('❌ ${ApiService.getErrorMessage(e)}', AppColors.error);
    }
  }

  Future<void> _actionRemoteRequest(int id, String action) async {
    try {
      await ApiService().post(
        '${AppConstants.attendanceBase}/remote-requests/$id/action/',
        data: {'status': action},
      );
      _showSnack('✅ Request $action successfully!', AppColors.success);
      _loadRemoteList();
    } catch (e) {
      _showSnack('❌ ${ApiService.getErrorMessage(e)}', AppColors.error);
    }
  }

  // ── Correction Requests ─────────────────────────────────────────────────────

  Future<void> _loadMyCorrectionRequests() async {
    try {
      final res = await ApiService()
          .get('${AppConstants.attendanceBase}/correction-requests/');
      if (mounted) {
        setState(() => _myCorrectionRequests =
            res.data is List ? res.data : (res.data['results'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadPendingCorrections() async {
    setState(() => _correctionLoading = true);
    try {
      final res = await ApiService().get(
          '${AppConstants.attendanceBase}/correction-requests/?status=pending');
      if (mounted) {
        setState(() {
          _pendingCorrectionRequests =
              res.data is List ? res.data : (res.data['results'] ?? []);
          _correctionLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _correctionLoading = false);
    }
  }

  Future<void> _submitCorrectionRequest({
    required String date,
    required String? checkIn,
    required String? checkOut,
    required String reason,
  }) async {
    try {
      await ApiService().post(
        '${AppConstants.attendanceBase}/correction-requests/',
        data: {
          'requested_date': date,
          if (checkIn != null && checkIn.isNotEmpty) 'requested_check_in': checkIn,
          if (checkOut != null && checkOut.isNotEmpty) 'requested_check_out': checkOut,
          'reason': reason,
        },
      );
      _showSnack('✅ Correction request submitted!', AppColors.success);
      _loadMyCorrectionRequests();
    } catch (e) {
      _showSnack('❌ ${ApiService.getErrorMessage(e)}', AppColors.error);
    }
  }

  Future<void> _actionCorrectionRequest(
      int id, String action, String adminNote) async {
    try {
      await ApiService().patch(
        '${AppConstants.attendanceBase}/correction-requests/$id/action/',
        data: {'status': action, 'admin_note': adminNote},
      );
      _showSnack('✅ Request $action!', AppColors.success);
      _loadPendingCorrections();
    } catch (e) {
      _showSnack('❌ ${ApiService.getErrorMessage(e)}', AppColors.error);
    }
  }

  void _showCorrectionRequestSheet() {
    final dateCtrl = TextEditingController();
    final checkInCtrl = TextEditingController();
    final checkOutCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Iconsax.calendar_edit, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Request Attendance Correction',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
                'Submit a request if you missed attendance due to a technical issue.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: dateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Date *',
                hintText: 'e.g. 2081-03-15',
                prefixIcon: Icon(Iconsax.calendar_1),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  final nd = picked.toNepaliDateTime();
                  dateCtrl.text =
                      '${nd.year}-${nd.month.toString().padLeft(2, '0')}-${nd.day.toString().padLeft(2, '0')}';
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: checkInCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Check-in time',
                      hintText: 'HH:MM',
                      prefixIcon: Icon(Iconsax.login),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: checkOutCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Check-out time',
                      hintText: 'HH:MM',
                      prefixIcon: Icon(Iconsax.logout),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason *',
                hintText: 'Explain why the attendance was missed or incorrect',
                prefixIcon: Icon(Iconsax.message_text),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Iconsax.send_1),
                label: const Text('Submit Request'),
                onPressed: () {
                  if (dateCtrl.text.isEmpty || reasonCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Date and Reason are required.')));
                    return;
                  }
                  Navigator.pop(ctx);
                  _submitCorrectionRequest(
                    date: dateCtrl.text,
                    checkIn: checkInCtrl.text,
                    checkOut: checkOutCtrl.text,
                    reason: reasonCtrl.text,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );

      if (image == null) {
        setState(() => _isLoading = false);
        return;
      }

      final pos = await _getLocation();
      final formData = FormData.fromMap({
        'latitude': pos.latitude.toString(),
        'longitude': pos.longitude.toString(),
        'photo': MultipartFile.fromBytes(await image.readAsBytes(), filename: 'checkin.jpg'),
      });

      final res = await ApiService().uploadFile(AppConstants.checkIn, formData);
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
          .contains('not within the office radius')) {
        _showSnack(
            '⚠️ You need to be at the office to check in. Ask your admin to grant remote work permission.',
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
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 50,
      );

      if (image == null) {
        setState(() => _isLoading = false);
        return;
      }

      final pos = await _getLocation();
      final formData = FormData.fromMap({
        'latitude': pos.latitude.toString(),
        'longitude': pos.longitude.toString(),
        'photo': MultipartFile.fromBytes(await image.readAsBytes(), filename: 'checkout.jpg'),
      });

      final res = await ApiService().uploadFile(AppConstants.checkOut, formData);
      if (!mounted) return;
      setState(() {
        _isCheckedIn = false;
        _checkInTime = null;
        _lastAction = 'Checked out at ${res.data['check_out_time']}';
      });
      _showSnack('✅ Checked out successfully!', AppColors.success);
      await _loadStats();
      await _loadDailyHistory();
    } catch (e) {
      if (!mounted) return;
      final msg = ApiService.getErrorMessage(e);
      if (msg
          .toLowerCase()
          .contains('not within the office radius')) {
        _showSnack(
            '⚠️ You need to be at the office to check out. Ask your admin to grant remote work permission.',
            AppColors.warning);
      } else {
        _showSnack('❌ $msg', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLog(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Attendance Log'),
        content: const Text('Are you sure you want to delete this attendance record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiService().delete('${AppConstants.attendanceBase}/$id/');
      _showSnack('Attendance log deleted successfully', AppColors.success);
      _loadOrgLogs();
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to delete log: ${ApiService.getErrorMessage(e)}', AppColors.error);
      }
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
    ref.listen(nepaliDateProvider, (_, __) => _loadAll());
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
            isScrollable: true,
            tabs: const [
              Tab(text: 'Check In/Out'),
              Tab(text: 'All Staff Logs'),
              Tab(text: 'Remote Access'),
              Tab(text: 'Corrections'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _adminTabs,
          children: [
            _buildCheckInUI(),
            _buildOrgLogs(),
            _buildRemoteAccessTab(),
            _buildAdminCorrectionTab(),
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Iconsax.calendar_edit),
        label: const Text('Request Correction'),
        onPressed: _showCorrectionRequestSheet,
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
                color: context.surface,
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
                  if (!_hasRemotePermission!)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        final ctrl = TextEditingController();
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Request Remote Work', style: TextStyle(fontSize: 16)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('This will capture your current GPS location and send it to your Admin for approval.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: ctrl,
                                  decoration: const InputDecoration(labelText: 'Reason for remote work'),
                                  maxLines: 3,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _requestRemoteWork(ctrl.text);
                                },
                                child: const Text('Submit Request'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Request', style: TextStyle(fontSize: 12)),
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
            ...(_dailyHistory).map((log) => _AttendanceLogTile(log: log, onTap: () => _showLogDetails(log))),

          const SizedBox(height: 16),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Note: Office employees must be within 50 m of the office to check in/out. Employees with remote work permission approved by an admin can check in from anywhere.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12))),

          // ── My Correction Requests ─────────────────────────────────────────
          if (_myCorrectionRequests.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('My Correction Requests',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(height: 8),
            ..._myCorrectionRequests.map((req) => _CorrectionRequestTile(
                  req: req,
                  isAdmin: false,
                  onAction: null,
                )),
          ],

          // ── Live Location Map (Admin only) ───────────────────────────────
          if (ref.watch(currentUserProvider)?.canManage == true) ...[
            const SizedBox(height: 24),
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Live Location Overview',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 220,
                child: _currentPosition == null
                    ? Container(
                        decoration: BoxDecoration(
                          color: context.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Fetching location…',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : GoogleMap(
                        onMapCreated: (c) => _liveMapController = c,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          zoom: 16,
                        ),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        markers: {
                          Marker(
                            markerId: const MarkerId('you'),
                            position: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            infoWindow: const InfoWindow(title: 'You are here'),
                          ),
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _startLiveLocation,
                icon: const Icon(Icons.my_location, size: 14),
                label: const Text('Refresh Location',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ]),
      );

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
                if (log['history'] != null && (log['history'] as List).isNotEmpty) ...[
                  const Text("Session History", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate((log['history'] as List).length, (i) {
                    final h = log['history'][i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('Session ${i + 1} - In: ${formatTime(h['in']?.toString())} | Out: ${formatTime(h['out']?.toString())}', style: const TextStyle(fontSize: 14)),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
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
                                  style: TextStyle(color: AppColors.textSecondary)),
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
                                  style: TextStyle(color: AppColors.textSecondary)),
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
                      double? inLat = double.tryParse(
                          log['check_in_lat']?.toString() ?? '');
                      double? inLng = double.tryParse(
                          log['check_in_lng']?.toString() ?? '');
                      double? outLat = double.tryParse(
                          log['check_out_lat']?.toString() ?? '');
                      double? outLng = double.tryParse(
                          log['check_out_lng']?.toString() ?? '');

                      if (inLat == null && outLat == null) {
                        return Container(
                          decoration: BoxDecoration(
                            color: context.border.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.border),
                          ),
                          child: const Center(
                              child: Text(
                                  "No location data recorded for this attendance.")),
                        );
                      }

                      final markers = <Marker>{};
                      LatLng center = LatLng(
                        inLat ?? outLat!,
                        inLng ?? outLng!,
                      );

                      if (inLat != null && inLng != null) {
                        markers.add(Marker(
                          markerId: const MarkerId('checkin'),
                          position: LatLng(inLat, inLng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueGreen),
                          infoWindow: const InfoWindow(
                              title: '✅ Check-In Location'),
                        ));
                      }
                      if (outLat != null && outLng != null) {
                        markers.add(Marker(
                          markerId: const MarkerId('checkout'),
                          position: LatLng(outLat, outLng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueRed),
                          infoWindow: const InfoWindow(
                              title: '🚪 Check-Out Location'),
                        ));
                        // Correctly average the two pin coordinates for the camera center
                        final centerLat = ((inLat ?? outLat) + outLat) / 2;
                        final centerLng = ((inLng ?? outLng) + outLng) / 2;
                        center = LatLng(centerLat, centerLng);
                      }

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: center,
                            zoom: 15,
                          ),
                          markers: markers,
                          zoomControlsEnabled: true,
                          myLocationButtonEnabled: false,
                        ),
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

  Widget _buildOrgLogs() => _orgLogsLoading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _loadOrgLogs,
          child: _orgLogs.isEmpty
              ? const Center(
                  child: Text('No attendance logs found.',
                      style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: _orgLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _AttendanceLogTile(
                          log: _orgLogs[i], 
                          showName: true, 
                          onDelete: () => _deleteLog(_orgLogs[i]['id']),
                          onTap: () => _showLogDetails(_orgLogs[i]),
                      ),
                ),
        );

  Widget _buildRemoteAccessTab() => _remoteLoading
      ? const Center(child: CircularProgressIndicator())
      : RefreshIndicator(
          onRefresh: _loadRemoteList,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_pendingRemoteRequests.isNotEmpty) ...[
                  const Text('Pending Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 12),
                  ..._pendingRemoteRequests.map((req) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(req['employee_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Requested on: ${_formatRemoteDate(req['created_at']?.toString())}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Reason: ${req['reason']}', style: const TextStyle(fontSize: 14)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => _actionRemoteRequest(req['id'], 'rejected'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.redAccent),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => _actionRemoteRequest(req['id'], 'approved'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                ],
                const Text('All Employees', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (_remoteEmployees.isEmpty)
                  const Center(child: Text('No employees found.', style: TextStyle(color: AppColors.textSecondary)))
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                                  .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              hasPermission
                                  ? Iconsax.location_tick
                                  : Iconsax.location_cross,
                              color: hasPermission
                                  ? AppColors.success
                                  : AppColors.textSecondary,
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
              ],
            ),
          ),
        );

  // ── Admin Corrections Tab ────────────────────────────────────────────────────
  Widget _buildAdminCorrectionTab() {
    if (_correctionLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pendingCorrectionRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.calendar_tick, size: 56, color: AppColors.textSecondary),
            SizedBox(height: 12),
            Text('No pending correction requests',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingCorrectionRequests.length,
      itemBuilder: (ctx, i) {
        final req = _pendingCorrectionRequests[i];
        return _CorrectionRequestTile(
          req: req,
          isAdmin: true,
          onAction: (action, note) =>
              _actionCorrectionRequest(req['id'] as int, action, note),
        );
      },
    );
  }
}


class _AttendanceLogTile extends StatelessWidget {
  final Map log;
  final bool showName;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  const _AttendanceLogTile({required this.log, this.showName = false, this.onDelete, this.onTap});

  @override
  Widget build(BuildContext context) {
    final checkedIn = log['check_in_time'] != null;
    final checkedOut = log['check_out_time'] != null;
    final isRemote = log['is_remote'] == true;
    final hours = log['total_hours'] ?? 0;

    String formatTime(String? t) {
      if (t == null || t.isEmpty) return '-';
      return t.split('.')[0];
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                    Text('In: ${formatTime(log['check_in_time']?.toString())}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.success)),
                  if (checkedIn && checkedOut)
                    const Text('  →  ',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  if (checkedOut)
                    Text('Out: ${formatTime(log['check_out_time']?.toString())}',
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
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: onDelete,
            ),
        ]),
        ),
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


class _CorrectionRequestTile extends StatelessWidget {
  final Map req;
  final bool isAdmin;
  final void Function(String action, String adminNote)? onAction;

  const _CorrectionRequestTile({
    required this.req,
    required this.isAdmin,
    required this.onAction,
  });

  Color _statusColor(String? s) {
    switch (s) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = req['status'] as String? ?? 'pending';
    final noteCtrl = TextEditingController();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (isAdmin)
                  Text(req['employee_name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Date: ${req['requested_date'] ?? '-'}',
                    style: const TextStyle(fontSize: 13)),
                if (req['requested_check_in'] != null)
                  Text(
                      'In: ${req['requested_check_in']}  Out: ${req['requested_check_out'] ?? '-'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _statusColor(status)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text('Reason: ${req['reason'] ?? '-'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (req['admin_note'] != null && (req['admin_note'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Admin note: ${req['admin_note']}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic)),
            ),
          if (isAdmin && status == 'pending' && onAction != null) ...[ 
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Admin note (optional)',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  onPressed: () => onAction!('rejected', noteCtrl.text),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  onPressed: () => onAction!('approved', noteCtrl.text),
                ),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}





