import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import 'package:nepali_utils/nepali_utils.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final Map task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  late Map _task;
  List<dynamic> _reports = [];
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiService.getErrorMessage(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _showAddProgressDialog() async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      final res = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: _AddProgressReportDialog(task: _task),
          ),
        ),
      );
      if (res == true) _loadReports();
    } else {
      final res = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _AddProgressReportDialog(task: _task),
      );
      if (res == true) _loadReports();
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case "done":
        return AppColors.success;
      case "in-progress":
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskStatus = (_task["status"] ?? "to-do") as String;
    final taskType = (_task["task_type"] ?? "daily") as String;
    final priority = (_task["priority"] ?? "low") as String;
    final priorityColor = priority == 'high'
        ? AppColors.error
        : priority == 'medium'
            ? AppColors.warning
            : const Color(0xFF10B981);

    final assignedTo = _task["assigned_to"];
    final assignedName = (assignedTo is Map) ? (assignedTo["name"] ?? "Unassigned") : "Unassigned";
    final proj = _task["project"];
    final projName = proj is Map ? (proj["name"] ?? proj["title"] ?? "Project") : "General Project";
    final rating = _task["rating"];
    final hasPdf = _task["description_pdf"] != null && _task["description_pdf"].toString().isNotEmpty;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: Text(
          _task["title"] ?? "Task Details",
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _updateTaskStatus,
            icon: const Icon(Iconsax.edit_2, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (_) => [
              const PopupMenuItem(value: "to-do", child: Text("Mark as To-Do")),
              const PopupMenuItem(value: "in-progress", child: Text("Mark as In-Progress")),
              const PopupMenuItem(value: "done", child: Text("Mark as Done")),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddProgressDialog,
        backgroundColor: AppColors.primary,
        elevation: 6,
        icon: const Icon(Iconsax.add_circle, color: Colors.white, size: 20),
        label: const Text(
          "Log Progress",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Hero Task Details Card ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badges Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        priority == 'high'
                                            ? Iconsax.danger
                                            : priority == 'medium'
                                                ? Iconsax.flash
                                                : Iconsax.tick_circle,
                                        size: 13,
                                        color: priorityColor,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${priority.toUpperCase()} PRIORITY',
                                        style: TextStyle(color: priorityColor, fontSize: 11, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.card,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: context.border),
                                  ),
                                  child: Text(
                                    taskType.toUpperCase(),
                                    style: TextStyle(
                                      color: context.textPrimary,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _statusColor(taskStatus).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                taskStatus.replaceAll("-", " ").toUpperCase(),
                                style: TextStyle(
                                  color: _statusColor(taskStatus),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Title
                        Text(
                          _task["title"] ?? "Untitled Task",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: context.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Status Segment Switcher
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.border),
                          ),
                          child: Row(
                            children: [
                              _buildStatusTab("To Do", "to-do", taskStatus == "to-do", AppColors.primary),
                              _buildStatusTab("In Progress", "in-progress", taskStatus == "in-progress", AppColors.warning),
                              _buildStatusTab("Completed", "done", taskStatus == "done", AppColors.success),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Assignee & Meta Grid
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.border),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                child: const Icon(Iconsax.user, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Assigned Employee",
                                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      assignedName,
                                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                              if (rating != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Iconsax.star1, size: 14, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        "$rating/10 Score",
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.amber),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Description
                        if (_task["description"] != null && (_task["description"] as String).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            "Description & Deliverable Scope",
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.textPrimary),
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
                              _task["description"].toString().replaceAll(RegExp(r"<[^>]*>"), ""),
                              style: TextStyle(fontSize: 13.5, color: context.textPrimary, height: 1.5),
                            ),
                          ),
                        ],

                        // Attachment button
                        if (hasPdf) ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: () {
                              final url = Uri.tryParse(_task["description_pdf"]);
                              if (url != null) launchUrl(url);
                            },
                            icon: const Icon(Iconsax.document_download, size: 18, color: AppColors.primary),
                            label: const Text("View Attached Specification Document"),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Progress Reports Timeline Section ───────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Iconsax.clock, color: AppColors.primary, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Progress Reports (${_reports.length})",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                          ),
                        ],
                      ),
                      if (_loadingReports)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),

                  const SizedBox(height: 14),

                  if (!_loadingReports && _reports.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.border),
                      ),
                      child: Column(
                        children: [
                          const Icon(Iconsax.document_text, size: 44, color: AppColors.textSecondary),
                          const SizedBox(height: 10),
                          Text(
                            "No progress reports logged yet",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Submit your daily or hourly progress update below.",
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._reports.map((r) => _ProgressReportCard(
                          report: r,
                          onDelete: () async {
                            try {
                              await ApiService().delete("${AppConstants.taskProgressBase}/${r["id"]}/");
                              _loadReports();
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(ApiService.getErrorMessage(e)),
                                  backgroundColor: AppColors.error,
                                ));
                              }
                            }
                          },
                        )),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTab(String label, String value, bool isSelected, Color color) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _updateTaskStatus(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
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
}

// ─── Progress Report Card ────────────────────────────────────────────────────
class _ProgressReportCard extends StatelessWidget {
  final Map report;
  final VoidCallback onDelete;

  const _ProgressReportCard({required this.report, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final hasAttachment = report["attachment_url"] != null && (report["attachment_url"] as String).isNotEmpty;
    final submitterName = report["submitted_by_name"] ?? "Staff Member";
    final date = report["date"] ?? "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  submitterName.isNotEmpty ? submitterName[0].toUpperCase() : "U",
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submitterName,
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: context.textPrimary),
                    ),
                    if (date.isNotEmpty)
                      Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Iconsax.trash, size: 16, color: AppColors.error),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Delete Report"),
                      content: const Text("Are you sure you want to remove this progress log?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text("Delete", style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) onDelete();
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            report["description"] ?? "",
            style: TextStyle(fontSize: 13, color: context.textPrimary, height: 1.4),
          ),

          if (report["hours_worked"] != null || report["days_worked"] != null || report["earned_amount"] != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (report["hours_worked"] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${report["hours_worked"]} hrs",
                      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (report["days_worked"] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${report["days_worked"]} days",
                      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (report["earned_amount"] != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "+ NPR ${report["earned_amount"]}",
                      style: const TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ],

          if (hasAttachment) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final url = Uri.parse(report["attachment_url"] as String);
                if (await canLaunchUrl(url)) launchUrl(url);
              },
              child: const Row(
                children: [
                  Icon(Iconsax.document_download, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    "View Attached Document",
                    style: TextStyle(color: AppColors.primary, decoration: TextDecoration.underline, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
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
    final now = NepaliDateTime.now();
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
        const SnackBar(content: Text("Please enter a description of work performed")),
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
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
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
                      child: const Icon(Iconsax.clock, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Task Progress',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary),
                        ),
                        const Text(
                          'Record effort, billable time & milestone proof',
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
              controller: _dateCtrl,
              decoration: const InputDecoration(
                labelText: "Date (B.S.)",
                prefixIcon: Icon(Iconsax.calendar, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: "What did you accomplish? *",
                hintText: "Summary of activities, merged PRs, or client updates...",
                alignLabelWithHint: true,
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _timeCtrl,
              decoration: InputDecoration(
                labelText: (widget.task['task_type'] == 'hourly') ? "Hours Worked" : "Days Worked",
                prefixIcon: const Icon(Iconsax.timer, size: 18),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Iconsax.document_upload, size: 18),
              label: Text(_attachment == null ? "Attach Document / Screenshots" : _attachment!.name),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

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
                          Icon(Iconsax.send_1, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Submit Progress Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
