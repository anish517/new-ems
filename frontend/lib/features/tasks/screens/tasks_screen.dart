import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:ems_app/shared/widgets/responsive_grid_list.dart';
import 'package:flutter/material.dart';
import '../../../shared/widgets/nepali_date_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/providers/date_provider.dart';

// ─── Date formatter ───────────────────────────────────────────────────────
String _fmtDate(String? raw, {String? fallback}) {
  if (raw == null && fallback == null) return '';
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

  void _showTaskDetail(BuildContext ctx, Map task) {
    final priority = task['priority'] ?? 'low';
    final priorityColor = priority == 'high'
        ? AppColors.error
        : priority == 'medium'
            ? AppColors.warning
            : AppColors.textSecondary;
    final statusColor = task['status'] == 'done'
        ? AppColors.success
        : task['status'] == 'in-progress'
            ? AppColors.warning
            : AppColors.primary;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(children: [
              Expanded(
                child: Text(task['title'] ?? '',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(priority.toUpperCase(),
                    style: TextStyle(
                        color: priorityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                (task['status'] ?? 'to-do').replaceAll('-', ' ').toUpperCase(),
                style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            if (task['assigned_to'] != null && task['assigned_to'] is Map) ...[
              _DetailRow(
                  icon: Icons.person_outline,
                  label: 'Assigned To',
                  value: task['assigned_to']['name'] ?? 'Unknown'),
              const SizedBox(height: 12),
            ],
            if (task['project'] != null && task['project'] is Map) ...[
              _DetailRow(
                  icon: Iconsax.folder,
                  label: 'Project',
                  value: task['project']['name'] ?? 'Unknown'),
              const SizedBox(height: 12),
            ],
            if (task['rating'] != null &&
                ref.read(currentUserProvider)?.canManage == true) ...[
              _DetailRow(
                  icon: Iconsax.star1,
                  label: 'Rating',
                  value: '${task['rating']}/10'),
              const SizedBox(height: 12),
            ],
            _DetailRow(
                icon: Iconsax.calendar,
                label: 'Start Date',
                value: _fmtDate(task['planned_start_date']?.toString(),
                    fallback: task['created_at']?.toString())),
            const SizedBox(height: 12),
            _DetailRow(
                icon: Iconsax.calendar_tick,
                label: 'Due Date',
                value: _fmtDate(task['planned_end_date']?.toString(),
                    fallback: task['created_at']?.toString())),
            if (task['description'] != null &&
                (task['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Description',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.2)),
                ),
                child: Text(task['description'],
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary)),
              ),
            ],
            if (task['description_pdf'] != null &&
                task['description_pdf'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final url = Uri.tryParse(task['description_pdf']);
                  if (url != null) launchUrl(url);
                },
                icon: const Icon(Iconsax.document_download, size: 18),
                label: const Text('View Attached Document'),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetCtx);
                  _showStatusMenu(ctx, Map.from(task));
                },
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Change Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showStatusMenu(BuildContext ctx, Map task) {
    final taskId = task['id'] as int;
    final current = task['status'] as String? ?? 'to-do';
    showModalBottomSheet(
      context: ctx,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Update Status', style: AppTextStyles.pageTitle),
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
                      isActive
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
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
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadTasks());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    return DefaultTabController(
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
                  _TaskList(
                      _filtered('to-do'), AppColors.primary, _showTaskDetail),
                  _TaskList(_filtered('in-progress'), AppColors.warning,
                      _showTaskDetail),
                  _TaskList(
                      _filtered('done'), AppColors.success, _showTaskDetail),
                ]),
              ),
        floatingActionButton: isAdmin
            ? FloatingActionButton.extended(
                onPressed: () => _showCreateTaskSheet(context),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Assign Task',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              )
            : null,
      ),
    );
  }

  void _showCreateTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _CreateTaskSheet(onCreated: _loadTasks),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ]);
}

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

  List _getProjectEmployees() {
    if (_selProject == null) return _employees;
    final proj =
        _projects.firstWhere((p) => p['id'] == _selProject, orElse: () => null);
    if (proj == null || proj['assignments'] == null) return _employees;
    final assignedIds =
        (proj['assignments'] as List).map((a) => a['employee_id']).toSet();
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
        title: 'Select Date',
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final pRes = await ApiService().get('/api/task-management/projects/');
      final eRes = await ApiService().get('/api/organization/employees/');
      if (!mounted) return;
      setState(() {
        _projects =
            pRes.data is List ? pRes.data : (pRes.data['results'] ?? []);
        _employees =
            eRes.data is List ? eRes.data : (eRes.data['results'] ?? []);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.isEmpty ||
        _selProject == null ||
        _selEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Please fill all fields and select a project and employee.'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'title': _titleCtrl.text,
        'description': _descCtrl.text,
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiService.getErrorMessage(e)}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
          height: 200, child: Center(child: CircularProgressIndicator()));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Iconsax.task_square,
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create Task', style: AppTextStyles.pageTitle),
                      Text('Assign a task to an employee under a project',
                          style: AppTextStyles.caption),
                    ]),
              ),
            ]),
            const SizedBox(height: 16),
            // Hint card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.info.withValues(alpha: 0.25)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select a Project first, then assign it to an employee. '
                    'Priority determines visibility order in the task list.',
                    style: TextStyle(fontSize: 12, color: AppColors.info),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Task Title')),
            const SizedBox(height: 12),
            TextField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    alignLabelWithHint: true)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Iconsax.document_upload, size: 16),
              label: Text(
                  _attachment == null ? 'Attach Document' : _attachment!.name),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _fromCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                    labelText: 'Start Date',
                    suffixIcon: Icon(Icons.calendar_today, size: 18)),
                onTap: () => _pickDate(true),
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: TextField(
                controller: _tillCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                    labelText: 'Due Date',
                    suffixIcon: Icon(Icons.calendar_today, size: 18)),
                onTap: () => _pickDate(false),
              )),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selProject,
              hint: const Text('Select Project'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Iconsax.briefcase, size: 18),
                helperText: 'Which project does this task belong to?',
              ),
              items: _projects
                  .map((p) => DropdownMenuItem<int>(
                        value: p['id'],
                        child: Text(p['title'] ?? p['name'] ?? ''),
                      ))
                  .toList(),
              onChanged: (v) => setState(() {
                _selProject = v;
                _selEmployee = null;
                final proj = _projects.firstWhere((p) => p['id'] == v,
                    orElse: () => null);
                if (proj != null) {
                  final pt = proj['project_type'];
                  if (pt == 'hourly') {
                    _taskType = 'hourly';
                  } else {
                    _taskType = 'daily';
                  }
                }

                final employees = _getProjectEmployees();
                if (employees.length == 1) {
                  _selEmployee = employees.first['id'];
                }
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _selEmployee,
              hint: const Text('Assign To'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Iconsax.user, size: 18),
                helperText: 'Who should complete this task?',
              ),
              items: _getProjectEmployees().map((e) {
                final user = e['user'] ?? {};
                return DropdownMenuItem<int>(
                  value: e['id'],
                  child: Text(
                      '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
                          .trim()),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selEmployee = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                DropdownMenuItem(
                    value: 'medium', child: Text('Medium Priority')),
                DropdownMenuItem(value: 'high', child: Text('High Priority')),
              ],
              onChanged: (v) => setState(() => _priority = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _taskType,
              decoration: const InputDecoration(labelText: 'Task Type *'),
              items: const [
                DropdownMenuItem(value: 'daily', child: Text('Daily Task')),
                DropdownMenuItem(value: 'hourly', child: Text('Hourly Task')),
              ],
              onChanged: (v) => setState(() => _taskType = v!),
            ),
            const SizedBox(height: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Task Rating/Score: ${_rating.toInt()}/10',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              Slider(
                value: _rating,
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: AppColors.primary,
                label: _rating.toInt().toString(),
                onChanged: (v) => setState(() => _rating = v),
              ),
            ]),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Iconsax.tick_circle, size: 18),
              label: Text(_saving ? 'Saving...' : 'Assign Task',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TaskList extends StatelessWidget {
  final List tasks;
  final Color accentColor;
  final void Function(BuildContext, Map) onTap;
  const _TaskList(this.tasks, this.accentColor, this.onTap);

  @override
  Widget build(BuildContext context) => tasks.isEmpty
      ? SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: const Center(
                child: Text('No tasks',
                    style: TextStyle(color: AppColors.textSecondary))),
          ),
        )
      : ResponsiveGridList(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (ctx, i) {
            final t = tasks[i];
            final priority = t['priority'] ?? 'low';
            final priorityColor = priority == 'high'
                ? AppColors.error
                : priority == 'medium'
                    ? AppColors.warning
                    : AppColors.textSecondary;

            // Extract assigned name from nested object
            final assignedTo = t['assigned_to'];
            final assignedName = assignedTo is Map
                ? (assignedTo['name'] ?? 'Unassigned')
                : 'Unassigned';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onTap(ctx, Map.from(t)),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: priorityColor, width: 4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                child: Text(
                                  t['title'] ?? '',
                                  style: AppTextStyles.cardTitle,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: priorityColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  priority.toUpperCase(),
                                  style: TextStyle(
                                    color: priorityColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              const Icon(Iconsax.user,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(assignedName, style: AppTextStyles.caption),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Iconsax.calendar,
                                  size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${_fmtDate(t['planned_start_date']?.toString(), fallback: t['created_at']?.toString())} → ${_fmtDate(t['planned_end_date']?.toString(), fallback: t['created_at']?.toString())}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary),
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 16, color: context.border),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
          });
}
