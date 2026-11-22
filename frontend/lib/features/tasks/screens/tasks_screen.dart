import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/date_provider.dart';
import '../../../shared/utils/document_viewer_util.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/nepali_date_picker.dart';
import '../widgets/task_kanban_board.dart';
import 'task_detail_screen.dart';

// ─── Date Formatter Helper ───────────────────────────────────────────────────
String _fmtDate(String? raw, {String? fallback}) {
  if (raw == null && fallback == null) return 'Not set';
  final s = raw ?? fallback!;
  try {
    if (s.contains('T')) {
      return NepaliDateFormat('dd MMMM yyyy')
          .format(DateTime.parse(s).toNepaliDateTime());
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
  String _scopeFilter = 'all'; // 'all' | 'project' | 'personal'
  int? _projectFilter;
  bool _isKanbanView = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
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
        _tasks =
            res.data is List ? res.data : (res.data['results'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int taskId, String newStatus) async {
    final idx = _tasks.indexWhere((t) => t['id'] == taskId);
    final prevStatus = idx >= 0 ? _tasks[idx]['status'] : null;

    // Optimistic UI update so Trello drag-and-drop feels instant
    if (idx >= 0 && mounted) {
      setState(() {
        final updated = Map<String, dynamic>.from(_tasks[idx] as Map);
        updated['status'] = newStatus;
        _tasks[idx] = updated;
      });
    }

    try {
      await ApiService().patch(
        '${AppConstants.taskBase}/tasks/$taskId/move/',
        data: {'status': newStatus},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      'Moved to ${newStatus.replaceAll('-', ' ').toUpperCase()}'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      _loadTasks();
    } catch (e) {
      if (idx >= 0 && prevStatus != null && mounted) {
        setState(() {
          final reverted = Map<String, dynamic>.from(_tasks[idx] as Map);
          reverted['status'] = prevStatus;
          _tasks[idx] = reverted;
        });
      }
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

  Future<void> _openProgressLogs(Map task) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
    );
    if (mounted) {
      _loadTasks();
    }
  }

  Future<void> _deleteTask(Map task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Iconsax.trash, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Task Card',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${task['title'] ?? 'this task'}"? All progress logs on this card will also be removed.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService().delete('${AppConstants.taskBase}/tasks/${task['id']}/');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Task card deleted successfully.'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

      // Scope filter (All / Project / Personal)
      final proj = t['project'];
      final projId = proj is Map ? proj['id'] : proj;
      final isPersonal = t['is_personal'] == true || projId == null;
      if (_scopeFilter == 'personal' && !isPersonal) return false;
      if (_scopeFilter == 'project' && isPersonal) return false;

      // Priority filter
      if (_priorityFilter != 'all') {
        final prio = (t['priority'] ?? 'low').toString().toLowerCase();
        if (prio != _priorityFilter) return false;
      }

      // Project filter
      if (_projectFilter != null) {
        if (projId != _projectFilter) return false;
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
            ? (t['project']['name'] ?? t['project']['title'] ?? '')
                .toString()
                .toLowerCase()
            : '';
        final tagMatch = isPersonal && 'personal'.contains(q);
        return title.contains(q) ||
            desc.contains(q) ||
            assigned.contains(q) ||
            projName.contains(q) ||
            tagMatch;
      }

      return true;
    }).toList();
  }

  void _showTaskDetail(Map task) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    Widget buildSheet(BuildContext ctx) => _TaskDetailSheet(
          task: task,
          onStatusChange: (newStatus) {
            Navigator.pop(ctx);
            _updateStatus(task['id'], newStatus);
          },
          onOpenLogs: () {
            Navigator.pop(ctx);
            _openProgressLogs(task);
          },
          onEdit: () {
            Navigator.pop(ctx);
            _showCreateTaskSheet(existingTask: task);
          },
          onDelete: () {
            Navigator.pop(ctx);
            _deleteTask(task);
          },
        );

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
            child: buildSheet(ctx),
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
        builder: buildSheet,
      );
    }
  }

  void _showCreateTaskSheet({String initialStatus = 'to-do', Map? existingTask}) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final isAdmin = ref.read(currentUserProvider)?.canManage ?? false;

    final sheet = _CreateTaskSheet(
      isAdmin: isAdmin,
      initialStatus: initialStatus,
      existingTask: existingTask,
      onSaved: _loadTasks,
    );

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
            child: sheet,
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
        builder: (_) => sheet,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadTasks());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;

    final todoCount =
        _tasks.where((t) => (t['status'] ?? 'to-do') == 'to-do').length;
    final inProgressCount =
        _tasks.where((t) => (t['status'] ?? 'to-do') == 'in-progress').length;
    final doneCount =
        _tasks.where((t) => (t['status'] ?? 'to-do') == 'done').length;
    final highPrioCount =
        _tasks.where((t) => (t['priority'] ?? 'low') == 'high').length;

    final isCompactScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTaskSheet(),
        backgroundColor: AppColors.primary,
        elevation: 6,
        icon: const Icon(Iconsax.add_square, color: Colors.white, size: 20),
        label: Text(
          isAdmin ? 'Assign Task' : 'Add Card',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTasks,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isCompactScreen ? 12 : 24,
              vertical: isCompactScreen ? 14 : 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // ── Top Header Card ──────────────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 650;
                  final titleRow = Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isMobile ? 10 : 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Iconsax.kanban,
                            color: AppColors.primary, size: isMobile ? 21 : 24),
                      ),
                      const SizedBox(width: 12),
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
                                  isAdmin ? 'Tasks & Board' : 'My Task Board',
                                  style: TextStyle(
                                    fontSize: isMobile ? 17 : 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: context.textPrimary,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.12),
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
                            Text(
                              isAdmin
                                  ? 'Manage project deliverables, personal cards & progress logs'
                                  : 'Create Trello-style cards, move across lanes & log daily progress',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  final actionsRow = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment:
                        isMobile ? WrapAlignment.start : WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Segmented Board | List Switcher
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildViewModePill(
                              label: 'Board',
                              icon: Iconsax.kanban,
                              selected: _isKanbanView,
                              onTap: () =>
                                  setState(() => _isKanbanView = true),
                            ),
                            const SizedBox(width: 2),
                            _buildViewModePill(
                              label: 'List',
                              icon: Iconsax.row_vertical,
                              selected: !_isKanbanView,
                              onTap: () =>
                                  setState(() => _isKanbanView = false),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.refresh, size: 19),
                        tooltip: 'Refresh',
                        onPressed: _loadTasks,
                        style: IconButton.styleFrom(
                          backgroundColor: context.card,
                          side: BorderSide(color: context.border),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showCreateTaskSheet(),
                        icon: const Icon(Iconsax.add_circle,
                            size: 17, color: Colors.white),
                        label: Text(
                          isAdmin ? 'New Task' : 'New Card',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  );

                  return Container(
                    padding: EdgeInsets.all(isMobile ? 14 : 20),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: context.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              titleRow,
                              const SizedBox(height: 12),
                              actionsRow,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: titleRow),
                              const SizedBox(width: 12),
                              actionsRow,
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
                        child: _buildKpiCard('To Do', '$todoCount',
                            Iconsax.clipboard_text, AppColors.primary, isTight),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard('In Progress', '$inProgressCount',
                            Iconsax.timer_1, AppColors.warning, isTight),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard('Completed', '$doneCount',
                            Iconsax.tick_circle, AppColors.success, isTight),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildKpiCard('Urgent', '$highPrioCount',
                            Iconsax.danger, AppColors.error, isTight),
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
                        hintText:
                            'Search tasks by title, project, assignee or description...',
                        prefixIcon: const Icon(Iconsax.search_normal, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon:
                                    const Icon(Iconsax.close_circle, size: 18),
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
                            'Type:',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          _buildScopeFilterChip('all', 'All Cards',
                              AppColors.primary, Iconsax.layer),
                          _buildScopeFilterChip('project', 'Projects',
                              const Color(0xFF0EA5E9), Iconsax.briefcase),
                          _buildScopeFilterChip('personal', 'Personal',
                              const Color(0xFF8B5CF6), Iconsax.user_tag),
                          const SizedBox(width: 8),
                          Container(
                              height: 22, width: 1, color: context.border),
                          const SizedBox(width: 10),
                          const Text(
                            'Priority:',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          _buildPriorityFilterChip('all', 'All',
                              AppColors.primary, Iconsax.category),
                          _buildPriorityFilterChip(
                              'high', 'High', AppColors.error, Iconsax.danger),
                          _buildPriorityFilterChip('medium', 'Medium',
                              AppColors.warning, Iconsax.flash),
                          _buildPriorityFilterChip('low', 'Low',
                              const Color(0xFF10B981), Iconsax.tick_circle),
                          if (_projects.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                                height: 22, width: 1, color: context.border),
                            const SizedBox(width: 10),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 190),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.border),
                              ),
                              child: DropdownButton<int?>(
                                value: _projectFilter,
                                isDense: true,
                                hint: const Text('All Projects',
                                    style: TextStyle(fontSize: 12)),
                                underline: const SizedBox(),
                                icon:
                                    const Icon(Icons.arrow_drop_down, size: 18),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('All Projects',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  ..._projects.map(
                                    (p) => DropdownMenuItem<int?>(
                                      value: p['id'] as int,
                                      child: ConstrainedBox(
                                        constraints:
                                            const BoxConstraints(maxWidth: 140),
                                        child: Text(
                                          (p['title'] ??
                                                  p['name'] ??
                                                  'Project')
                                              .toString(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  _projectFilter = v;
                                  if (v != null && _scopeFilter == 'personal') {
                                    _scopeFilter = 'all';
                                  }
                                }),
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
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
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
                    onTap: (idx) => setState(() {}),
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
                            Text('To Do (${_filterTasks('to-do').length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.timer_1, size: 16),
                            const SizedBox(width: 6),
                            Text(
                                'In Progress (${_filterTasks('in-progress').length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.tick_circle, size: 16),
                            const SizedBox(width: 6),
                            Text('Done (${_filterTasks('done').length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final idx = _tabs.index;
                    if (idx == 1) {
                      return _buildTaskList(
                          _filterTasks('in-progress'), AppColors.warning);
                    } else if (idx == 2) {
                      return _buildTaskList(
                          _filterTasks('done'), AppColors.success);
                    } else {
                      return _buildTaskList(
                          _filterTasks('to-do'), AppColors.primary);
                    }
                  },
                ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildViewModePill({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : context.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeFilterChip(
      String key, String label, Color color, IconData icon) {
    final isSelected = _scopeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() {
            _scopeFilter = key;
            if (key == 'personal') {
              _projectFilter = null;
            }
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
                Icon(icon,
                    size: 13.5,
                    color: isSelected ? color : AppColors.textSecondary),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildPriorityFilterChip(
      String key, String label, Color color, IconData icon) {
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
                Icon(icon,
                    size: 14,
                    color: isSelected ? color : AppColors.textSecondary),
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

  Widget _buildKpiCard(
      String title, String count, IconData icon, Color color, bool isTight) {
    if (isTight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border, width: 1),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
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

  // ─── Trello Kanban Board View ──────────────────────────────────────────────
  Widget _buildKanbanBoard() {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    return TaskKanbanBoard(
      todoTasks: _filterTasks('to-do'),
      inProgressTasks: _filterTasks('in-progress'),
      doneTasks: _filterTasks('done'),
      isAdmin: isAdmin,
      onTapTask: _showTaskDetail,
      onOpenLogs: _openProgressLogs,
      onAddCard: (status) => _showCreateTaskSheet(initialStatus: status),
      onMoveTask: (task, newStatus) => _updateStatus(task['id'], newStatus),
      onEditTask: (task) => _showCreateTaskSheet(existingTask: task),
      onDeleteTask: _deleteTask,
      formatDate: _fmtDate,
    );
  }

  // ─── List View ─────────────────────────────────────────────────────────────
  Widget _buildTaskList(List<dynamic> list, Color accentColor) {
    if (list.isEmpty) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.task,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No tasks match "$_searchQuery"'
                    : 'No tasks found in this section.',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _buildTaskCard(list[i]),
    );
  }

  // ─── Card Widget (List View) ───────────────────────────────────────────────
  Widget _buildTaskCard(Map t) {
    final priority = (t['priority'] ?? 'low').toString().toLowerCase();
    final priorityColor = priority == 'high'
        ? AppColors.error
        : priority == 'medium'
            ? AppColors.warning
            : const Color(0xFF10B981);

    final status = (t['status'] ?? 'to-do').toString().toLowerCase();
    final statusColor = status == 'done'
        ? AppColors.success
        : status == 'in-progress'
            ? AppColors.warning
            : AppColors.primary;

    final assignedTo = t['assigned_to'];
    final assignedName =
        assignedTo is Map ? (assignedTo['name'] ?? 'Unassigned') : 'Unassigned';

    final proj = t['project'];
    final projId = proj is Map ? proj['id'] : null;
    final projName = proj is Map ? (proj['name'] ?? proj['title']) : null;
    final isPersonal = t['is_personal'] == true || projId == null;
    const personalColor = Color(0xFF8B5CF6);

    final rating = t['rating'];
    final hasPdf = t['description_pdf'] != null &&
        t['description_pdf'].toString().isNotEmpty;
    final isAdmin = ref.read(currentUserProvider)?.canManage ?? false;
    final progressCount = t['progress_count'] is int
        ? t['progress_count'] as int
        : (t['progress_reports'] is List
            ? (t['progress_reports'] as List).length
            : 0);
    final canEdit = t['can_edit'] == true || isAdmin;
    final canDelete = t['can_delete'] == true || isAdmin;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showTaskDetail(t),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top chips row + menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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
                        if (isPersonal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: personalColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.user_tag,
                                    size: 11, color: personalColor),
                                SizedBox(width: 4),
                                Text(
                                  'Personal',
                                  style: TextStyle(
                                    color: personalColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (projName != null)
                          Container(
                            constraints: const BoxConstraints(maxWidth: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              projName.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert,
                          size: 18, color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (action) {
                        if (action.startsWith('move:')) {
                          _updateStatus(t['id'], action.substring(5));
                        } else if (action == 'logs') {
                          _openProgressLogs(t);
                        } else if (action == 'edit') {
                          _showCreateTaskSheet(existingTask: t);
                        } else if (action == 'delete') {
                          _deleteTask(t);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'logs',
                          child: Row(
                            children: [
                              Icon(Iconsax.document_text,
                                  size: 15, color: AppColors.primary),
                              SizedBox(width: 8),
                              Text('Progress Logs & Updates'),
                            ],
                          ),
                        ),
                        if (status != 'to-do')
                          const PopupMenuItem(
                              value: 'move:to-do', child: Text('Move to To Do')),
                        if (status != 'in-progress')
                          const PopupMenuItem(
                              value: 'move:in-progress',
                              child: Text('Move to In Progress')),
                        if (status != 'done')
                          const PopupMenuItem(
                              value: 'move:done', child: Text('Move to Done')),
                        if (canEdit)
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit Card')),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete Card',
                                style: TextStyle(color: AppColors.error)),
                          ),
                      ],
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

              if (t['description'] != null &&
                  (t['description'] as String).isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  t['description'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                      height: 1.3),
                ),
              ],

              const SizedBox(height: 12),
              Divider(color: context.border, height: 1),
              const SizedBox(height: 10),

              // Bottom info (responsive Wrap so narrow mobile screens never overflow)
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: (isPersonal
                                ? personalColor
                                : AppColors.primary)
                            .withValues(alpha: 0.12),
                        child: Icon(Iconsax.user,
                            size: 10,
                            color:
                                isPersonal ? personalColor : AppColors.primary),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          assignedName.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openProgressLogs(t),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Iconsax.document_text,
                                    size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  progressCount == 1
                                      ? '1 Log'
                                      : '$progressCount Logs',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (hasPdf)
                        const Icon(Iconsax.document_1,
                            size: 14, color: AppColors.primary),
                      if (isAdmin && rating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Iconsax.star1,
                                size: 13, color: Colors.amber),
                            const SizedBox(width: 2),
                            Text(
                              '$rating/10',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber),
                            ),
                          ],
                        ),
                      Text(
                        _fmtDate(t['planned_end_date']?.toString(),
                            fallback: t['created_at']?.toString()),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
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
class _TaskDetailSheet extends ConsumerWidget {
  final Map task;
  final void Function(String newStatus) onStatusChange;
  final VoidCallback onOpenLogs;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _TaskDetailSheet({
    required this.task,
    required this.onStatusChange,
    required this.onOpenLogs,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final priority = (task['priority'] ?? 'low').toString().toLowerCase();
    final priorityColor = priority == 'high'
        ? AppColors.error
        : priority == 'medium'
            ? AppColors.warning
            : const Color(0xFF10B981);

    final status = (task['status'] ?? 'to-do').toString().toLowerCase();
    final assignedTo = task['assigned_to'];
    final assignedName =
        assignedTo is Map ? (assignedTo['name'] ?? 'Unassigned') : 'Unassigned';
    final proj = task['project'];
    final projId = proj is Map ? proj['id'] : null;
    final isPersonal = task['is_personal'] == true || projId == null;
    final projName = isPersonal
        ? 'Personal Task'
        : (proj is Map
            ? (proj['name'] ?? proj['title'] ?? 'Project').toString()
            : 'Project');
    const personalColor = Color(0xFF8B5CF6);

    final progressCount = task['progress_count'] is int
        ? task['progress_count'] as int
        : (task['progress_reports'] is List
            ? (task['progress_reports'] as List).length
            : 0);
    final canEdit = task['can_edit'] == true || isAdmin;
    final canDelete = task['can_delete'] == true || isAdmin;

    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${priority.toUpperCase()} PRIORITY',
                          style: TextStyle(
                              color: priorityColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isPersonal ? personalColor : AppColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isPersonal) ...[
                              const Icon(Iconsax.user_tag,
                                  size: 12, color: personalColor),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              projName,
                              style: TextStyle(
                                  color: isPersonal
                                      ? personalColor
                                      : AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (canEdit)
                  IconButton(
                    tooltip: 'Edit Card',
                    onPressed: onEdit,
                    icon: const Icon(Iconsax.edit_2, size: 19),
                    color: AppColors.primary,
                  ),
                if (canDelete)
                  IconButton(
                    tooltip: 'Delete Card',
                    onPressed: onDelete,
                    icon: const Icon(Iconsax.trash, size: 19),
                    color: AppColors.error,
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
                  _buildStatusChoice(
                      'To Do', 'to-do', status == 'to-do', AppColors.primary),
                  _buildStatusChoice('In Progress', 'in-progress',
                      status == 'in-progress', AppColors.warning),
                  _buildStatusChoice(
                      'Done', 'done', status == 'done', AppColors.success),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Primary CTA: Direct Access to Daily Progress Logs & Updates
            Container(
              height: 46,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark]),
              ),
              child: ElevatedButton.icon(
                onPressed: onOpenLogs,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Iconsax.document_text,
                    size: 18, color: Colors.white),
                label: Text(
                  progressCount > 0
                      ? 'Log & View Progress Updates ($progressCount)'
                      : 'Log Progress & Daily Updates',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ),

            const SizedBox(height: 18),

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
                  _buildDetailRow(
                      Iconsax.user, 'Assigned Employee', assignedName.toString()),
                  const Divider(height: 20),
                  _buildDetailRow(
                    Iconsax.calendar,
                    'Planned Start Date',
                    _fmtDate(task['planned_start_date']?.toString(),
                        fallback: task['created_at']?.toString()),
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    Iconsax.calendar_tick,
                    'Due Date',
                    _fmtDate(task['planned_end_date']?.toString(),
                        fallback: task['created_at']?.toString()),
                  ),
                  if (isAdmin && task['rating'] != null) ...[
                    const Divider(height: 20),
                    _buildDetailRow(
                        Iconsax.star1, 'Quality Score', '${task['rating']}/10'),
                  ],
                ],
              ),
            ),

            if (task['description'] != null &&
                (task['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Description & Instructions',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary),
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
                  style: TextStyle(
                      fontSize: 13.5, color: context.textPrimary, height: 1.5),
                ),
              ),
            ],

            if (task['description_pdf'] != null &&
                task['description_pdf'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  viewDocumentOrImage(
                    context,
                    task['description_pdf']?.toString(),
                    title: 'Task Specification Document',
                  );
                },
                icon: const Icon(Iconsax.document_download, size: 18),
                label: const Text('View Attached Specification Document'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChoice(
      String label, String value, bool isSelected, Color color) {
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
        Text(label,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

// ─── Create / Edit Task Card Sheet (Employee & Admin) ─────────────────────────
class _CreateTaskSheet extends StatefulWidget {
  final bool isAdmin;
  final String initialStatus;
  final Map? existingTask;
  final VoidCallback onSaved;

  const _CreateTaskSheet({
    required this.isAdmin,
    this.initialStatus = 'to-do',
    this.existingTask,
    required this.onSaved,
  });

  @override
  State<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<_CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _tillCtrl = TextEditingController();
  List _projects = [];
  List _employees = [];
  int? _selProject;
  int? _selEmployee;
  String _status = 'to-do';
  String _priority = 'medium';
  String _taskType = 'daily';
  PlatformFile? _attachment;
  double _rating = 5;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.existingTask != null;

  @override
  void initState() {
    super.initState();
    final t = widget.existingTask;
    if (t != null) {
      _titleCtrl.text = (t['title'] ?? '').toString();
      _descCtrl.text = (t['description'] ?? '').toString();
      _fromCtrl.text = (t['planned_start_date'] ?? '').toString();
      _tillCtrl.text = (t['planned_end_date'] ?? '').toString();
      final proj = t['project'];
      if (proj is Map && proj['id'] is int) {
        _selProject = proj['id'] as int;
      }
      final assignee = t['assigned_to'];
      if (assignee is Map && assignee['id'] is int) {
        _selEmployee = assignee['id'] as int;
      }
      _status = (t['status'] ?? 'to-do').toString();
      _priority = (t['priority'] ?? 'medium').toString();
      _taskType = (t['task_type'] ?? 'daily').toString();
      if (t['rating'] != null) {
        _rating = (t['rating'] as num).toDouble().clamp(1, 10);
      }
    } else {
      _status = widget.initialStatus;
    }
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
      final projectsList =
          pRes.data is List ? pRes.data : (pRes.data['results'] ?? []);

      List employeesList = [];
      if (widget.isAdmin) {
        final eRes = await ApiService().get('/api/organization/employees/');
        employeesList =
            eRes.data is List ? eRes.data : (eRes.data['results'] ?? []);
      }

      if (!mounted) return;
      setState(() {
        _projects = projectsList is List ? projectsList : [];
        _employees = employeesList;
        // Keep _selProject valid if the project no longer exists in list
        if (_selProject != null &&
            !_projects.any((p) => p['id'] == _selProject)) {
          _selProject = null;
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List _getProjectEmployees() {
    if (_selProject == null) return _employees;
    final proj =
        _projects.firstWhere((p) => p['id'] == _selProject, orElse: () => null);
    if (proj == null ||
        proj['assignments'] == null ||
        (proj['assignments'] as List).isEmpty) {
      return _employees;
    }
    final assignedIds =
        (proj['assignments'] as List).map((a) => a['employee_id']).toSet();
    final filtered =
        _employees.where((e) => assignedIds.contains(e['id'])).toList();
    return filtered.isNotEmpty ? filtered : _employees;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.isNotEmpty && mounted) {
      setState(() => _attachment = result.files.first);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a task title.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    if (widget.isAdmin && _selEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select an Assignee.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }

    setState(() => _saving = true);
    try {
      final fromStr = _fromCtrl.text.trim();
      final tillStr = _tillCtrl.text.trim();
      final endpoint = _isEdit
          ? '/api/task-management/tasks/${widget.existingTask!['id']}/'
          : '/api/task-management/tasks/';

      if (_attachment != null) {
        final fields = <String, String>{
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'priority': _priority,
          'task_type': _taskType,
          'status': _status,
          'is_personal': (_selProject == null).toString(),
        };
        if (_selProject != null) {
          fields['project'] = _selProject.toString();
        } else if (_isEdit) {
          fields['project'] = '';
        }
        if (widget.isAdmin && _selEmployee != null) {
          fields['assigned_to'] = _selEmployee.toString();
          fields['rating'] = _rating.toInt().toString();
        }
        if (fromStr.isNotEmpty) fields['planned_start_date'] = fromStr;
        if (tillStr.isNotEmpty) fields['planned_end_date'] = tillStr;

        if (_isEdit) {
          await ApiService().patchMultipart(
            endpoint,
            fields: fields,
            files: {'description_pdf': _attachment!},
          );
        } else {
          await ApiService().postMultipart(
            endpoint,
            fields: fields,
            files: {'description_pdf': _attachment!},
          );
        }
      } else {
        final payload = <String, dynamic>{
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'project': _selProject,
          'priority': _priority,
          'task_type': _taskType,
          'status': _status,
          'is_personal': _selProject == null,
        };
        if (widget.isAdmin && _selEmployee != null) {
          payload['assigned_to'] = _selEmployee;
          payload['rating'] = _rating.toInt();
        }
        if (fromStr.isNotEmpty) payload['planned_start_date'] = fromStr;
        if (tillStr.isNotEmpty) payload['planned_end_date'] = tillStr;

        if (_isEdit) {
          await ApiService().patch(endpoint, data: payload);
        } else {
          await ApiService().post(endpoint, data: payload);
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isEdit
                      ? 'Task card updated successfully!'
                      : (widget.isAdmin
                          ? 'Task created successfully!'
                          : 'Task card added to your board!'),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${ApiService.getErrorMessage(e)}'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 240, child: Center(child: CircularProgressIndicator()));
    }

    final headerTitle = _isEdit
        ? 'Edit Task Card'
        : (widget.isAdmin ? 'Create / Assign Task' : 'Create Task Card');
    final headerSub = _isEdit
        ? 'Update card details, column, dates or attachment'
        : (widget.isAdmin
            ? 'Delegate a project task or standalone card with deadlines'
            : 'Add a personal Trello card or link it to an assigned project');
    final submitLabel = _isEdit
        ? 'Save Changes'
        : (widget.isAdmin ? 'Create Task' : 'Add Card to Board');

    final eligibleEmployees = _getProjectEmployees();
    final safeSelEmployee =
        eligibleEmployees.any((e) => e['id'] == _selEmployee)
            ? _selEmployee
            : null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isVeryNarrow = constraints.maxWidth < 360;

          final dateFields = isVeryNarrow
              ? Column(
                  children: [
                    NepaliDateFormField(
                      controller: _fromCtrl,
                      labelText: 'Start Date (B.S.)',
                      prefixIcon: Iconsax.calendar,
                    ),
                    const SizedBox(height: 12),
                    NepaliDateFormField(
                      controller: _tillCtrl,
                      labelText: 'Due Date (B.S.)',
                      prefixIcon: Iconsax.calendar_tick,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: NepaliDateFormField(
                        controller: _fromCtrl,
                        labelText: 'Start Date (B.S.)',
                        prefixIcon: Iconsax.calendar,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NepaliDateFormField(
                        controller: _tillCtrl,
                        labelText: 'Due Date (B.S.)',
                        prefixIcon: Iconsax.calendar_tick,
                      ),
                    ),
                  ],
                );

          final priorityDropdown = DropdownButtonFormField<String>(
            key: ValueKey('prio_$_priority'),
            initialValue: _priority,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Priority'),
            items: const [
              DropdownMenuItem(
                  value: 'low',
                  child: Text('🌱 Low',
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(
                  value: 'medium',
                  child: Text('⚡ Medium',
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(
                  value: 'high',
                  child: Text('🔥 High',
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _priority = v);
            },
          );

          final typeDropdown = DropdownButtonFormField<String>(
            key: ValueKey('type_$_taskType'),
            initialValue: _taskType,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tracking Type'),
            items: const [
              DropdownMenuItem(
                  value: 'daily',
                  child: Text('Daily Task',
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(
                  value: 'hourly',
                  child: Text('Hourly Task',
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _taskType = v);
            },
          );

          return SingleChildScrollView(
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
                            child: const Icon(Iconsax.kanban,
                                color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headerTitle,
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: context.textPrimary),
                                ),
                                Text(
                                  headerSub,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary),
                                  maxLines: 2,
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
                const SizedBox(height: 14),
                Divider(color: context.border),
                const SizedBox(height: 14),

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
                    labelText: 'Description & Notes (optional)',
                    hintText: 'Task goals, checklist notes, or links...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Column / Status Selector
                DropdownButtonFormField<String>(
                  key: ValueKey('status_$_status'),
                  initialValue: _status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Board Column',
                    prefixIcon: Icon(Iconsax.kanban, size: 18),
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'to-do',
                        child: Text('To Do',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'in-progress',
                        child: Text('In Progress',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                        value: 'done',
                        child: Text('Done',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
                const SizedBox(height: 12),

                // Project Dropdown (Optional: Personal Card vs Linked Project)
                DropdownButtonFormField<int?>(
                  key: ValueKey('proj_$_selProject'),
                  initialValue: _selProject,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: widget.isAdmin
                        ? 'Project (Optional — leave Personal for standalone)'
                        : 'Link to Project (Optional)',
                    prefixIcon: const Icon(Iconsax.briefcase, size: 18),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Personal Card (No Project)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ..._projects.map(
                      (p) => DropdownMenuItem<int?>(
                        value: p['id'] as int,
                        child: Text(
                          (p['title'] ?? p['name'] ?? 'Project').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() {
                    _selProject = v;
                    if (widget.isAdmin) {
                      final emps = _getProjectEmployees();
                      if (!emps.any((e) => e['id'] == _selEmployee)) {
                        _selEmployee =
                            emps.length == 1 ? emps.first['id'] as int : null;
                      }
                    }
                  }),
                ),
                const SizedBox(height: 12),

                // Assignee Dropdown (Admin only — Employees self-assign)
                if (widget.isAdmin) ...[
                  DropdownButtonFormField<int>(
                    key: ValueKey('emp_${_selProject}_$safeSelEmployee'),
                    initialValue: safeSelEmployee,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Assign To *',
                      prefixIcon: Icon(Iconsax.user, size: 18),
                    ),
                    items: eligibleEmployees.map((e) {
                      final user = e['user'] ?? {};
                      final fullName =
                          '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                              .trim();
                      final display = fullName.isNotEmpty
                          ? fullName
                          : (user['email'] ?? 'Employee').toString();
                      return DropdownMenuItem<int>(
                        value: e['id'] as int,
                        child: Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selEmployee = v),
                  ),
                  const SizedBox(height: 12),
                ],

                // Date pickers (stacked on very narrow mobile, 2-col otherwise)
                dateFields,
                const SizedBox(height: 12),

                // Priority & Tracking Type
                if (isVeryNarrow) ...[
                  priorityDropdown,
                  const SizedBox(height: 12),
                  typeDropdown,
                ] else
                  Row(
                    children: [
                      Expanded(child: priorityDropdown),
                      const SizedBox(width: 12),
                      Expanded(child: typeDropdown),
                    ],
                  ),
                const SizedBox(height: 12),

                // File Attachment
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Iconsax.document_upload, size: 18),
                  label: Text(
                    _attachment == null
                        ? 'Attach Document / Reference'
                        : _attachment!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

                // Score Slider (Admin only)
                if (widget.isAdmin) ...[
                  const SizedBox(height: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Task Difficulty / Score Weight: ${_rating.toInt()}/10',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
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
                ],
                const SizedBox(height: 20),

                // Submit Button
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark]),
                  ),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.send_1,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                submitLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
