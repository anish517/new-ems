
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:iconsax/iconsax.dart";
import "package:file_picker/file_picker.dart";
import "package:url_launcher/url_launcher.dart";
import "../../../core/theme/app_theme.dart";
import "../../../core/services/api_service.dart";
import "../../../core/constants/app_constants.dart";


class TaskDetailScreen extends ConsumerStatefulWidget {
  final Map task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late Map _task;
  List _reports = [];
  bool _loadingReports = true;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _loadReports();
  }

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() => _loadingReports = true);
    try {
      final res = await ApiService().get(
        "${AppConstants.taskProgressBase}/${_task["id"]}/progress/",
      );
      if (mounted) {
        setState(() {
          _reports = (res.data is List ? res.data : (res.data["results"] ?? [])) as List;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingReports = false);
    }
  }

  Future<void> _updateTaskStatus(String newStatus) async {
    try {
      await ApiService().patch(
        "${AppConstants.taskBase}/tasks/${_task["id"]}/",
        data: {"status": newStatus},
      );
      setState(() => _task = {..._task, "status": newStatus});
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
      case "done": return AppColors.success;
      case "in-progress": return Colors.orange;
      default: return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskStatus = (_task["status"] ?? "to-do") as String;
    final taskType = (_task["task_type"] ?? "daily") as String;
    final priority = (_task["priority"] ?? "low") as String;
    final assignedTo = _task["assigned_to"];
    final assignedName = (assignedTo is Map) ? (assignedTo["name"] ?? "—") : "—";

    return Scaffold(
      appBar: AppBar(
        title: Text(_task["title"] ?? "Task"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _updateTaskStatus,
            icon: const Icon(Iconsax.edit),
            itemBuilder: (_) => const [
              PopupMenuItem(value: "to-do", child: Text("Mark To-Do")),
              PopupMenuItem(value: "in-progress", child: Text("Mark In-Progress")),
              PopupMenuItem(value: "done", child: Text("Mark Done")),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await showDialog(
            context: context,
            builder: (_) => _AddProgressReportDialog(task: widget.task),
          );
          if (res == true) _loadReports();
        },
        icon: const Icon(Icons.add),
        label: const Text("Log Progress"),
        backgroundColor: AppColors.primary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status badges row
          Wrap(
            spacing: 8,
            children: [
              _Badge(
                label: taskStatus.replaceAll("-", " ").toUpperCase(),
                color: _statusColor(taskStatus),
              ),
              _Badge(label: taskType.toUpperCase(), color: AppColors.primary),
              _Badge(
                label: priority.toUpperCase(),
                color: priority == "high"
                    ? AppColors.error
                    : priority == "medium"
                        ? Colors.orange
                        : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Assigned to
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Iconsax.user, size: 20),
            title: const Text("Assigned to"),
            subtitle: Text(assignedName),
          ),

          // Description
          if (_task["description"] != null && (_task["description"] as String).isNotEmpty) ...[
            const Divider(),
            Text("Description", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(_task["description"].toString().replaceAll(RegExp(r"<[^>]*>"), "")),
            const SizedBox(height: 16),
          ],

          // Progress reports timeline
          const Divider(),
          Row(
            children: [
              Text(
                "Progress Reports (${_reports.length})",
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              if (_loadingReports) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 12),

          if (!_loadingReports && _reports.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Iconsax.document, size: 48, color: context.textSecondary),
                    const SizedBox(height: 8),
                    Text("No progress logged yet", style: TextStyle(color: context.textSecondary)),
                    const SizedBox(height: 4),
                    Text("Tap + to log your daily progress", style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            )
          else
            ..._reports.map((r) => _ProgressReportCard(report: r, onDelete: () async {
              try {
                await ApiService().delete("${AppConstants.taskBase.replaceAll("/tasks", "")}/progress/${r["id"]}/");
                _loadReports();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ApiService.getErrorMessage(e)),
                    backgroundColor: AppColors.error,
                  ));
                }
              }
            })),
          const SizedBox(height: 80), // FAB space
        ],
      ),
    );
  }
}

// ─── Progress Report Card ────────────────────────────────────────────────────

class _ProgressReportCard extends StatelessWidget {
  final Map report;
  final VoidCallback onDelete;

  const _ProgressReportCard({required this.report, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasAttachment = report["attachment_url"] != null && (report["attachment_url"] as String).isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    ((report["submitted_by_name"] ?? "?") as String).isNotEmpty
                        ? (report["submitted_by_name"] as String)[0].toUpperCase()
                        : "?",
                    style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report["submitted_by_name"] ?? "Unknown",
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Text(
                        report["date"] ?? "",
                        style: TextStyle(fontSize: 11, color: context.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Iconsax.trash, size: 16),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text("Delete Report"),
                        content: const Text("Remove this progress report?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete")),
                        ],
                      ),
                    );
                    if (confirm == true) onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Description
            Text(report["description"] ?? ""),

            // Time & Earned Amount
            if (report["hours_worked"] != null || report["days_worked"] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (report["hours_worked"] != null)
                    _Badge(label: "${report["hours_worked"]} hours", color: context.textSecondary),
                  if (report["days_worked"] != null)
                    _Badge(label: "${report["days_worked"]} days", color: context.textSecondary),
                  if (report["earned_amount"] != null) ...[
                    const SizedBox(width: 8),
                    _Badge(label: "+ NPR ${report["earned_amount"]}", color: AppColors.success),
                  ],
                ],
              ),
            ],

            // Attachment
            if (hasAttachment) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final url = Uri.parse(report["attachment_url"] as String);
                  if (await canLaunchUrl(url)) launchUrl(url);
                },
                child: Row(
                  children: [
                    const Icon(Iconsax.document_download, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "View Attachment",
                        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Add Progress Report Dialog ───────────────────────────────────────────────

class _AddProgressReportDialog extends ConsumerStatefulWidget {
  final Map task;
  const _AddProgressReportDialog({required this.task});

  @override
  ConsumerState<_AddProgressReportDialog> createState() => _AddProgressReportDialogState();
}

class _AddProgressReportDialogState extends ConsumerState<_AddProgressReportDialog> {
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  PlatformFile? _attachment;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default to today
    final now = DateTime.now();
    _dateCtrl.text = "${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}";
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (result != null && result.files.isNotEmpty && mounted) {
      setState(() => _attachment = result.files.first);
    }
  }

  Future<void> _submit() async {
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a description")),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final taskId = widget.task['id'];
      final taskType = widget.task['task_type'] ?? 'daily';
      final isHourly = taskType == 'hourly';
      final timeKey = isHourly ? "hours_worked" : "days_worked";
      
      if (_attachment != null) {
        // multipart upload
        final formData = {
          "task": taskId.toString(),
          "date": _dateCtrl.text.trim(),
          "description": _descCtrl.text.trim(),
          if (_timeCtrl.text.isNotEmpty) timeKey: _timeCtrl.text.trim(),
        };
        await ApiService().postMultipart(
          "${AppConstants.taskProgressBase}/$taskId/progress/",
          fields: formData,
          files: {"attachment": _attachment!},
        );
      } else {
        await ApiService().post(
          "${AppConstants.taskProgressBase}/$taskId/progress/",
          data: {
            "task": taskId,
            "date": _dateCtrl.text.trim(),
            "description": _descCtrl.text.trim(),
            if (_timeCtrl.text.isNotEmpty) timeKey: _timeCtrl.text.trim(),
          },
        );
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
      title: const Text("Log Progress"),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _dateCtrl,
              decoration: const InputDecoration(
                labelText: "Date",
                hintText: "YYYY-MM-DD",
                suffixIcon: Icon(Iconsax.calendar),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: "What did you do? *"),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timeCtrl,
              decoration: InputDecoration(
                labelText: (widget.task['task_type'] == 'hourly') ? "Hours Worked" : "Days Worked",
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Iconsax.document_upload, size: 16),
              label: Text(_attachment == null ? "Attach Document" : _attachment!.name),
            ),
          ],
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
              : const Text("Submit"),
        ),
      ],
    );
  }
}

// ─── Badge widget ────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
