import 'package:material_ui/material_ui.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';

class TaskKanbanBoard extends StatefulWidget {
  final List<dynamic> todoTasks;
  final List<dynamic> inProgressTasks;
  final List<dynamic> doneTasks;
  final bool isAdmin;
  final void Function(Map task) onTapTask;
  final void Function(Map task) onOpenLogs;
  final void Function(String initialStatus) onAddCard;
  final void Function(Map task, String newStatus) onMoveTask;
  final void Function(Map task) onEditTask;
  final void Function(Map task) onDeleteTask;
  final String Function(String? raw, {String? fallback}) formatDate;

  const TaskKanbanBoard({
    super.key,
    required this.todoTasks,
    required this.inProgressTasks,
    required this.doneTasks,
    required this.isAdmin,
    required this.onTapTask,
    required this.onOpenLogs,
    required this.onAddCard,
    required this.onMoveTask,
    required this.onEditTask,
    required this.onDeleteTask,
    required this.formatDate,
  });

  @override
  State<TaskKanbanBoard> createState() => _TaskKanbanBoardState();
}

class _TaskKanbanBoardState extends State<TaskKanbanBoard> {
  final ScrollController _mobileScrollCtrl = ScrollController();
  int _activeMobileLane = 0;
  String? _hoveredStatus;
  double _lastLaneExtent = 312;

  @override
  void initState() {
    super.initState();
    _mobileScrollCtrl.addListener(_handleMobileScroll);
  }

  @override
  void dispose() {
    _mobileScrollCtrl.removeListener(_handleMobileScroll);
    _mobileScrollCtrl.dispose();
    super.dispose();
  }

  void _handleMobileScroll() {
    if (!_mobileScrollCtrl.hasClients || _lastLaneExtent <= 0) return;
    final idx = (_mobileScrollCtrl.offset / _lastLaneExtent).round().clamp(0, 2);
    if (idx != _activeMobileLane && mounted) {
      setState(() => _activeMobileLane = idx);
    }
  }

  void _jumpToLane(int index) {
    if (!_mobileScrollCtrl.hasClients) return;
    final target = (index * _lastLaneExtent)
        .clamp(0.0, _mobileScrollCtrl.position.maxScrollExtent);
    setState(() => _activeMobileLane = index);
    _mobileScrollCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildColumn(
                  context,
                  title: 'To Do',
                  status: 'to-do',
                  color: AppColors.primary,
                  icon: Iconsax.clipboard_text,
                  tasks: widget.todoTasks,
                  isMobile: false,
                  cardDragWidth: (constraints.maxWidth - 32) / 3 - 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildColumn(
                  context,
                  title: 'In Progress',
                  status: 'in-progress',
                  color: AppColors.warning,
                  icon: Iconsax.timer_1,
                  tasks: widget.inProgressTasks,
                  isMobile: false,
                  cardDragWidth: (constraints.maxWidth - 32) / 3 - 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildColumn(
                  context,
                  title: 'Done',
                  status: 'done',
                  color: AppColors.success,
                  icon: Iconsax.tick_circle,
                  tasks: widget.doneTasks,
                  isMobile: false,
                  cardDragWidth: (constraints.maxWidth - 32) / 3 - 28,
                ),
              ),
            ],
          );
        }

        // Responsive mobile / narrow tablet horizontal Trello lanes
        final laneWidth = (constraints.maxWidth * 0.85).clamp(255.0, 340.0);
        const laneGap = 12.0;
        _lastLaneExtent = laneWidth + laneGap;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick-jump mobile lane pills (To Do / In Progress / Done)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  _buildMobileLanePill(
                    0,
                    'To Do',
                    widget.todoTasks.length,
                    AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  _buildMobileLanePill(
                    1,
                    'In Progress',
                    widget.inProgressTasks.length,
                    AppColors.warning,
                  ),
                  const SizedBox(width: 4),
                  _buildMobileLanePill(
                    2,
                    'Done',
                    widget.doneTasks.length,
                    AppColors.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Row(
                children: [
                  Icon(Iconsax.arrow_swap_horizontal,
                      size: 13, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Swipe lanes, long-press to drag, or tap ⋮ on any card to move',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              controller: _mobileScrollCtrl,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: laneWidth,
                    child: _buildColumn(
                      context,
                      title: 'To Do',
                      status: 'to-do',
                      color: AppColors.primary,
                      icon: Iconsax.clipboard_text,
                      tasks: widget.todoTasks,
                      isMobile: true,
                      cardDragWidth: laneWidth - 24,
                    ),
                  ),
                  const SizedBox(width: laneGap),
                  SizedBox(
                    width: laneWidth,
                    child: _buildColumn(
                      context,
                      title: 'In Progress',
                      status: 'in-progress',
                      color: AppColors.warning,
                      icon: Iconsax.timer_1,
                      tasks: widget.inProgressTasks,
                      isMobile: true,
                      cardDragWidth: laneWidth - 24,
                    ),
                  ),
                  const SizedBox(width: laneGap),
                  SizedBox(
                    width: laneWidth,
                    child: _buildColumn(
                      context,
                      title: 'Done',
                      status: 'done',
                      color: AppColors.success,
                      icon: Iconsax.tick_circle,
                      tasks: widget.doneTasks,
                      isMobile: true,
                      cardDragWidth: laneWidth - 24,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileLanePill(
      int index, String label, int count, Color color) {
    final active = _activeMobileLane == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _jumpToLane(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: active ? color.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? color : Colors.transparent,
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? color : AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: active
                        ? color
                        : color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColumn(
    BuildContext context, {
    required String title,
    required String status,
    required Color color,
    required IconData icon,
    required List<dynamic> tasks,
    required bool isMobile,
    required double cardDragWidth,
  }) {
    final isHovering = _hoveredStatus == status;

    return DragTarget<Map>(
      onWillAcceptWithDetails: (details) {
        final current =
            (details.data['status'] ?? 'to-do').toString().toLowerCase();
        if (current != status && _hoveredStatus != status) {
          setState(() => _hoveredStatus = status);
        }
        return current != status;
      },
      onLeave: (_) {
        if (_hoveredStatus == status) {
          setState(() => _hoveredStatus = null);
        }
      },
      onAcceptWithDetails: (details) {
        setState(() => _hoveredStatus = null);
        widget.onMoveTask(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = isHovering || candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: highlighted
                ? color.withValues(alpha: context.isDark ? 0.14 : 0.06)
                : context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: highlighted ? color : context.border,
              width: highlighted ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.2 : 0.025),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Colored Trello top strip
                Container(height: 3.5, color: color),
                Padding(
                  padding: EdgeInsets.all(isMobile ? 12 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Column Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(icon, size: 16, color: color),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${tasks.length}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color: color,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              tooltip: 'Add card to $title',
                              onPressed: () => widget.onAddCard(status),
                              icon: Icon(Iconsax.add, size: 18, color: color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: context.border, height: 1),
                      const SizedBox(height: 12),

                      // Cards List or Drop Hint
                      if (tasks.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 24),
                          decoration: BoxDecoration(
                            color: context.card.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: highlighted
                                  ? color.withValues(alpha: 0.5)
                                  : context.border,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                highlighted ? Iconsax.direct_inbox : icon,
                                size: 22,
                                color: highlighted
                                    ? color
                                    : AppColors.textSecondary
                                        .withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                highlighted
                                    ? 'Drop card into $title'
                                    : 'No cards in $title',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: highlighted
                                      ? color
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tasks.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _buildDraggableCard(
                            context,
                            tasks[i] as Map,
                            isMobile: isMobile,
                            dragWidth: cardDragWidth.clamp(220.0, 360.0),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Trello-style "+ Add a card" column footer button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onAddCard(status),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: color.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.add_circle,
                                    size: 16, color: color),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Add Card',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggableCard(
    BuildContext context,
    Map task, {
    required bool isMobile,
    required double dragWidth,
  }) {
    final card = _buildTrelloCard(context, task, isMobile: isMobile);
    final feedback = Material(
      color: Colors.transparent,
      elevation: 10,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: dragWidth,
        child: Opacity(opacity: 0.94, child: card),
      ),
    );
    final childWhenDragging = Opacity(opacity: 0.35, child: card);

    if (isMobile) {
      return LongPressDraggable<Map>(
        data: task,
        delay: const Duration(milliseconds: 220),
        feedback: feedback,
        childWhenDragging: childWhenDragging,
        child: card,
      );
    }

    return Draggable<Map>(
      data: task,
      feedback: feedback,
      childWhenDragging: childWhenDragging,
      child: card,
    );
  }

  Widget _buildTrelloCard(BuildContext context, Map t,
      {required bool isMobile}) {
    final priority = (t['priority'] ?? 'low').toString().toLowerCase();
    final priorityColor = priority == 'high'
        ? AppColors.error
        : priority == 'medium'
            ? AppColors.warning
            : const Color(0xFF10B981);

    final status = (t['status'] ?? 'to-do').toString().toLowerCase();
    final proj = t['project'];
    final projId = proj is Map ? proj['id'] : null;
    final projName = proj is Map ? (proj['name'] ?? proj['title']) : null;
    final isPersonal = t['is_personal'] == true || projId == null;

    final assignedTo = t['assigned_to'];
    final assignedName =
        assignedTo is Map ? (assignedTo['name'] ?? 'Unassigned') : 'Unassigned';

    final rating = t['rating'];
    final hasPdf = t['description_pdf'] != null &&
        t['description_pdf'].toString().isNotEmpty;
    final progressCount = t['progress_count'] is int
        ? t['progress_count'] as int
        : (t['progress_reports'] is List
            ? (t['progress_reports'] as List).length
            : 0);
    final canEdit = t['can_edit'] == true || widget.isAdmin;
    final canDelete = t['can_delete'] == true || widget.isAdmin;

    const personalColor = Color(0xFF8B5CF6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onTapTask(t),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 12 : 14),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: context.isDark ? 0.22 : 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Badges + Quick Action Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            priority.toUpperCase(),
                            style: TextStyle(
                              color: priorityColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (isPersonal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: personalColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.user_tag,
                                    size: 10, color: personalColor),
                                SizedBox(width: 4),
                                Text(
                                  'Personal',
                                  style: TextStyle(
                                    color: personalColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (projName != null)
                          Container(
                            constraints: BoxConstraints(
                                maxWidth: isMobile ? 140 : 165),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              projName.toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      tooltip: 'Card actions',
                      icon: const Icon(Icons.more_vert,
                          size: 17, color: AppColors.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      onSelected: (action) {
                        if (action.startsWith('move:')) {
                          widget.onMoveTask(t, action.substring(5));
                        } else if (action == 'logs') {
                          widget.onOpenLogs(t);
                        } else if (action == 'edit') {
                          widget.onEditTask(t);
                        } else if (action == 'delete') {
                          widget.onDeleteTask(t);
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
                            value: 'move:to-do',
                            child: Row(
                              children: [
                                Icon(Iconsax.clipboard_text,
                                    size: 15, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Move to To Do'),
                              ],
                            ),
                          ),
                        if (status != 'in-progress')
                          const PopupMenuItem(
                            value: 'move:in-progress',
                            child: Row(
                              children: [
                                Icon(Iconsax.timer_1,
                                    size: 15, color: AppColors.warning),
                                SizedBox(width: 8),
                                Text('Move to In Progress'),
                              ],
                            ),
                          ),
                        if (status != 'done')
                          const PopupMenuItem(
                            value: 'move:done',
                            child: Row(
                              children: [
                                Icon(Iconsax.tick_circle,
                                    size: 15, color: AppColors.success),
                                SizedBox(width: 8),
                                Text('Move to Done'),
                              ],
                            ),
                          ),
                        if (canEdit)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Iconsax.edit_2,
                                    size: 15, color: AppColors.primary),
                                SizedBox(width: 8),
                                Text('Edit Card'),
                              ],
                            ),
                          ),
                        if (canDelete)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Iconsax.trash,
                                    size: 15, color: AppColors.error),
                                SizedBox(width: 8),
                                Text('Delete Card',
                                    style: TextStyle(color: AppColors.error)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Card Title
              Text(
                t['title'] ?? 'Untitled Task',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 14.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: context.textPrimary,
                ),
              ),

              if (t['description'] != null &&
                  t['description'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  t['description'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.32,
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Action / Meta pills row (Progress Logs chip + PDF + Rating + Date)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => widget.onOpenLogs(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasPdf)
                    const Icon(Iconsax.paperclip,
                        size: 13, color: AppColors.textSecondary),
                  if (widget.isAdmin && rating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.star1,
                            size: 12, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          '$rating/10',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.calendar_1,
                          size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        widget.formatDate(
                          t['planned_end_date']?.toString(),
                          fallback: t['created_at']?.toString(),
                        ),
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(color: context.border, height: 1),
              const SizedBox(height: 8),

              // Assignee Footer
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: isPersonal
                        ? personalColor.withValues(alpha: 0.14)
                        : AppColors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      Iconsax.user,
                      size: 10,
                      color: isPersonal ? personalColor : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      assignedName.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
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
