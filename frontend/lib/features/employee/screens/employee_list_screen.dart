import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import 'add_employee_sheet.dart';
import '../../salary/screens/add_salary_sheet.dart';

class EmployeeListScreen extends ConsumerStatefulWidget {
  const EmployeeListScreen({super.key});
  @override
  ConsumerState<EmployeeListScreen> createState() => _EmployeeListScreenState();
}
class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen> {
  List _employees = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiService().get('${AppConstants.organizationBase}/employees/');
      if (!mounted) return;
      setState(() { _employees = res.data['results'] ?? res.data; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List get _filtered => _employees.where((e) {
    final name = '${e['user']?['first_name'] ?? ''} '.toLowerCase();
    return name.contains(_search.toLowerCase());
  }).toList();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Employees')),
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
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e = _filtered[i];
                final name = '${e['user']?['first_name'] ?? ''} ';
                return Card(child: ListTile(
                  leading: CircleAvatar(backgroundColor: AppColors.primary,
                    child: Text(name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(color: Colors.white))),
                  title: Text(name.trim()),
                  subtitle: Text(e['employee_type'] ?? ''),
                  trailing: Icon(e['is_active'] == true ? Icons.circle : Icons.circle_outlined,
                    color: e['is_active'] == true ? AppColors.success : AppColors.error, size: 12),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.surfaceDark,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                      builder: (_) => AddSalarySheet(employeeId: e['id'], employeeName: name.trim()),
                    );
                  },
                ));
              }),
      ),
    ]),
  );
}
