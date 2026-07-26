import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import 'add_employee_sheet.dart';
import '../../salary/screens/add_salary_sheet.dart';
import '../../../core/providers/date_provider.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});
  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}
class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List _employees = [];
  List _archivedEmployees = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { 
    super.initState(); 
    _tabController = TabController(length: 2, vsync: this);
    _load(); 
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('${AppConstants.organizationBase}/employees/');
      final arcRes = await ApiService().get('${AppConstants.organizationBase}/employees/', queryParams: {'status': 'archived'});
      if (!mounted) return;
      setState(() { 
        _employees = res.data['results'] ?? res.data; 
        _archivedEmployees = arcRes.data['results'] ?? arcRes.data;
        _loading = false; 
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteEmployee(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee'),
        content: const Text('Are you sure you want to delete this employee?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete')
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService().delete('${AppConstants.organizationBase}/employees/$id/');
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Employee deleted successfully'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e)), backgroundColor: AppColors.error));
    }
  }

  Future<void> _changePassword(int id) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password', hintText: 'Enter new password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirm != true || ctrl.text.trim().isEmpty) return;

    try {
      await ApiService().post('${AppConstants.organizationBase}/employees/$id/reset_password/', data: {
        'password': ctrl.text.trim(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e)), backgroundColor: AppColors.error));
    }
  }

  List _getFiltered(List list) => list.where((e) {
    final name = '${e['user']?['first_name'] ?? ''} '.toLowerCase();
    return name.contains(_search.toLowerCase());
  }).toList();

  void _showEmployeeDetails(Map e) {
    context.push('/employees/${e['id']}');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _load());
    return Scaffold(
    appBar: AppBar(
      title: const Text('Employees'),
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Active'),
          Tab(text: 'Archived (Deleted)'),
        ],
      ),
    ),
    floatingActionButton: FloatingActionButton(
      backgroundColor: AppColors.primary,
      child: const Icon(Icons.person_add),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surfaceDark,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => AddEmployeeSheet(onSuccess: _load),
        );
      },
    ),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Iconsax.search_normal), hintText: 'Search employee...'),
          onChanged: (v) => setState(() => _search = v),
        )),
      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_getFiltered(_employees), false),
                _buildList(_getFiltered(_archivedEmployees), true),
              ],
            ),
      ),
    ]),
  );
  }

  Widget _buildList(List list, bool isArchived) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final e = list[i];
            final name = '${e['user']?['first_name'] ?? ''} ';
            return Card(child: ListTile(
              onTap: () => _showEmployeeDetails(e),
              leading: CircleAvatar(backgroundColor: AppColors.primary,
                child: Text(name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(color: Colors.white))),
              title: Row(
                children: [
                  Text(name.trim()),
                  if (isArchived) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Deleted', style: TextStyle(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
              subtitle: Text(e['employee_type'] ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(e['is_active'] == true ? Icons.circle : Icons.circle_outlined,
                    color: e['is_active'] == true ? AppColors.success : AppColors.error, size: 12),
                  if (!isArchived)
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: AppColors.surfaceDark,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                            builder: (_) => AddEmployeeSheet(onSuccess: _load, employee: e),
                          );
                        } else if (val == 'delete') {
                          _deleteEmployee(e['id']);
                        } else if (val == 'password') {
                          _changePassword(e['id']);
                        } else if (val == 'salary') {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: AppColors.surfaceDark,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                            builder: (_) => AddSalarySheet(employeeId: e['id'], employeeName: name.trim()),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'salary', child: Text('Add Salary')),
                        const PopupMenuItem(value: 'password', child: Text('Change Password')),
                        const PopupMenuItem(value: 'edit', child: Text('Edit Employee')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                ],
              ),
            ));
          }),
    );
  }
}
