import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isGridView = true;
  List<dynamic> _employees = [];
  List<dynamic> _archivedEmployees = [];
  bool _loading = true;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
  Future<void> _exportEmployeeCSV() async {
    try {
      final token = await ApiService().getAccessToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session expired. Please log in again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      final url =
          '${AppConstants.baseUrl}/api/organization/employees/export-csv/?token=$token';
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch the CSV export. Try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
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
            return RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: SingleChildScrollView(
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
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Iconsax.people,
                                      color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Employee Directory',
                                          style: TextStyle(
                                            fontSize: isTight ? 17 : 20,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.4,
                                            color: context.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${_employees.length} Active',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Manage staff profiles, contracts & CSV records',
                                      style: TextStyle(
                                        fontSize: isTight ? 11 : 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: context.card,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: context.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () => setState(() => _isGridView = true),
                                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: _isGridView ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(11)),
                                          ),
                                          child: Icon(
                                            Iconsax.grid_1,
                                            size: 17,
                                            color: _isGridView ? AppColors.primary : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                      Container(width: 1, height: 18, color: context.border),
                                      InkWell(
                                        onTap: () => setState(() => _isGridView = false),
                                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: !_isGridView ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
                                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(11)),
                                          ),
                                          child: Icon(
                                            Iconsax.row_vertical,
                                            size: 17,
                                            color: !_isGridView ? AppColors.primary : AppColors.textSecondary,
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
                                OutlinedButton.icon(
                                  onPressed: _exportEmployeeCSV,
                                  icon: const Icon(Iconsax.document_download, size: 16),
                                  label: const Text('Export CSV',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(color: context.border),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _openAddEmployeeModal(),
                                  icon: const Icon(Iconsax.user_add, size: 17, color: Colors.white),
                                  label: const Text('Add Employee',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
              else if (_tabController.index == 0)
                _isGridView
                    ? _buildEmployeeGrid(_getFiltered(_employees), false)
                    : _buildEmployeeList(_getFiltered(_employees), false)
              else
                _isGridView
                    ? _buildEmployeeGrid(_getFiltered(_archivedEmployees), true)
                    : _buildEmployeeList(_getFiltered(_archivedEmployees), true),
            ],
          ),
        ),
      );
    },
  ),
),
);
  }

  Widget _buildEmptyState(bool isArchived) {
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

  Widget _buildFallbackAvatar(String fname, String fullName) {
    final initial = fname.isNotEmpty
        ? fname[0].toUpperCase()
        : (fullName.isNotEmpty ? fullName[0].toUpperCase() : 'E');
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
            Color(0xFFEC4899),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 36,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeGrid(List<dynamic> list, bool isArchived) {
    if (list.isEmpty) {
      return _buildEmptyState(isArchived);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final int crossAxisCount;
        final double childAspectRatio;

        if (width >= 1200) {
          crossAxisCount = 5;
          childAspectRatio = 0.70;
        } else if (width >= 900) {
          crossAxisCount = 4;
          childAspectRatio = 0.71;
        } else if (width >= 620) {
          crossAxisCount = 3;
          childAspectRatio = 0.70;
        } else if (width >= 420) {
          crossAxisCount = 2;
          childAspectRatio = 0.68;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 0.63;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, i) {
            final e = list[i];
            return _buildEmployeeGridCard(e, isArchived);
          },
        );
      },
    );
  }

  Widget _buildEmployeeGridCard(dynamic e, bool isArchived) {
    final user = e['user'] ?? {};
    final fname = (user['first_name'] ?? '').toString();
    final lname = (user['last_name'] ?? '').toString();
    final fullName = '$fname $lname'.trim().isNotEmpty
        ? '$fname $lname'.trim()
        : (e['official_email'] ?? 'Unnamed Employee');
    final profilePic = user['profile_picture']?.toString();
    final email = user['email'] ?? e['official_email'] ?? 'No email';
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
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: context.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Large Profile Image with Status and Action Overlays ──
              Expanded(
                flex: 11,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                      child: profilePic != null && profilePic.isNotEmpty
                          ? Image.network(
                              profilePic,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) => _buildFallbackAvatar(fname, fullName),
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          : _buildFallbackAvatar(fname, fullName),
                    ),

                    // Bottom subtle gradient overlay
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Status Badge (Top-Left)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (isArchived
                                    ? AppColors.error
                                    : (isActive ? AppColors.success : AppColors.error))
                                .withValues(alpha: 0.7),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isArchived
                                    ? AppColors.error
                                    : (isActive ? AppColors.success : AppColors.error),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isArchived
                                  ? 'Archived'
                                  : (isActive ? 'Active' : 'Inactive'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions Menu (Top-Right)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: isArchived
                              ? IconButton(
                                  icon: const Icon(Iconsax.trash, size: 15, color: Colors.white),
                                  tooltip: 'Permanently Delete',
                                  padding: const EdgeInsets.all(5),
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteEmployee(e['id'], fullName),
                                )
                              : PopupMenuButton<String>(
                                  icon: const Icon(Iconsax.more, size: 15, color: Colors.white),
                                  padding: const EdgeInsets.all(5),
                                  constraints: const BoxConstraints(),
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
                                        constraints: const BoxConstraints(maxWidth: 600),
                                        backgroundColor: context.surface,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                        ),
                                        builder: (_) => AddSalarySheet(
                                          employeeId: e['id'],
                                          employeeName: fullName,
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Iconsax.edit, size: 16, color: AppColors.primary),
                                          SizedBox(width: 10),
                                          Text('Edit Profile'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'salary',
                                      child: Row(
                                        children: [
                                          Icon(Iconsax.wallet_money, size: 16, color: AppColors.success),
                                          SizedBox(width: 10),
                                          Text('Manage Salary'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'password',
                                      child: Row(
                                        children: [
                                          Icon(Iconsax.key, size: 16, color: AppColors.warning),
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
                                          Icon(Iconsax.trash, size: 16, color: AppColors.error),
                                          SizedBox(width: 10),
                                          Text(
                                            'Archive Staff',
                                            style: TextStyle(
                                              color: AppColors.error,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Details Section ──
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Text(
                            fullName,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: context.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            designation,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      // Badge (Employment Type / Archived)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isArchived
                              ? AppColors.error.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isArchived
                              ? 'Archived'
                              : (empType == 'full_time'
                                  ? 'Full-Time'
                                  : empType == 'part_time'
                                      ? 'Part-Time'
                                      : 'Intern'),
                          style: TextStyle(
                            color: isArchived ? AppColors.error : AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      // Email / Subtitle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.sms, size: 11, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              email,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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

  Widget _buildEmployeeList(List<dynamic> list, bool isArchived) {
    if (list.isEmpty) {
      return _buildEmptyState(isArchived);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
    );
  }
}
