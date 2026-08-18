import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import 'package:currency_converter/currency.dart';
import 'package:currency_converter/currency_converter.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'task_detail_screen.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final Map project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen> {
  late Map _project;
  List<dynamic> _tasks = [];
  bool _loading = true;
  String? _convertedBudget;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadTasks();
    _convertBudget();
  }

  Future<void> _convertBudget() async {
    if (_project["total_budget"] == null) return;
    try {
      Currency? myCurrency;
      try {
        myCurrency = await CurrencyConverter.getMyCurrency();
      } catch (_) {}
      myCurrency ??= Currency.usd;

      if (myCurrency != Currency.npr) {
        final amount = double.tryParse(_project["total_budget"].toString());
        if (amount != null && amount > 0) {
          final converted = await CurrencyConverter.convert(
            from: Currency.npr,
            to: myCurrency,
            amount: amount,
          );
          if (mounted && converted != null) {
            setState(() {
              _convertedBudget = "${converted.toStringAsFixed(2)} ${myCurrency!.name.toUpperCase()}";
            });
          }
        }
      }
    } catch (_) {}
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Text('Project marked as ${newStatus.toUpperCase()}'),
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

  Color _statusColor(String s) {
    switch (s) {
      case "complete":
        return AppColors.success;
      case "incomplete":
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

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

  Color _taskStatusColor(String s) {
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
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final completion = (_project["completion"] ?? 0) as int;
    final projectStatus = (_project["status"] ?? "ongoing") as String;
    final projectType = (_project["project_type"] ?? "monthly").toString();
    final assignments = (_project["assignments"] as List?) ?? [];
    final files = (_project["files"] as List?) ?? [];
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: Text(
          _project["title"] ?? "Project Details",
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (isAdmin)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              icon: const Icon(Iconsax.edit_2, size: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              itemBuilder: (_) => [
                const PopupMenuItem(value: "ongoing", child: Text("Mark as Ongoing")),
                const PopupMenuItem(value: "incomplete", child: Text("Mark as Incomplete")),
                const PopupMenuItem(value: "complete", child: Text("Mark as Complete")),
              ],
            ),
          const SizedBox(width: 8),
        ],
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
                  // ── Hero Project Overview Card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(22),
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
                                    color: _statusColor(projectStatus).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    projectStatus.toUpperCase(),
                                    style: TextStyle(
                                      color: _statusColor(projectStatus),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _typeColor(projectType).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    projectType == "monthly"
                                        ? "MONTHLY RETAINER"
                                        : projectType == "daily"
                                            ? "DAILY BILLING"
                                            : "HOURLY BILLING",
                                    style: TextStyle(
                                      color: _typeColor(projectType),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "$completion% Complete",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Title
                        Text(
                          _project["title"] ?? "Untitled Project",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: context.textPrimary,
                          ),
                        ),

                        if (_project["description"] != null && (_project["description"] as String).isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            _project["description"].toString().replaceAll(RegExp(r"<[^>]*>"), ""),
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Progress bar
                        ClipRRect(
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

                        const SizedBox(height: 16),

                        // Quick Status Switcher Segment
                        if (isAdmin) ...[
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: context.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.border),
                            ),
                            child: Row(
                              children: [
                                _buildStatusTab("Ongoing", "ongoing", projectStatus == "ongoing", AppColors.primary),
                                _buildStatusTab("Incomplete", "incomplete", projectStatus == "incomplete", AppColors.error),
                                _buildStatusTab("Complete", "complete", projectStatus == "complete", AppColors.success),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Financial & Estimation Metrics Grid ──────────────────────
                  LayoutBuilder(
                    builder: (context, c) {
                      final cols = c.maxWidth < 600 ? 1 : 2;
                      return GridView.count(
                        crossAxisCount: cols,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: cols == 1 ? 4.5 : 3.0,
                        children: [
                          _buildMetricCard(
                            Iconsax.money_recive,
                            "Total Project Budget",
                            _project["total_budget"] != null
                                ? "NPR ${_project["total_budget"]}${_convertedBudget != null ? ' (~$_convertedBudget)' : ''}"
                                : "Unbudgeted",
                            AppColors.success,
                          ),
                          _buildMetricCard(
                            Iconsax.timer,
                            projectType == "monthly"
                                ? "Estimated Months"
                                : projectType == "daily"
                                    ? "Estimated Days"
                                    : "Estimated Hours",
                            _project["estimated_hours"] != null
                                ? "${_project["estimated_hours"]} ${projectType == "monthly" ? "months" : projectType == "daily" ? "days" : "hrs"}"
                                : "Not specified",
                            AppColors.primary,
                          ),
                        ],
                      );
                    },
                  ),

                  // ── Attached Project Documents ──────────────────────────────
                  if (files.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      "Attached Project Documents (${files.length})",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: files.map<Widget>((file) {
                        return OutlinedButton.icon(
                          onPressed: () {
                            final url = Uri.tryParse(file["file"]?.toString() ?? "");
                            if (url != null) launchUrl(url);
                          },
                          icon: const Icon(Iconsax.document_download, size: 16, color: AppColors.primary),
                          label: Text(file["title"] ?? "Project Document"),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Team Members & Compensation Breakdown ───────────────────
                  Text(
                    "Team Members & Compensation (${assignments.length})",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  if (assignments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.border),
                      ),
                      child: const Text("No team members assigned yet.", style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, c) {
                        final cols = c.maxWidth < 600 ? 1 : 2;
                        return GridView.count(
                          crossAxisCount: cols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: cols == 1 ? 4.0 : 2.8,
                          children: assignments.map<Widget>((a) {
                            final isSenior = a["role"] == "senior";
                            final earned = a["total_earned"] ?? 0;
                            final hours = a["total_hours"] ?? 0;
                            final days = a["total_days"] ?? 0;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: context.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: context.border),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: isSenior
                                        ? AppColors.primary.withValues(alpha: 0.12)
                                        : const Color(0xFF64748B).withValues(alpha: 0.12),
                                    child: Text(
                                      (a["name"] ?? "?").isNotEmpty ? (a["name"] as String)[0].toUpperCase() : "?",
                                      style: TextStyle(
                                        color: isSenior ? AppColors.primary : const Color(0xFF64748B),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                a["name"] ?? "Staff Member",
                                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.textPrimary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSenior ? AppColors.primary.withValues(alpha: 0.1) : context.card,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isSenior ? "SENIOR" : "JUNIOR",
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isSenior ? AppColors.primary : AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        if (a["hourly_rate"] != null)
                                          Text("Rate: NPR ${a["hourly_rate"]}/hr", style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary))
                                        else if (a["daily_rate"] != null)
                                          Text("Rate: NPR ${a["daily_rate"]}/day", style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                                        if (earned > 0)
                                          Text(
                                            projectType == "hourly" ? "$hours hrs • NPR $earned earned" : "$days days • NPR $earned earned",
                                            style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                  const SizedBox(height: 24),

                  // ── Tasks Section ───────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Project Tasks (${_tasks.length})",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
                      ),
                      if (_loading)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (!_loading && _tasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.border),
                      ),
                      child: const Text("No tasks assigned to this project yet.", style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else if (!_loading && _tasks.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final t = _tasks[i];
                        final tStatus = (t["status"] ?? "to-do") as String;
                        final priority = (t["priority"] ?? "low") as String;

                        return Container(
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.border),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => TaskDetailScreen(task: t)),
                                );
                                _loadTasks();
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _taskStatusColor(tStatus),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            t["title"] ?? "Untitled Task",
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.textPrimary),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            "${t["task_type"] ?? "daily"} • ${tStatus.replaceAll("-", " ")} • ${priority.toUpperCase()} priority",
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 40),
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
        onTap: () => _updateStatus(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
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

  Widget _buildMetricCard(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: context.textPrimary),
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
