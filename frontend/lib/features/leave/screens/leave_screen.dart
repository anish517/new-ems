import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/models/user_model.dart';
import '../../../core/providers/date_provider.dart';
import '../../../shared/widgets/nepali_date_picker.dart';

// ─── Date Formatter ────────────────────────────────────────────────────────
String _fmtDate(String? raw, {String? fallback}) {
  if (raw == null && fallback == null) return '';
  final s = raw ?? fallback!;
  try {
    if (s.contains('T')) {
      return NepaliDateFormat('dd MMMM yyyy')
          .format(DateTime.parse(s).toNepaliDateTime());
    }
    return NepaliDateFormat('dd MMMM yyyy').format(NepaliDateTime.parse(s));
  } catch (_) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }
}

// ─── Document / Image Previewer Helper ─────────────────────────────────────
void _viewLeaveDocument(BuildContext context, String? rawUrl,
    {String? title}) async {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No document URL available.')),
    );
    return;
  }

  // Normalize relative URLs into absolute URLs
  String url = rawUrl.trim();
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    final base = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;
    final path = url.startsWith('/') ? url : '/$url';
    url = '$base$path';
  }

  final cleanPath = url.toLowerCase().split('?').first;
  final bool isImage = cleanPath.endsWith('.png') ||
      cleanPath.endsWith('.jpg') ||
      cleanPath.endsWith('.jpeg') ||
      cleanPath.endsWith('.webp') ||
      cleanPath.endsWith('.gif') ||
      cleanPath.endsWith('.bmp');

  if (isImage) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title ?? 'Supporting Certificate / Image',
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
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                          tooltip: 'Open in external browser / Download',
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
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: ctx.card,
                      alignment: Alignment.center,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.image,
                                  size: 40, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              const Text('Failed to load image preview'),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(url);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  }
                                },
                                icon: const Icon(Iconsax.export_1, size: 14),
                                label: const Text('Open in Browser'),
                              ),
                            ],
                          ),
                        ),
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
  } else {
    try {
      final uri = Uri.parse(url);
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        await launchUrl(uri);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open document: $e')),
        );
      }
    }
  }
}

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});
  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen>
    with TickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _requests = [];
  Map<String, dynamic>? _balance;
  Map<String, dynamic>? _leaveSetting;
  List<dynamic> _pending = [];
  List<dynamic> _adminBalances = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final isAdmin = ref.read(currentUserProvider)?.canManage ?? false;
    _tabs = TabController(length: isAdmin ? 3 : 2, vsync: this);
    _loadLeaves();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadLeaves() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final user = ref.read(currentUserProvider);
      final isAdmin = user?.canManage ?? false;
      final nepaliDate = ref.read(nepaliDateProvider);

      // Fetch organization leave settings (Provision & Intern rules)
      try {
        final settingRes =
            await ApiService().get('${AppConstants.leaveBase}/settings/');
        if (mounted && settingRes.data is Map) {
          _leaveSetting = Map<String, dynamic>.from(settingRes.data);
        }
      } catch (_) {}

      // My leave requests (admins get all org requests, employees get only theirs)
      final res =
          await ApiService().get('${AppConstants.leaveBase}/leave-requests/');
      if (!mounted) return;
      final all = res.data is List
          ? res.data as List
          : ((res.data['results'] ?? res.data) as List);

      setState(() {
        _requests = all;
        if (isAdmin) {
          _pending = all
              .where(
                  (r) => r['is_approved'] != true && r['is_reviewed'] != true)
              .toList();
        }
      });

      if (isAdmin) {
        try {
          final summaryRes = await ApiService().get(
            '${AppConstants.leaveBase}/leave-summary/?nepali_year=${nepaliDate.year}&nepali_month=${nepaliDate.month}',
          );
          if (mounted) {
            setState(() => _adminBalances =
                summaryRes.data is List ? summaryRes.data as List : []);
          }
        } catch (_) {}
      }

      // Fetch personal leave balance
      if (user?.employeeId != null) {
        try {
          final balRes = await ApiService().get(
            '${AppConstants.leaveBase}/leave-balance/${user!.employeeId}/?nepali_year=${nepaliDate.year}&nepali_month=${nepaliDate.month}',
          );
          if (mounted) {
            setState(() => _balance = balRes.data as Map<String, dynamic>?);
          }
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _togglePolicySetting(String key, bool value) async {
    final updated = Map<String, dynamic>.from(_leaveSetting ?? {});
    updated[key] = value;
    setState(() => _leaveSetting = updated);
    try {
      final res = await ApiService().patch(
        '${AppConstants.leaveBase}/settings/',
        data: {
          'paid_leave_during_provision':
              updated['paid_leave_during_provision'] ?? false,
          'allow_intern_leave': updated['allow_intern_leave'] ?? true,
        },
      );
      if (mounted) {
        setState(() {
          _leaveSetting = Map<String, dynamic>.from(res.data);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text(
                    'Policy updated: ${key == 'allow_intern_leave' ? 'Allow Intern Leave' : 'Paid Leave in Provision'} is now ${value ? 'ON' : 'OFF'}'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _loadLeaves();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update leave policy: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showLeaveSettingsDialog(BuildContext context) {
    bool paidInProvision =
        _leaveSetting?['paid_leave_during_provision'] ?? false;
    bool allowIntern = _leaveSetting?['allow_intern_leave'] ?? true;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.setting_2,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave Policy Settings',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Configure organization leave rules',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ctx.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ctx.border),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      title: const Text('Paid Leave in Provision Period',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                        'If ON, staff in probation can take paid Casual & Sick leave. If OFF, only unpaid leave is permitted.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      value: paidInProvision,
                      activeThumbColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) =>
                          setModalState(() => paidInProvision = val),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: ctx.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: ctx.border),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: SwitchListTile(
                      title: const Text('Allow Intern Leave',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                        'If ON, intern employees can submit leave applications. If OFF, intern leave requests are blocked.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      value: allowIntern,
                      activeThumbColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setModalState(() => allowIntern = val),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setModalState(() => isSaving = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final res = await ApiService().patch(
                          '${AppConstants.leaveBase}/settings/',
                          data: {
                            'paid_leave_during_provision': paidInProvision,
                            'allow_intern_leave': allowIntern,
                          },
                        );
                        if (mounted) {
                          setState(() {
                            _leaveSetting =
                                Map<String, dynamic>.from(res.data);
                          });
                          if (ctx.mounted) Navigator.pop(ctx);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Row(
                                children: [
                                  Icon(Iconsax.tick_circle,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 10),
                                  Text(
                                      'Leave policy settings saved successfully!'),
                                ],
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Failed to save settings: ${ApiService.getErrorMessage(e)}'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setModalState(() => isSaving = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Policy',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLeaveApproval(int leaveId, String action,
      {String? rejectionReason}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final Map<String, dynamic> data = {'action': action};
      if (action == 'reject') {
        data['rejection_reason'] = rejectionReason ?? '';
        data['is_approved'] = false;
        data['is_reviewed'] = true;
      } else if (action == 'initial_approve') {
        data['is_initial_approved'] = true;
      } else if (action == 'final_approve') {
        data['is_approved'] = true;
        data['is_reviewed'] = true;
      }

      await ApiService().patch(
        '${AppConstants.leaveBase}/update/$leaveId/',
        data: data,
      );

      String msg = 'Leave request updated';
      Color bgColor = AppColors.success;
      if (action == 'initial_approve') {
        msg = 'Sick leave initial approved!';
        bgColor = const Color(0xFF6366F1);
      } else if (action == 'final_approve') {
        msg = 'Leave request approved successfully!';
        bgColor = AppColors.success;
      } else if (action == 'reject') {
        msg = 'Leave request rejected (reason recorded)';
        bgColor = AppColors.error;
      }

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                  action == 'reject'
                      ? Iconsax.close_circle
                      : Iconsax.tick_circle,
                  color: Colors.white,
                  size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: bgColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      _loadLeaves();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _promptRejectLeave(BuildContext context, int leaveId, String empName) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.close_circle,
                    color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Reject Leave Request',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Please provide a mandatory reason for rejecting $empName's leave application. This reason will be shared with the employee.",
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: reasonController,
                  maxLines: 3,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Rejection *',
                    hintText:
                        'e.g. Critical project deadline, staffing coverage...',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Iconsax.edit_2, size: 18),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'A rejection reason is required';
                    }
                    if (val.trim().length < 5) {
                      return 'Please enter at least 5 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateModal(() => isSubmitting = true);
                      Navigator.pop(ctx);
                      await _handleLeaveApproval(leaveId, 'reject',
                          rejectionReason: reasonController.text.trim());
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Confirm Rejection',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplyLeaveDialog(BuildContext context) async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final user = ref.read(currentUserProvider);

    if (isDesktop) {
      final res = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: context.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: _ApplyLeaveSheet(
              onSuccess: _loadLeaves,
              balance: _balance,
              existingRequests: _requests,
              leaveSetting: _leaveSetting,
              currentUser: user,
            ),
          ),
        ),
      );
      if (res == true) _loadLeaves();
    } else {
      final res = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _ApplyLeaveSheet(
          onSuccess: _loadLeaves,
          balance: _balance,
          existingRequests: _requests,
          leaveSetting: _leaveSetting,
          currentUser: user,
        ),
      );
      if (res == true) _loadLeaves();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadLeaves());
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.canManage ?? false;
    final isDark = context.isDark;

    final tabLength = isAdmin ? 3 : 2;
    if (!mounted) return const SizedBox.shrink();
    if (_tabs.length != tabLength) {
      _tabs.dispose();
      _tabs = TabController(length: tabLength, vsync: this);
    }

    // Filter requests
    final filtered = _requests.where((r) {
      if (_statusFilter == 'pending' &&
          (r['is_approved'] == true || r['is_reviewed'] == true)) {
        return false;
      }
      if (_statusFilter == 'approved' && r['is_approved'] != true) return false;
      if (_statusFilter == 'rejected' &&
          (r['is_approved'] == true || r['is_reviewed'] != true)) {
        return false;
      }

      if (_searchQuery.isEmpty) return true;
      final empName = (r['employee_name'] ?? '').toString().toLowerCase();
      final subject = (r['subject'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return empName.contains(query) || subject.contains(query);
    }).toList();

    // Compute metrics
    final totalRequests = _requests.length;
    final pendingCount = _requests
        .where((r) => r['is_approved'] != true && r['is_reviewed'] != true)
        .length;
    final approvedCount =
        _requests.where((r) => r['is_approved'] == true).length;

    // Leave Balances for employee (sum of all paid leave types: Casual, Sick, Paid Leave)
    final myBalances = (_balance?['leave_balances'] as List?) ?? [];
    double myPaidRemaining = 0;
    for (final lb in myBalances) {
      final typeName =
          lb['leave_type']?['name']?.toString().toLowerCase() ?? '';
      if (!typeName.contains('unpaid')) {
        final quota = (lb['quota'] as num? ?? 0).toDouble();
        final taken = (lb['leaves_taken'] as num? ?? 0).toDouble();
        myPaidRemaining += (quota - taken);
      }
    }
    if (myPaidRemaining < 0) myPaidRemaining = 0;

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showApplyLeaveDialog(context),
              backgroundColor: AppColors.primary,
              elevation: 6,
              icon: const Icon(Iconsax.calendar_add,
                  color: Colors.white, size: 20),
              label: const Text('Apply Leave',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLeaves,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              // ── Top Header Card ──────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrowHeader = constraints.maxWidth < 780;
                  final titleBlock = Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Iconsax.calendar_remove,
                            color: Color(0xFFF59E0B), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Leave & Attendance Portal',
                                  style: TextStyle(
                                    fontSize: isNarrowHeader ? 18 : 20,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isAdmin ? 'Admin View' : 'Employee View',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isAdmin
                                  ? 'Review leave applications, manage categories & staff quotas'
                                  : 'Request time-off, track leave balances & approvals',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final actionsBlock = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Iconsax.refresh, size: 18),
                        tooltip: 'Refresh Leaves',
                        onPressed: _loadLeaves,
                        style: IconButton.styleFrom(
                          backgroundColor: context.card,
                          side: BorderSide(color: context.border),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      if (isAdmin) ...[
                        OutlinedButton.icon(
                          onPressed: () => _showLeaveSettingsDialog(context),
                          icon: const Icon(Iconsax.setting_2,
                              size: 16, color: AppColors.primary),
                          label: const Text('Leave Policy',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                                color:
                                    AppColors.primary.withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showApplyLeaveDialog(context),
                          icon: const Icon(Iconsax.add,
                              size: 16, color: Colors.white),
                          label: const Text('New Leave',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ],
                  );

                  return Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isNarrowHeader ? 16 : 20),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isNarrowHeader
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              titleBlock,
                              const SizedBox(height: 14),
                              actionsBlock,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: titleBlock),
                              const SizedBox(width: 12),
                              actionsBlock,
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── KPI Summary Cards ─────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isVeryNarrow = constraints.maxWidth < 400;
                  final isNarrow = constraints.maxWidth < 600;
                  final count = isAdmin ? 3 : 4;
                  final spacing = isVeryNarrow ? 6.0 : 10.0;
                  final itemWidth =
                      (constraints.maxWidth - ((count - 1) * spacing)) / count;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _buildKpiCard(
                          isAdmin ? 'Total' : 'Total Applications',
                          '$totalRequests',
                          Iconsax.calendar_tick,
                          AppColors.primary,
                          isNarrow,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildKpiCard(
                          'Pending',
                          '$pendingCount',
                          Iconsax.timer_1,
                          const Color(0xFFF59E0B),
                          isNarrow,
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _buildKpiCard(
                          'Approved',
                          '$approvedCount',
                          Iconsax.tick_circle,
                          AppColors.success,
                          isNarrow,
                        ),
                      ),
                      if (!isAdmin)
                        SizedBox(
                          width: itemWidth,
                          child: _buildKpiCard(
                            'Paid Left',
                            '${myPaidRemaining.toStringAsFixed(1)}d',
                            Iconsax.wallet_3,
                            const Color(0xFF6366F1),
                            isNarrow,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Tab Bar Navigation ────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.border),
                ),
                child: TabBar(
                  controller: _tabs,
                  onTap: (idx) => setState(() {}),
                  isScrollable: false,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  padding: const EdgeInsets.all(4),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.document_text, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isAdmin ? 'All Requests' : 'My Requests',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAdmin)
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Iconsax.tick_circle, size: 16),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Approvals ($pendingCount)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.chart_2, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isAdmin ? 'Staff Quotas' : 'My Balance',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // ── Tab Content Views ─────────────────────────────────────────
              _isLoading
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                              color: AppColors.primary)))
                  : Builder(
                      builder: (context) {
                        final idx = _tabs.index;
                        if (idx == 0) {
                          return _buildRequestsListTab(filtered, isAdmin);
                        } else if (isAdmin && idx == 1) {
                          return _buildPendingApprovalsTab();
                        } else {
                          return isAdmin
                              ? _buildAdminBalancesTab()
                              : _LeaveBalanceTab(
                                  balance: _balance,
                                  existingRequests: _requests,
                                );
                        }
                      },
                    ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildRequestsListTab(List<dynamic> filtered, bool isAdmin) {
    return Column(
      children: [
        // Search & Status Filters
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.border),
          ),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: isAdmin
                      ? 'Search leaves by employee name or subject...'
                      : 'Search by leave subject...',
                  prefixIcon: const Icon(Iconsax.search_normal, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Iconsax.close_circle, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusFilterChip(
                        'all', 'All Statuses', AppColors.primary),
                    _buildStatusFilterChip(
                        'pending', '⏳ Pending', const Color(0xFFF59E0B)),
                    _buildStatusFilterChip(
                        'approved', '✅ Approved', AppColors.success),
                    _buildStatusFilterChip(
                        'rejected', '❌ Rejected', AppColors.error),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        filtered.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.border),
                ),
                child: const Text('No matching leave requests found.',
                    style: TextStyle(color: AppColors.textSecondary)),
              )
            : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _LeaveCard(filtered[i],
                    isAdmin: isAdmin, onRefresh: _loadLeaves),
              ),
      ],
    );
  }

  Widget _buildPendingApprovalsTab() {
    return _pending.isEmpty
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.tick_circle,
                      size: 40, color: AppColors.success),
                ),
                const SizedBox(height: 14),
                Text(
                  'All Pending Requests Reviewed!',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'There are no pending employee leave requests requiring approval.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _AdminLeaveCard(
              leave: _pending[i],
              onInitialApprove: () => _handleLeaveApproval(
                  _pending[i]['id'] as int, 'initial_approve'),
              onFinalApprove: () => _handleLeaveApproval(
                  _pending[i]['id'] as int, 'final_approve'),
              onReject: () => _promptRejectLeave(
                  context,
                  _pending[i]['id'] as int,
                  _pending[i]['employee_name'] ?? 'Employee'),
            ),
          );
  }

  Widget _buildAdminBalancesTab() {
    final allowIntern = _leaveSetting?['allow_intern_leave'] ?? true;
    final paidInProvision =
        _leaveSetting?['paid_leave_during_provision'] ?? false;

    final policyCard = Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
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
                child: const Icon(Iconsax.setting_2,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Organization Leave Policies',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Intern Leave Toggle Switch
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Allow Intern Leave',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (allowIntern
                                      ? AppColors.success
                                      : AppColors.error)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              allowIntern ? 'ON (Allowed)' : 'OFF (Blocked)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: allowIntern
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'When ON, interns can apply for leaves. When OFF, intern leave applications are blocked.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: allowIntern,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) =>
                      _togglePolicySetting('allow_intern_leave', val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Provision Leave Toggle Switch
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Paid Leave in Provision Period',
                            style: TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (paidInProvision
                                      ? AppColors.success
                                      : AppColors.warning)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              paidInProvision
                                  ? 'ON (Paid)'
                                  : 'OFF (Unpaid Only)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: paidInProvision
                                    ? AppColors.success
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'When ON, staff on probation can take paid leaves. When OFF, probation leave is unpaid.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: paidInProvision,
                  activeThumbColor: AppColors.primary,
                  onChanged: (val) =>
                      _togglePolicySetting('paid_leave_during_provision', val),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (_adminBalances.isEmpty) {
      return Column(
        children: [
          policyCard,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: const Text('No employee leave quotas configured.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      );
    }

    return Column(
      children: [
        policyCard,
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _adminBalances.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _AdminEmployeeBalanceCard(
            data: _adminBalances[i],
            onRefresh: _loadLeaves,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard(
      String title, String count, IconData icon, Color color, bool isTight) {
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
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  count,
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
                  title,
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
                  count,
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
                  title,
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

  Widget _buildStatusFilterChip(String key, String label, Color color) {
    final isSelected = _statusFilter.toLowerCase() == key.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _statusFilter = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : context.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? color : context.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Leave Card (My Leaves / All Leaves) ─────────────────────────────────────
class _LeaveCard extends StatelessWidget {
  final Map data;
  final bool isAdmin;
  final VoidCallback? onRefresh;
  const _LeaveCard(this.data, {required this.isAdmin, this.onRefresh});

  Color get _statusColor {
    if (data['is_approved'] == true) return AppColors.success;
    if (data['is_reviewed'] == true) return AppColors.error;
    if (data['is_initial_approved'] == true) return const Color(0xFF6366F1);
    return const Color(0xFFF59E0B);
  }

  String get _status {
    if (data['is_approved'] == true) return 'Approved';
    if (data['is_reviewed'] == true) return 'Rejected';
    if (data['is_initial_approved'] == true) return 'Initial Approved';
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final empName = data['employee_name'] ?? 'Employee';
    final typeName = data['leave_type_name'] ??
        (data['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave');
    final hasDoc = data['document_url'] != null &&
        data['document_url'].toString().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () =>
              _showLeaveDetails(context, data, isAdmin, onRefresh: onRefresh),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    data['is_approved'] == true
                        ? Iconsax.tick_circle
                        : data['is_reviewed'] == true
                            ? Iconsax.close_circle
                            : data['is_initial_approved'] == true
                                ? Iconsax.verify
                                : Iconsax.timer_1,
                    color: _statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['subject'] ?? 'Leave Application',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _status,
                              style: TextStyle(
                                  color: _statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Requested by: $empName',
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Iconsax.calendar,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  data['is_half_day'] == true
                                      ? '${_fmtDate(data['from_date']?.toString())} (Half Day • ${data['half_day_period'] ?? 'N/A'})'
                                      : '${_fmtDate(data['from_date']?.toString())} → ${_fmtDate(data['till_date']?.toString())}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          // Category Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              typeName,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          // Paid/Unpaid Chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: data['is_paid'] == true
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : const Color(0xFFF59E0B)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              data['is_paid'] == true ? 'Paid' : 'Unpaid',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: data['is_paid'] == true
                                    ? AppColors.success
                                    : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                          if (hasDoc)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Iconsax.paperclip_2,
                                      size: 10, color: Color(0xFF6366F1)),
                                  SizedBox(width: 3),
                                  Text('Doc',
                                      style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF6366F1))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Admin Leave Approval Card ───────────────────────────────────────────────
class _AdminLeaveCard extends StatelessWidget {
  final Map leave;
  final VoidCallback onInitialApprove, onFinalApprove, onReject;
  const _AdminLeaveCard({
    required this.leave,
    required this.onInitialApprove,
    required this.onFinalApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final empName = leave['employee_name'] ?? 'Unknown Employee';
    final typeName = leave['leave_type_name'] ??
        (leave['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave');
    final isSickLeave = leave['is_sick_leave'] == true ||
        typeName.toString().toLowerCase().contains('sick');
    final isInitialApproved = leave['is_initial_approved'] == true;
    final isDark = context.isDark;
    final hasDoc = leave['document_url'] != null &&
        leave['document_url'].toString().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSickLeave
              ? (isInitialApproved
                      ? const Color(0xFF6366F1)
                      : const Color(0xFFF59E0B))
                  .withValues(alpha: 0.5)
              : const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empName,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary),
                    ),
                    Text(
                      leave['subject'] ?? 'Leave Request',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isSickLeave && isInitialApproved
                          ? const Color(0xFF6366F1)
                          : const Color(0xFFF59E0B))
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isSickLeave
                      ? (isInitialApproved
                          ? '📋 Initial Approved'
                          : '⏳ Pending Initial')
                      : 'Pending Review',
                  style: TextStyle(
                    color: isSickLeave && isInitialApproved
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.border),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.calendar,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      leave['is_half_day'] == true
                          ? 'Half Day (${leave['half_day_period'] ?? 'N/A'}) • ${_fmtDate(leave['from_date']?.toString())}'
                          : '${_fmtDate(leave['from_date']?.toString())} → ${_fmtDate(leave['till_date']?.toString())} (${leave['no_days']} days)',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary),
                      overflow: TextOverflow.ellipsis,
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
                child: Text(
                  typeName,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: leave['is_paid'] == true
                      ? AppColors.success.withValues(alpha: 0.1)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  leave['is_paid'] == true ? 'Paid' : 'Unpaid',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: leave['is_paid'] == true
                        ? AppColors.success
                        : const Color(0xFFF59E0B),
                  ),
                ),
              ),
              if (hasDoc)
                InkWell(
                  onTap: () => _viewLeaveDocument(
                    context,
                    leave['document_url'],
                    title: '${leave['leave_type_name'] ?? 'Leave'} Certificate',
                  ),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Iconsax.document_download,
                            size: 12, color: Color(0xFF6366F1)),
                        SizedBox(width: 4),
                        Text('View Certificate',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1))),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (leave['remarks'] != null &&
              (leave['remarks'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: "${leave['remarks']}"',
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic),
            ),
          ],
          if (isSickLeave && isInitialApproved) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.info_circle,
                      size: 14, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Initial Approval by: ${leave['initial_approved_by_name'] ?? 'Admin'} • Ready for Final Approval',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6366F1)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Iconsax.close_circle,
                      size: 16, color: AppColors.error),
                  label: const Text('Reject Leave',
                      style: TextStyle(
                          color: AppColors.error, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isSickLeave && !isInitialApproved)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onInitialApprove,
                    icon: const Icon(Iconsax.verify,
                        size: 16, color: Colors.white),
                    label: const Text('Initial Approve',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onFinalApprove,
                    icon: const Icon(Iconsax.tick_circle,
                        size: 16, color: Colors.white),
                    label: Text(
                      isSickLeave ? 'Final Approve' : 'Approve Leave',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Leave Balance Tab ───────────────────────────────────────────────────────
class _LeaveBalanceTab extends StatelessWidget {
  final Map<String, dynamic>? balance;
  final List<dynamic> existingRequests;
  const _LeaveBalanceTab({this.balance, required this.existingRequests});

  @override
  Widget build(BuildContext context) {
    if (balance == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border),
        ),
        child: const Text('Leave balance information not available',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final leaveBalances = (balance!['leave_balances'] as List?) ?? [];

    // Compute totals for paid leave types (Casual, Sick)
    double totalTaken = 0;
    double totalQuota = 0;
    double totalAvailableThisMonth = 0;
    for (final lb in leaveBalances) {
      final typeName =
          lb['leave_type']?['name']?.toString().toLowerCase() ?? '';
      if (!typeName.contains('unpaid')) {
        totalTaken += (lb['paid_taken'] as num? ?? lb['leaves_taken'] as num? ?? 0).toDouble();
        totalQuota += (lb['quota'] as num? ?? 0).toDouble();
        totalAvailableThisMonth += (lb['available_this_month'] as num? ?? (totalQuota - totalTaken)).toDouble();
      }
    }
    final remaining = (totalQuota - totalTaken).clamp(0, totalQuota);

    // Pending unreviewed requests days
    final pendingRequests = existingRequests
        .where((r) => r['is_approved'] != true && r['is_reviewed'] != true)
        .toList();
    final pendingDays = pendingRequests.fold<double>(
        0, (sum, r) => sum + ((r['no_days'] as num?)?.toDouble() ?? 0.0));

    return Column(
      children: [
        // Summary Hero Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.calendar_tick, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text('Available Leave This Month',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${totalAvailableThisMonth.toStringAsFixed(1)} Days Available',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalTaken.toStringAsFixed(1)}d Taken / ${totalQuota.toStringAsFixed(0)}d Annual Total (${remaining.toStringAsFixed(1)}d Remaining in Year)'
                '${pendingDays > 0 ? ' • ${pendingDays.toStringAsFixed(1)}d in pending requests' : ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (leaveBalances.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Leave Quotas & Monthly Accrual Breakdown',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: context.textPrimary),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 550;
              final itemWidth = isTwoCol
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: leaveBalances.map((lb) {
                  return SizedBox(
                    width: itemWidth,
                    child:
                        _LeaveTypeTile(lb, pendingRequests: pendingRequests),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _LeaveTypeTile extends StatelessWidget {
  final dynamic lb;
  final List<dynamic> pendingRequests;
  const _LeaveTypeTile(this.lb, {required this.pendingRequests});

  @override
  Widget build(BuildContext context) {
    final typeName = lb['leave_type']?['name'] ?? 'Leave';
    final isSick = typeName.toString().toLowerCase().contains('sick');
    final isCasual = typeName.toString().toLowerCase().contains('casual');
    final isPaid = typeName == 'Paid Leave' || isCasual || isSick;

    final annualQuota = (lb['annual_quota'] as num? ?? lb['quota'] as num? ?? 1).toDouble();
    final total = (lb['quota'] as num? ?? 1).toDouble();
    final isProrated = lb['is_prorated'] == true;
    final paidTaken = (lb['paid_taken'] as num? ?? lb['leaves_taken'] as num? ?? 0).toDouble();
    final unpaidTaken = (lb['unpaid_taken'] as num? ?? 0).toDouble();
    final halfDayCount = (lb['half_day_count'] as num? ?? 0).toInt();
    final halfDayDays = (lb['half_day_days'] as num? ?? 0).toDouble();
    final accruedToDate = (lb['accrued_to_date'] as num? ?? total).toDouble();
    final availableThisMonth = (lb['available_this_month'] as num? ?? (total - paidTaken)).toDouble();
    final remainingAnnual = (lb['remaining_annual'] as num? ?? (total - paidTaken)).toDouble();
    final pct = total > 0 ? (paidTaken / total).clamp(0.0, 1.0).toDouble() : 0.0;

    // Filter pending for this specific type
    final typePending = pendingRequests
        .where((r) =>
            (r['leave_type_name'] ??
                (r['is_paid'] == true ? 'Casual Leave' : 'Unpaid Leave')) ==
            typeName)
        .fold<double>(
            0, (sum, r) => sum + ((r['no_days'] as num?)?.toDouble() ?? 0.0));
    final netAvailable = (availableThisMonth - typePending).clamp(0, total);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isSick
                  ? const Color(0xFF6366F1)
                  : isCasual
                      ? AppColors.primary
                      : (isPaid ? AppColors.success : const Color(0xFFF59E0B)))
              .withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isSick
                                ? const Color(0xFF6366F1)
                                : isCasual
                                    ? AppColors.primary
                                    : (isPaid ? AppColors.success : const Color(0xFFF59E0B)))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSick
                            ? Iconsax.health
                            : isCasual
                                ? Iconsax.sun_1
                                : (isPaid ? Iconsax.wallet_3 : Iconsax.calendar_remove),
                        color: isSick
                            ? const Color(0xFF6366F1)
                            : isCasual
                                ? AppColors.primary
                                : (isPaid ? AppColors.success : const Color(0xFFF59E0B)),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeName,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: context.textPrimary),
                          ),
                          Text(
                            isProrated
                                ? 'Annual: ${annualQuota.toStringAsFixed(1)}d (Prorated) • Accrued: ${accruedToDate.toStringAsFixed(1)}d'
                                : 'Annual: ${total.toStringAsFixed(0)}d • Accrued: ${accruedToDate.toStringAsFixed(1)}d',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${netAvailable.toStringAsFixed(1)}d Available',
                    style: TextStyle(
                      color: isSick
                          ? const Color(0xFF6366F1)
                          : isCasual
                              ? AppColors.primary
                              : (isPaid ? AppColors.success : const Color(0xFFF59E0B)),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'This Month',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: isSick
                          ? const Color(0xFF6366F1)
                          : isCasual
                              ? AppColors.primary
                              : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-metric chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Paid: ${paidTaken.toStringAsFixed(1)}d',
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success),
                ),
              ),
              if (unpaidTaken > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Unpaid: ${unpaidTaken.toStringAsFixed(1)}d',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B)),
                  ),
                ),
              if (halfDayCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Half-Day: $halfDayCount (${halfDayDays.toStringAsFixed(1)}d)',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1)),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.border),
                ),
                child: Text(
                  'Year Left: ${remainingAnnual.toStringAsFixed(1)}d',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          LinearProgressIndicator(
            value: pct,
            backgroundColor: context.card,
            color: pct > 0.85
                ? AppColors.error
                : (isSick
                    ? const Color(0xFF6366F1)
                    : (isPaid ? AppColors.success : const Color(0xFFF59E0B))),
            borderRadius: BorderRadius.circular(6),
            minHeight: 5.5,
          ),
          if (typePending > 0) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${typePending.toStringAsFixed(1)}d Pending Approval',
                style: const TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Apply Leave Sheet with Strict Quota Guard ──────────────────────────────
class _ApplyLeaveSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  final Map<String, dynamic>? balance;
  final List<dynamic> existingRequests;
  final Map<String, dynamic>? leaveSetting;
  final UserProfile? currentUser;
  const _ApplyLeaveSheet({
    required this.onSuccess,
    required this.balance,
    required this.existingRequests,
    this.leaveSetting,
    this.currentUser,
  });

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _fromCtrl = TextEditingController();
  final _tillCtrl = TextEditingController();
  String _subject = '', _fromDate = '', _tillDate = '', _reason = '';
  bool _isPaid = true;
  bool _isLoading = false;
  bool _isHalfDay = false;
  String _halfDayPeriod = 'First Half';

  // Leave Category selection
  List<dynamic> _leaveTypes = [];
  int? _selectedLeaveTypeId;
  String _selectedCategoryName = 'Casual Leave';
  PlatformFile? _selectedFile;
  int _excludedSaturdays = 0;

  bool get _isInternBlocked {
    final isIntern =
        (widget.currentUser?.employeeType ?? '').toLowerCase() == 'intern';
    final allowIntern = widget.leaveSetting?['allow_intern_leave'] ?? true;
    return isIntern && !allowIntern;
  }

  bool get _isProvisionRestricted {
    final inProvision = widget.currentUser?.isInProvision ?? false;
    final allowPaidInProvision =
        widget.leaveSetting?['paid_leave_during_provision'] ?? false;
    return inProvision && !allowPaidInProvision;
  }

  @override
  void initState() {
    super.initState();
    if (_isProvisionRestricted) {
      _isPaid = false;
    }
    _fetchLeaveTypes();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _tillCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaveTypes() async {
    try {
      final res =
          await ApiService().get('${AppConstants.leaveBase}/leave-types/');
      if (mounted) {
        final rawList = res.data is List
            ? res.data as List
            : ((res.data['results'] ?? []) as List);
        final list = rawList.where((t) {
          final name = t['name']?.toString().toLowerCase() ?? '';
          return name.contains('casual') || name.contains('sick');
        }).toList();

        setState(() {
          _leaveTypes = list;
          if (list.isNotEmpty) {
            final casual = list.firstWhere(
              (t) =>
                  t['name']?.toString().toLowerCase().contains('casual') ==
                  true,
              orElse: () => list.first,
            );
            _selectedLeaveTypeId = casual['id'];
            _selectedCategoryName = casual['name'] ?? 'Casual Leave';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _selectedFile = result.files.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('File picker error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  double _calculateRequestedDays() {
    if (_isHalfDay) {
      _excludedSaturdays = 0;
      return 0.5;
    }
    if (_fromDate.isEmpty || _tillDate.isEmpty) {
      _excludedSaturdays = 0;
      return 0;
    }
    try {
      final fromNd = NepaliDateTime.parse(_fromDate);
      final tillNd = NepaliDateTime.parse(_tillDate);
      if (fromNd.isAfter(tillNd)) {
        _excludedSaturdays = 0;
        return 0.0;
      }

      double workingDays = 0.0;
      int saturdays = 0;
      NepaliDateTime curr = fromNd;
      while (!curr.isAfter(tillNd)) {
        final adDate = curr.toDateTime();
        if (adDate.weekday == DateTime.saturday) {
          saturdays++;
        } else {
          workingDays += 1.0;
        }
        curr = curr.add(const Duration(days: 1));
      }
      _excludedSaturdays = saturdays;
      return workingDays;
    } catch (_) {
      _excludedSaturdays = 0;
      return 0.0;
    }
  }

  double _calculateAvailableQuota() {
    if (!_isPaid) return 999.0; // Unpaid leave is unrestricted by quota
    if (widget.balance == null) return 999.0;
    final leaveBalances = (widget.balance!['leave_balances'] as List?) ?? [];

    dynamic targetBalance;
    for (final lb in leaveBalances) {
      final typeName =
          lb['leave_type']?['name']?.toString().toLowerCase() ?? '';
      if (_selectedLeaveTypeId != null &&
          lb['leave_type']?['id'] == _selectedLeaveTypeId) {
        targetBalance = lb;
        break;
      }
      if (typeName.contains(_selectedCategoryName.toLowerCase()) ||
          _selectedCategoryName.toLowerCase().contains(typeName)) {
        targetBalance = lb;
        break;
      }
    }

    if (targetBalance == null && leaveBalances.isNotEmpty) {
      targetBalance = leaveBalances.first;
    }

    if (targetBalance == null) return 999.0;

    final availableThisMonth = (targetBalance['available_this_month'] as num?)
            ?.toDouble() ??
        ((targetBalance['quota'] as num? ?? 0).toDouble() -
            (targetBalance['leaves_taken'] as num? ?? 0).toDouble());

    final pendingOfThisType = widget.existingRequests
        .where((r) =>
            r['is_approved'] != true &&
            r['is_reviewed'] != true &&
            r['is_paid'] == true &&
            (r['leave_type_name'] == _selectedCategoryName ||
                (r['leave_type_name'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(_selectedCategoryName.toLowerCase())))
        .fold<double>(
            0.0, (sum, r) => sum + ((r['no_days'] as num?)?.toDouble() ?? 0.0));

    return (availableThisMonth - pendingOfThisType).clamp(0.0, 999.0);
  }

  bool get _isSickLeaveSelected {
    return _selectedCategoryName.toLowerCase().contains('sick');
  }

  Future<void> _submit() async {
    if (_isInternBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Interns are not permitted to submit leave requests per company policy.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    _fromDate = _fromCtrl.text.trim();
    _tillDate = _tillCtrl.text.trim();
    if (_fromDate.isEmpty || _tillDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select or enter both From Date and Till Date'),
            backgroundColor: AppColors.error),
      );
      return;
    }

    final reqDays = _calculateRequestedDays();
    if (reqDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selected date range contains no working days (only weekend/Saturday).'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final available = _calculateAvailableQuota();
    if (_isPaid && reqDays > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Monthly quota exceeded for $_selectedCategoryName. You requested $reqDays day(s), but only have $available day(s) available this month.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final formData = FormData();
      formData.fields.add(MapEntry('subject', _subject.trim()));
      formData.fields.add(MapEntry('from_date', _fromDate));
      formData.fields.add(MapEntry('till_date', _tillDate));
      formData.fields.add(MapEntry('remarks', _reason.trim()));
      formData.fields.add(MapEntry('is_paid', _isPaid.toString()));
      formData.fields.add(MapEntry('is_half_day', _isHalfDay.toString()));
      if (_isHalfDay) {
        formData.fields.add(MapEntry('half_day_period', _halfDayPeriod));
      }
      if (_selectedLeaveTypeId != null) {
        formData.fields.add(MapEntry('type', _selectedLeaveTypeId.toString()));
      }
      formData.fields.add(MapEntry('leave_category', _selectedCategoryName));

      if (_selectedFile != null && _selectedFile!.bytes != null) {
        formData.files.add(MapEntry(
          'document',
          MultipartFile.fromBytes(_selectedFile!.bytes!,
              filename: _selectedFile!.name),
        ));
      }

      await ApiService().post(
        '${AppConstants.leaveBase}/leave-requests/',
        data: formData,
      );

      if (mounted) {
        Navigator.pop(context, true);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Leave request submitted successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestedDays = _calculateRequestedDays();
    final availableQuota = _calculateAvailableQuota();
    final isExceeded = _isPaid && (requestedDays > availableQuota);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Iconsax.calendar_add,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apply for Leave',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Submit time-off request for review',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Iconsax.close_circle, size: 20),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: context.border),
              const SizedBox(height: 14),

              // ── Policy Warning Banners ──
              if (_isInternBlocked) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Iconsax.warning_2, color: AppColors.error, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Intern Policy: Leave applications are currently disabled for interns by company policy.',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_isProvisionRestricted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Iconsax.info_circle,
                          color: Color(0xFFF59E0B), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Provision Period: Staff serving probation are eligible only for Unpaid Leave.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Live Quota & Saturday Indicator Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isExceeded
                      ? AppColors.error.withValues(alpha: 0.08)
                      : (_isPaid
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.06)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isExceeded
                        ? AppColors.error
                        : (_isPaid
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExceeded
                          ? Iconsax.warning_2
                          : (_isPaid ? Iconsax.info_circle : Iconsax.wallet_3),
                      color: isExceeded
                          ? AppColors.error
                          : (_isPaid
                              ? AppColors.primary
                              : const Color(0xFFF59E0B)),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isPaid
                                ? 'Available This Month ($_selectedCategoryName): ${availableQuota.toStringAsFixed(1)} Days'
                                : 'Unpaid Leave (No Quota Limit • Deducted in Payroll)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isExceeded
                                  ? AppColors.error
                                  : context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            requestedDays > 0
                                ? 'Duration: ${requestedDays.toStringAsFixed(1)} working day(s)'
                                    '${_excludedSaturdays > 0 ? ' ($_excludedSaturdays Saturday(s) excluded)' : ''}'
                                : 'Select dates to calculate working duration & verify monthly quota',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isExceeded
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Leave Category Selection Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Leave Category *',
                  prefixIcon: Icon(Iconsax.category, size: 18),
                ),
                // ignore: deprecated_member_use
                value: _selectedCategoryName,
                items: (_leaveTypes.isNotEmpty
                        ? _leaveTypes
                            .map((t) => t['name']?.toString() ?? 'Leave')
                            .where((name) =>
                                name.toLowerCase().contains('casual') ||
                                name.toLowerCase().contains('sick'))
                            .toSet()
                            .toList()
                        : [
                            'Casual Leave',
                            'Sick Leave',
                          ])
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategoryName = val;
                      try {
                        final found =
                            _leaveTypes.firstWhere((t) => t['name'] == val);
                        _selectedLeaveTypeId = found['id'];
                      } catch (_) {}
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Subject / Purpose *',
                  hintText: 'e.g. Medical checkup, Personal emergency',
                  prefixIcon: Icon(Iconsax.document_text, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Subject is required'
                    : null,
                onSaved: (v) => _subject = v ?? '',
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: NepaliDateFormField(
                      controller: _fromCtrl,
                      labelText: 'From Date *',
                      prefixIcon: Iconsax.calendar_1,
                      isRequired: true,
                      onChanged: (val) {
                        setState(() {
                          _fromDate = val;
                          if (_isHalfDay || _tillDate.isEmpty) {
                            _tillDate = val;
                            _tillCtrl.text = val;
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NepaliDateFormField(
                      controller: _tillCtrl,
                      labelText: _isHalfDay ? 'Same Day' : 'Till Date *',
                      prefixIcon: Iconsax.calendar_2,
                      enabled: !_isHalfDay,
                      isRequired: true,
                      onChanged: (val) {
                        setState(() {
                          _tillDate = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason & Remarks (Optional)',
                  hintText:
                      'Provide additional details for reviewing managers...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Iconsax.note_text, size: 18),
                ),
                onSaved: (v) => _reason = v ?? '',
              ),
              const SizedBox(height: 12),

              // Supporting Document Upload (Highlighted for Sick Leave)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSickLeaveSelected
                      ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                      : context.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isSickLeaveSelected
                        ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                        : context.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Iconsax.document_upload,
                          size: 18,
                          color: _isSickLeaveSelected
                              ? const Color(0xFF6366F1)
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isSickLeaveSelected
                                ? 'Medical Certificate (Recommended for Sick Leave)'
                                : 'Supporting Document (Optional)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isSickLeaveSelected
                                  ? const Color(0xFF6366F1)
                                  : context.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedFile != null) ...[
                      Row(
                        children: [
                          const Icon(Iconsax.document_1,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_selectedFile!.name} (${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB)',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Iconsax.trash,
                                size: 16, color: AppColors.error),
                            onPressed: () =>
                                setState(() => _selectedFile = null),
                            tooltip: 'Remove file',
                          ),
                        ],
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Iconsax.paperclip, size: 16),
                        label: const Text('Attach File (PDF, JPG, PNG)'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 38),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Paid Leave & Half Day Switches
              Material(
                type: MaterialType.transparency,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 450;
                    return Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      children: [
                        isMobile
                            ? SwitchListTile(
                                title: const Text('Paid Leave',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                  _isProvisionRestricted
                                      ? 'Locked: Only unpaid leave allowed in provision period'
                                      : 'Toggle for paid vs unpaid leave',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                value: _isPaid,
                                onChanged: _isProvisionRestricted
                                    ? null
                                    : (v) => setState(() => _isPaid = v),
                                activeThumbColor: AppColors.primary,
                                contentPadding: EdgeInsets.zero,
                              )
                            : Expanded(
                                child: SwitchListTile(
                                  title: const Text('Paid Leave',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  subtitle: Text(
                                    _isProvisionRestricted
                                        ? 'Locked: Unpaid only in provision'
                                        : 'Toggle for paid vs unpaid',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  value: _isPaid,
                                  onChanged: _isProvisionRestricted
                                      ? null
                                      : (v) => setState(() => _isPaid = v),
                                  activeThumbColor: AppColors.primary,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                        if (isMobile) const Divider(height: 1),
                        isMobile
                            ? SwitchListTile(
                                title: const Text('Half Day Leave',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                subtitle: const Text('0.5 day duration',
                                    style: TextStyle(fontSize: 11)),
                                value: _isHalfDay,
                                onChanged: (v) => setState(() {
                                  _isHalfDay = v;
                                  if (v) {
                                    _tillCtrl.text = _fromCtrl.text;
                                    _tillDate = _fromDate;
                                  }
                                }),
                                activeThumbColor: AppColors.primary,
                                contentPadding: EdgeInsets.zero,
                              )
                            : Expanded(
                                child: SwitchListTile(
                                  title: const Text('Half Day Leave',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  subtitle: const Text('0.5 day duration',
                                      style: TextStyle(fontSize: 11)),
                                  value: _isHalfDay,
                                  onChanged: (v) => setState(() {
                                    _isHalfDay = v;
                                    if (v) {
                                      _tillCtrl.text = _fromCtrl.text;
                                      _tillDate = _fromDate;
                                    }
                                  }),
                                  activeThumbColor: AppColors.primary,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                      ],
                    );
                  },
                ),
              ),

              if (_isHalfDay) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Half Day Period',
                    prefixIcon: Icon(Iconsax.clock, size: 18),
                  ),
                  // ignore: deprecated_member_use
                  value: _halfDayPeriod,
                  items: const [
                    DropdownMenuItem(
                        value: 'First Half',
                        child: Text(
                          'First Half (Morning Session)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                    DropdownMenuItem(
                        value: 'Second Half',
                        child: Text(
                          'Second Half (Afternoon Session)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )),
                  ],
                  onChanged: (v) => setState(() => _halfDayPeriod = v!),
                ),
              ],

              const SizedBox(height: 22),

              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: (isExceeded || _isInternBlocked)
                      ? null
                      : const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark]),
                  color: (isExceeded || _isInternBlocked) ? Colors.grey : null,
                ),
                child: ElevatedButton(
                  onPressed: (_isLoading || isExceeded || _isInternBlocked)
                      ? null
                      : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Iconsax.send_1,
                                size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              _isInternBlocked
                                  ? 'Intern Leave Disabled'
                                  : isExceeded
                                      ? 'Monthly Quota Exceeded'
                                      : 'Submit Leave Request',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Details Modal ───────────────────────────────────────────────────────────
void _showLeaveDetails(BuildContext context, Map leave, bool isAdmin,
    {VoidCallback? onRefresh}) {
  String status = 'Pending';
  Color statusColor = const Color(0xFFF59E0B);
  if (leave['is_approved'] == true) {
    status = 'Approved';
    statusColor = AppColors.success;
  } else if (leave['is_reviewed'] == true) {
    status = 'Rejected';
    statusColor = AppColors.error;
  } else if (leave['is_initial_approved'] == true) {
    status = 'Initial Approved';
    statusColor = const Color(0xFF6366F1);
  }

  final typeName = leave['leave_type_name'] ??
      (leave['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave');
  final isSickLeave = leave['is_sick_leave'] == true ||
      typeName.toString().toLowerCase().contains('sick');
  final rejectionReason = leave['rejection_reason']?.toString().trim();
  String? currentDocUrl = leave['document_url']?.toString();
  bool isUploadingDoc = false;
  final messenger = ScaffoldMessenger.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 600),
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        Future<void> pickAndUploadDocument() async {
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
              withData: true,
            );
            if (result == null || result.files.isEmpty) return;
            final file = result.files.first;
            if (file.bytes == null) return;

            setModalState(() => isUploadingDoc = true);

            final formData = FormData();
            formData.files.add(MapEntry(
              'document',
              MultipartFile.fromBytes(file.bytes!, filename: file.name),
            ));

            final res = await ApiService().patch(
              '${AppConstants.leaveBase}/update/${leave['id']}/',
              data: formData,
            );

            setModalState(() {
              isUploadingDoc = false;
              if (res.data != null && res.data['document_url'] != null) {
                currentDocUrl = res.data['document_url'].toString();
                leave['document_url'] = currentDocUrl;
              }
            });

            onRefresh?.call();

            if (ctx.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text('Medical document uploaded successfully!'),
                    ],
                  ),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          } catch (e) {
            setModalState(() => isUploadingDoc = false);
            if (ctx.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Failed to upload document: ${ApiService.getErrorMessage(e)}'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }

        final hasDoc = currentDocUrl != null && currentDocUrl!.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Iconsax.calendar_tick,
                            color: statusColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status.toUpperCase(),
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800),
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
              const SizedBox(height: 16),
              Text(
                leave['subject'] ?? 'Leave Request',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary),
              ),
              const SizedBox(height: 14),
              Divider(color: context.border),
              const SizedBox(height: 14),

              if (isAdmin && leave['employee_name'] != null) ...[
                _DetailRow(
                    icon: Iconsax.user,
                    label: 'Employee',
                    value: leave['employee_name']),
                const SizedBox(height: 12),
              ],
              _DetailRow(
                icon: Iconsax.category,
                label: 'Leave Category',
                value: typeName,
                valueColor: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Iconsax.calendar,
                label: 'Date Range',
                value: leave['is_half_day'] == true
                    ? '${_fmtDate(leave['from_date']?.toString())} (Half Day • ${leave['half_day_period'] ?? 'N/A'})'
                    : '${_fmtDate(leave['from_date']?.toString())} → ${_fmtDate(leave['till_date']?.toString())}',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Iconsax.timer_1,
                label: 'Total Working Days',
                value: leave['is_half_day'] == true
                    ? '0.5 Day'
                    : '${leave['no_days']} Days (Saturdays excluded)',
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Iconsax.wallet_3,
                label: 'Payment Type',
                value: leave['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave',
                valueColor: leave['is_paid'] == true
                    ? AppColors.success
                    : const Color(0xFFF59E0B),
              ),

              if (leave['remarks'] != null &&
                  (leave['remarks'] as String).trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Reason / Remarks',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(leave['remarks'],
                    style: TextStyle(
                        fontSize: 13.5,
                        color: context.textPrimary,
                        height: 1.5)),
              ],

              // Rejection Reason Alert Box
              if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Iconsax.info_circle,
                              color: AppColors.error, size: 16),
                          SizedBox(width: 8),
                          Text('Reason for Rejection',
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(rejectionReason,
                          style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 13,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],

              // Supporting Document Section (View / Upload / Replace)
              const SizedBox(height: 16),
              if (hasDoc) ...[
                ElevatedButton.icon(
                  onPressed: () => _viewLeaveDocument(
                    context,
                    currentDocUrl,
                    title: 'Medical Certificate / Document',
                  ),
                  icon: const Icon(Iconsax.document_download,
                      size: 18, color: Colors.white),
                  label: const Text('View Medical Document / Certificate',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: isUploadingDoc ? null : pickAndUploadDocument,
                  icon: isUploadingDoc
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Iconsax.document_upload,
                          size: 16, color: Color(0xFF6366F1)),
                  label: Text(
                    isUploadingDoc
                        ? 'Uploading...'
                        : 'Replace / Update Document',
                    style: const TextStyle(
                        color: Color(0xFF6366F1), fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF6366F1)),
                    minimumSize: const Size(double.infinity, 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else ...[
                // If no document is attached, provide an Upload Supporting Document button
                OutlinedButton.icon(
                  onPressed: isUploadingDoc ? null : pickAndUploadDocument,
                  icon: isUploadingDoc
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Iconsax.document_upload,
                          size: 18, color: Color(0xFF6366F1)),
                  label: Text(
                    isUploadingDoc
                        ? 'Uploading Medical Document...'
                        : (isSickLeave
                            ? '📎 Attach Supporting Medical Document'
                            : '📎 Attach Supporting Document'),
                    style: const TextStyle(
                        color: Color(0xFF6366F1), fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    backgroundColor:
                        const Color(0xFF6366F1).withValues(alpha: 0.05),
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],

              if (isAdmin && leave['is_reviewed'] != true) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final reasonCtrl = TextEditingController();
                          final formKey = GlobalKey<FormState>();
                          showDialog(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              title: const Row(
                                children: [
                                  Icon(Iconsax.close_circle,
                                      color: AppColors.error, size: 22),
                                  SizedBox(width: 10),
                                  Text('Reject Leave',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16)),
                                ],
                              ),
                              content: Form(
                                key: formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Provide a reason for rejecting this leave application:',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: reasonCtrl,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                          hintText:
                                              'e.g. Inadequate balance / Team shortage'),
                                      validator: (v) => (v == null ||
                                              v.trim().isEmpty)
                                          ? 'Reason is required'
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dCtx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (formKey.currentState!.validate()) {
                                      Navigator.pop(dCtx);
                                      try {
                                        await ApiService().patch(
                                          '${AppConstants.leaveBase}/update/${leave['id']}/',
                                          data: {
                                            'action': 'reject',
                                            'is_approved': false,
                                            'is_reviewed': true,
                                            'rejection_reason':
                                                reasonCtrl.text.trim(),
                                          },
                                        );
                                        onRefresh?.call();
                                        messenger.showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Leave request rejected successfully'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      } catch (e) {
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Error: ${ApiService.getErrorMessage(e)}'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.error),
                                  child: const Text('Confirm Rejection',
                                      style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Iconsax.close_circle,
                            size: 16, color: AppColors.error),
                        label: const Text('Reject',
                            style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isSickLeave && leave['is_initial_approved'] != true)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await ApiService().patch(
                                '${AppConstants.leaveBase}/update/${leave['id']}/',
                                data: {
                                  'action': 'initial_approve',
                                  'is_initial_approved': true,
                                },
                              );
                              onRefresh?.call();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Iconsax.verify,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 10),
                                      Text('Sick leave initial approved!'),
                                    ],
                                  ),
                                  backgroundColor: Color(0xFF6366F1),
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Error: ${ApiService.getErrorMessage(e)}'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Iconsax.verify,
                              size: 16, color: Colors.white),
                          label: const Text('Initial Approve',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            try {
                              await ApiService().patch(
                                '${AppConstants.leaveBase}/update/${leave['id']}/',
                                data: {
                                  'action': 'final_approve',
                                  'is_approved': true,
                                  'is_reviewed': true,
                                },
                              );
                              onRefresh?.call();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Iconsax.tick_circle,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 10),
                                      Text(
                                          'Leave request approved successfully!'),
                                    ],
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Error: ${ApiService.getErrorMessage(e)}'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Iconsax.tick_circle,
                              size: 16, color: Colors.white),
                          label: Text(
                            isSickLeave ? 'Final Approve' : 'Approve Leave',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close Details'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11.5)),
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: valueColor ?? context.textPrimary)),
          ],
        ),
      ],
    );
  }
}

// ─── Admin Staff Balance Card ────────────────────────────────────────────────
class _AdminEmployeeBalanceCard extends StatelessWidget {
  final Map data;
  final VoidCallback onRefresh;
  const _AdminEmployeeBalanceCard(
      {required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final balances = (data['balances'] as List?) ?? [];
    final empName = data['employee_name'] ?? 'Employee';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    empName,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: context.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${balances.length} Quota Types',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.border),
          const SizedBox(height: 12),

          // ── Two-Column Quota Balance Display ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isTwoCol = constraints.maxWidth >= 440;
              final itemWidth = isTwoCol
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: balances.map((b) {
                  return SizedBox(
                    width: itemWidth,
                    child: _buildQuotaTile(context, b),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaTile(BuildContext context, Map b) {
    final annualQuota = (b['annual_quota'] as num? ?? b['quota'] as num? ?? 0).toDouble();
    final quota = (b['quota'] as num?)?.toInt() ?? annualQuota.toInt();
    final isProrated = b['is_prorated'] == true;
    final paidTaken = (b['paid_taken'] as num? ?? b['leaves_taken'] as num? ?? 0).toDouble();
    final unpaidTaken = (b['unpaid_taken'] as num? ?? 0).toDouble();
    final halfDayCount = (b['half_day_count'] as num? ?? 0).toInt();
    final halfDayDays = (b['half_day_days'] as num? ?? 0).toDouble();
    final accruedToDate = (b['accrued_to_date'] as num? ?? quota).toDouble();
    final availableThisMonth = (b['available_this_month'] as num? ?? (quota - paidTaken)).toDouble();
    final remainingAnnual = (b['remaining_annual'] as num? ?? (quota - paidTaken)).toDouble();

    final typeName = b['leave_type']?['name'] ?? 'Leave';
    final isSick = typeName.toString().toLowerCase().contains('sick');
    final isCasual = typeName.toString().toLowerCase().contains('casual');
    final isPaid = typeName == 'Paid Leave' || isCasual || isSick;
    final pct = quota > 0 ? (paidTaken / quota).clamp(0.0, 1.0).toDouble() : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isSick
                  ? const Color(0xFF6366F1)
                  : isCasual
                      ? AppColors.primary
                      : (isPaid ? AppColors.success : const Color(0xFFF59E0B)))
              .withValues(alpha: 0.3),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Name + Edit Button
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isSick
                                ? const Color(0xFF6366F1)
                                : isCasual
                                    ? AppColors.primary
                                    : (isPaid ? AppColors.success : const Color(0xFFF59E0B)))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isSick
                            ? Iconsax.health
                            : isCasual
                                ? Iconsax.sun_1
                                : (isPaid ? Iconsax.wallet_3 : Iconsax.calendar_remove),
                        color: isSick
                            ? const Color(0xFF6366F1)
                            : isCasual
                                ? AppColors.primary
                                : (isPaid ? AppColors.success : const Color(0xFFF59E0B)),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeName,
                            style: TextStyle(
                                color: isSick
                                    ? const Color(0xFF6366F1)
                                    : isCasual
                                        ? AppColors.primary
                                        : (isPaid ? AppColors.success : const Color(0xFFF59E0B)),
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                            ),
                          ),
                          Text(
                            isProrated
                                ? 'Annual: ${annualQuota.toStringAsFixed(1)}d (Prorated) • Accrued: ${accruedToDate.toStringAsFixed(1)}d'
                                : 'Annual: ${quota}d • Accrued: ${accruedToDate.toStringAsFixed(1)}d',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Iconsax.edit, size: 15, color: AppColors.primary),
                tooltip: 'Adjust Annual Quota',
                onPressed: () => _showEditQuotaDialog(context, b),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Available This Month Hero Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (isSick ? const Color(0xFF6366F1) : AppColors.primary)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Iconsax.calendar_tick,
                      size: 14,
                      color: isSick ? const Color(0xFF6366F1) : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Available This Month:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isSick ? const Color(0xFF6366F1) : AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${availableThisMonth.toStringAsFixed(1)} Days',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isSick ? const Color(0xFF6366F1) : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Multi-metric Breakdown Chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Paid: ${paidTaken.toStringAsFixed(1)}d',
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success),
                ),
              ),
              if (unpaidTaken > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Unpaid: ${unpaidTaken.toStringAsFixed(1)}d',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF59E0B)),
                  ),
                ),
              if (halfDayCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Half-Day: $halfDayCount (${halfDayDays.toStringAsFixed(1)}d)',
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6366F1)),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.border),
                ),
                child: Text(
                  'Remaining: ${remainingAnnual.toStringAsFixed(1)}d',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress indicator
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: context.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                pct > 0.85
                    ? AppColors.error
                    : (isSick
                        ? const Color(0xFF6366F1)
                        : (isPaid ? AppColors.success : const Color(0xFFF59E0B))),
              ),
              minHeight: 4.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditQuotaDialog(BuildContext context, Map balanceData) {
    final typeName = balanceData['leave_type']?['name'] ?? 'Leave';
    final ctrl =
        TextEditingController(text: balanceData['quota']?.toString() ?? '0');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text('Edit Quota: $typeName',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adjusting quota for ${data['employee_name']}'),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'New Annual Quota (Days)',
                  prefixIcon: Icon(Iconsax.calendar, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final val = int.tryParse(ctrl.text.trim());
                      if (val == null || val < 0) return;

                      setStateModal(() => isLoading = true);
                      try {
                        await ApiService().patch(
                          '${AppConstants.leaveBase}/leave-balance/update/${balanceData['id']}/',
                          data: {'quota': val},
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Staff leave quota updated successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          onRefresh();
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Error: ${ApiService.getErrorMessage(e)}'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setStateModal(() => isLoading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Quota',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
