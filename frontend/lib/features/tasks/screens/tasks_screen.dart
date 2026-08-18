import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/date_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/nepali_date_picker.dart';

// ─── Date Formatter Helper ───────────────────────────────────────────────────
String _fmtDate(String? raw, {String? fallback}) {
  if (raw == null && fallback == null) return 'Not set';
  final s = raw ?? fallback!;
  try {
    if (s.contains('T')) {
      return NepaliDateFormat('dd MMM yyyy')
          .format(DateTime.parse(s).toNepaliDateTime());
    }
    return NepaliDateFormat('dd MMM yyyy').format(NepaliDateTime.parse(s));
  } catch (_) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<dynamic> _tasks = [];
  List<dynamic> _projects = [];
  bool _loading = true;
  String _searchQuery = '';
  String _priorityFilter = 'all';
  int? _projectFilter;
  bool _isKanbanView = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadTasks();
    _loadProjects();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final res = await ApiService().get('${AppConstants.taskBase}/projects/');
      final data = res.data is List ? res.data : (res.data['results'] ?? []);
      if (mounted && data is List) {
        setState(() => _projects = data);
      }
    } catch (_) {}
  }

  Future<void> _loadTasks() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await ApiService().get('${AppConstants.taskBase}/tasks/');
      if (!mounted) return;
      setState(() {
        _tasks = res.data is List ? res.data : (res.data['results'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int taskId, String newStatus) async {
    try {
      await ApiService().patch(
        '${AppConstants.taskBase}/tasks/$taskId/',
        data: {'status': newStatus},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Task status updated to ${newStatus.replaceAll('-', ' ').toUpperCase()}'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      _loadTasks();
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
    }
  }

  List<dynamic> _filterTasks(String? status) {
    return _tasks.where((t) {
      final taskStatus = (t['status'] ?? 'to-do').toString().toLowerCase();
      if (status != null && taskStatus != status) return false;

      // Priority filter
      if (_priorityFilter != 'all') {
        final prio = (t['priority'] ?? 'low').toString().toLowerCase();
        if (prio != _priorityFilter) return false;
      }

      // Project filter
      if (_projectFilter != null) {
        final proj = t['project'];
        final pId = proj is Map ? proj['id'] : proj;
        if (pId != _projectFilter) return false;
      }

      // Search query filter
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final title = (t['title'] ?? '').toString().toLowerCase();
        final desc = (t['description'] ?? '').toString().toLowerCase();
        final assigned = t['assigned_to'] is Map
            ? (t['assigned_to']['name'] ?? '').toString().toLowerCase()
            : '';
        final projName = t['project'] is Map
            ? (t['project']['name'] ?? t['project']['title'] ?? '').toString().toLowerCase()
            : '';
        return title.contains(q) || desc.contains(q) || assigned.contains(q) || projName.contains(q);
      }

      return true;
    }).toList();
  }

  void _showTaskDetail(Map task) {
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
            constraints: const BoxConstraints(maxWidth: 620),
            child: _TaskDetailSheet(
              task: task,
              onStatusChange: (newStatus) {
                Navigator.pop(ctx);
                _updateStatus(task['id'], newStatus);
              },
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
        builder: (ctx) => _TaskDetailSheet(
          task: task,
          onStatusChange: (newStatus) {
            Navigator.pop(ctx);
            _updateStatus(task['id'], newStatus);
          },
        ),
      );
    }
  }

  void _showCreateTaskSheet() {
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
            constraints: const BoxConstraints(maxWidth: 600),
            child: _CreateTaskSheet(onCreated: _loadTasks),
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
        builder: (_) => _CreateTaskSheet(onCreated: _loadTasks),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadTasks());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;

    final todoCount = _tasks.where((t) => (t['status'] ?? 'to-do') == 'to-do').length;
    final inProgressCount = _tasks.where((t) => (t['status'] ?? 'to-do') == 'in-progress').length;
    final doneCount = _tasks.where((t) => (t['status'] ?? 'to-do') == 'done').length;
    final highPrioCount = _tasks.where((t) => (t['priority'] ?? 'low') == 'high').length;

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _showCreateTaskSheet,
              backgroundColor: AppColors.primary,
              elevation: 6,
              icon: const Icon(Iconsax.task_square, color: Colors.white, size: 20),
              label: const Text(
                'Assign Task',
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;
                  return Container(
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
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Iconsax.task_square, color: AppColors.primary, size: 24),
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
                                        'Tasks & Assignments',
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
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${_tasks.length} Total',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Track deliverables & project milestones',
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
                            IconButton(
                              icon: Icon(_isKanbanView ? Iconsax.row_vertical : Iconsax.kanban, size: 20),
                              tooltip: _isKanbanView ? 'Switch to List View' : 'Switch to Board View',
                              onPressed: () => setState(() => _isKanbanView = !_isKanbanView),
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Iconsax.refresh, size: 20),
                              tooltip: 'Refresh',
                              onPressed: _loadTasks,
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: _showCreateTaskSheet,
                                icon: const Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                                label: const Text('New Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // ── KPI Summary Cards ────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 740;

                  return Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard('To Do', '$todoCount', Iconsax.clipboard_text, AppColors.primary, isTight),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard('In Progress', '$inProgressCount', Iconsax.timer_1, AppColors.warning, isTight),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard('Completed', '$doneCount', Iconsax.tick_circle, AppColors.success, isTight),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard('Urgent', '$highPrioCount', Iconsax.danger, AppColors.error, isTight),
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
                        hintText: 'Search tasks by title, project, assignee or description...',
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
                            'Filter by:',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 10),
                          _buildPriorityFilterChip('all', 'All', AppColors.primary, Iconsax.category),
                          _buildPriorityFilterChip('high', 'High', AppColors.error, Iconsax.danger),
                          _buildPriorityFilterChip('medium', 'Medium', AppColors.warning, Iconsax.flash),
                          _buildPriorityFilterChip('low', 'Low', const Color(0xFF10B981), Iconsax.tick_circle),
                          if (_projects.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(height: 24, width: 1, color: context.border),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.border),
                              ),
                              child: DropdownButton<int?>(
                                value: _projectFilter,
                                hint: const Text('All Projects', style: TextStyle(fontSize: 12.5)),
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('All Projects', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                                  ),
                                  ..._projects.map((p) => DropdownMenuItem<int?>(
                                        value: p['id'] as int,
                                        child: Text(p['title'] ?? p['name'] ?? 'Project', style: const TextStyle(fontSize: 12.5)),
                                      )),
                                ],
                                onChanged: (v) => setState(() => _projectFilter = v),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Task View (Kanban Board vs Tabbed List) ──────────────────
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (_isKanbanView)
                _buildKanbanBoard()
              else ...[
                Container(
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(16),
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
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.clipboard_text, size: 16),
                            const SizedBox(width: 6),
                            Text('To Do (${_filterTasks('to-do').length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.timer_1, size: 16),
                            const SizedBox(width: 6),
                            Text('In Progress (${_filterTasks('in-progress').length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.tick_circle, size: 16),
                            const SizedBox(width: 6),
                            Text('Done (${_filterTasks('done').length})', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 650,
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _buildTaskList(_filterTasks('to-do'), AppColors.primary),
                      _buildTaskList(_filterTasks('in-progress'), AppColors.warning),
                      _buildTaskList(_filterTasks('done'), AppColors.success),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityFilterChip(String key, String label, Color color, IconData icon) {
    final isSelected = _priorityFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _priorityFilter = key),
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
    if (isTight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border, width: 1),
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
                    fontSize: 16,
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
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.textPrimary,
                  ),
                ),
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

  // ─── Kanban Board View ─────────────────────────────────────────────────────
  Widget _buildKanbanBoard() {
    return LayoutBuilder(
      builder: (context, c) {
        final isDesktop = c.maxWidth >= 900;

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildKanbanColumn('To Do', 'to-do', AppColors.primary, Iconsax.clipboard_text)),
              const SizedBox(width: 16),
              Expanded(child: _buildKanbanColumn('In Progress', 'in-progress', AppColors.warning, Iconsax.timer_1)),
              const SizedBox(width: 16),
              Expanded(child: _buildKanbanColumn('Completed', 'done', AppColors.success, Iconsax.tick_circle)),
            ],
          );
        } else {
          return Column(
            children: [
              _buildKanbanColumn('To Do', 'to-do', AppColors.primary, Iconsax.clipboard_text),
              const SizedBox(height: 16),
              _buildKanbanColumn('In Progress', 'in-progress', AppColors.warning, Iconsax.timer_1),
              const SizedBox(height: 16),
              _buildKanbanColumn('Completed', 'done', AppColors.success, Iconsax.tick_circle),
            ],
          );
        }
      },
    );
  }

  Widget _buildKanbanColumn(String title, String status, Color color, IconData icon) {
    final tasks = _filterTasks(status);

    return Container(
      padding: const EdgeInsets.all(16),
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
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: context.border, height: 1),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(
                'No tasks in $title',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _buildTaskCard(tasks[i]),
            ),
        ],
      ),
    );
  }

  // ─── List View ─────────────────────────────────────────────────────────────
  Widget _buildTaskList(List<dynamic> list, Color accentColor) {
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
              const Icon(Iconsax.task, size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No tasks match "$_searchQuery"'
                    : 'No tasks found in this section.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildTaskCard(list[i]),
    );
  }

  // ─── Card Widget ───────────────────────────────────────────────────────────
  Widget _buildTaskCard(Map t) {
    final priority = (t['priority'] ?? 'low').toString().toLowerCase();
    final priorityColor = priority == 'high'
        ? AppColors.error
        : priority == 'medium'
            ? AppColors.warning
            : const Color(0xFF64748B);

    final status = (t['status'] ?? 'to-do').toString().toLowerCase();
    final statusColor = status == 'done'
        ? AppColors.success
        : status == 'in-progress'
            ? AppColors.warning
            : AppColors.primary;

    final assignedTo = t['assigned_to'];
    final assignedName = assignedTo is Map
        ? (assignedTo['name'] ?? 'Unassigned')
        : 'Unassigned';

    final proj = t['project'];
    final projName = proj is Map ? (proj['name'] ?? proj['title'] ?? 'Project') : null;
    final rating = t['rating'];
    final hasPdf = t['description_pdf'] != null && t['description_pdf'].toString().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTaskDetail(t),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top chips row
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          priority.toUpperCase(),
                          style: TextStyle(
                            color: priorityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (projName != null)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            projName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.replaceAll('-', ' ').toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Title
              Text(
                t['title'] ?? 'Untitled Task',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: context.textPrimary,
                ),
              ),

              if (t['description'] != null && (t['description'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  t['description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3),
                ),
              ],

              const SizedBox(height: 12),
              Divider(color: context.border, height: 1),
              const SizedBox(height: 10),

              // Bottom info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: const Icon(Iconsax.user, size: 10, color: AppColors.primary),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        assignedName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (hasPdf) ...[
                        const Icon(Iconsax.document_1, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                      ],
                      if (rating != null) ...[
                        const Icon(Iconsax.star1, size: 13, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '$rating/10',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        _fmtDate(t['planned_end_date']?.toString(), fallback: t['created_at']?.toString()),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Task Details Sheet ───────────────────────────────────────────────────────
class _TaskDetailSheet extends StatelessWidget {
  final Map task;
  final void Function(String newStatus) onStatusChange;
  const _TaskDetailSheet({required this.task, required this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final priority = (task['priority'] ?? 'low').toString().toLowerCase();
    final priorityColor = priority == 'high'
        ? AppColors.error
        : priority == 'medium'
            ? AppColors.warning
            : const Color(0xFF64748B);

    final status = (task['status'] ?? 'to-do').toString().toLowerCase();
    final assignedTo = task['assigned_to'];
    final assignedName = assignedTo is Map ? (assignedTo['name'] ?? 'Unassigned') : 'Unassigned';
    final proj = task['project'];
    final projName = proj is Map ? (proj['name'] ?? proj['title'] ?? 'General Project') : 'General Project';

    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${priority.toUpperCase()} PRIORITY',
                          style: TextStyle(color: priorityColor, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          projName,
                          style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.close_circle, size: 22),
                  color: AppColors.textSecondary,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              task['title'] ?? 'Task Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: context.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            // Status Quick Changer Bar
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  _buildStatusChoice('To Do', 'to-do', status == 'to-do', AppColors.primary),
                  _buildStatusChoice('In Progress', 'in-progress', status == 'in-progress', AppColors.warning),
                  _buildStatusChoice('Done', 'done', status == 'done', AppColors.success),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Meta Info Grid
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: Column(
                children: [
                  _buildDetailRow(Iconsax.user, 'Assigned Employee', assignedName),
                  const Divider(height: 20),
                  _buildDetailRow(
                    Iconsax.calendar,
                    'Planned Start Date',
                    _fmtDate(task['planned_start_date']?.toString(), fallback: task['created_at']?.toString()),
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    Iconsax.calendar_tick,
                    'Due Date',
                    _fmtDate(task['planned_end_date']?.toString(), fallback: task['created_at']?.toString()),
                  ),
                  if (task['rating'] != null) ...[
                    const Divider(height: 20),
                    _buildDetailRow(Iconsax.star1, 'Quality Score', '${task['rating']}/10'),
                  ],
                ],
              ),
            ),

            if (task['description'] != null && (task['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Description & Instructions',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.border),
                ),
                child: Text(
                  task['description'],
                  style: TextStyle(fontSize: 13.5, color: context.textPrimary, height: 1.5),
                ),
              ),
            ],

            if (task['description_pdf'] != null && task['description_pdf'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  final url = Uri.tryParse(task['description_pdf']);
                  if (url != null) launchUrl(url);
                },
                icon: const Icon(Iconsax.document_download, size: 18),
                label: const Text('View Attached Specification Document'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChoice(String label, String value, bool isSelected, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onStatusChange(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─── Create & Assign Task Sheet ───────────────────────────────────────────────
class _CreateTaskSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateTaskSheet({required this.onCreated});

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _tillCtrl = TextEditingController();
  String _fromDate = '', _tillDate = '';
  List _projects = [];
  List _employees = [];
  int? _selProject, _selEmployee;
  String _priority = 'medium';
  String _taskType = 'daily';
  PlatformFile? _attachment;
  double _rating = 5;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _fromCtrl.dispose();
    _tillCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final pRes = await ApiService().get('/api/task-management/projects/');
      final eRes = await ApiService().get('/api/organization/employees/');
      if (!mounted) return;
      setState(() {
        _projects = pRes.data is List ? pRes.data : (pRes.data['results'] ?? []);
        _employees = eRes.data is List ? eRes.data : (eRes.data['results'] ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List _getProjectEmployees() {
    if (_selProject == null) return _employees;
    final proj = _projects.firstWhere((p) => p['id'] == _selProject, orElse: () => null);
    if (proj == null || proj['assignments'] == null) return _employees;
    final assignedIds = (proj['assignments'] as List).map((a) => a['employee_id']).toSet();
    return _employees.where((e) => assignedIds.contains(e['id'])).toList();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.isNotEmpty && mounted) {
      setState(() => _attachment = result.files.first);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final nepaliPicked = await showDialog<NepaliDateTime>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: isFrom ? 'Select Planned Start Date' : 'Select Planned Due Date',
        initial: NepaliDateTime.now(),
      ),
    );
    if (nepaliPicked != null) {
      setState(() {
        final dateStr =
            '${nepaliPicked.year}-${nepaliPicked.month.toString().padLeft(2, '0')}-${nepaliPicked.day.toString().padLeft(2, '0')}';
        if (isFrom) {
          _fromDate = dateStr;
          _fromCtrl.text = dateStr;
        } else {
          _tillDate = dateStr;
          _tillCtrl.text = dateStr;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _selProject == null || _selEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a task title and select both a Project and Assignee.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'project': _selProject.toString(),
        'assigned_to': _selEmployee.toString(),
        'priority': _priority,
        'task_type': _taskType,
        'status': 'to-do',
        'rating': _rating.toInt().toString(),
      };
      if (_fromDate.isNotEmpty) data['planned_start_date'] = _fromDate;
      if (_tillDate.isNotEmpty) data['planned_end_date'] = _tillDate;

      if (_attachment != null) {
        await ApiService().postMultipart(
          '/api/task-management/tasks/',
          fields: data,
          files: {'description_pdf': _attachment!},
        );
      } else {
        await ApiService().post('/api/task-management/tasks/', data: data);
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Task assigned successfully!'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiService.getErrorMessage(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                        child: const Icon(Iconsax.task_square, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assign New Task',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary),
                            ),
                            const Text(
                              'Delegate deliverables with deadlines and files',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
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
            const SizedBox(height: 16),

            // Title
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Task Title *',
                hintText: 'e.g. Implement OAuth login screen',
                prefixIcon: Icon(Iconsax.text, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description & Scope (optional)',
                hintText: 'Detailed task goals, acceptance criteria, or links...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // Project Dropdown
            DropdownButtonFormField<int>(
              initialValue: _selProject,
              decoration: const InputDecoration(
                labelText: 'Project *',
                prefixIcon: Icon(Iconsax.briefcase, size: 18),
              ),
              items: _projects
                  .map((p) => DropdownMenuItem<int>(
                        value: p['id'] as int,
                        child: Text(p['title'] ?? p['name'] ?? 'Project'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selProject = v;
                _selEmployee = null;
                final employees = _getProjectEmployees();
                if (employees.length == 1) {
                  _selEmployee = employees.first['id'];
                }
              }),
            ),
            const SizedBox(height: 12),

            // Assignee Dropdown
            DropdownButtonFormField<int>(
              initialValue: _selEmployee,
              decoration: const InputDecoration(
                labelText: 'Assign To *',
                prefixIcon: Icon(Iconsax.user, size: 18),
              ),
              items: _getProjectEmployees().map((e) {
                final user = e['user'] ?? {};
                return DropdownMenuItem<int>(
                  value: e['id'] as int,
                  child: Text('${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim()),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selEmployee = v),
            ),
            const SizedBox(height: 12),

            // Date pickers row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _fromCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Start Date (B.S.)',
                      prefixIcon: Icon(Iconsax.calendar, size: 18),
                    ),
                    onTap: () => _pickDate(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _tillCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Due Date (B.S.)',
                      prefixIcon: Icon(Iconsax.calendar_tick, size: 18),
                    ),
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Priority & Task Type row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const [
                      DropdownMenuItem(value: 'low', child: Text('🌱 Low')),
                      DropdownMenuItem(value: 'medium', child: Text('⚡ Medium')),
                      DropdownMenuItem(value: 'high', child: Text('🔥 High')),
                    ],
                    onChanged: (v) => setState(() => _priority = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _taskType,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily Task')),
                      DropdownMenuItem(value: 'hourly', child: Text('Hourly Task')),
                    ],
                    onChanged: (v) => setState(() => _taskType = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // File Attachment
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Iconsax.document_upload, size: 18),
              label: Text(_attachment == null ? 'Attach Document / Specification' : _attachment!.name),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            // Score Slider
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task Difficulty / Score Weight: ${_rating.toInt()}/10',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                Slider(
                  value: _rating,
                  min: 1,
                  max: 10,
                  divisions: 9,
                  activeColor: AppColors.primary,
                  label: _rating.toInt().toString(),
                  onChanged: (v) => setState(() => _rating = v),
                ),
              ],
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
                onPressed: _saving ? null : _save,
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
                          Icon(Iconsax.send_1, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Assign Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
