import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:iconsax/iconsax.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../core/theme/app_theme.dart";
import "../../../core/services/api_service.dart";
import "../../../core/constants/app_constants.dart";
import "../../auth/providers/auth_provider.dart";
import "task_detail_screen.dart";

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final Map project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  late Map _project;
  List _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService().get(
        "${AppConstants.taskBase}/tasks/",
        queryParams: {"project": _project["id"].toString()},
      );
      if (mounted) {
        setState(() {
          _tasks = (res.data is List ? res.data : (res.data["results"] ?? [])) as List;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await ApiService().patch(
        "${AppConstants.projectsBase}/${_project["id"]}/",
        data: {"status": newStatus},
      );
      setState(() => _project = {..._project, "status": newStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.getErrorMessage(e)),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case "complete": return AppColors.success;
      case "incomplete": return AppColors.error;
      default: return AppColors.primary;
    }
  }

  Color _taskStatusColor(String s) {
    switch (s) {
      case "done": return AppColors.success;
      case "in-progress": return Colors.orange;
      default: return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final completion = (_project["completion"] ?? 0) as int;
    final projectStatus = (_project["status"] ?? "ongoing") as String;
    final assignments = (_project["assignments"] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_project["title"] ?? "Project"),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              itemBuilder: (_) => const [
                PopupMenuItem(value: "ongoing", child: Text("Mark Ongoing")),
                PopupMenuItem(value: "incomplete", child: Text("Mark Incomplete")),
                PopupMenuItem(value: "complete", child: Text("Mark Complete")),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status + Progress
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(projectStatus).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    projectStatus.toUpperCase(),
                    style: TextStyle(
                      color: _statusColor(projectStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (_project["project_type"] ?? "monthly").toString().toUpperCase(),
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completion / 100,
                      minHeight: 8,
                      backgroundColor: context.border,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text("$completion%", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                _StatChip(
                  label: _project["project_type"] == "monthly"
                      ? "Est. Months"
                      : _project["project_type"] == "daily"
                          ? "Est. Days"
                          : "Est. Hours",
                  value: _project["estimated_hours"] != null
                      ? "${_project["estimated_hours"]}${_project["project_type"] == "monthly" ? "m" : _project["project_type"] == "daily" ? "d" : "h"}"
                      : "—",
                  icon: Iconsax.clock,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: "Budget",
                  value: _project["total_budget"] != null
                      ? "NPR ${_project["total_budget"]}"
                      : "—",
                  icon: Iconsax.money,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Description
            if (_project["description"] != null && (_project["description"] as String).isNotEmpty) ...[
              Text("Description", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Text(_project["description"].toString().replaceAll(RegExp(r"<[^>]*>"), "")),
              const SizedBox(height: 16),
            ],

            // Attached Documents
            if (_project["files"] != null && (_project["files"] as List).isNotEmpty) ...[
              Text("Attached Documents", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (_project["files"] as List).map((file) {
                  return OutlinedButton.icon(
                    onPressed: () {
                      final url = Uri.tryParse(file["file"]?.toString() ?? "");
                      if (url != null) launchUrl(url);
                    },
                    icon: const Icon(Iconsax.document, size: 16),
                    label: Text(file["title"] ?? "Document"),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Members
            if (assignments.isNotEmpty) ...[
              Text("Team Members", style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: assignments.map<Widget>((a) {
                  final isSenior = a["role"] == "senior";
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: isSenior ? AppColors.primary : Colors.grey,
                      child: Text((a["name"] ?? "?")[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                    label: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(a["name"] ?? "Unknown"),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSenior ? "Senior" : "Junior",
                              style: TextStyle(
                                fontSize: 10,
                                color: isSenior ? AppColors.primary : context.textSecondary,
                              ),
                            ),
                            if (a["hourly_rate"] != null)
                              Text(" • ${a["hourly_rate"]}/hr", style: const TextStyle(fontSize: 10)),
                            if (a["daily_rate"] != null)
                              Text(" • ${a["daily_rate"]}/day", style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                        if (a["total_earned"] != null && (a["total_earned"] > 0))
                          Text(
                            a["hourly_rate"] != null
                                ? "${a["total_hours"]}h • NPR ${a["total_earned"]}"
                                : "${a["total_days"]}d • NPR ${a["total_earned"]}",
                            style: const TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Tasks
            Text("Tasks (${_tasks.length})", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),

            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text("No tasks yet", style: TextStyle(color: context.textSecondary)),
                ),
              )
            else
              ..._tasks.map((t) {
                final tStatus = (t["status"] ?? "to-do") as String;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _taskStatusColor(tStatus),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(t["title"] ?? "Untitled"),
                    subtitle: Text(
                      "${t["task_type"] ?? "daily"} • ${tStatus.replaceAll("-", " ")} • ${t["priority"] ?? "low"} priority",
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(task: t),
                        ),
                      );
                      _loadTasks();
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: context.textSecondary)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
