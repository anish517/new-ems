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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      final res = await ApiService().get('${AppConstants.taskBase}/tasks/');
      setState(() { _tasks = res.data['results'] ?? res.data; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
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
          : TabBarView(controller: _tabs, children: [
              _TaskList(_filtered('to-do'), AppColors.primary),
              _TaskList(_filtered('in-progress'), AppColors.warning),
              _TaskList(_filtered('done'), AppColors.success),
            ]),
    ),
  );
}

class _TaskList extends StatelessWidget {
  final List tasks;
  final Color accentColor;
  const _TaskList(this.tasks, this.accentColor);

  @override
  Widget build(BuildContext context) => tasks.isEmpty
      ? const Center(child: Text('No tasks', style: TextStyle(color: AppColors.textSecondary)))
      : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final t = tasks[i];
            final priority = t['priority'] ?? 'low';
            final priorityColor = priority == 'high' ? AppColors.error
                : priority == 'medium' ? AppColors.warning : AppColors.textSecondary;

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
                        color: priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(priority.toUpperCase(),
                          style: TextStyle(color: priorityColor, fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Iconsax.calendar, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${t['planned_start_date']} → ${t['planned_end_date']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ]),
              ),
            );
          });
}
