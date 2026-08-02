import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
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

class EmployeeAttendanceLogsScreen extends ConsumerStatefulWidget {
  final int employeeId;
  final String employeeName;
  final String? avatarUrl;

  const EmployeeAttendanceLogsScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
    this.avatarUrl,
  });

  @override
  ConsumerState<EmployeeAttendanceLogsScreen> createState() =>
      _EmployeeAttendanceLogsScreenState();
}

class _EmployeeAttendanceLogsScreenState
    extends ConsumerState<EmployeeAttendanceLogsScreen> {
  List _logs = [];
  bool _loading = true;
  int _daysPresent = 0;
  double _totalHours = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get(
        '${AppConstants.attendanceBase}/list/',
        queryParams: {'employee': widget.employeeId},
      );
      if (!mounted) return;
      final all = res.data is List
          ? res.data as List
          : (res.data['results'] ?? []) as List;

      final days = all.where((l) => l['check_in_time'] != null).length;
      final hours = all.fold<double>(
          0, (sum, l) => sum + ((l['total_hours'] ?? 0) as num).toDouble());

      setState(() {
        _logs = all;
        _daysPresent = days;
        _totalHours = hours;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log['history'] != null &&
                    (log['history'] as List).isNotEmpty) ...[
                  const Text('Session History',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate((log['history'] as List).length, (i) {
                    final h = log['history'][i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                          'Session ${i + 1} - In: ${formatTime(h['in']?.toString())} | Out: ${formatTime(h['out']?.toString())}',
                          style: const TextStyle(fontSize: 14)),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
                const Text('Photos',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Check-In'),
                          const SizedBox(height: 4),
                          log['check_in_photo'] != null
                              ? Image.network(log['check_in_photo'],
                                  height: 150, fit: BoxFit.cover)
                              : const Text('No photo',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        children: [
                          const Text('Check-Out'),
                          const SizedBox(height: 4),
                          log['check_out_photo'] != null
                              ? Image.network(log['check_out_photo'],
                                  height: 150, fit: BoxFit.cover)
                              : const Text('No photo',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text('Map View',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 250,
                  child: Builder(builder: (context) {
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
                                'No location data recorded for this attendance.')),
                      );
                    }

                    final markers = <Marker>{};
                    LatLng center = LatLng(inLat ?? outLat!, inLng ?? outLng!);

                    if (inLat != null && inLng != null) {
                      markers.add(Marker(
                        markerId: const MarkerId('checkin'),
                        position: LatLng(inLat, inLng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen),
                        infoWindow:
                            const InfoWindow(title: '✅ Check-In Location'),
                      ));
                    }
                    if (outLat != null && outLng != null) {
                      markers.add(Marker(
                        markerId: const MarkerId('checkout'),
                        position: LatLng(outLat, outLng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed),
                        infoWindow:
                            const InfoWindow(title: '🚪 Check-Out Location'),
                      ));
                      final centerLat =
                          ((inLat ?? outLat) + outLat) / 2;
                      final centerLng =
                          ((inLng ?? outLng) + outLng) / 2;
                      center = LatLng(centerLat, centerLng);
                    }

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: GoogleMap(
                        initialCameraPosition:
                            CameraPosition(target: center, zoom: 15),
                        markers: markers,
                        zoomControlsEnabled: true,
                        myLocationButtonEnabled: false,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadLogs());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.employeeName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Attendance Logs',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Summary Banner ─────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primaryDark,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage: widget.avatarUrl != null
                            ? NetworkImage(widget.avatarUrl!)
                            : null,
                        child: widget.avatarUrl == null
                            ? Text(
                                widget.employeeName.isNotEmpty
                                    ? widget.employeeName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.employeeName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16)),
                            const SizedBox(height: 6),
                            Row(children: [
                              _SummaryChip(
                                  icon: Iconsax.calendar_tick,
                                  label: '$_daysPresent days present'),
                              const SizedBox(width: 10),
                              _SummaryChip(
                                  icon: Iconsax.clock,
                                  label:
                                      '${_totalHours.toStringAsFixed(2)}h worked'),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Logs List ──────────────────────────────────────────────
                Expanded(
                  child: _logs.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.calendar_remove,
                                  size: 64, color: AppColors.textSecondary),
                              SizedBox(height: 12),
                              Text('No attendance records found.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 16)),
                              SizedBox(height: 4),
                              Text('Try changing the month filter.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLogs,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final log = _logs[i];
                              return _AttendanceLogTile(
                                log: log,
                                onTap: () => _showLogDetails(log),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Mini chip for summary banner ────────────────────────────────────────────
class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ]),
      );
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

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  Text(_formatDate(log['date']?.toString()),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Wrap(children: [
                    if (checkedIn)
                      Text(
                          'In: ${formatTime(log['check_in_time']?.toString())}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.success)),
                    if (checkedIn && checkedOut)
                      const Text('  →  ',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    if (checkedOut)
                      Text(
                          'Out: ${formatTime(log['check_out_time']?.toString())}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.error)),
                    if (!checkedIn)
                      const Text('Not checked in',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.error)),
                  ]),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${hours.toStringAsFixed(2)}h',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              if (isRemote)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Remote',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.accent)),
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}
