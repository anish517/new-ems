import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _tasks = [];
  bool _loading = true;

  static const _statuses = ['to-do', 'in-progress', 'done'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    try {
      final res = await ApiService().get('${AppConstants.taskBase}/tasks/');
      if (!mounted) return;
      setState(() {
        _tasks = res.data is List ? res.data : (res.data['results'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(int taskId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService().patch(
        '${AppConstants.taskBase}/tasks/$taskId/',
        data: {'status': newStatus},
      );
      messenger.showSnackBar(SnackBar(
        content: Text('Task moved to ${newStatus.replaceAll('-', ' ')}'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
      _loadTasks();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Error: ${ApiService.getErrorMessage(e)}'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _showStatusMenu(BuildContext ctx, Map task) {
    final taskId = task['id'] as int;
    final current = task['status'] as String? ?? 'to-do';
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Text('Update Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ..._statuses.map((s) {
            final isActive = s == current;
            final color = s == 'done'
                ? AppColors.success
                : s == 'in-progress'
                    ? AppColors.warning
                    : AppColors.primary;
            return ListTile(
              leading: Icon(
                  isActive ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: color),
              title: Text(s.replaceAll('-', ' ').toUpperCase(),
                  style: TextStyle(
                      color: color,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal)),
              onTap: isActive
                  ? null
                  : () {
                      Navigator.pop(sheetCtx);
                      _updateStatus(taskId, s);
                    },
            );
          }),
        ]),
      ),
    );
  }

  List _filtered(String status) =>
      _tasks.where((t) => t['status'] == status).toList();

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Tasks'),
            bottom: TabBar(controller: _tabs, tabs: const [
              Tab(text: 'To Do'),
              Tab(text: 'In Progress'),
              Tab(text: 'Done'),
            ]),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: TabBarView(controller: _tabs, children: [
                    _TaskList(_filtered('to-do'),    AppColors.primary, _showStatusMenu),
                    _TaskList(_filtered('in-progress'), AppColors.warning, _showStatusMenu),
                    _TaskList(_filtered('done'),     AppColors.success, _showStatusMenu),
                  ]),
                ),
        ),
      );
}

class _TaskList extends StatelessWidget {
  final List tasks;
  final Color accentColor;
  final void Function(BuildContext, Map) onStatusTap;
  const _TaskList(this.tasks, this.accentColor, this.onStatusTap);

  @override
  Widget build(BuildContext context) => tasks.isEmpty
      ? const Center(child: Text('No tasks', style: TextStyle(color: AppColors.textSecondary)))
      : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) {
            final t = tasks[i];
            final priority = t['priority'] ?? 'low';
            final priorityColor = priority == 'high'
                ? AppColors.error
                : priority == 'medium'
                    ? AppColors.warning
                    : AppColors.textSecondary;

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(t['title'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(priority.toUpperCase(),
                          style: TextStyle(color: priorityColor,
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Iconsax.calendar, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(
                        '${t['planned_start_date']} → ${t['planned_end_date']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                  ]),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => onStatusTap(ctx, Map.from(t)),
                      icon: const Icon(Icons.swap_horiz, size: 14),
                      label: const Text('Change Status', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          });
}
