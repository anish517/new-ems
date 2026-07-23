import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';

class SalaryScreen extends ConsumerStatefulWidget {
  const SalaryScreen({super.key});
  @override
  ConsumerState<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends ConsumerState<SalaryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _adminTabs;

  // Employee View State
  Map<String, dynamic>? _mySalary;
  Map<String, dynamic>? _myNetSalary;
  List _myTransactions = [];
  bool _loading = true;
  String? _error;

  // Admin View State
  List _allSalaries = [];
  List _allTransactions = [];
  List _employees = [];

  @override
  void initState() {
    super.initState();
    _adminTabs = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _adminTabs.dispose();
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
        // Find own salary
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
      return '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
    } catch (_) {
      return 'Employee #$empId';
    }
  }

  String _fmt(dynamic val) {
    if (val == null) return 'N/A';
    final n = double.tryParse(val.toString()) ?? 0;
    return 'NPR ${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary Management'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
        bottom: isAdmin
            ? TabBar(
                controller: _adminTabs,
                tabs: const [
                  Tab(text: 'Base Salaries'),
                  Tab(text: 'Issue & History'),
                ],
              )
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.error, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _loadData, child: const Text('Retry')),
                ]))
              : isAdmin
                  ? TabBarView(
                      controller: _adminTabs,
                      children: [
                        _buildAdminSalariesTab(),
                        _buildAdminTransactionsTab(),
                      ],
                    )
                  : _buildEmployeeView(),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showIssueSalarySheet(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Issue Salary',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildAdminSalariesTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _allSalaries.isEmpty
          ? const Center(child: Text('No salary configurations found.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16).copyWith(bottom: 80),
              itemCount: _allSalaries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final s = _allSalaries[i];
                final empId = s['employee'] as int? ?? 0;
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.primaryDark,
                      child: Icon(Iconsax.money_recive,
                          color: Colors.white, size: 18),
                    ),
                    title: Text(_empName(empId),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'Basic: ${_fmt(s['basic_salary'])}  |  Remote: ${_fmt(s['remote_salary'])}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined,
                              color: AppColors.primary, size: 20),
                          tooltip: 'View Salary Detail',
                          onPressed: () =>
                              _showEmployeeSalaryDetail(ctx, s, empId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: AppColors.textSecondary, size: 20),
                          tooltip: 'Edit Base Salary',
                          onPressed: () => _showEditBaseSalarySheet(ctx, s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showEmployeeSalaryDetail(BuildContext ctx, Map salary, int empId) {
    final salaryId = salary['id'] as int? ?? 0;
    if (salaryId == 0) return;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EmployeeSalaryDetailSheet(
        salaryId: salaryId,
        empName: _empName(empId),
        basicSalary: _fmt(salary['basic_salary']),
        remoteSalary: _fmt(salary['remote_salary']),
      ),
    );
  }

  Widget _buildAdminTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: _allTransactions.isEmpty
          ? const Center(child: Text('No transactions issued yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16).copyWith(bottom: 80),
              itemCount: _allTransactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final tx = _allTransactions[i];
                return _TransactionTile(tx,
                    empName: _empName(tx['employee'] ?? 0));
              },
            ),
    );
  }

  Widget _buildEmployeeView() {
    if (_mySalary == null) {
      return const Center(
          child: Text('No salary record found.\nContact your admin.',
              textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Payslip card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A5F), Color(0xFF0F2D4A)]),
                borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Current Month Salary Estimate',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                  _fmt(_myNetSalary?['net_salary'] ??
                      _mySalary?['basic_salary']),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24, height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _PayslipItem('Basic', _fmt(_mySalary?['basic_salary'])),
                _PayslipItem('Remote', _fmt(_mySalary?['remote_salary'])),
                _PayslipItem(
                    'Net',
                    _fmt(_myNetSalary?['net_salary'] ??
                        _mySalary?['basic_salary'])),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // Breakdown
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('This Month\'s Breakdown',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(height: 12),
          _InfoRow(Iconsax.calendar, 'Days Present',
              '${_myNetSalary?['no_of_days_present'] ?? '—'}'),
          _InfoRow(
              Iconsax.sun_1, 'Holidays', '${_myNetSalary?['holidays'] ?? '—'}'),
          _InfoRow(Iconsax.calendar_remove, 'Paid Leaves',
              '${_myNetSalary?['paid_leaves'] ?? '—'}'),
          _InfoRow(Iconsax.calendar_remove, 'Unpaid Leaves',
              '${_myNetSalary?['unpaid_leaves'] ?? '—'}'),

          // Transactions history
          if (_myTransactions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Payment History',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(height: 12),
            ..._myTransactions.map((tx) => _TransactionTile(tx)),
          ],
        ]),
      ),
    );
  }

  void _showEditBaseSalarySheet(BuildContext ctx, Map salaryRecord) {
    final basicCtrl =
        TextEditingController(text: salaryRecord['basic_salary'].toString());
    final remoteCtrl =
        TextEditingController(text: salaryRecord['remote_salary'].toString());
    bool saving = false;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      builder: (sheetCtx) => StatefulBuilder(builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    'Edit Base Salary for ${_empName(salaryRecord['employee'])}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                  controller: basicCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Basic Salary (NPR)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remoteCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Remote Salary (NPR)'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          try {
                            await ApiService().patch(
                                '${AppConstants.salaryBase}/salary/${salaryRecord['id']}/',
                                data: {
                                  'basic_salary': basicCtrl.text,
                                  'remote_salary': remoteCtrl.text,
                                });
                            if (context.mounted) {
                              Navigator.pop(context);
                              _loadData();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(ApiService.getErrorMessage(e))));
                            }
                          } finally {
                            if (context.mounted) setState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const CircularProgressIndicator()
                      : const Text('Save Salary'),
                )
              ]),
        );
      }),
    );
  }

  void _showIssueSalarySheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
  const _CreateSalarySheet(
      {required this.salaries,
      required this.employees,
      required this.onCreated});
  @override
  State<_CreateSalarySheet> createState() => _CreateSalarySheetState();
}

class _CreateSalarySheetState extends State<_CreateSalarySheet> {
  List _fiscalYears = [];
  int? _selSalaryId;
  int? _selFiscalYear;
  // Default to today in Nepali calendar YYYY-MM-DD format
  String _date = () {
    final now = NepaliDateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }();
  Map<String, dynamic>? _netSalaryInfo;
  final TextEditingController _netSalaryController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void dispose() {
    _netSalaryController.dispose();
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
        _fiscalYears =
            fRes.data is List ? fRes.data : (fRes.data['results'] ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadNetSalary() async {
    if (_selSalaryId == null) return;
    setState(() => _netSalaryInfo = null);
    try {
      final res = await ApiService()
          .get('/api/salary-management/net-salary/$_selSalaryId/?date=$_date');
      if (mounted) {
        setState(() {
          _netSalaryInfo = res.data;
          _netSalaryController.text = (_netSalaryInfo!['net_salary'] ?? '').toString();
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
      await ApiService()
          .post('/api/salary-management/transactions/organization/', data: {
        'salary': _selSalaryId,
        'fiscal_year': _selFiscalYear,
        'date': _date,
        'status': true,
        'net_salary': _netSalaryController.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiService.getErrorMessage(e)}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showAddFiscalYearDialog() async {
    final titleController = TextEditingController();
    bool saving = false;

    await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
                  backgroundColor: AppColors.accent,
                  title: const Text('Add Fiscal Year',
                      style: TextStyle(color: AppColors.textPrimary)),
                  content: TextField(
                    controller: titleController,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                        hintText: 'e.g. 2082/83',
                        hintStyle: TextStyle(color: AppColors.textSecondary)),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final text = titleController.text.trim();
                              if (text.isEmpty) return;
                              setStateDialog(() => saving = true);
                              try {
                                await ApiService().post('/api/fiscal-year/',
                                    data: {'title': text});
                                if (ctx.mounted) Navigator.pop(ctx);
                                _loadFiscalYears();
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              ApiService.getErrorMessage(e))));
                                }
                              } finally {
                                if (ctx.mounted)
                                  setStateDialog(() => saving = false);
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    )
                  ],
                )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
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
          const Text('Issue Salary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (widget.salaries.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'No salary records found. Please configure base salaries for employees first.',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            )
          else
            ...([
              DropdownButtonFormField<int>(
                // ignore: deprecated_member_use
                value: _selSalaryId,
                hint: const Text('Select Employee'),
                isExpanded: true,
                items: widget.salaries
                    .fold<List<dynamic>>([], (prev, curr) {
                      if (!prev.any((e) => e['id'] == curr['id']))
                        prev.add(curr);
                      return prev;
                    })
                    .map((s) => DropdownMenuItem<int>(
                          value: s['id'],
                          child: Text(
                              '${_empName(s['employee'])} (Base: ${s['basic_salary']})'),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() => _selSalaryId = v);
                  _loadNetSalary();
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: _selFiscalYear,
                      hint: const Text('Select Fiscal Year'),
                      isExpanded: true,
                      items: _fiscalYears.isEmpty
                          ? [
                              const DropdownMenuItem(
                                  value: -1,
                                  child: Text('No fiscal years available'))
                            ]
                          : _fiscalYears
                              .fold<List<dynamic>>([], (prev, curr) {
                                if (!prev.any((e) => e['id'] == curr['id']))
                                  prev.add(curr);
                                return prev;
                              })
                              .map((f) => DropdownMenuItem<int>(
                                    value: f['id'],
                                    child: Text(f['title'] ?? ''),
                                  ))
                              .toList(),
                      onChanged: _fiscalYears.isEmpty
                          ? null
                          : (v) => setState(() => _selFiscalYear = v),
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.add_circle, color: AppColors.primary),
                    onPressed: _showAddFiscalYearDialog,
                  )
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _date,
                decoration: const InputDecoration(
                  labelText: 'Month Date (YYYY-MM-DD)',
                  helperText: 'Enter date in Nepali calendar format',
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
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    _InfoRow(Iconsax.calendar, 'Days Present',
                        '${_netSalaryInfo!['no_of_days_present']}'),
                    _InfoRow(Iconsax.calendar_remove, 'Paid Leaves',
                        '${_netSalaryInfo!['paid_leaves']}'),
                    _InfoRow(Iconsax.calendar_remove, 'Unpaid Leaves',
                        '${_netSalaryInfo!['unpaid_leaves']}'),
                    _InfoRow(Iconsax.calendar, 'Holidays',
                        '${_netSalaryInfo!['holidays']}'),
                    const Divider(color: Colors.white24),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(Iconsax.money_recive, size: 20, color: AppColors.primary),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text('Net Salary Payable', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _netSalaryController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              decoration: const InputDecoration(
                                prefixText: 'NPR ',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    (_saving || _selSalaryId == null || _selFiscalYear == null)
                        ? null
                        : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Issue Payment'),
              ),
            ]),
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
  State<_EmployeeSalaryDetailSheet> createState() =>
      _EmployeeSalaryDetailSheetState();
}

class _EmployeeSalaryDetailSheetState
    extends State<_EmployeeSalaryDetailSheet> {
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
      if (mounted)
        setState(() {
          _netInfo = res.data;
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.getErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  String _fmt(dynamic val) {
    if (val == null) return 'N/A';
    final n = double.tryParse(val.toString()) ?? 0;
    return 'NPR ${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Row(children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryDark,
              child: Icon(Iconsax.profile_2user, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(widget.empName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const Text('Current Month Salary Summary',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ])),
          ]),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          // Base salary info
          _InfoRow(Iconsax.money_4, 'Basic Salary', widget.basicSalary),
          _InfoRow(Iconsax.buildings_2, 'Remote Salary', widget.remoteSalary),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          if (_loading)
            const Center(
                child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ))
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
            )
          else if (_netInfo != null) ...[
            _InfoRow(Iconsax.calendar_tick, 'Days Present',
                '${_netInfo!['no_of_days_present'] ?? 0} days'),
            _InfoRow(Iconsax.sun_1, 'Holidays',
                '${_netInfo!['holidays'] ?? 0} days'),
            _InfoRow(Iconsax.calendar_remove, 'Paid Leaves Taken',
                '${_netInfo!['paid_leaves'] ?? 0} days'),
            _InfoRow(Iconsax.calendar_remove, 'Unpaid Leaves Taken',
                '${_netInfo!['unpaid_leaves'] ?? 0} days'),
          ],
          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

class _PayslipItem extends StatelessWidget {
  final String label, value;
  const _PayslipItem(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ]);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool bold;
  const _InfoRow(this.icon, this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                  color: bold ? AppColors.success : null)),
        ]),
      );
}

class _TransactionTile extends StatelessWidget {
  final Map tx;
  final String? empName;
  const _TransactionTile(this.tx, {this.empName});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CircleAvatar(
                  backgroundColor: AppColors.success,
                  radius: 18,
                  child: Icon(Iconsax.money_recive,
                      color: Colors.white, size: 16)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (empName != null && empName != 'Employee #0')
                      Text(empName!,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('Date: ${tx['date'] ?? '—'}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ])),
              Text('NPR ${tx['net_salary'] ?? '—'}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                      fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _MiniStat(
                icon: Iconsax.calendar_tick,
                label: 'Days Present',
                value: '${tx['no_of_days_present'] ?? 0}',
              )),
              Expanded(
                  child: _MiniStat(
                icon: Iconsax.sun_1,
                label: 'Holidays',
                value: '${tx['holidays'] ?? 0}',
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _MiniStat(
                icon: Iconsax.calendar_remove,
                label: 'Paid Leaves',
                value: '${tx['paid_leaves'] ?? 0}',
              )),
              Expanded(
                  child: _MiniStat(
                icon: Iconsax.calendar_remove,
                label: 'Unpaid Leaves',
                value: '${tx['unpaid_leaves'] ?? 0}',
              )),
            ]),
            if (tx['fiscal_year'] != null) ...[
              const SizedBox(height: 8),
              Text('Fiscal Year: ${tx['fiscal_year']}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ]),
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _MiniStat(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ]);
}
