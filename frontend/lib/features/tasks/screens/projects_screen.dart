
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:iconsax/iconsax.dart";
import "package:dio/dio.dart";
import "package:file_picker/file_picker.dart";
import "../../../core/theme/app_theme.dart";
import "../../../core/services/api_service.dart";
import "../../../core/constants/app_constants.dart";
import "../../auth/providers/auth_provider.dart";
import "project_detail_screen.dart";

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List _projects = [];
  bool _loading = true;

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

  List _byStatus(String status) =>
      _projects.where((p) => p["status"] == status).toList();

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Projects"),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: "Ongoing"),
              Tab(text: "Incomplete"),
              Tab(text: "Complete"),
            ],
          ),
        ),
        floatingActionButton: isAdmin
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final created = await showDialog<bool>(
                    context: context,
                    builder: (_) => const _CreateProjectDialog(),
                  );
                  if (created == true) _loadProjects();
                },
                icon: const Icon(Icons.add),
                label: const Text("New Project"),
                backgroundColor: AppColors.primary,
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadProjects,
                child: TabBarView(
                  controller: _tabs,
                  children: _statuses.asMap().entries.map((e) {
                    final list = _byStatus(e.value);
                    if (list.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Iconsax.folder_open, size: 64, color: context.textSecondary),
                            const SizedBox(height: 12),
                            Text("No ${_statusLabels[e.key].toLowerCase()} projects",
                                style: TextStyle(color: context.textSecondary)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
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
      case "hourly": return Colors.orange;
      case "daily": return Colors.blue;
      default: return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (project["project_type"] ?? "monthly") as String;
    final completion = (project["completion"] ?? 0) as int;
    final assignments = (project["assignments"] as List?) ?? [];
    final taskCounts = (project["task_counts"] as Map?) ?? {};

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + Type Badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project["title"] ?? "Untitled",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _typeColor(type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: TextStyle(
                        color: _typeColor(type),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completion / 100,
                  minHeight: 6,
                  backgroundColor: context.border,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "$completion% complete  •  ${taskCounts["done"] ?? 0}/${taskCounts["total"] ?? 0} tasks done",
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              const SizedBox(height: 12),

              // Members row
              if (assignments.isNotEmpty)
                Row(
                  children: [
                    Icon(Iconsax.people, size: 14, color: context.textSecondary),
                    const SizedBox(width: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: assignments.map<Widget>((a) {
                        final isSenior = a["role"] == "senior";
                        
                        String labelStr = "${a["name"] ?? "?"}";
                        if (type == "hourly") {
                          final h = a["total_hours"] ?? 0;
                          final e = a["total_earned"] ?? 0;
                          labelStr += " • ${h}h • NPR $e";
                        } else if (type == "daily") {
                          final d = a["total_days"] ?? 0;
                          final e = a["total_earned"] ?? 0;
                          labelStr += " • ${d}d • NPR $e";
                        }

                        return Chip(
                          label: Text(labelStr, style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: isSenior
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : context.card,
                        );
                      }).toList(),
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
      // Build member assignment list
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
    return AlertDialog(
      title: const Text("Create Project"),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: "Project Title *"),
                  validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: "Description"),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),

                // File attachments
                OutlinedButton.icon(
                  onPressed: _pickFiles,
                  icon: const Icon(Iconsax.document_upload, size: 16),
                  label: Text(_attachments.isEmpty
                      ? "Add Attachments"
                      : "${_attachments.length} file(s) selected"),
                ),
                const SizedBox(height: 12),

                // Project Type
                DropdownButtonFormField<String>(
                  value: _projectType,
                  decoration: const InputDecoration(labelText: "Project Type *"),
                  items: const [
                    DropdownMenuItem(value: "monthly", child: Text("Monthly")),
                    DropdownMenuItem(value: "daily", child: Text("Daily")),
                    DropdownMenuItem(value: "hourly", child: Text("Hourly")),
                  ],
                  onChanged: (v) => setState(() => _projectType = v!),
                ),
                const SizedBox(height: 12),

                // Estimated Hours — for all types
                TextFormField(
                  controller: _estHoursCtrl,
                  decoration: InputDecoration(
                    labelText: _projectType == "monthly"
                        ? "Estimated Months"
                        : _projectType == "daily"
                            ? "Estimated Days"
                            : "Estimated Hours",
                    suffixText: _projectType == "monthly"
                        ? "months"
                        : _projectType == "daily"
                            ? "days"
                            : "hrs",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),

                // Total Budget
                TextFormField(
                  controller: _budgetCtrl,
                  decoration: const InputDecoration(
                    labelText: "Total Budget",
                    prefixText: "NPR ",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),

                // Assign Members
                Text("Assign Members", style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_allEmployees.isEmpty)
                  const Text("Loading employees…", style: TextStyle(fontSize: 12))
                else
                  ..._allEmployees.map((emp) {
                    final id = emp["id"] as int;
                    final name = "${emp["user"]?["first_name"] ?? ""} ${emp["user"]?["last_name"] ?? ""}".trim();
                    final isSelected = _selectedRoles.containsKey(id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
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
                          Expanded(child: Text(name.isEmpty ? "Employee #$id" : name)),
                          if (isSelected && _projectType != "monthly")
                            Container(
                              width: 120,
                              margin: const EdgeInsets.only(right: 8),
                              child: TextField(
                                controller: _rateControllers[id],
                                decoration: InputDecoration(
                                  labelText: _projectType == "hourly" ? "Rate/hr" : "Rate/day",
                                  prefixText: "NPR ",
                                  isDense: true,
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                            ),
                          if (isSelected)
                            SizedBox(
                              width: 90,
                              child: DropdownButton<String>(
                                value: _selectedRoles[id],
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: "senior", child: Text("Senior")),
                                  DropdownMenuItem(value: "junior", child: Text("Junior")),
                                ],
                                onChanged: (v) => setState(() => _selectedRoles[id] = v!),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text("Create"),
        ),
      ],
    );
  }
}
