import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _isCheckedIn  = false;
  bool _isLoading    = false;
  String? _checkInTime;
  String? _lastAction;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user?.employeeId == null) return;
      final res = await ApiService().get(
        '${AppConstants.attendanceBase}/total-working-hour/${user!.employeeId}/',
      );
      setState(() => _stats = res.data);
    } catch (_) {}
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw Exception('Permission denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _checkIn() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _getLocation();
      final res = await ApiService().post(AppConstants.checkIn, data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      setState(() {
        _isCheckedIn = true;
        _checkInTime = res.data['check_in_time'];
        _lastAction  = 'Checked in at $_checkInTime';
      });
      _showSnack('✅ Checked in successfully!', AppColors.success);
    } catch (e) {
      _showSnack('❌ ${e.toString()}', AppColors.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _getLocation();
      final res = await ApiService().post(AppConstants.checkOut, data: {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      setState(() {
        _isCheckedIn = false;
        _lastAction  = 'Checked out at ${res.data['check_in_time']}';
      });
      _showSnack('✅ Checked out successfully!', AppColors.success);
      await _loadStats();
    } catch (e) {
      _showSnack('❌ ${e.toString()}', AppColors.error);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Stats row
          if (_stats != null) ...[
            Row(children: [
              Expanded(child: _StatBox('Hours Worked',
                  '${_stats!['total_working_hour']}h', AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _StatBox('Days Present',
                  '${_stats!['total_no_of_days_present']}', AppColors.success)),
              const SizedBox(width: 12),
              Expanded(child: _StatBox('Remaining',
                  '${_stats!['remaining_working_hour']}h', AppColors.warning)),
            ]),
            const SizedBox(height: 24),
          ],

          // Check-in / Check-out button
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
                color: Colors.white, size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                _isCheckedIn ? 'Currently Checked In' : 'Not Checked In',
                style: const TextStyle(color: Colors.white, fontSize: 18,
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
                  foregroundColor: _isCheckedIn ? AppColors.success : AppColors.primary,
                  minimumSize: const Size(200, 48),
                ),
                onPressed: _isLoading ? null : (_isCheckedIn ? _checkOut : _checkIn),
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(_isCheckedIn ? Iconsax.logout : Iconsax.login),
                label: Text(_isCheckedIn ? 'Check Out' : 'Check In',
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
                const Icon(Iconsax.info_circle, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(_lastAction!, style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ),
          ],

          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Note: Check-in requires you to be within\n500m of your office or approved remote location.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
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
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          textAlign: TextAlign.center),
    ]),
  );
}
