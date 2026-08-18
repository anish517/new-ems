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

class _EmployeeListScreenState extends ConsumerState<EmployeeListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _employees = [];
  List<dynamic> _archivedEmployees = [];
  bool _loading = true;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await ApiService().get('${AppConstants.organizationBase}/employees/');
      final arcRes = await ApiService().get(
          '${AppConstants.organizationBase}/employees/',
          queryParams: {'status': 'archived'});
      if (!mounted) return;
      setState(() {
        _employees = (res.data is List)
            ? res.data
            : (res.data['results'] ?? res.data);
        _archivedEmployees = (arcRes.data is List)
            ? arcRes.data
            : (arcRes.data['results'] ?? arcRes.data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteEmployee(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ctx.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.trash,
                          color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Archive Employee',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ctx.textPrimary,
                            ),
                          ),
                          const Text(
                            'Soft delete and disable account access',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Are you sure you want to archive $name? Their account will be deactivated and historical records preserved.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: ctx.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Archive',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService()
          .delete('${AppConstants.organizationBase}/employees/$id/');
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Employee $name archived successfully'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _changePassword(int id, String name) async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ctx.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.key,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ctx.textPrimary,
                            ),
                          ),
                          Text(
                            'For $name',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Min 6 characters',
                    prefixIcon: Icon(Iconsax.lock, size: 20),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Update Password',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirm != true || ctrl.text.trim().isEmpty) return;

    try {
      await ApiService().post(
          '${AppConstants.organizationBase}/employees/$id/reset_password/',
          data: {
            'password': ctrl.text.trim(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle,
                    color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Password for $name updated successfully'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openAddEmployeeModal({Map? employee}) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: ctx.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: ctx.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: AddEmployeeSheet(
              onSuccess: _load,
              employee: employee,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => AddEmployeeSheet(
          onSuccess: _load,
          employee: employee,
        ),
      );
    }
  }

  List<dynamic> _getFiltered(List<dynamic> list) => list.where((e) {
        final name =
            '${e['user']?['first_name'] ?? ''} ${e['user']?['last_name'] ?? ''}'
                .toLowerCase();
        final email = (e['user']?['email'] ?? '').toString().toLowerCase();
        final phone = (e['phone_no'] ?? '').toString().toLowerCase();
        final query = _search.toLowerCase().trim();
        return name.contains(query) ||
            email.contains(query) ||
            phone.contains(query);
      }).toList();

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _load());
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEmployeeModal(),
        backgroundColor: AppColors.primary,
        elevation: 6,
        icon: const Icon(Iconsax.user_add, color: Colors.white, size: 20),
        label: const Text(
          'Add Employee',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 600;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isTight ? 14 : 24,
                vertical: isTight ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Bar ───────────────────────────────────────────
                  Container(
                    padding: EdgeInsets.all(isTight ? 14 : 20),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTight ? 9 : 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Iconsax.people,
                                  color: AppColors.primary, size: isTight ? 20 : 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Employee Directory',
                                      style: TextStyle(
                                        fontSize: isTight ? 17 : 20,
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
                                      '${_employees.length} Active',
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
                              onPressed: _load,
                              tooltip: 'Refresh',
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            if (!isTight) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _openAddEmployeeModal(),
                                icon: const Icon(Iconsax.user_add, size: 18, color: Colors.white),
                                label: const Text('Add Employee',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Manage staff profiles, contracts & access credentials',
                          style: TextStyle(
                            fontSize: isTight ? 11.5 : 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

              const SizedBox(height: 20),

              // ── Search & Filter Tabs ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.border, width: 1),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by employee name, email, or phone number...',
                        prefixIcon: const Icon(Iconsax.search_normal, size: 20),
                        suffixIcon: _search.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Iconsax.close_circle, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                    const SizedBox(height: 14),
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.profile_2user, size: 18),
                              const SizedBox(width: 8),
                              Text('Active Staff (${_employees.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.user_remove, size: 18),
                              const SizedBox(width: 8),
                              Text('Archived (${_archivedEmployees.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Content Area ─────────────────────────────────────────────
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                SizedBox(
                  height: 600,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEmployeeList(
                          _getFiltered(_employees), false),
                      _buildEmployeeList(
                          _getFiltered(_archivedEmployees), true),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  ),
);
  }

  Widget _buildEmployeeList(List<dynamic> list, bool isArchived) {
    if (list.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Iconsax.user_search,
                  size: 38, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              _search.isNotEmpty
                  ? 'No employees match "$_search"'
                  : (isArchived
                      ? 'No archived employees.'
                      : 'No active employees found.'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _search.isNotEmpty
                  ? 'Try searching with a different name, email, or department.'
                  : (isArchived
                      ? 'Archived staff members will appear here.'
                      : 'Get started by adding your first employee to the directory.'),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isArchived && _search.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _openAddEmployeeModal(),
                icon: const Icon(Iconsax.user_add, size: 18, color: Colors.white),
                label: const Text('Add First Employee',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final e = list[i];
          final user = e['user'] ?? {};
          final fname = (user['first_name'] ?? '').toString();
          final lname = (user['last_name'] ?? '').toString();
          final fullName = '$fname $lname'.trim().isNotEmpty
              ? '$fname $lname'.trim()
              : (e['official_email'] ?? 'Unnamed Employee');
          final email = user['email'] ?? e['official_email'] ?? 'No email';
          final phone = e['phone_no'] ?? 'No phone';
          final empType = e['employee_type'] ?? 'full_time';
          final isActive = e['is_active'] == true;
          final designation = e['designation_title'] ??
              (e['post'] is Map ? e['post']['title'] : null) ??
              'Staff Member';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/employees/${e['id']}'),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: context.isDark ? 0.2 : 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar with Active Indicator
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          backgroundImage: user['profile_picture'] != null
                              ? NetworkImage(user['profile_picture'])
                              : null,
                          child: user['profile_picture'] == null
                              ? Text(
                                  fname.isNotEmpty ? fname[0].toUpperCase() : 'E',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.success : AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: context.surface, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // Employee Info Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fullName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isArchived)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Archived',
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    empType == 'full_time'
                                        ? 'Full-Time'
                                        : empType == 'part_time'
                                            ? 'Part-Time'
                                            : 'Intern',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            designation,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.sms,
                                      size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.call,
                                      size: 13, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Quick Action Buttons
                    if (!isArchived)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Iconsax.user_octagon,
                                size: 18, color: AppColors.primary),
                            tooltip: 'View Profile',
                            onPressed: () =>
                                context.push('/employees/${e['id']}'),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Iconsax.more,
                                size: 18, color: AppColors.textSecondary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            onSelected: (val) {
                              if (val == 'edit') {
                                _openAddEmployeeModal(employee: e);
                              } else if (val == 'delete') {
                                _deleteEmployee(e['id'], fullName);
                              } else if (val == 'password') {
                                _changePassword(e['id'], fullName);
                              } else if (val == 'salary') {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  constraints:
                                      const BoxConstraints(maxWidth: 600),
                                  backgroundColor: context.surface,
                                  shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24))),
                                  builder: (_) => AddSalarySheet(
                                      employeeId: e['id'],
                                      employeeName: fullName),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Iconsax.edit,
                                        size: 16, color: AppColors.primary),
                                    SizedBox(width: 10),
                                    Text('Edit Profile'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'salary',
                                child: Row(
                                  children: [
                                    Icon(Iconsax.wallet_money,
                                        size: 16, color: AppColors.success),
                                    SizedBox(width: 10),
                                    Text('Manage Salary'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'password',
                                child: Row(
                                  children: [
                                    Icon(Iconsax.key,
                                        size: 16, color: AppColors.warning),
                                    SizedBox(width: 10),
                                    Text('Reset Password'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Iconsax.trash,
                                        size: 16, color: AppColors.error),
                                    SizedBox(width: 10),
                                    Text('Archive Staff',
                                        style: TextStyle(
                                            color: AppColors.error,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      IconButton(
                        icon: const Icon(Iconsax.trash,
                            color: AppColors.error, size: 18),
                        tooltip: 'Permanently Delete Record',
                        onPressed: () => _deleteEmployee(e['id'], fullName),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
