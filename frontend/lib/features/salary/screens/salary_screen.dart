import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class SalaryScreen extends ConsumerStatefulWidget {
  const SalaryScreen({super.key});
  @override
  ConsumerState<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends ConsumerState<SalaryScreen> {
  Map<String, dynamic>? _salary;
  Map<String, dynamic>? _netSalary;
  List _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = ref.read(currentUserProvider);

      // Fetch all salary records (works for both admin and employee)
      final salaryRes = await ApiService().get('${AppConstants.salaryBase}/salary/');
      final salaries = salaryRes.data is List
          ? salaryRes.data as List
          : ((salaryRes.data['results'] ?? []) as List);

      Map<String, dynamic>? mySalary;
      if (user?.employeeId != null) {
        // Employee: find their specific salary
        for (final s in salaries) {
          if (s['employee'] == user!.employeeId) {
            mySalary = Map<String, dynamic>.from(s);
            break;
          }
        }
        if (mySalary == null && salaries.isNotEmpty) {
          mySalary = Map<String, dynamic>.from(salaries.first);
        }
      } else if (salaries.isNotEmpty) {
        // Admin without employee record — show first available
        mySalary = Map<String, dynamic>.from(salaries.first);
      }

      if (mySalary != null) {
        final salaryId = mySalary['id'];
        try {
          final netRes = await ApiService().get(
            '${AppConstants.salaryBase}/net-salary/$salaryId/',
          );
          if (mounted) setState(() => _netSalary = netRes.data);
        } catch (_) {}
      }

      // Fetch transactions
      if (user?.employeeId != null) {
        try {
          final txRes = await ApiService().get(
            '${AppConstants.salaryBase}/transactions/?employee=${user!.employeeId}',
          );
          final txList = txRes.data is List
              ? txRes.data as List
              : ((txRes.data['results'] ?? []) as List);
          if (mounted) setState(() => _transactions = txList);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _salary = mySalary;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = ApiService.getErrorMessage(e); });
    }
  }

  String _fmt(dynamic val) {
    if (val == null) return 'N/A';
    final n = double.tryParse(val.toString()) ?? 0;
    return 'NPR ${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salary'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
                ]))
              : _salary == null
                  ? const Center(child: Text('No salary record found.\nContact your admin.', textAlign: TextAlign.center))
                  : RefreshIndicator(
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
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Current Month Salary',
                                  style: TextStyle(color: Colors.white70, fontSize: 13)),
                              const SizedBox(height: 8),
                              Text(_fmt(_netSalary?['net_salary'] ?? _salary?['basic_salary']),
                                  style: const TextStyle(color: Colors.white,
                                      fontSize: 32, fontWeight: FontWeight.bold)),
                              const Divider(color: Colors.white24, height: 32),
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                _PayslipItem('Basic', _fmt(_salary?['basic_salary'])),
                                _PayslipItem('Remote', _fmt(_salary?['remote_salary'])),
                                _PayslipItem('Net', _fmt(_netSalary?['net_salary'] ?? _salary?['basic_salary'])),
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
                              '${_netSalary?['no_of_days_present'] ?? '—'}'),
                          _InfoRow(Iconsax.sun_1, 'Holidays',
                              '${_netSalary?['holidays'] ?? '—'}'),
                          _InfoRow(Iconsax.calendar_remove, 'Paid Leaves',
                              '${_netSalary?['paid_leaves'] ?? '—'}'),
                          _InfoRow(Iconsax.money_recive, 'Net Salary',
                              _fmt(_netSalary?['net_salary'] ?? _salary?['basic_salary']),
                              bold: true),

                          // Transactions history
                          if (_transactions.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Payment History',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            ),
                            const SizedBox(height: 12),
                            ..._transactions.take(6).map((tx) => _TransactionTile(tx)),
                          ],
                        ]),
                      ),
                    ),
    );
  }
}

class _PayslipItem extends StatelessWidget {
  final String label, value;
  const _PayslipItem(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white,
        fontWeight: FontWeight.bold, fontSize: 16)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
      Expanded(child: Text(label, style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Text(value, style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: bold ? AppColors.success : null)),
    ]),
  );
}

class _TransactionTile extends StatelessWidget {
  final Map tx;
  const _TransactionTile(this.tx);
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: const CircleAvatar(
        backgroundColor: AppColors.success,
        child: Icon(Iconsax.money_recive, color: Colors.white, size: 18)),
      title: Text('${tx['date'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('TDS: ${tx['tds'] ?? 0}  |  SSF: ${tx['ssf'] ?? 0}'),
      trailing: Text('NPR ${tx['net_salary'] ?? '—'}',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
    ),
  );
}
