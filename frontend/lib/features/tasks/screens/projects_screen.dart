import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'project_detail_screen.dart';
import 'currency_converter_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _projects = [];
  bool _loading = true;
  String _searchQuery = '';
  String _typeFilter = 'all';
  final _searchController = TextEditingController();

  static const _statuses = ["ongoing", "incomplete", "complete"];
  static const _statusLabels = ["Ongoing", "Incomplete", "Complete"];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadProjects();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().get("${AppConstants.projectsBase}/");
      if (mounted) {
        setState(() {
          _projects = (res.data is List ? res.data : (res.data["results"] ?? [])) as List;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<dynamic> _byStatus(String status) {
    return _projects.where((p) {
      final projStatus = (p["status"] ?? "ongoing").toString().toLowerCase();
      if (projStatus != status) return false;

      // Project Type filter
      if (_typeFilter != 'all') {
        final pType = (p["project_type"] ?? "monthly").toString().toLowerCase();
        if (pType != _typeFilter) return false;
      }

      // Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final title = (p["title"] ?? "").toString().toLowerCase();
        final desc = (p["description"] ?? "").toString().toLowerCase();
        final assignments = (p["assignments"] as List?) ?? [];
        final hasMember = assignments.any((a) => (a["name"] ?? "").toString().toLowerCase().contains(q));
        return title.contains(q) || desc.contains(q) || hasMember;
      }

      return true;
    }).toList();
  }

  void _showCreateProjectDialog() async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: const _CreateProjectDialog(),
          ),
        ),
      );
      if (created == true) _loadProjects();
    } else {
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const _CreateProjectDialog(),
      );
      if (created == true) _loadProjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;

    final ongoingCount = _projects.where((p) => (p["status"] ?? "ongoing") == "ongoing").length;
    final incompleteCount = _projects.where((p) => (p["status"] ?? "ongoing") == "incomplete").length;
    final completeCount = _projects.where((p) => (p["status"] ?? "ongoing") == "complete").length;

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              heroTag: "new_project_btn",
              onPressed: _showCreateProjectDialog,
              backgroundColor: AppColors.primary,
              elevation: 6,
              icon: const Icon(Iconsax.folder_add, color: Colors.white, size: 20),
              label: const Text(
                'New Project',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Card ──────────────────────────────────────────
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Iconsax.briefcase, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Projects Portfolio',
                                      style: TextStyle(
                                        fontSize: 20,
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
                                        '${_projects.length} Total',
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
                                const Text(
                                  'Manage project budgets, hourly/daily billing & milestones',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()),
                            );
                          },
                          icon: const Icon(Iconsax.money, size: 16, color: AppColors.success),
                          label: const Text('Currency', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Iconsax.refresh, size: 20),
                          tooltip: 'Refresh',
                          onPressed: _loadProjects,
                          style: IconButton.styleFrom(
                            backgroundColor: context.card,
                            side: BorderSide(color: context.border),
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _showCreateProjectDialog,
                            icon: const Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                            label: const Text('New Project', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── KPI Summary Cards ────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 740;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard('Active / Ongoing', '$ongoingCount', Iconsax.play_circle, AppColors.primary, isTight),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard('Incomplete / On-Hold', '$incompleteCount', Iconsax.pause_circle, AppColors.warning, isTight),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildKpiCard('Completed', '$completeCount', Iconsax.tick_circle, AppColors.success, isTight),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── Search & Filter Controls ─────────────────────────────────
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
                        hintText: 'Search projects by title, member name, or description...',
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
                    const SizedBox(height: 14),

                    // Filter Chips Bar
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const Text(
                            'Billing Model:',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          _buildTypeFilterChip('all', 'All Models', AppColors.primary, Iconsax.category),
                          _buildTypeFilterChip('monthly', 'Monthly Retainer', const Color(0xFF8B5CF6), Iconsax.briefcase),
                          _buildTypeFilterChip('hourly', 'Hourly Billing', AppColors.warning, Iconsax.flash),
                          _buildTypeFilterChip('daily', 'Daily Rate', const Color(0xFF0284C7), Iconsax.calendar),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Project Tabs & Content ───────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.border),
                ),
                child: TabBar(
                  controller: _tabs,
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
                          const Icon(Iconsax.play_circle, size: 18),
                          const SizedBox(width: 8),
                          Text('Ongoing (${_byStatus('ongoing').length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.pause_circle, size: 18),
                          const SizedBox(width: 8),
                          Text('Incomplete (${_byStatus('incomplete').length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.tick_circle, size: 18),
                          const SizedBox(width: 8),
                          Text('Completed (${_byStatus('complete').length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else
                SizedBox(
                  height: 650,
                  child: TabBarView(
                    controller: _tabs,
                    children: _statuses.asMap().entries.map((e) {
                      final list = _byStatus(e.value);
                      if (list.isEmpty) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.folder_open, size: 48, color: context.textSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No ${_statusLabels[e.key].toLowerCase()} projects match "$_searchQuery"'
                                      : 'No ${_statusLabels[e.key].toLowerCase()} projects found.',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) => _ProjectCard(
                          project: list[i],
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProjectDetailScreen(project: list[i]),
                              ),
                            );
                            _loadProjects();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilterChip(String key, String label, Color color, IconData icon) {
    final isSelected = _typeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _typeFilter = key),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isSelected ? color : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String count, IconData icon, Color color, bool isTight) {
    return Container(
      padding: EdgeInsets.all(isTight ? 12 : 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isTight ? 18 : 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: isTight ? 18 : 22,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isTight ? 10.5 : 11.5,
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
}

// ─── Project Card ─────────────────────────────────────────────────────────────
class _ProjectCard extends StatelessWidget {
  final Map project;
  final VoidCallback onTap;

  const _ProjectCard({required this.project, required this.onTap});

  Color _typeColor(String type) {
    switch (type) {
      case "hourly":
        return AppColors.warning;
      case "daily":
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (project["project_type"] ?? "monthly") as String;
    final completion = (project["completion"] ?? 0) as int;
    final assignments = (project["assignments"] as List?) ?? [];
    final taskCounts = (project["task_counts"] as Map?) ?? {};
    final budget = project["total_budget"];
    final estHours = project["estimated_hours"];

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Title + Type Badge + Budget
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        project["title"] ?? "Untitled Project",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _typeColor(type).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: _typeColor(type),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                if (project["description"] != null && (project["description"] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    project["description"],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],

                const SizedBox(height: 14),

                // Progress Indicator
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (completion / 100).clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: context.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completion == 100
                                ? AppColors.success
                                : completion > 50
                                    ? AppColors.primary
                                    : AppColors.warning,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "$completion%",
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${taskCounts["done"] ?? 0}/${taskCounts["total"] ?? 0} Tasks Completed",
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                    if (budget != null && budget.toString().isNotEmpty)
                      Text(
                        "Budget: NPR $budget",
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.success),
                      )
                    else if (estHours != null && estHours.toString().isNotEmpty)
                      Text(
                        "Est: $estHours ${type == 'monthly' ? 'months' : type == 'daily' ? 'days' : 'hrs'}",
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                  ],
                ),

                const SizedBox(height: 14),
                Divider(color: context.border, height: 1),
                const SizedBox(height: 12),

                // Team Members Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.people, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          "${assignments.length} Team Members",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Text('View Project', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                      ],
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

// ─── Create Project Dialog ────────────────────────────────────────────────────
class _CreateProjectDialog extends ConsumerStatefulWidget {
  const _CreateProjectDialog();

  @override
  ConsumerState<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<_CreateProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _estHoursCtrl = TextEditingController();

  String _projectType = "monthly";
  bool _saving = false;
  List _allEmployees = [];
  final Map<int, String> _selectedRoles = {};
  final Map<int, TextEditingController> _rateControllers = {};
  List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    _estHoursCtrl.dispose();
    for (final c in _rateControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await ApiService().get("${AppConstants.organizationBase}/employees/");
      final data = (res.data is List ? res.data : (res.data["results"] ?? [])) as List;
      if (mounted) setState(() => _allEmployees = data);
    } catch (_) {}
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result != null && mounted) {
      setState(() => _attachments = result.files);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final assignMembers = _selectedRoles.entries.map((e) {
        final rate = _rateControllers[e.key]?.text.trim() ?? '';
        final isHourly = _projectType == "hourly";
        return {
          "employee_id": e.key,
          "role": e.value,
          if (rate.isNotEmpty) (isHourly ? "hourly_rate" : "daily_rate"): rate,
        };
      }).toList();

      final payload = {
        "title": _titleCtrl.text.trim(),
        "description": _descCtrl.text.trim(),
        "project_type": _projectType,
        if (_budgetCtrl.text.isNotEmpty) "total_budget": _budgetCtrl.text.trim(),
        if (_estHoursCtrl.text.isNotEmpty) "estimated_hours": _estHoursCtrl.text.trim(),
        "assign_members": assignMembers,
      };

      final res = await ApiService().post("${AppConstants.projectsBase}/", data: payload);

      if (_attachments.isNotEmpty && res.data != null && res.data['id'] != null) {
        final projectId = res.data['id'];
        final formData = FormData();
        for (final file in _attachments) {
          if (file.bytes != null) {
            formData.files.add(MapEntry("files", MultipartFile.fromBytes(file.bytes!, filename: file.name)));
          } else if (file.path != null) {
            formData.files.add(MapEntry("files", await MultipartFile.fromFile(file.path!, filename: file.name)));
          }
        }
        await ApiService().post("${AppConstants.projectsBase}/$projectId/files/", data: formData);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.folder_add, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Project',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary),
                          ),
                          const Text(
                            'Define billing structure, budget & team allocation',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
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
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: "Project Title *",
                  hintText: 'e.g. Mobile Banking App v2',
                  prefixIcon: Icon(Iconsax.briefcase, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Title is required" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: "Description",
                  hintText: 'High-level project scope and objectives...',
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),

              // Project Type
              DropdownButtonFormField<String>(
                initialValue: _projectType,
                decoration: const InputDecoration(
                  labelText: "Billing Model *",
                  prefixIcon: Icon(Iconsax.card, size: 18),
                ),
                items: const [
                  DropdownMenuItem(value: "monthly", child: Text("💼 Monthly Retainer")),
                  DropdownMenuItem(value: "daily", child: Text("📅 Daily Rate Billing")),
                  DropdownMenuItem(value: "hourly", child: Text("⚡ Hourly Billing")),
                ],
                onChanged: (v) => setState(() => _projectType = v!),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _estHoursCtrl,
                      decoration: InputDecoration(
                        labelText: _projectType == "monthly"
                            ? "Est. Months"
                            : _projectType == "daily"
                                ? "Est. Days"
                                : "Est. Hours",
                        prefixIcon: const Icon(Iconsax.timer, size: 18),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetCtrl,
                      decoration: const InputDecoration(
                        labelText: "Total Budget",
                        prefixText: "NPR ",
                        prefixIcon: Icon(Iconsax.money_recive, size: 18),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // File attachments
              OutlinedButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Iconsax.document_upload, size: 18),
                label: Text(_attachments.isEmpty
                    ? "Add Project Documents & Specifications"
                    : "${_attachments.length} file(s) selected"),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Assign Members Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.people, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          "Assign Team Members & Set Rates",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_allEmployees.isEmpty)
                      const Text("Loading team members...", style: TextStyle(fontSize: 12, color: AppColors.textSecondary))
                    else
                      ..._allEmployees.map((emp) {
                        final id = emp["id"] as int;
                        final name = "${emp["user"]?["first_name"] ?? ""} ${emp["user"]?["last_name"] ?? ""}".trim();
                        final isSelected = _selectedRoles.containsKey(id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: AppColors.primary,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedRoles[id] = "junior";
                                      _rateControllers[id] = TextEditingController();
                                    } else {
                                      _selectedRoles.remove(id);
                                      _rateControllers[id]?.dispose();
                                      _rateControllers.remove(id);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Text(
                                  name.isEmpty ? "Employee #$id" : name,
                                  style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                                ),
                              ),
                              if (isSelected && _projectType != "monthly") ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: _rateControllers[id],
                                    decoration: InputDecoration(
                                      labelText: _projectType == "hourly" ? "Rate/hr" : "Rate/day",
                                      prefixText: "NPR ",
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                              ],
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 86,
                                  child: DropdownButton<String>(
                                    value: _selectedRoles[id],
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    items: const [
                                      DropdownMenuItem(value: "senior", child: Text("Senior", style: TextStyle(fontSize: 12))),
                                      DropdownMenuItem(value: "junior", child: Text("Junior", style: TextStyle(fontSize: 12))),
                                    ],
                                    onChanged: (v) => setState(() => _selectedRoles[id] = v!),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Submit Button
              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.folder_add, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Create Project', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
