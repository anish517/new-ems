import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/providers/date_provider.dart';
import 'add_salary_sheet.dart';

class SalaryScreen extends ConsumerStatefulWidget {
  const SalaryScreen({super.key});
  @override
  ConsumerState<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends ConsumerState<SalaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _adminTabs;
  int? _graphEmployeeId;

  // Employee View State
  Map<String, dynamic>? _mySalary;
  Map<String, dynamic>? _myNetSalary;
  List<dynamic> _myTransactions = [];
  bool _loading = true;
  String? _error;

  // Admin View State
  List<dynamic> _allSalaries = [];
  List<dynamic> _allTransactions = [];
  List<dynamic> _employees = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _adminTabs = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _adminTabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = ref.read(currentUserProvider);
      final isAdmin = user?.canManage ?? false;

      // 1. Fetch salaries
      final salaryRes =
          await ApiService().get('${AppConstants.salaryBase}/salary/');
      final salaries = salaryRes.data is List
          ? salaryRes.data as List
          : ((salaryRes.data['results'] ?? []) as List);

      // 2. Fetch employees (for mapping names)
      final empRes = await ApiService().get('/api/organization/employees/');
      final employees = empRes.data is List
          ? empRes.data as List
          : ((empRes.data['results'] ?? []) as List);

      // 3. Admin transactions
      if (isAdmin) {
        final txRes = await ApiService()
            .get('${AppConstants.salaryBase}/transactions/organization/');
        _allTransactions = txRes.data is List
            ? txRes.data as List
            : ((txRes.data['results'] ?? []) as List);
        _allSalaries = salaries;
        _employees = employees;
      }

      // 4. Employee specific data
      final empId = user?.employeeId;
      if (empId != null) {
        try {
          _mySalary = salaries.firstWhere((s) => s['employee'] == empId);
        } catch (_) {
          _mySalary = null;
        }

        if (_mySalary != null) {
          try {
            final netRes = await ApiService().get(
                '${AppConstants.salaryBase}/net-salary/${_mySalary!['id']}/');
            _myNetSalary = netRes.data;
          } catch (_) {}

          try {
            final txRes = await ApiService().get(
                '${AppConstants.salaryBase}/transactions/?employee=$empId');
            _myTransactions = txRes.data is List
                ? txRes.data as List
                : ((txRes.data['results'] ?? []) as List);
          } catch (_) {}
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = ApiService.getErrorMessage(e);
        });
      }
    }
  }

  String _empName(int empId) {
    try {
      final e = _employees.firstWhere((x) => x['id'] == empId);
      final u = e['user'] ?? {};
      final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      return name.isNotEmpty ? name : 'Employee #$empId';
    } catch (_) {
      return 'Employee #$empId';
    }
  }

  String _fmt(dynamic val) {
    if (val == null) return 'N/A';
    final n = double.tryParse(val.toString()) ?? 0;
    return 'NPR ${n.toStringAsFixed(0)}';
  }

  void _showAddBaseSalaryDialog(BuildContext context, int empId, String empName) async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: AddSalarySheet(employeeId: empId, employeeName: empName),
            ),
          ),
        ),
      );
      _loadData();
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => AddSalarySheet(employeeId: empId, employeeName: empName),
      );
      _loadData();
    }
  }

  void _promptAddBaseSalary() async {
    final configuredEmpIds = _allSalaries.map((s) => s['employee']).toSet();
    final unconfigured = _employees.where((e) => !configuredEmpIds.contains(e['id'])).toList();

    if (unconfigured.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All current employees already have a base salary configured! You can edit them below.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final selectedEmp = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select Employee to Configure Salary', style: TextStyle(fontWeight: FontWeight.w800)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        children: unconfigured.map((e) {
          final u = e['user'] ?? {};
          final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, e as Map<String, dynamic>),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'E', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Text(name.isNotEmpty ? name : 'Employee #${e['id']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );

    if (selectedEmp != null && mounted) {
      final u = selectedEmp['user'] ?? {};
      final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
      _showAddBaseSalaryDialog(context, selectedEmp['id'] as int, name.isNotEmpty ? name : 'Employee #${selectedEmp['id']}');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadData());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;

    // Calculate total base payroll sum
    double totalBasePayroll = 0;
    for (final s in _allSalaries) {
      final b = double.tryParse(s['basic_salary']?.toString() ?? '0') ?? 0;
      final r = double.tryParse(s['remote_salary']?.toString() ?? '0') ?? 0;
      totalBasePayroll += (b + r);
    }

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showIssueSalarySheet(context),
              backgroundColor: AppColors.primary,
              elevation: 6,
              icon: const Icon(Iconsax.money_send, color: Colors.white, size: 20),
              label: const Text(
                'Issue Salary',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _error != null
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      margin: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.warning_2, color: AppColors.error, size: 48),
                          const SizedBox(height: 14),
                          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: context.textPrimary)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Iconsax.refresh, size: 16),
                            label: const Text('Retry Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Top Header Card ──────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: context.border, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: LayoutBuilder(
                            builder: (context, headerConstraints) {
                              final isHeaderTight = headerConstraints.maxWidth < 650;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(isHeaderTight ? 9 : 12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Icon(Iconsax.wallet_money, color: AppColors.primary, size: isHeaderTight ? 20 : 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                'Payroll & Compensation',
                                                style: TextStyle(
                                                  fontSize: isHeaderTight ? 17 : 20,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: -0.4,
                                                  color: context.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${_allSalaries.length} Active',
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Iconsax.refresh, size: 18),
                                        tooltip: 'Refresh Payroll',
                                        onPressed: _loadData,
                                        style: IconButton.styleFrom(
                                          backgroundColor: context.card,
                                          side: BorderSide(color: context.border),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                      ),
                                      if (isAdmin && !isHeaderTight) ...[
                                        const SizedBox(width: 10),
                                        ElevatedButton.icon(
                                          onPressed: () => _showIssueSalarySheet(context),
                                          icon: const Icon(Iconsax.money_send, size: 18, color: Colors.white),
                                          label: const Text('Issue Salary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (isAdmin && isHeaderTight) ...[
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showIssueSalarySheet(context),
                                        icon: const Icon(Iconsax.money_send, size: 18, color: Colors.white),
                                        label: const Text('Issue Salary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    'Manage company payroll, statutory deductions (TDS, SSF, EPF) & payslips',
                                    style: TextStyle(fontSize: isHeaderTight ? 11.5 : 12, color: AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Executive Payroll KPI Cards (Admin) ──────────────
                        if (isAdmin) ...[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isTight = constraints.maxWidth < 740;

                              return Row(
                                children: [
                                  Expanded(
                                    child: _buildKpiCard(
                                      'Monthly Base Pool',
                                      'NPR ${(totalBasePayroll / 1000).toStringAsFixed(0)}k',
                                      Iconsax.coin_1,
                                      AppColors.primary,
                                      isTight,
                                    ),
                                  ),
                                  SizedBox(width: isTight ? 6 : 12),
                                  Expanded(
                                    child: _buildKpiCard(
                                      'Configured Staff',
                                      '${_allSalaries.length} Staff',
                                      Iconsax.profile_2user,
                                      const Color(0xFF0284C7),
                                      isTight,
                                    ),
                                  ),
                                  SizedBox(width: isTight ? 6 : 12),
                                  Expanded(
                                    child: _buildKpiCard(
                                      'Issued Payouts',
                                      '${_allTransactions.length} Paid',
                                      Iconsax.receipt_2_1,
                                      AppColors.success,
                                      isTight,
                                    ),
                                  ),
                                  SizedBox(width: isTight ? 6 : 12),
                                  Expanded(
                                    child: _buildKpiCard(
                                      'Statutory Taxes',
                                      'TDS • SSF • EPF',
                                      Iconsax.shield_tick,
                                      const Color(0xFF8B5CF6),
                                      isTight,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Admin Segmented Tabs ───────────────────────────
                          Container(
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.border),
                            ),
                            child: TabBar(
                              controller: _adminTabs,
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              labelColor: AppColors.primary,
                              unselectedLabelColor: AppColors.textSecondary,
                              indicatorColor: AppColors.primary,
                              indicatorWeight: 3,
                              tabs: const [
                                Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Iconsax.wallet_3, size: 18),
                                      SizedBox(width: 8),
                                      Text('Base Salaries', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Iconsax.receipt_item, size: 18),
                                      SizedBox(width: 8),
                                      Text('Issue & History', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                                Tab(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Iconsax.chart_2, size: 18),
                                      SizedBox(width: 8),
                                      Text('Analytics & Trends', style: TextStyle(fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Tabs Content
                          SizedBox(
                            height: 750,
                            child: TabBarView(
                              controller: _adminTabs,
                              children: [
                                _buildAdminSalariesTab(),
                                _buildAdminTransactionsTab(),
                                _buildAnalyticsTab(),
                              ],
                            ),
                          ),
                        ] else ...[
                          _buildEmployeeView(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String count, IconData icon, Color color, bool isTight) {
    if (isTight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 5),
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
                    fontSize: 10,
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
                    fontSize: 18,
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

  // ── Tab 1: Base Salaries ──────────────────────────────────────────────────
  Widget _buildAdminSalariesTab() {
    final filteredSalaries = _allSalaries.where((s) {
      if (_searchQuery.isEmpty) return true;
      final empId = s['employee'] as int? ?? 0;
      final name = _empName(empId).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Distribution Chart Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Company Salary Distribution',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                    const Text('Basic Pay (NPR)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _buildAllEmployeesSalaryChart(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search & Action Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search employee salary records...',
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
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _promptAddBaseSalary,
                icon: const Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                label: const Text('Add Base Salary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (filteredSalaries.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.border),
              ),
              child: const Text('No matching salary records found.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredSalaries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final s = filteredSalaries[i];
                final empId = s['employee'] as int? ?? 0;
                final name = _empName(empId);

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'E',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Basic: ${_fmt(s['basic_salary'])}',
                                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Remote: ${_fmt(s['remote_salary'])}',
                                    style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.eye, size: 20, color: AppColors.primary),
                        tooltip: 'View Current Month Breakdown',
                        onPressed: () => _showEmployeeSalaryDetail(ctx, s, empId),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.edit, size: 20, color: AppColors.textSecondary),
                        tooltip: 'Edit Base Salary',
                        onPressed: () => _showEditBaseSalarySheet(ctx, s),
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

  Widget _buildAllEmployeesSalaryChart() {
    if (_allSalaries.isEmpty) return const SizedBox.shrink();

    final barGroups = <BarChartGroupData>[];
    double maxY = 0;

    for (int i = 0; i < _allSalaries.length; i++) {
      final s = _allSalaries[i];
      final basic = (double.tryParse(s['basic_salary']?.toString() ?? '0') ?? 0);
      if (basic > maxY) maxY = basic;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: basic,
              color: AppColors.primary,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    maxY = maxY + (maxY * 0.15);
    if (maxY == 0) maxY = 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: _allSalaries.length <= 8 ? 1.0 : (_allSalaries.length / 8).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= _allSalaries.length) return const SizedBox.shrink();
                final empId = _allSalaries[i]['employee'] as int? ?? 0;
                final name = _empName(empId);
                final shortName = name.split(' ').first;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    shortName,
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final empId = _allSalaries[group.x.toInt()]['employee'] as int? ?? 0;
              final name = _empName(empId);
              return BarTooltipItem(
                '$name\nNPR ${rod.toY.toInt()}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showEmployeeSalaryDetail(BuildContext ctx, Map salary, int empId) {
    final salaryId = salary['id'] as int? ?? 0;
    if (salaryId == 0) return;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EmployeeSalaryDetailSheet(
        salaryId: salaryId,
        empName: _empName(empId),
        basicSalary: _fmt(salary['basic_salary']),
        remoteSalary: _fmt(salary['remote_salary']),
      ),
    );
  }

  // ── Tab 2: Issue & History ────────────────────────────────────────────────
  Widget _buildAdminTransactionsTab() {
    if (_allTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border),
        ),
        child: const Text('No salary disbursements recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.separated(
      itemCount: _allTransactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final tx = _allTransactions[i];
        return _TransactionTile(tx, empName: _empName(tx['employee'] ?? 0), isAdmin: true);
      },
    );
  }

  // ── Tab 3: Analytics & Trends ─────────────────────────────────────────────
  Widget _buildAnalyticsTab() {
    final salariesWithEmployees = _allSalaries.where((s) => s['employee'] != null).toList();
    final graphTransactions = _graphEmployeeId != null
        ? (_allTransactions.where((tx) => tx['employee'] == _graphEmployeeId).toList()
          ..sort((a, b) => ((a as Map)['date'] ?? '').compareTo((b as Map)['date'] ?? '')))
        : <dynamic>[];

    final netSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    final months = <int, String>{};

    double sumNet = 0;
    double sumTds = 0;
    double sumSsf = 0;
    double sumEpf = 0;
    double sumTotalExpense = 0;

    for (var i = 0; i < graphTransactions.length; i++) {
      final tx = graphTransactions[i] as Map;
      final net = (tx['net_salary'] ?? 0).toDouble();
      final exp = (tx['total_expense'] ?? net).toDouble();
      final tds = (tx['transaction_tds'] ?? 0).toDouble();
      final ssf = (tx['transaction_ssf'] ?? 0).toDouble();
      final epf = (tx['transaction_epf'] ?? 0).toDouble();

      final dateStr = tx['date'] as String? ?? '';
      months[i] = dateStr;
      netSpots.add(FlSpot(i.toDouble(), net));
      expenseSpots.add(FlSpot(i.toDouble(), exp));

      sumNet += net;
      sumTds += tds;
      sumSsf += ssf;
      sumEpf += epf;
      sumTotalExpense += exp;
    }

    final sumOther = sumTotalExpense - (sumNet + sumTds + sumSsf + sumEpf);
    final pieDataReady = sumTotalExpense > 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.border),
            ),
            child: DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _graphEmployeeId,
              hint: const Text('Select Employee to View Salary Trends'),
              isExpanded: true,
              items: salariesWithEmployees
                  .map((s) => DropdownMenuItem<int>(
                        value: s['employee'] as int,
                        child: Text(_empName(s['employee'] as int)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _graphEmployeeId = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Iconsax.user, size: 20),
                border: InputBorder.none,
                filled: false,
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_graphEmployeeId == null)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.border),
              ),
              child: const Column(
                children: [
                  Icon(Iconsax.chart_2, size: 48, color: AppColors.primary),
                  SizedBox(height: 12),
                  Text(
                    'Select an employee above to analyze payment history and deductions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else if (graphTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.border),
              ),
              child: const Text('No transaction records found for this employee.', style: TextStyle(color: AppColors.textSecondary)),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      const Text('Net Salary', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 20),
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.warning, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      const Text('Total Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: (netSpots.length - 1).toDouble().clamp(0, double.infinity),
                        gridData: FlGridData(
                          show: true,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(color: context.border, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 56,
                              getTitlesWidget: (v, meta) => Text(
                                'NPR ${(v / 1000).toStringAsFixed(0)}k',
                                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: netSpots.length <= 6 ? 1.0 : (netSpots.length / 6).ceilToDouble(),
                              getTitlesWidget: (v, meta) {
                                final idx = v.toInt();
                                return Text(
                                  months[idx] ?? '',
                                  style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: netSpots,
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(show: true, color: AppColors.primary.withValues(alpha: 0.10)),
                          ),
                          LineChartBarData(
                            spots: expenseSpots,
                            isCurved: true,
                            color: AppColors.warning,
                            barWidth: 2,
                            dotData: const FlDotData(show: true),
                            dashArray: [5, 3],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (pieDataReady) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 160,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 36,
                            sections: [
                              if (sumNet > 0)
                                PieChartSectionData(
                                  color: AppColors.primary,
                                  value: sumNet,
                                  title: '${((sumNet / sumTotalExpense) * 100).toStringAsFixed(0)}%',
                                  radius: 46,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (sumTds > 0)
                                PieChartSectionData(
                                  color: AppColors.error,
                                  value: sumTds,
                                  title: '${((sumTds / sumTotalExpense) * 100).toStringAsFixed(0)}%',
                                  radius: 46,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (sumSsf > 0)
                                PieChartSectionData(
                                  color: AppColors.success,
                                  value: sumSsf,
                                  title: '${((sumSsf / sumTotalExpense) * 100).toStringAsFixed(0)}%',
                                  radius: 46,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (sumEpf > 0)
                                PieChartSectionData(
                                  color: const Color(0xFF8B5CF6),
                                  value: sumEpf,
                                  title: '${((sumEpf / sumTotalExpense) * 100).toStringAsFixed(0)}%',
                                  radius: 46,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              if (sumOther > 0)
                                PieChartSectionData(
                                  color: AppColors.warning,
                                  value: sumOther,
                                  title: '${((sumOther / sumTotalExpense) * 100).toStringAsFixed(0)}%',
                                  radius: 46,
                                  titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PieLegendIndicator(color: AppColors.primary, text: 'Net Salary', amount: sumNet),
                          const SizedBox(height: 6),
                          _PieLegendIndicator(color: AppColors.error, text: 'TDS (Tax)', amount: sumTds),
                          const SizedBox(height: 6),
                          _PieLegendIndicator(color: AppColors.success, text: 'SSF', amount: sumSsf),
                          const SizedBox(height: 6),
                          _PieLegendIndicator(color: const Color(0xFF8B5CF6), text: 'EPF', amount: sumEpf),
                          if (sumOther > 0) ...[
                            const SizedBox(height: 6),
                            _PieLegendIndicator(color: AppColors.warning, text: 'Other Deductions', amount: sumOther),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              'Past Disbursements (${graphTransactions.length})',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
            ),
            const SizedBox(height: 10),
            ...graphTransactions.map((tx) => _TransactionTile(
                  tx as Map<String, dynamic>,
                  empName: _empName(_graphEmployeeId!),
                  isAdmin: true,
                )),
          ],
        ],
      ),
    );
  }

  // ── Employee Self-Service View ────────────────────────────────────────────
  Widget _buildEmployeeView() {
    if (_mySalary == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.border),
        ),
        child: const Column(
          children: [
            Icon(Iconsax.info_circle, size: 48, color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'No salary configuration found for your account.\nPlease contact your HR Administrator.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Payslip Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.04),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Month Estimated Payout',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Text(
                _fmt(_myNetSalary?['net_salary'] ?? _mySalary?['basic_salary']),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: context.border),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _PayslipItem('Basic Salary', _fmt(_mySalary?['basic_salary'])),
                  _PayslipItem('Remote Allowance', _fmt(_mySalary?['remote_salary'])),
                  _PayslipItem('Net Payable', _fmt(_myNetSalary?['net_salary'] ?? _mySalary?['basic_salary'])),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Attendance & Deductions Breakdown
        Text(
          'This Month\'s Attendance & Leaves',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border),
          ),
          child: Column(
            children: [
              _InfoRow(Iconsax.calendar_tick, 'Days Present', '${_myNetSalary?['no_of_days_present'] ?? '—'} days'),
              _InfoRow(Iconsax.sun_1, 'Public Holidays', '${_myNetSalary?['holidays'] ?? '—'} days'),
              _InfoRow(Iconsax.calendar_remove, 'Paid Leaves', '${_myNetSalary?['paid_leaves'] ?? '—'} days'),
              _InfoRow(Iconsax.calendar_remove, 'Unpaid Leaves', '${_myNetSalary?['unpaid_leaves'] ?? '—'} days'),
              _InfoRow(Iconsax.clock, 'Half Leaves', '${_myNetSalary?['half_leaves'] ?? '—'} days'),
            ],
          ),
        ),

        if (_myTransactions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Payment & Slip History (${_myTransactions.length})',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
          const SizedBox(height: 10),
          ..._myTransactions.map((tx) => _TransactionTile(tx)),
        ],
      ],
    );
  }

  void _showEditBaseSalarySheet(BuildContext ctx, Map salaryRecord) {
    final basicCtrl = TextEditingController(text: salaryRecord['basic_salary'].toString());
    final remoteCtrl = TextEditingController(text: salaryRecord['remote_salary'].toString());
    bool saving = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(builder: (context, setStateModal) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Edit Base Salary: ${_empName(salaryRecord['employee'])}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Iconsax.close_circle, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: basicCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Basic Salary (NPR)',
                  prefixIcon: Icon(Iconsax.money, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remoteCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Remote Allowance (NPR)',
                  prefixIcon: Icon(Iconsax.buildings, size: 18),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        setStateModal(() => saving = true);
                        try {
                          await ApiService().patch(
                            '${AppConstants.salaryBase}/salary/${salaryRecord['id']}/',
                            data: {
                              'basic_salary': basicCtrl.text.isEmpty ? '0' : basicCtrl.text,
                              'remote_salary': remoteCtrl.text.isEmpty ? '0' : remoteCtrl.text,
                            },
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadData();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ApiService.getErrorMessage(e))),
                            );
                          }
                        } finally {
                          if (context.mounted) setStateModal(() => saving = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Update Base Salary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showIssueSalarySheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => _CreateSalarySheet(
        salaries: _allSalaries,
        employees: _employees,
        onCreated: _loadData,
      ),
    );
  }
}

// ─── Shared Components ────────────────────────────────────────────────────────
class _CreateSalarySheet extends StatefulWidget {
  final List salaries;
  final List employees;
  final VoidCallback onCreated;
  const _CreateSalarySheet({
    required this.salaries,
    required this.employees,
    required this.onCreated,
  });
  @override
  State<_CreateSalarySheet> createState() => _CreateSalarySheetState();
}

class _CreateSalarySheetState extends State<_CreateSalarySheet> {
  List _fiscalYears = [];
  int? _selSalaryId;
  int? _selFiscalYear;
  String _date = () {
    final now = NepaliDateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }();
  Map<String, dynamic>? _netSalaryInfo;
  final TextEditingController _netSalaryController = TextEditingController();
  final TextEditingController _incentiveController = TextEditingController(text: '0');
  final TextEditingController _bonusController = TextEditingController(text: '0');
  final TextEditingController _holidaysController = TextEditingController();
  final TextEditingController _ssfController = TextEditingController();
  final TextEditingController _epfController = TextEditingController();
  final TextEditingController _tdsController = TextEditingController();
  String _emailPreference = 'official';
  bool _loading = true;
  bool _saving = false;

  @override
  void dispose() {
    _netSalaryController.dispose();
    _incentiveController.dispose();
    _bonusController.dispose();
    _holidaysController.dispose();
    _ssfController.dispose();
    _epfController.dispose();
    _tdsController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadFiscalYears();
  }

  Future<void> _loadFiscalYears() async {
    try {
      final fRes = await ApiService().get('/api/fiscal-year/');
      if (!mounted) return;
      setState(() {
        _fiscalYears = fRes.data is List ? fRes.data : (fRes.data['results'] ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNetSalary({bool clear = true}) async {
    if (_selSalaryId == null) return;
    if (clear) setState(() => _netSalaryInfo = null);
    try {
      String url = '/api/salary-management/net-salary/$_selSalaryId/?date=$_date';
      if (_holidaysController.text.trim().isNotEmpty) url += '&holidays=${_holidaysController.text.trim()}';
      if (_ssfController.text.trim().isNotEmpty) url += '&ssf=${_ssfController.text.trim()}';
      if (_epfController.text.trim().isNotEmpty) url += '&epf=${_epfController.text.trim()}';
      if (_tdsController.text.trim().isNotEmpty) url += '&tds=${_tdsController.text.trim()}';
      if (_incentiveController.text.trim().isNotEmpty) url += '&incentive=${_incentiveController.text.trim()}';
      if (_bonusController.text.trim().isNotEmpty) url += '&bonus=${_bonusController.text.trim()}';
      final res = await ApiService().get(url);
      if (mounted) {
        setState(() {
          _netSalaryInfo = res.data;
          _netSalaryController.text = (_netSalaryInfo!['net_salary'] ?? '').toString();
          _holidaysController.text = (_netSalaryInfo!['holidays'] ?? '').toString();
          _tdsController.text = (_netSalaryInfo!['tds'] ?? '').toString();
          _ssfController.text = (_netSalaryInfo!['ssf'] ?? '').toString();
          _epfController.text = (_netSalaryInfo!['epf'] ?? '').toString();
        });
      }
    } catch (_) {}
  }

  String _empName(int empId) {
    try {
      final e = widget.employees.firstWhere((x) => x['id'] == empId);
      final u = e['user'] ?? {};
      return '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    } catch (_) {
      return 'Emp #$empId';
    }
  }

  Future<void> _save() async {
    if (_selSalaryId == null || _selFiscalYear == null) return;
    setState(() => _saving = true);
    try {
      await ApiService().post('/api/salary-management/transactions/organization/', data: {
        'salary': _selSalaryId,
        'fiscal_year': _selFiscalYear,
        'date': _date,
        'status': true,
        'net_salary': _netSalaryController.text.trim(),
        'incentive': _incentiveController.text.trim(),
        'bonus': _bonusController.text.trim(),
        'email_preference': _emailPreference,
        'holidays': _holidaysController.text.trim(),
        'ssf': _ssfController.text.trim(),
        'epf': _epfController.text.trim(),
        'tds': _tdsController.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiService.getErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildEditableRow(IconData icon, String label, TextEditingController controller, {Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: context.textSecondary),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: context.textSecondary, fontSize: 13)),
            ],
          ),
          SizedBox(
            width: 90,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              style: TextStyle(color: context.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onChanged: onChanged ?? (_) => _loadNetSalary(clear: false),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Issue Monthly Salary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Iconsax.close_circle, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.salaries.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No salary records found. Please configure base salaries for employees first.',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            )
          else ...[
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _selSalaryId,
              hint: const Text('Select Employee'),
              isExpanded: true,
              items: widget.salaries
                  .fold<List<dynamic>>([], (prev, curr) {
                    if (!prev.any((e) => e['id'] == curr['id'])) prev.add(curr);
                    return prev;
                  })
                  .map((s) => DropdownMenuItem<int>(
                        value: s['id'],
                        child: Text('${_empName(s['employee'])} (Base: ${s['basic_salary']})'),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(() => _selSalaryId = v);
                _loadNetSalary();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              // ignore: deprecated_member_use
              value: _selFiscalYear,
              hint: const Text('Select Fiscal Year'),
              isExpanded: true,
              items: _fiscalYears
                  .fold<List<dynamic>>([], (prev, curr) {
                    if (!prev.any((e) => e['id'] == curr['id'])) prev.add(curr);
                    return prev;
                  })
                  .map((f) => DropdownMenuItem<int>(
                        value: f['id'],
                        child: Text(f['title'] ?? ''),
                      ))
                  .toList(),
              onChanged: _fiscalYears.isEmpty ? null : (v) => setState(() => _selFiscalYear = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _date,
              decoration: const InputDecoration(
                labelText: 'Month Date (B.S. YYYY-MM-DD)',
                prefixIcon: Icon(Iconsax.calendar, size: 18),
              ),
              keyboardType: TextInputType.datetime,
              onChanged: (v) {
                _date = v;
                if (v.length == 10) _loadNetSalary();
              },
            ),
            const SizedBox(height: 16),
            if (_netSalaryInfo != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border.all(color: context.border),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _InfoRow(Iconsax.calendar_tick, 'Days Present', '${_netSalaryInfo!['no_of_days_present']}'),
                    _InfoRow(Iconsax.calendar_remove, 'Paid Leaves', '${_netSalaryInfo!['paid_leaves']}'),
                    _InfoRow(Iconsax.calendar_remove, 'Unpaid Leaves', '${_netSalaryInfo!['unpaid_leaves']}'),
                    _InfoRow(Iconsax.clock, 'Half Leaves', '${_netSalaryInfo!['half_leaves'] ?? 0}'),
                    Divider(color: context.border),
                    _buildEditableRow(Iconsax.calendar, 'Public Holidays', _holidaysController),
                    _buildEditableRow(Iconsax.award, 'Incentive (NPR)', _incentiveController, onChanged: (_) {
                      _tdsController.clear();
                      _loadNetSalary(clear: false);
                    }),
                    _buildEditableRow(Iconsax.gift, 'Bonus (NPR)', _bonusController, onChanged: (_) {
                      _tdsController.clear();
                      _loadNetSalary(clear: false);
                    }),
                    _buildEditableRow(Iconsax.minus, 'Tax (TDS)', _tdsController),
                    _buildEditableRow(Iconsax.minus, 'SSF Deduction', _ssfController),
                    _buildEditableRow(Iconsax.minus, 'EPF Deduction', _epfController),
                    Divider(color: context.border),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Iconsax.money_recive, size: 20, color: AppColors.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Net Salary Payable',
                                    style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: TextFormField(
                              controller: _netSalaryController,
                              keyboardType: TextInputType.number,
                              style: TextStyle(fontWeight: FontWeight.w900, color: context.textPrimary),
                              decoration: InputDecoration(
                                prefixText: 'NPR ',
                                prefixStyle: TextStyle(color: context.textSecondary),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _emailPreference,
              decoration: const InputDecoration(
                labelText: 'Send Salary Slip Email To',
                prefixIcon: Icon(Iconsax.sms),
              ),
              items: const [
                DropdownMenuItem(value: 'official', child: Text('Official Email')),
                DropdownMenuItem(value: 'personal', child: Text('Personal Email')),
                DropdownMenuItem(value: 'both', child: Text('Both Emails')),
                DropdownMenuItem(value: 'none', child: Text('Do Not Send')),
              ],
              onChanged: (v) => setState(() => _emailPreference = v!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_saving || _selSalaryId == null || _selFiscalYear == null) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Issue Salary Payment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Employee Salary Detail Sheet (Admin) ────────────────────────────────────
class _EmployeeSalaryDetailSheet extends StatefulWidget {
  final int salaryId;
  final String empName;
  final String basicSalary;
  final String remoteSalary;
  const _EmployeeSalaryDetailSheet({
    required this.salaryId,
    required this.empName,
    required this.basicSalary,
    required this.remoteSalary,
  });
  @override
  State<_EmployeeSalaryDetailSheet> createState() => _EmployeeSalaryDetailSheetState();
}

class _EmployeeSalaryDetailSheetState extends State<_EmployeeSalaryDetailSheet> {
  Map<String, dynamic>? _netInfo;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService().get(
        '${AppConstants.salaryBase}/net-salary/${widget.salaryId}/',
      );
      if (mounted) {
        setState(() {
          _netInfo = res.data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.getErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: const Icon(Iconsax.user, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.empName,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: context.textPrimary),
                    ),
                    const Text('Current Month Salary Estimation', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Iconsax.close_circle, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: context.border),
          const SizedBox(height: 12),
          _InfoRow(Iconsax.money_4, 'Basic Salary', widget.basicSalary),
          _InfoRow(Iconsax.buildings_2, 'Remote Allowance', widget.remoteSalary),
          const SizedBox(height: 8),
          Divider(color: context.border),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.error)),
            )
          else if (_netInfo != null) ...[
            _InfoRow(Iconsax.calendar_tick, 'Days Present', '${_netInfo!['no_of_days_present'] ?? 0} days'),
            _InfoRow(Iconsax.sun_1, 'Public Holidays', '${_netInfo!['holidays'] ?? 0} days'),
            _InfoRow(Iconsax.calendar_remove, 'Paid Leaves Taken', '${_netInfo!['paid_leaves'] ?? 0} days'),
            _InfoRow(Iconsax.calendar_remove, 'Unpaid Leaves Taken', '${_netInfo!['unpaid_leaves'] ?? 0} days'),
            _InfoRow(Iconsax.clock, 'Half Leaves Taken', '${_netInfo!['half_leaves'] ?? 0} days'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Estimated Net Payout', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
                  Text(
                    'NPR ${_netInfo!['net_salary'] ?? '0'}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.success),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _PayslipItem extends StatelessWidget {
  final String label, value;
  const _PayslipItem(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(color: context.textPrimary, fontSize: 13))),
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary, fontSize: 13)),
          ],
        ),
      );
}

class _TransactionTile extends StatelessWidget {
  final Map tx;
  final String? empName;
  final bool isAdmin;
  const _TransactionTile(this.tx, {this.empName, this.isAdmin = false});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.success.withValues(alpha: 0.12),
                  radius: 18,
                  child: const Icon(Iconsax.money_recive, color: AppColors.success, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (empName != null && empName != 'Employee #0')
                        Text(
                          empName!,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: context.textPrimary),
                        ),
                      Text(
                        'Date: ${tx['date'] ?? '—'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  'NPR ${tx['net_salary'] ?? '—'}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.success, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: context.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MiniStat(icon: Iconsax.calendar_tick, label: 'Present', value: '${tx['no_of_days_present'] ?? 0}d')),
                Expanded(child: _MiniStat(icon: Iconsax.sun_1, label: 'Holidays', value: '${tx['holidays'] ?? 0}d')),
                Expanded(child: _MiniStat(icon: Iconsax.calendar_remove, label: 'Paid L.', value: '${tx['paid_leaves'] ?? 0}d')),
                Expanded(child: _MiniStat(icon: Iconsax.calendar_remove, label: 'Unpaid L.', value: '${tx['unpaid_leaves'] ?? 0}d')),
                Expanded(child: _MiniStat(icon: Iconsax.clock, label: 'Half L.', value: '${tx['half_leaves'] ?? 0}d')),
              ],
            ),
          ],
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _MiniStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: context.textPrimary)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), textAlign: TextAlign.center),
        ],
      );
}

class _PieLegendIndicator extends StatelessWidget {
  final Color color;
  final String text;
  final double amount;

  const _PieLegendIndicator({
    required this.color,
    required this.text,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
          ),
        ),
        Text(
          'NPR ${amount.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: context.textPrimary),
        ),
      ],
    );
  }
}
