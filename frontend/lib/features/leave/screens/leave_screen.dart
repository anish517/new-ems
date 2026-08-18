import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/date_provider.dart';
import '../../../shared/widgets/nepali_date_picker.dart';

// ─── Date Formatter ────────────────────────────────────────────────────────
String _fmtDate(String? raw, {String? fallback}) {
  if (raw == null && fallback == null) return '';
  final s = raw ?? fallback!;
  try {
    if (s.contains('T')) {
      return NepaliDateFormat('dd MMMM yyyy').format(DateTime.parse(s).toNepaliDateTime());
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

class LeaveScreen extends ConsumerStatefulWidget {
  const LeaveScreen({super.key});
  @override
  ConsumerState<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends ConsumerState<LeaveScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _requests = [];
  Map<String, dynamic>? _balance;
  List<dynamic> _pending = [];
  List<dynamic> _adminBalances = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all'; // 'all', 'pending', 'approved', 'rejected'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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

      // My leave requests (admins get all org requests, employees get only theirs)
      final res = await ApiService().get('${AppConstants.leaveBase}/leave-requests/');
      if (!mounted) return;
      final all = res.data is List ? res.data as List : ((res.data['results'] ?? res.data) as List);

      setState(() {
        _requests = all;
        if (isAdmin) {
          _pending = all.where((r) => r['is_approved'] != true && r['is_reviewed'] != true).toList();
        }
      });

      if (isAdmin) {
        try {
          final summaryRes = await ApiService().get('${AppConstants.leaveBase}/leave-summary/');
          if (mounted) {
            setState(() => _adminBalances = summaryRes.data is List ? summaryRes.data as List : []);
          }
        } catch (_) {}
      }

      // Fetch personal leave balance
      if (user?.employeeId != null) {
        try {
          final balRes = await ApiService().get(
            '${AppConstants.leaveBase}/leave-balance/${user!.employeeId}/',
          );
          if (mounted) setState(() => _balance = balRes.data as Map<String, dynamic>?);
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _approveLeave(int leaveId, bool approve) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService().patch(
        '${AppConstants.leaveBase}/update/$leaveId/',
        data: {'is_approved': approve, 'is_reviewed': true},
      );
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(approve ? Iconsax.tick_circle : Iconsax.close_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(approve ? 'Leave request approved' : 'Leave request rejected'),
            ],
          ),
          backgroundColor: approve ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  void _showApplyLeaveDialog(BuildContext context) async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      final res = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _ApplyLeaveSheet(
                onSuccess: _loadLeaves,
                balance: _balance,
                existingRequests: _requests,
              ),
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
    try {
      if (_tabs.length != tabLength) {
        _tabs.dispose();
        _tabs = TabController(length: tabLength, vsync: this);
      }
    } catch (_) {
      _tabs = TabController(length: tabLength, vsync: this);
    }

    // Filter requests
    final filtered = _requests.where((r) {
      if (_statusFilter == 'pending' && (r['is_approved'] == true || r['is_reviewed'] == true)) return false;
      if (_statusFilter == 'approved' && r['is_approved'] != true) return false;
      if (_statusFilter == 'rejected' && (r['is_approved'] == true || r['is_reviewed'] != true)) return false;

      if (_searchQuery.isEmpty) return true;
      final empName = (r['employee_name'] ?? '').toString().toLowerCase();
      final subject = (r['subject'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return empName.contains(query) || subject.contains(query);
    }).toList();

    // Compute metrics
    final totalRequests = _requests.length;
    final pendingCount = _requests.where((r) => r['is_approved'] != true && r['is_reviewed'] != true).length;
    final approvedCount = _requests.where((r) => r['is_approved'] == true).length;

    // Leave Balances for employee
    final myBalances = (_balance?['leave_balances'] as List?) ?? [];
    double myPaidRemaining = 0;
    double myPaidQuota = 0;
    for (final lb in myBalances) {
      if (lb['leave_type']?['name'] == 'Paid Leave') {
        myPaidQuota = (lb['quota'] as num? ?? 0).toDouble();
        final taken = (lb['leaves_taken'] as num? ?? 0).toDouble();
        myPaidRemaining = (myPaidQuota - taken).clamp(0, myPaidQuota);
      }
    }

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showApplyLeaveDialog(context),
              backgroundColor: AppColors.primary,
              elevation: 6,
              icon: const Icon(Iconsax.calendar_add, color: Colors.white, size: 20),
              label: const Text('Apply Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Card ──────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  return Container(
                    padding: const EdgeInsets.all(20),
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
                    child: Flex(
                      direction: isMobile ? Axis.vertical : Axis.horizontal,
                      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Iconsax.calendar_remove, color: Color(0xFFF59E0B), size: 24),
                            ),
                            const SizedBox(width: 14),
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
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.4,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '$totalRequests Requests',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Time-off requests & quota tracking',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (isMobile) const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: isMobile ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isAdmin) ...[
                              ElevatedButton.icon(
                                onPressed: () => _showApplyLeaveDialog(context),
                                icon: const Icon(Iconsax.calendar_add, size: 18, color: Colors.white),
                                label: const Text('Apply Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            IconButton(
                              icon: const Icon(Iconsax.refresh, size: 20),
                              tooltip: 'Refresh Leaves',
                              onPressed: _loadLeaves,
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
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

              // ── Executive KPI Row ────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 740;

                  return Row(
                    children: [
                      if (isAdmin) ...[
                        Expanded(
                          child: _buildKpiCard(
                            'Pending Approvals',
                            '$pendingCount In Queue',
                            Iconsax.timer_start,
                            const Color(0xFFF59E0B),
                            isTight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildKpiCard(
                            'Approved Leaves',
                            '$approvedCount Processed',
                            Iconsax.tick_circle,
                            AppColors.success,
                            isTight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildKpiCard(
                            'Total Applications',
                            '$totalRequests Filed',
                            Iconsax.document_text,
                            AppColors.primary,
                            isTight,
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: _buildKpiCard(
                            'Paid Leave Available',
                            '$myPaidRemaining / ${myPaidQuota.toInt()} Days',
                            Iconsax.wallet_3,
                            AppColors.success,
                            isTight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildKpiCard(
                            'Pending Decisions',
                            '$pendingCount In Review',
                            Iconsax.timer_1,
                            const Color(0xFFF59E0B),
                            isTight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildKpiCard(
                            'Approved Leaves',
                            '$approvedCount Granted',
                            Iconsax.tick_circle,
                            AppColors.primary,
                            isTight,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── Tab Switcher ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.border),
                ),
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  tabs: isAdmin
                      ? [
                          Tab(text: 'All Leaves ($totalRequests)'),
                          Tab(text: 'Pending Approvals ($pendingCount)'),
                          Tab(text: 'Staff Quotas (${_adminBalances.length})'),
                        ]
                      : const [
                          Tab(text: 'My Requests'),
                          Tab(text: 'Leave Balances & Quota'),
                        ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Tab Content ──────────────────────────────────────────────
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else
                SizedBox(
                  height: 680,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      // Tab 1: All Leaves (Admin) or My Leaves (Employee)
                      _buildRequestsListTab(filtered, isAdmin),

                      // Tab 2: Pending Approvals (Admin) or Balances (Employee)
                      isAdmin
                          ? _buildPendingApprovalsTab()
                          : _LeaveBalanceTab(balance: _balance, existingRequests: _requests),

                      // Tab 3 (Admin Only): Staff Quotas
                      if (isAdmin) _buildAdminBalancesTab(),
                    ],
                  ),
                ),

              const SizedBox(height: 40),
            ],
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
                  hintText: isAdmin ? 'Search leaves by employee name or subject...' : 'Search by leave subject...',
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
                    _buildStatusFilterChip('all', 'All Statuses', AppColors.primary),
                    _buildStatusFilterChip('pending', '⏳ Pending', const Color(0xFFF59E0B)),
                    _buildStatusFilterChip('approved', '✅ Approved', AppColors.success),
                    _buildStatusFilterChip('rejected', '❌ Rejected', AppColors.error),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Expanded(
          child: filtered.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.border),
                  ),
                  child: const Text('No matching leave requests found.', style: TextStyle(color: AppColors.textSecondary)),
                )
              : ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _LeaveCard(filtered[i], isAdmin: isAdmin),
                ),
        ),
      ],
    );
  }

  Widget _buildPendingApprovalsTab() {
    return _pending.isEmpty
        ? Container(
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
                  child: const Icon(Iconsax.tick_circle, size: 40, color: AppColors.success),
                ),
                const SizedBox(height: 14),
                Text(
                  'All Pending Requests Reviewed!',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'There are no pending employee leave requests requiring approval.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        : ListView.separated(
            itemCount: _pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _AdminLeaveCard(
              leave: _pending[i],
              onApprove: () => _approveLeave(_pending[i]['id'] as int, true),
              onReject: () => _approveLeave(_pending[i]['id'] as int, false),
            ),
          );
  }

  Widget _buildAdminBalancesTab() {
    return _adminBalances.isEmpty
        ? Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: const Text('No employee leave quotas configured.', style: TextStyle(color: AppColors.textSecondary)),
          )
        : ListView.separated(
            itemCount: _adminBalances.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _AdminEmployeeBalanceCard(
              data: _adminBalances[i],
              onRefresh: _loadLeaves,
            ),
          );
  }

  Widget _buildKpiCard(String title, String count, IconData icon, Color color, bool isTight) {
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
  const _LeaveCard(this.data, {required this.isAdmin});

  Color get _statusColor {
    if (data['is_approved'] == true) return AppColors.success;
    if (data['is_reviewed'] == true) return AppColors.error;
    return const Color(0xFFF59E0B);
  }

  String get _status {
    if (data['is_approved'] == true) return 'Approved';
    if (data['is_reviewed'] == true) return 'Rejected';
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final empName = data['employee_name'] ?? 'Employee';

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
          onTap: () => _showLeaveDetails(context, data, isAdmin),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _status,
                              style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      if (isAdmin) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Requested by: $empName',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Iconsax.calendar, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            data['is_half_day'] == true
                                ? '${_fmtDate(data['from_date']?.toString())} (Half Day • ${data['half_day_period'] ?? 'N/A'})'
                                : '${_fmtDate(data['from_date']?.toString())} → ${_fmtDate(data['till_date']?.toString())}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: data['is_paid'] == true
                                  ? AppColors.success.withValues(alpha: 0.1)
                                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              data['is_paid'] == true ? 'Paid' : 'Unpaid',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: data['is_paid'] == true ? AppColors.success : const Color(0xFFF59E0B),
                              ),
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
  final VoidCallback onApprove, onReject;
  const _AdminLeaveCard({required this.leave, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final empName = leave['employee_name'] ?? 'Unknown Employee';
    final isDark = context.isDark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
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
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empName,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                    Text(
                      leave['subject'] ?? 'Leave Request',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Pending Review',
                  style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.border),
          const SizedBox(height: 10),

          Row(
            children: [
              const Icon(Iconsax.calendar, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                leave['is_half_day'] == true
                    ? 'Half Day (${leave['half_day_period'] ?? 'N/A'}) • ${_fmtDate(leave['from_date']?.toString())}'
                    : '${_fmtDate(leave['from_date']?.toString())} → ${_fmtDate(leave['till_date']?.toString())} (${leave['no_days']} days)',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: leave['is_paid'] == true
                      ? AppColors.success.withValues(alpha: 0.1)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  leave['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: leave['is_paid'] == true ? AppColors.success : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),

          if (leave['remarks'] != null && (leave['remarks'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Reason: "${leave['remarks']}"',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Iconsax.close_circle, size: 16, color: AppColors.error),
                  label: const Text('Reject Leave', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Iconsax.tick_circle, size: 16, color: Colors.white),
                  label: const Text('Approve Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        child: const Text('Leave balance information not available', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final leaveBalances = (balance!['leave_balances'] as List?) ?? [];

    // Compute totals from the per-type list
    double totalTaken = 0;
    double totalQuota = 0;
    for (final lb in leaveBalances) {
      totalTaken += (lb['leaves_taken'] as num? ?? 0).toDouble();
      totalQuota += (lb['quota'] as num? ?? 0).toDouble();
    }
    final remaining = (totalQuota - totalTaken).clamp(0, totalQuota);

    // Pending unreviewed requests days
    final pendingRequests = existingRequests.where((r) => r['is_approved'] != true && r['is_reviewed'] != true).toList();
    final pendingDays = pendingRequests.fold<double>(0, (sum, r) => sum + ((r['no_days'] as num?)?.toDouble() ?? 0.0));

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
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
                const Text('Annual Leave Entitlement', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '${remaining.toStringAsFixed(1)} Days Left',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${totalTaken.toStringAsFixed(1)} Days Taken / ${totalQuota.toStringAsFixed(0)} Total Quota'
                  '${pendingDays > 0 ? ' • ${pendingDays.toStringAsFixed(1)}d in pending requests' : ''}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (leaveBalances.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Breakdown by Leave Type',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: context.textPrimary),
              ),
            ),
            const SizedBox(height: 12),
            ...leaveBalances.map((lb) => _LeaveTypeTile(lb, pendingRequests: pendingRequests)),
          ],
        ],
      ),
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
    final isPaid = typeName == 'Paid Leave';
    final used = (lb['leaves_taken'] as num? ?? 0).toDouble();
    final total = (lb['quota'] as num? ?? 1).toDouble();
    final remaining = (total - used).clamp(0, total);
    final pct = total > 0 ? (used / total).clamp(0.0, 1.0).toDouble() : 0.0;

    // Filter pending for this specific type
    final typePending = pendingRequests.where((r) => r['is_paid'] == isPaid).fold<double>(0, (sum, r) => sum + ((r['no_days'] as num?)?.toDouble() ?? 0.0));
    final netAvailable = (remaining - typePending).clamp(0, total);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isPaid ? AppColors.success : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPaid ? Iconsax.wallet_3 : Iconsax.calendar_remove,
                      color: isPaid ? AppColors.success : const Color(0xFFF59E0B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    typeName,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: context.textPrimary),
                  ),
                ],
              ),
              Text(
                '${netAvailable.toStringAsFixed(1)}d Net Available',
                style: TextStyle(
                  color: isPaid ? AppColors.success : const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: pct,
            backgroundColor: context.card,
            color: pct > 0.8 ? AppColors.error : AppColors.primary,
            borderRadius: BorderRadius.circular(6),
            minHeight: 6,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Used: ${used.toStringAsFixed(1)}d • Quota: ${total.toStringAsFixed(0)}d',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
              if (typePending > 0)
                Text(
                  '${typePending.toStringAsFixed(1)}d Pending Approval',
                  style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
            ],
          ),
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
  const _ApplyLeaveSheet({required this.onSuccess, required this.balance, required this.existingRequests});

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

  @override
  void dispose() {
    _fromCtrl.dispose();
    _tillCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDialog<NepaliDateTime>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: isFrom ? 'Select From Date (B.S.)' : 'Select Till Date (B.S.)',
        initial: NepaliDateTime.now(),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        final dateStr =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        if (isFrom) {
          _fromDate = dateStr;
          _fromCtrl.text = dateStr;
          if (_isHalfDay || _tillDate.isEmpty) {
            _tillDate = dateStr;
            _tillCtrl.text = dateStr;
          }
        } else {
          _tillDate = dateStr;
          _tillCtrl.text = dateStr;
        }
      });
    }
  }

  double _calculateRequestedDays() {
    if (_isHalfDay) return 0.5;
    if (_fromDate.isEmpty || _tillDate.isEmpty) return 0;
    try {
      final fromNd = NepaliDateTime.parse(_fromDate);
      final tillNd = NepaliDateTime.parse(_tillDate);
      final adFrom = fromNd.toDateTime();
      final adTill = tillNd.toDateTime();
      final utcFrom = DateTime.utc(adFrom.year, adFrom.month, adFrom.day);
      final utcTill = DateTime.utc(adTill.year, adTill.month, adTill.day);
      final diff = utcTill.difference(utcFrom).inDays + 1;
      return diff > 0 ? diff.toDouble() : 0.0;
    } catch (_) {
      return 0.0;
    }
  }

  double _calculateAvailableQuota() {
    if (widget.balance == null) return 999.0;
    final leaveBalances = (widget.balance!['leave_balances'] as List?) ?? [];
    final targetTypeName = _isPaid ? 'Paid Leave' : 'Unpaid Leave';

    dynamic targetBalance;
    for (final lb in leaveBalances) {
      if (lb['leave_type']?['name']?.toString().toLowerCase() == targetTypeName.toLowerCase()) {
        targetBalance = lb;
        break;
      }
    }

    if (targetBalance == null) return 999.0;

    final quota = (targetBalance['quota'] as num? ?? 0).toDouble();
    final taken = (targetBalance['leaves_taken'] as num? ?? 0).toDouble();
    final approvedRemaining = (quota - taken).clamp(0.0, quota);

    // Subtract pending requests of this type
    final pendingOfThisType = widget.existingRequests
        .where((r) => r['is_approved'] != true && r['is_reviewed'] != true && r['is_paid'] == _isPaid)
        .fold<double>(0.0, (sum, r) => sum + ((r['no_days'] as num?)?.toDouble() ?? 0.0));

    return (approvedRemaining - pendingOfThisType).clamp(0.0, quota);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_fromDate.isEmpty || _tillDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both From Date and Till Date'), backgroundColor: AppColors.error),
      );
      return;
    }

    final reqDays = _calculateRequestedDays();
    if (reqDays <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Till date cannot be earlier than From date'), backgroundColor: AppColors.error),
      );
      return;
    }

    final available = _calculateAvailableQuota();
    final targetTypeName = _isPaid ? 'Paid Leave' : 'Unpaid Leave';

    if (reqDays > available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quota exceeded for $targetTypeName. You requested $reqDays day(s), but only have $available day(s) available.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiService().post(
        '${AppConstants.leaveBase}/leave-requests/',
        data: {
          'subject': _subject.trim(),
          'from_date': _fromDate,
          'till_date': _tillDate,
          'remarks': _reason.trim(),
          'is_paid': _isPaid,
          'is_half_day': _isHalfDay,
          if (_isHalfDay) 'half_day_period': _halfDayPeriod,
        },
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final isExceeded = requestedDays > availableQuota;

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
                          child: const Icon(Iconsax.calendar_add, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apply for Leave',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Submit time-off request for approval',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
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

              // Live Quota Indicator Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isExceeded
                      ? AppColors.error.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isExceeded ? AppColors.error : AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isExceeded ? Iconsax.warning_2 : Iconsax.info_circle,
                      color: isExceeded ? AppColors.error : AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Available ${_isPaid ? 'Paid' : 'Unpaid'} Quota: ${availableQuota.toStringAsFixed(1)} Days',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isExceeded ? AppColors.error : context.textPrimary,
                            ),
                          ),
                          Text(
                            requestedDays > 0
                                ? 'Requested Duration: ${requestedDays.toStringAsFixed(1)} day(s)'
                                : 'Select dates to verify duration vs remaining quota',
                            style: TextStyle(
                              fontSize: 11,
                              color: isExceeded ? AppColors.error : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Subject / Purpose *',
                  hintText: 'e.g. Medical emergency, Vacation',
                  prefixIcon: Icon(Iconsax.document_text, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
                onSaved: (v) => _subject = v ?? '',
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fromCtrl,
                      readOnly: true,
                      onTap: () => _pickDate(true),
                      decoration: const InputDecoration(
                        labelText: 'From Date *',
                        prefixIcon: Icon(Iconsax.calendar_1, size: 18),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _tillCtrl,
                      readOnly: true,
                      enabled: !_isHalfDay,
                      onTap: () => _pickDate(false),
                      decoration: InputDecoration(
                        labelText: _isHalfDay ? 'Same Day' : 'Till Date *',
                        prefixIcon: const Icon(Iconsax.calendar_2, size: 18),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason & Remarks (Optional)',
                  hintText: 'Provide additional details for the reviewing manager...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Iconsax.note_text, size: 18),
                ),
                onSaved: (v) => _reason = v ?? '',
              ),
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 450;
                  return Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    children: [
                      isMobile
                          ? SwitchListTile(
                              title: const Text('Paid Leave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              subtitle: const Text('Toggle for unpaid leave', style: TextStyle(fontSize: 11)),
                              value: _isPaid,
                              onChanged: (v) => setState(() => _isPaid = v),
                              activeThumbColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                            )
                          : Expanded(
                              child: SwitchListTile(
                                title: const Text('Paid Leave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                subtitle: const Text('Toggle for unpaid leave', style: TextStyle(fontSize: 11)),
                                value: _isPaid,
                                onChanged: (v) => setState(() => _isPaid = v),
                                activeThumbColor: AppColors.primary,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                      if (isMobile) const Divider(height: 1),
                      isMobile
                          ? SwitchListTile(
                              title: const Text('Half Day Leave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              subtitle: const Text('0.5 day duration', style: TextStyle(fontSize: 11)),
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
                                title: const Text('Half Day Leave', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                subtitle: const Text('0.5 day duration', style: TextStyle(fontSize: 11)),
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

              if (_isHalfDay) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Half Day Period',
                    prefixIcon: Icon(Iconsax.clock, size: 18),
                  ),
                  initialValue: _halfDayPeriod,
                  items: const [
                    DropdownMenuItem(value: 'First Half', child: Text('First Half (Morning Session)')),
                    DropdownMenuItem(value: 'Second Half', child: Text('Second Half (Afternoon Session)')),
                  ],
                  onChanged: (v) => setState(() => _halfDayPeriod = v!),
                ),
              ],

              const SizedBox(height: 22),

              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: isExceeded
                      ? null
                      : const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                  color: isExceeded ? Colors.grey : null,
                ),
                child: ElevatedButton(
                  onPressed: (_isLoading || isExceeded) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Iconsax.send_1, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              isExceeded ? 'Quota Exceeded' : 'Submit Leave Request',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
void _showLeaveDetails(BuildContext context, Map leave, bool isAdmin) {
  String status = 'Pending';
  Color statusColor = const Color(0xFFF59E0B);
  if (leave['is_approved'] == true) {
    status = 'Approved';
    statusColor = AppColors.success;
  } else if (leave['is_reviewed'] == true) {
    status = 'Rejected';
    statusColor = AppColors.error;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 600),
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
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
                    child: Icon(Iconsax.calendar_tick, color: statusColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w800),
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: context.textPrimary),
          ),
          const SizedBox(height: 14),
          Divider(color: context.border),
          const SizedBox(height: 14),

          if (isAdmin && leave['employee_name'] != null) ...[
            _DetailRow(icon: Iconsax.user, label: 'Employee', value: leave['employee_name']),
            const SizedBox(height: 12),
          ],
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
            label: 'Total Duration',
            value: leave['is_half_day'] == true ? '0.5 Day' : '${leave['no_days']} Days',
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon: Iconsax.wallet_3,
            label: 'Leave Type',
            value: leave['is_paid'] == true ? 'Paid Leave' : 'Unpaid Leave',
            valueColor: leave['is_paid'] == true ? AppColors.success : const Color(0xFFF59E0B),
          ),

          if (leave['remarks'] != null && (leave['remarks'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Reason / Remarks', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(leave['remarks'], style: TextStyle(fontSize: 13.5, color: context.textPrimary, height: 1.5)),
          ],

          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Close Details'),
          ),
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: valueColor ?? context.textPrimary)),
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
  const _AdminEmployeeBalanceCard({required this.data, required this.onRefresh});

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
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  empName,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: context.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: context.border),
          const SizedBox(height: 8),

          ...balances.map((b) {
            final quota = (b['quota'] as num?)?.toInt() ?? 0;
            final taken = (b['leaves_taken'] as num?)?.toDouble() ?? 0;
            final remaining = (quota - taken).clamp(0, quota);
            final typeName = b['leave_type']?['name'] ?? 'Leave';
            final isPaid = typeName == 'Paid Leave';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    typeName,
                    style: TextStyle(
                      color: isPaid ? AppColors.success : const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.border),
                        ),
                        child: Text(
                          '$remaining / $quota days remaining',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Iconsax.edit, size: 16, color: AppColors.primary),
                        tooltip: 'Adjust Quota',
                        onPressed: () => _showEditQuotaDialog(context, b),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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

  void _showEditQuotaDialog(BuildContext context, Map balanceData) {
    final typeName = balanceData['leave_type']?['name'] ?? 'Leave';
    final ctrl = TextEditingController(text: balanceData['quota']?.toString() ?? '0');
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateModal) => AlertDialog(
          title: Text('Edit Quota: $typeName', style: const TextStyle(fontWeight: FontWeight.w800)),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                              content: Text('Staff leave quota updated successfully'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          onRefresh();
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${ApiService.getErrorMessage(e)}'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoading
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Quota', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
