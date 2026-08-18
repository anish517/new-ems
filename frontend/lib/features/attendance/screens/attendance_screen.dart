import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:async';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/providers/date_provider.dart';
import 'employee_attendance_logs_screen.dart';
import '../../../shared/widgets/responsive_grid_list.dart';
import '../../../shared/widgets/nepali_date_picker.dart';

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
  return NepaliDateFormat('dd MMMM yyyy').format(dt);
}

String _formatRemoteDate(String? isoString) {
  if (isoString == null) return 'N/A';
  try {
    final nd = DateTime.parse(isoString).toNepaliDateTime();
    return '${nd.year}-${nd.month.toString().padLeft(2, '0')}-${nd.day.toString().padLeft(2, '0')} B.S.';
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
  List _employees = [];
  bool _employeesLoading = false;
  String _employeeSearch = '';
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

  int _selectedAdminTab = 0;
  Timer? _autoActionTimer;
  bool _autoInFlight = false;
  bool _hasPromptedAutoAttendance = true; // start true so we don't auto-prompt before data loads

  @override
  void initState() {
    super.initState();
    _adminTabs = TabController(length: 4, vsync: this);
    _adminTabs.addListener(() {
      if (_adminTabs.indexIsChanging || _adminTabs.index != _selectedAdminTab) {
        if (mounted) setState(() => _selectedAdminTab = _adminTabs.index);
      }
    });
    WidgetsBinding.instance.addObserver(this);
    _loadAll().then((_) {
      _hasPromptedAutoAttendance = false;
      _attemptAutoAttendance();
    });
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
      String timeStr = _checkInTime!.trim().toUpperCase();
      bool isPM = timeStr.contains('PM');
      bool isAM = timeStr.contains('AM');

      timeStr = timeStr.replaceAll(' AM', '').replaceAll(' PM', '').replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = timeStr.split(':');

      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      int second = 0;
      if (parts.length > 2) {
        final secStr = parts[2].split('.')[0];
        second = int.parse(secStr);
      }

      if (isPM && hour < 12) hour += 12;
      if (isAM && hour == 12) hour = 0;

      final checkedInAt = DateTime(now.year, now.month, now.day, hour, minute, second);
      if (now.hour < 17) return false;
      return now.difference(checkedInAt) >= const Duration(hours: 6);
    } catch (_) {
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
      _loadEmployees();
      _loadRemoteList();
      _loadPendingCorrections();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTodayStatus() async {
    try {
      final res = await ApiService().get('${AppConstants.attendanceBase}/today-status/');
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
      final myLogs = all.where((a) => a['employee_id'] == user?.employeeId).toList();
      setState(() => _dailyHistory = myLogs);
    } catch (_) {}
  }

  Future<void> _loadEmployees() async {
    setState(() => _employeesLoading = true);
    try {
      final res = await ApiService().get('${AppConstants.organizationBase}/employees/');
      if (mounted) {
        setState(() {
          _employees = res.data is List ? res.data : (res.data['results'] ?? []);
          _employeesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _employeesLoading = false);
    }
  }

  Future<void> _loadMyRemoteStatus() async {
    try {
      final res = await ApiService().get('${AppConstants.attendanceBase}/remote-work-permission/me/');
      if (mounted) {
        setState(() => _hasRemotePermission = res.data['has_remote_permission'] == true);
      }
    } catch (_) {}
  }

  Future<void> _loadRemoteList() async {
    setState(() => _remoteLoading = true);
    try {
      final res = await ApiService().get('${AppConstants.attendanceBase}/remote-work-permission/list/');
      final reqRes = await ApiService().get('${AppConstants.attendanceBase}/remote-requests/');
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

  Future<void> _loadMyCorrectionRequests() async {
    try {
      final res = await ApiService().get('${AppConstants.attendanceBase}/correction-requests/');
      if (mounted) {
        setState(() => _myCorrectionRequests = res.data is List ? res.data : (res.data['results'] ?? []));
      }
    } catch (_) {}
  }

  Future<void> _loadPendingCorrections() async {
    setState(() => _correctionLoading = true);
    try {
      final res = await ApiService().get('${AppConstants.attendanceBase}/correction-requests/?status=pending');
      if (mounted) {
        setState(() {
          _pendingCorrectionRequests = res.data is List ? res.data : (res.data['results'] ?? []);
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

  Future<void> _actionCorrectionRequest(int id, String action, String adminNote) async {
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

  void _showCorrectionRequestSheet({String? initialDate, String? initialCheckIn, String? initialCheckOut}) {
    final dateCtrl = TextEditingController(text: initialDate ?? '');
    final checkInCtrl = TextEditingController(text: initialCheckIn ?? '');
    final checkOutCtrl = TextEditingController(text: initialCheckOut ?? '');
    final reasonCtrl = TextEditingController();
    final isMobile = MediaQuery.of(context).size.width < 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 18 : 24,
          20,
          isMobile ? 18 : 24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                    child: const Icon(Iconsax.calendar_edit, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Request Attendance Correction',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(icon: const Icon(Iconsax.close_circle, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Submit a request if you missed clocking in/out due to technical or network issues.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Target Date (B.S.) *',
                  hintText: 'Select Nepali date',
                  prefixIcon: Icon(Iconsax.calendar_1, size: 18),
                ),
                onTap: () async {
                  final picked = await showDialog<NepaliDateTime>(
                    context: ctx,
                    builder: (dialogCtx) => NepaliDatePickerDialog(
                      title: 'Select Attendance Date',
                      initial: NepaliDateTime.now(),
                    ),
                  );
                  if (picked != null) {
                    dateCtrl.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: checkInCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Check-In Time',
                        hintText: 'e.g. 10:00 AM',
                        prefixIcon: Icon(Iconsax.login, size: 18),
                        suffixIcon: Icon(Iconsax.clock, size: 16),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: const TimeOfDay(hour: 10, minute: 0),
                        );
                        if (picked != null) {
                          checkInCtrl.text =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: checkOutCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Check-Out Time',
                        hintText: 'e.g. 05:30 PM (17:30)',
                        prefixIcon: Icon(Iconsax.logout, size: 18),
                        suffixIcon: Icon(Iconsax.clock, size: 16),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: const TimeOfDay(hour: 17, minute: 30),
                        );
                        if (picked != null) {
                          checkOutCtrl.text =
                              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}:00';
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason & Remarks *',
                  hintText: 'Explain why attendance was missed or requires correction...',
                  prefixIcon: Icon(Iconsax.note_text, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Iconsax.send_1, size: 18),
                label: const Text('Submit Correction Request', style: TextStyle(fontWeight: FontWeight.w800)),
                onPressed: () {
                  if (dateCtrl.text.isEmpty || reasonCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Date and Reason are required.'), backgroundColor: AppColors.error),
                    );
                    return;
                  }
                  String inVal = checkInCtrl.text.trim();
                  String outVal = checkOutCtrl.text.trim();

                  // Smart auto-normalization if user typed 12-hour format manually
                  if (inVal.isNotEmpty && outVal.isNotEmpty) {
                    try {
                      final inParts = inVal.split(':').map(int.parse).toList();
                      final outParts = outVal.split(':').map(int.parse).toList();
                      if (outParts[0] < inParts[0] && outParts[0] < 12 && inParts[0] >= 8) {
                        outVal = '${(outParts[0] + 12).toString().padLeft(2, '0')}:${outParts.length > 1 ? outParts[1].toString().padLeft(2, '0') : '00'}:00';
                      }
                    } catch (_) {}
                  }

                  Navigator.pop(ctx);
                  _submitCorrectionRequest(
                    date: dateCtrl.text,
                    checkIn: inVal,
                    checkOut: outVal,
                    reason: reasonCtrl.text,
                  );
                },
              ),
            ],
          ),
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
      throw Exception('Location permission permanently denied. Please enable it in browser/system settings.');
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
        title: const Text('Confirm Check In'),
        content: const Text('Ready to capture verification selfie and clock in?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Proceed', style: TextStyle(color: Colors.white)),
          ),
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
      if (msg.toLowerCase().contains('cannot check in again') || msg.toLowerCase().contains('without checking out')) {
        _showSnack('⚠️ You are already checked in. Please check out first.', AppColors.warning);
      } else if (msg.toLowerCase().contains('not within the office radius')) {
        _showSnack(
          '⚠️ You must be within the office GPS geofence. Request remote permission from your admin if working remotely.',
          AppColors.warning,
        );
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
        title: const Text('Confirm Check Out'),
        content: const Text('Confirm you want to clock out for today?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check Out', style: TextStyle(color: Colors.white)),
          ),
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
      if (msg.toLowerCase().contains('not within the office radius')) {
        _showSnack(
          '⚠️ You need to be within office geofence to check out or have approved remote status.',
          AppColors.warning,
        );
      } else {
        _showSnack('❌ $msg', AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      _showSnack('✅ Office Location geofence configured successfully!', AppColors.success);
    } catch (e) {
      _showSnack('❌ Failed to set office location: ${ApiService.getErrorMessage(e)}', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadAll());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 16),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top Header Card ──────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isMobile ? 14 : 20),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(Iconsax.clock, color: Color(0xFF10B981), size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Attendance & Geofencing',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.4,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (_isCheckedIn ? AppColors.success : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _isCheckedIn ? '● Checked In' : '● Not Checked In',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: _isCheckedIn ? AppColors.success : const Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      const Text(
                                        'High-accuracy GPS verification & daily worklogs',
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _showCorrectionRequestSheet(),
                                  icon: const Icon(Iconsax.calendar_edit, size: 16),
                                  label: const Text('Correction Request', style: TextStyle(fontWeight: FontWeight.w700)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isAdmin) ...[
                                  IconButton(
                                    icon: const Icon(Iconsax.location_add, size: 20),
                                    tooltip: 'Set Office Coordinates to Current GPS',
                                    onPressed: _isLoading ? null : _setOfficeLocation,
                                    style: IconButton.styleFrom(
                                      backgroundColor: context.card,
                                      side: BorderSide(color: context.border),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                IconButton(
                                  icon: const Icon(Iconsax.refresh, size: 20),
                                  tooltip: 'Refresh Status',
                                  onPressed: _loadAll,
                                  style: IconButton.styleFrom(
                                    backgroundColor: context.card,
                                    side: BorderSide(color: context.border),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Iconsax.clock, color: Color(0xFF10B981), size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Attendance & Geofencing',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (_isCheckedIn ? AppColors.success : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _isCheckedIn ? '● Checked In' : '● Not Checked In',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _isCheckedIn ? AppColors.success : const Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'High-accuracy GPS verification & daily worklogs',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _showCorrectionRequestSheet(),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary, width: 1.2),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Iconsax.calendar_edit, size: 16, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Text(
                                        'Correction Request',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isAdmin) ...[
                              Container(
                                decoration: BoxDecoration(
                                  color: context.card,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.border),
                                ),
                                child: IconButton(
                                  icon: const Icon(Iconsax.location_add, size: 20),
                                  tooltip: 'Set Office Coordinates to Current GPS',
                                  onPressed: _isLoading ? null : _setOfficeLocation,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.border),
                              ),
                              child: IconButton(
                                icon: const Icon(Iconsax.refresh, size: 20),
                                tooltip: 'Refresh Status',
                                onPressed: _loadAll,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 20),

                // ── Tab Switcher for Admin / Views ───────────────────────────
                if (isAdmin) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.border),
                    ),
                    child: TabBar(
                      controller: _adminTabs,
                      isScrollable: true,
                      onTap: (idx) => setState(() => _selectedAdminTab = idx),
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      tabs: [
                        const Tab(text: 'My Check-In Hub'),
                        Tab(text: 'Staff Logs (${_employees.length})'),
                        Tab(text: 'Remote Access (${_pendingRemoteRequests.length} Pending)'),
                        Tab(text: 'Corrections (${_pendingCorrectionRequests.length})'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedAdminTab == 0) _buildCheckInUI(isMobile)
                  else if (_selectedAdminTab == 1) _buildEmployeeGrid()
                  else if (_selectedAdminTab == 2) _buildRemoteAccessTab()
                  else if (_selectedAdminTab == 3) _buildAdminCorrectionTab(),
                ] else
                  _buildCheckInUI(isMobile),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInUI(bool isMobile) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KPI Stats Row
          if (_stats != null) ...[
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    'Hours Worked',
                    '${_stats!['total_working_hour']}h',
                    Iconsax.timer_1,
                    AppColors.primary,
                    isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                Expanded(
                  child: _StatBox(
                    'Days Present',
                    '${_stats!['total_no_of_days_present']} Days',
                    Iconsax.calendar_tick,
                    AppColors.success,
                    isMobile,
                  ),
                ),
                SizedBox(width: isMobile ? 6 : 12),
                Expanded(
                  child: _StatBox(
                    'Remaining Target',
                    '${_stats!['remaining_working_hour']}h',
                    Iconsax.clock,
                    const Color(0xFFF59E0B),
                    isMobile,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // Interactive Check-In Status Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isCheckedIn
                    ? [const Color(0xFF10B981), const Color(0xFF047857)]
                    : [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_isCheckedIn ? const Color(0xFF10B981) : AppColors.primary).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isCheckedIn ? Iconsax.tick_circle : Iconsax.clock,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _isCheckedIn ? 'Currently Clocked In' : 'Not Clocked In Today',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCheckedIn && _checkInTime != null
                      ? 'Check-In recorded at $_checkInTime'
                      : 'Ready to capture selfie verification and verify office geofence',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _isCheckedIn ? const Color(0xFF047857) : AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isLoading ? null : (_isCheckedIn ? _checkOut : _checkIn),
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(_isCheckedIn ? Iconsax.logout : Iconsax.login, size: 20),
                  label: _isLoading
                      ? const Text('Verifying location...', style: TextStyle(fontWeight: FontWeight.bold))
                      : Text(
                          _isCheckedIn ? 'Clock Out Now' : 'Take Selfie & Clock In',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                        ),
                ),
              ],
            ),
          ),

          if (_lastAction != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle, size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _lastAction!,
                      style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_hasRemotePermission != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_hasRemotePermission! ? AppColors.success : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_hasRemotePermission! ? AppColors.success : const Color(0xFFF59E0B)).withValues(alpha: 0.3),
                ),
              ),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _hasRemotePermission! ? Iconsax.location_tick : Iconsax.location_cross,
                              size: 18,
                              color: _hasRemotePermission! ? AppColors.success : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _hasRemotePermission!
                                    ? 'Remote work permission active — GPS checks bypassed.'
                                    : 'Standard in-office geofencing active (50m radius).',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _hasRemotePermission! ? AppColors.success : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!_hasRemotePermission!) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showCorrectionRequestSheet(),
                                icon: const Icon(Iconsax.calendar_edit, size: 14),
                                label: const Text('Correction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () {
                                  final ctrl = TextEditingController();
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Request Remote Work Approval'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'This will snapshot your current GPS location and submit a remote work authorization request to your admin.',
                                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 14),
                                          TextField(
                                            controller: ctrl,
                                            decoration: const InputDecoration(labelText: 'Reason for remote work *'),
                                            maxLines: 3,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (ctrl.text.trim().isEmpty) return;
                                            Navigator.pop(ctx);
                                            _requestRemoteWork(ctrl.text.trim());
                                          },
                                          child: const Text('Submit'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Request WFH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                _hasRemotePermission! ? Iconsax.location_tick : Iconsax.location_cross,
                                size: 18,
                                color: _hasRemotePermission! ? AppColors.success : const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _hasRemotePermission!
                                      ? 'Remote work permission active — GPS checks bypassed.'
                                      : 'Standard in-office geofencing active (50m radius).',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _hasRemotePermission! ? AppColors.success : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!_hasRemotePermission!) ...[
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showCorrectionRequestSheet(),
                                icon: const Icon(Iconsax.calendar_edit, size: 14),
                                label: const Text('Correction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              const SizedBox(width: 4),
                              TextButton(
                                onPressed: () {
                                  final ctrl = TextEditingController();
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Request Remote Work Approval'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'This will snapshot your current GPS location and submit a remote work authorization request to your admin.',
                                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(height: 14),
                                          TextField(
                                            controller: ctrl,
                                            decoration: const InputDecoration(labelText: 'Reason for remote work *'),
                                            maxLines: 3,
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                        ElevatedButton(
                                          onPressed: () {
                                            if (ctrl.text.trim().isEmpty) return;
                                            Navigator.pop(ctx);
                                            _requestRemoteWork(ctrl.text.trim());
                                          },
                                          child: const Text('Submit'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const Text('Request WFH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ],

          const SizedBox(height: 24),

          // Daily Session History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Attendance Logs',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_dailyHistory.length} Sessions Logged',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showCorrectionRequestSheet(),
                icon: const Icon(Iconsax.calendar_edit, size: 14),
                label: const Text('Request Correction', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_dailyHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.border),
              ),
              child: const Text('No attendance records logged for this period.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ..._dailyHistory.map((log) => _AttendanceLogTile(log: log, onTap: () => _showLogDetails(log))),

          // My Correction Requests
          if (_myCorrectionRequests.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Correction Requests',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.textPrimary),
                ),
                TextButton.icon(
                  onPressed: () => _showCorrectionRequestSheet(),
                  icon: const Icon(Iconsax.add, size: 14),
                  label: const Text('New Request', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._myCorrectionRequests.map((req) => _CorrectionRequestTile(req: req, isAdmin: false, onAction: null)),
          ] else ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Iconsax.calendar_edit, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Missed clock-in or have wrong logs?',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                        const Text(
                          'Submit an attendance correction request to your admin',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showCorrectionRequestSheet(),
                    child: const Text('Request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ],
      );

  void _showLogDetails(Map log) {
    String formatTime(String? t) {
      if (t == null || t.isEmpty) return '-';
      return t.split('.')[0];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Attendance Log: ${_formatDate(log['date']?.toString())}',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16.5, color: context.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Iconsax.close_circle, size: 20)),
                ],
              ),
              const SizedBox(height: 12),
              Divider(color: context.border),
              const SizedBox(height: 10),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Check-In: ${formatTime(log['check_in_time']?.toString())}',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Check-Out: ${formatTime(log['check_out_time']?.toString())}',
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (log['history'] != null && (log['history'] as List).isNotEmpty) ...[
                const Text('Multi-Session Timeline', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 8),
                ...List.generate((log['history'] as List).length, (i) {
                  final h = log['history'][i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Session #${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        Text('In: ${formatTime(h['in']?.toString())}  →  Out: ${formatTime(h['out']?.toString())}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 18),
              ],

              const Text('Selfie Verification Photos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: log['check_in_photo'] != null
                          ? Image.network(log['check_in_photo'], height: 160, fit: BoxFit.cover)
                          : Container(height: 120, color: context.card, alignment: Alignment.center, child: const Text('No Check-In Photo', style: TextStyle(fontSize: 11))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: log['check_out_photo'] != null
                          ? Image.network(log['check_out_photo'], height: 160, fit: BoxFit.cover)
                          : Container(height: 120, color: context.card, alignment: Alignment.center, child: const Text('No Check-Out Photo', style: TextStyle(fontSize: 11))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  final rawDate = log['date']?.toString();
                  String? dateStr;
                  if (rawDate != null) {
                    try {
                      if (rawDate.contains('T')) {
                        final nd = DateTime.parse(rawDate).toNepaliDateTime();
                        dateStr = '${nd.year}-${nd.month.toString().padLeft(2, '0')}-${nd.day.toString().padLeft(2, '0')}';
                      } else {
                        final nd = NepaliDateTime.parse(rawDate);
                        dateStr = '${nd.year}-${nd.month.toString().padLeft(2, '0')}-${nd.day.toString().padLeft(2, '0')}';
                      }
                    } catch (_) {
                      dateStr = rawDate.split('T')[0];
                    }
                  }
                  _showCorrectionRequestSheet(
                    initialDate: dateStr,
                    initialCheckIn: formatTime(log['check_in_time']?.toString()),
                    initialCheckOut: formatTime(log['check_out_time']?.toString()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Iconsax.calendar_edit, size: 16),
                label: const Text('Request Correction for this Date', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),

              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close Log Details'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeGrid() {
    if (_employeesLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final filtered = _employees.where((e) {
      final name = ('${e['user']?['first_name'] ?? ''} ${e['user']?['last_name'] ?? ''}').toLowerCase();
      return name.contains(_employeeSearch.toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TextField(
            onChanged: (v) => setState(() => _employeeSearch = v),
            decoration: InputDecoration(
              hintText: 'Search staff members by name…',
              prefixIcon: const Icon(Iconsax.search_normal, size: 20),
              suffixIcon: _employeeSearch.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Iconsax.close_circle, size: 18),
                      onPressed: () => setState(() => _employeeSearch = ''),
                    )
                  : null,
            ),
          ),
        ),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: const Text('No matching employees found.', style: TextStyle(color: AppColors.textSecondary)),
          )
        else
          ResponsiveGridList(
            minItemWidth: 260,
            spacing: 14,
            runSpacing: 14,
            scrollable: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final emp = filtered[i];
              final user = emp['user'] as Map? ?? {};
              final firstName = user['first_name'] ?? '';
              final lastName = user['last_name'] ?? '';
              final fullName = '$firstName $lastName'.trim().isEmpty ? 'Employee' : '$firstName $lastName'.trim();
              final avatar = user['profile_picture'] as String?;
              final empType = (emp['employee_type'] as String? ?? '').replaceAll('_', ' ');
              final empId = emp['id'] as int;

              return _EmployeeAttendanceCard(
                name: fullName,
                employeeType: empType,
                avatarUrl: avatar,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EmployeeAttendanceLogsScreen(
                      employeeId: empId,
                      employeeName: fullName,
                      avatarUrl: avatar,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRemoteAccessTab() {
    if (_remoteLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_pendingRemoteRequests.isNotEmpty) ...[
          Text('Pending Remote Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const SizedBox(height: 12),
          ..._pendingRemoteRequests.map((req) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(req['employee_name'] ?? 'Employee', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.textPrimary)),
                      Text('Requested: ${_formatRemoteDate(req['created_at']?.toString())}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Reason: "${req['reason']}"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _actionRemoteRequest(req['id'], 'rejected'),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error)),
                        child: const Text('Reject', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _actionRemoteRequest(req['id'], 'approved'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                        child: const Text('Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
        Text('All Staff Remote Geofence Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 12),
        if (_remoteEmployees.isEmpty)
          const Text('No employees found.', style: TextStyle(color: AppColors.textSecondary))
        else
          ..._remoteEmployees.map((e) {
            final hasPermission = e['has_remote_permission'] == true;
            final employeeId = e['employee_id'] as int;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (hasPermission ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasPermission ? Iconsax.location_tick : Iconsax.location_cross,
                      color: hasPermission ? AppColors.success : AppColors.textSecondary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e['employee_name'] ?? 'Staff Member', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.textPrimary)),
                        Text(hasPermission ? 'Remote work approved' : 'Standard in-office geofence', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  hasPermission
                      ? IconButton(
                          icon: const Icon(Iconsax.close_circle, color: AppColors.error, size: 20),
                          tooltip: 'Revoke remote permission',
                          onPressed: () => _removeRemoteLocation(employeeId),
                        )
                      : IconButton(
                          icon: const Icon(Iconsax.location_add, color: AppColors.primary, size: 20),
                          tooltip: 'Grant remote GPS location',
                          onPressed: () => _setRemoteLocation(employeeId),
                        ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAdminCorrectionTab() {
    if (_correctionLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    if (_pendingCorrectionRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border),
        ),
        child: const Text('No pending attendance correction requests.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Pending Correction Requests (${_pendingCorrectionRequests.length})',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
        ),
        const SizedBox(height: 12),
        ..._pendingCorrectionRequests.map(
          (req) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CorrectionRequestTile(
              req: req,
              isAdmin: true,
              onAction: (action, note) => _actionCorrectionRequest(req['id'] as int, action, note),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Employee Attendance Card ────────────────────────────────────────────────
class _EmployeeAttendanceCard extends StatelessWidget {
  final String name;
  final String employeeType;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _EmployeeAttendanceCard({
    required this.name,
    required this.employeeType,
    this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Text(initials, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.border),
                  ),
                  child: Text(
                    employeeType.isNotEmpty ? employeeType : 'Full Time',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Tap to view history →', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Attendance Log Tile ──────────────────────────────────────────────────────
class _AttendanceLogTile extends StatelessWidget {
  final Map log;
  final VoidCallback? onTap;
  const _AttendanceLogTile({required this.log, this.onTap});

  @override
  Widget build(BuildContext context) {
    final checkedIn = log['check_in_time'] != null;
    final checkedOut = log['check_out_time'] != null;
    final isRemote = log['is_remote'] == true;
    final double hours = ((log['total_hours'] ?? 0) as num).toDouble();

    String formatTime(String? t) {
      if (t == null || t.isEmpty) return '-';
      return t.split('.')[0];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (checkedIn ? AppColors.success : AppColors.error).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    checkedIn ? Iconsax.tick_circle : Iconsax.close_circle,
                    color: checkedIn ? AppColors.success : AppColors.error,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(log['date']?.toString()),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: context.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (checkedIn) ...[
                            Text('In: ${formatTime(log['check_in_time']?.toString())}', style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w700)),
                          ],
                          if (checkedIn && checkedOut) const Text('  →  ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          if (checkedOut) ...[
                            Text('Out: ${formatTime(log['check_out_time']?.toString())}', style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w700)),
                          ],
                          if (!checkedIn) ...[
                            const Text('Missed check-in', style: TextStyle(fontSize: 12, color: AppColors.error)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${hours.toStringAsFixed(1)}h', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    if (isRemote)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Remote', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool isTight;
  const _StatBox(this.label, this.value, this.icon, this.color, this.isTight);

  @override
  Widget build(BuildContext context) {
    if (isTight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: context.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CorrectionRequestTile extends StatefulWidget {
  final Map req;
  final bool isAdmin;
  final Future<void> Function(String action, String adminNote)? onAction;

  const _CorrectionRequestTile({
    required this.req,
    required this.isAdmin,
    required this.onAction,
  });

  @override
  State<_CorrectionRequestTile> createState() => _CorrectionRequestTileState();
}

class _CorrectionRequestTileState extends State<_CorrectionRequestTile> {
  late final TextEditingController _noteCtrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.req['admin_note']?.toString() ?? '');
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Color _statusColor(String? s) {
    switch (s?.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Future<void> _handleAction(String action) async {
    if (widget.onAction == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await widget.onAction!(action, _noteCtrl.text.trim());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.req['status'] as String? ?? 'pending').toLowerCase();
    final isPending = status == 'pending';
    final employeeName = widget.req['employee_name']?.toString() ?? 'Employee';
    final requestedDate = widget.req['requested_date']?.toString() ?? '-';
    final checkIn = widget.req['requested_check_in']?.toString();
    final checkOut = widget.req['requested_check_out']?.toString();
    final reason = widget.req['reason']?.toString() ?? '-';
    final adminNote = widget.req['admin_note']?.toString();
    final isDark = context.isDark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending ? const Color(0xFFF59E0B).withValues(alpha: 0.35) : context.border,
          width: isPending ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Employee Name & Status Badge ─────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isPending
                      ? Iconsax.clock
                      : (status == 'approved' ? Iconsax.tick_circle : Iconsax.close_circle),
                  color: _statusColor(status),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isAdmin)
                      Text(
                        employeeName,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.5, color: context.textPrimary),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Iconsax.calendar_1, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 5),
                        Text(
                          'Target Date: $requestedDate',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.textPrimary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _statusColor(status)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Requested Shift Times ─────────────────────────────────────────
          if (checkIn != null || checkOut != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Iconsax.login, size: 16, color: AppColors.success),
                        const SizedBox(width: 8),
                        Text(
                          'In: ${checkIn ?? '-'}',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 16, color: context.border),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Iconsax.logout, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Out: ${checkOut ?? '-'}',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Reason Bubble ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Iconsax.note_text, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                      color: context.textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Existing Admin Note (if reviewed) ────────────────────────────
          if (!isPending && adminNote != null && adminNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Iconsax.info_circle, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Admin note: $adminNote',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ],

          // ── Admin Action Panel (for Pending requests) ────────────────────
          if (widget.isAdmin && isPending && widget.onAction != null) ...[
            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              enabled: !_isProcessing,
              decoration: InputDecoration(
                labelText: 'Approval / Rejection Remark (Optional)',
                hintText: 'e.g. Approved due to network failure...',
                isDense: true,
                filled: true,
                fillColor: context.card,
                prefixIcon: const Icon(Iconsax.edit_2, size: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isProcessing ? null : () => _handleAction('rejected'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.close_circle, size: 18, color: Color(0xFFEF4444)),
                          SizedBox(width: 8),
                          Text(
                            'Reject Request',
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
                const SizedBox(width: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isProcessing ? null : () => _handleAction('approved'),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isProcessing)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                            )
                          else
                            const Icon(Iconsax.tick_circle, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _isProcessing ? 'Processing...' : 'Approve & Update Attendance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
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
        ],
      ),
    );
  }
}
