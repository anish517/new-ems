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
  return NepaliDateFormat('dd MMMM yyyy').format(dt);
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
  ConsumerState<EmployeeAttendanceLogsScreen> createState() => _EmployeeAttendanceLogsScreenState();
}

class _EmployeeAttendanceLogsScreenState extends ConsumerState<EmployeeAttendanceLogsScreen> {
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
      final all = res.data is List ? res.data as List : (res.data['results'] ?? []) as List;

      final days = all.where((l) => l['check_in_time'] != null).length;
      final hours = all.fold<double>(0, (sum, l) => sum + ((l['total_hours'] ?? 0) as num).toDouble());

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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attendance Log: ${_formatDate(log['date']?.toString())}',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: context.textPrimary),
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
                const Text('Multi-Session Breakdown', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
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
              const SizedBox(height: 18),

              const Text('GPS Geolocation Map View', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
              const SizedBox(height: 10),
              SizedBox(
                height: 220,
                child: Builder(
                  builder: (context) {
                    double? inLat = double.tryParse(log['check_in_lat']?.toString() ?? '');
                    double? inLng = double.tryParse(log['check_in_lng']?.toString() ?? '');
                    double? outLat = double.tryParse(log['check_out_lat']?.toString() ?? '');
                    double? outLng = double.tryParse(log['check_out_lng']?.toString() ?? '');

                    if (inLat == null && outLat == null) {
                      return Container(
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.border),
                        ),
                        child: const Center(child: Text('No GPS coordinates recorded for this session.', style: TextStyle(fontSize: 12))),
                      );
                    }

                    final markers = <Marker>{};
                    LatLng center = LatLng(inLat ?? outLat!, inLng ?? outLng!);

                    if (inLat != null && inLng != null) {
                      markers.add(Marker(
                        markerId: const MarkerId('checkin'),
                        position: LatLng(inLat, inLng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                        infoWindow: const InfoWindow(title: 'Check-In Pin'),
                      ));
                    }
                    if (outLat != null && outLng != null) {
                      markers.add(Marker(
                        markerId: const MarkerId('checkout'),
                        position: LatLng(outLat, outLng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        infoWindow: const InfoWindow(title: 'Check-Out Pin'),
                      ));
                      final centerLat = ((inLat ?? outLat) + outLat) / 2;
                      final centerLng = ((inLng ?? outLng) + outLng) / 2;
                      center = LatLng(centerLat, centerLng);
                    }

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: center, zoom: 15),
                        markers: markers,
                        zoomControlsEnabled: true,
                        myLocationButtonEnabled: false,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

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

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadLogs());

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.employeeName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: context.textPrimary)),
            const Text('Individual Attendance Logs & Session History', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Iconsax.refresh, size: 20), onPressed: _loadLogs),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  // Summary Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          backgroundImage: widget.avatarUrl != null ? NetworkImage(widget.avatarUrl!) : null,
                          child: widget.avatarUrl == null
                              ? Text(
                                  widget.employeeName.isNotEmpty ? widget.employeeName[0].toUpperCase() : 'E',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.employeeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _SummaryChip(icon: Iconsax.calendar_tick, label: '$_daysPresent Days Present'),
                                  const SizedBox(width: 10),
                                  _SummaryChip(icon: Iconsax.clock, label: '${_totalHours.toStringAsFixed(1)}h Total Worked'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Chronological Attendance Records', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: context.textPrimary)),
                      Text('${_logs.length} Records', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_logs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.calendar_remove, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text('No attendance records found.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Adjust the fiscal month picker in the sidebar to review past records.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ..._logs.map((log) => _AttendanceLogTile(log: log, onTap: () => _showLogDetails(log))),
                ],
              ),
            ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SummaryChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

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
