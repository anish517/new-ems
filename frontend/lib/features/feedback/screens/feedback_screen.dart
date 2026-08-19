import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/date_provider.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});
  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _complaints = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  String _searchQuery = '';
  int? _selectedCategoryId;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadComplaints();
    _loadCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res =
          await ApiService().get('${AppConstants.feedbackBase}/categories/');
      final data =
          res.data is List ? res.data : (res.data['results'] ?? res.data);
      if (mounted && data is List) {
        setState(() => _categories = data);
      }
    } catch (_) {}
  }

  Future<void> _loadComplaints() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('${AppConstants.feedbackBase}/');
      if (!mounted) return;
      setState(() {
        _complaints =
            res.data is List ? res.data : (res.data['results'] ?? res.data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteComplaint(int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ctx.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.trash,
                          color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete Feedback',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ctx.textPrimary,
                            ),
                          ),
                          const Text(
                            'Permanent deletion of grievance thread',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Are you sure you want to permanently delete "$title" and all its associated conversation replies?',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: ctx.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirm != true) return;

    try {
      await ApiService().delete('${AppConstants.feedbackBase}/$id/');
      _loadComplaints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Feedback entry deleted successfully'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleStatus(Map complaint) async {
    final currentStatus = (complaint['status'] ?? 'pending').toString().toLowerCase();
    final isResolved = currentStatus == 'resolved' || currentStatus == 'reviewed';
    final newStatus = isResolved ? 'pending' : 'resolved';

    try {
      await ApiService().patch(
        '${AppConstants.feedbackBase}/${complaint['id']}/',
        data: {'status': newStatus},
      );
      _loadComplaints();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus == 'resolved' ? Iconsax.tick_circle : Iconsax.refresh_2,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(newStatus == 'resolved'
                    ? 'Feedback marked as Resolved'
                    : 'Feedback reopened as Pending'),
              ],
            ),
            backgroundColor: newStatus == 'resolved' ? AppColors.success : AppColors.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<dynamic> _getFilteredList(String statusFilter) {
    return _complaints.where((c) {
      final status = (c['status'] ?? 'pending').toString().toLowerCase();
      final isResolved = status == 'resolved' || status == 'reviewed';
      if (statusFilter == 'pending' && isResolved) return false;
      if (statusFilter == 'reviewed' && !isResolved) return false;

      if (_selectedCategoryId != null) {
        final catId = c['category'] is Map
            ? c['category']['id']
            : c['category'];
        if (catId != _selectedCategoryId) return false;
      }

      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase().trim();
        final title = (c['title'] ?? '').toString().toLowerCase();
        final desc = (c['description'] ?? '').toString().toLowerCase();
        final owner = (c['owner_name'] ?? '').toString().toLowerCase();
        final cat = (c['category_name'] ?? '').toString().toLowerCase();
        return title.contains(query) ||
            desc.contains(query) ||
            owner.contains(query) ||
            cat.contains(query);
      }

      return true;
    }).toList();
  }

  void _showSubmitDialog() {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

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
            constraints: const BoxConstraints(maxWidth: 580),
            child: _SubmitComplaintSheet(
              categories: _categories,
              onSuccess: _loadComplaints,
            ),
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
        builder: (_) => _SubmitComplaintSheet(
          categories: _categories,
          onSuccess: _loadComplaints,
        ),
      );
    }
  }

  void _showComplaintDetails(Map c, bool isAdmin) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

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
            constraints: const BoxConstraints(maxWidth: 640),
            child: _ComplaintDetailsSheet(
              complaint: c,
              isAdmin: isAdmin,
              onStatusToggle: () => _toggleStatus(c),
              onDelete: () => _deleteComplaint(c['id'], c['title'] ?? 'Feedback'),
              onReplySuccess: _loadComplaints,
            ),
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
        builder: (_) => _ComplaintDetailsSheet(
          complaint: c,
          isAdmin: isAdmin,
          onStatusToggle: () => _toggleStatus(c),
          onDelete: () => _deleteComplaint(c['id'], c['title'] ?? 'Feedback'),
          onReplySuccess: _loadComplaints,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadComplaints());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;

    final pendingCount = _complaints.where((c) {
      final s = (c['status'] ?? 'pending').toString().toLowerCase();
      return s != 'resolved' && s != 'reviewed';
    }).length;
    final resolvedCount = _complaints.where((c) {
      final s = (c['status'] ?? 'pending').toString().toLowerCase();
      return s == 'resolved' || s == 'reviewed';
    }).length;
    final anonymousCount = _complaints
        .where((c) => (c['visibility'] ?? 'anonymous') == 'anonymous')
        .length;

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSubmitDialog,
        backgroundColor: AppColors.primary,
        elevation: 6,
        icon: const Icon(Iconsax.message_add_1, color: Colors.white, size: 20),
        label: const Text(
          'New Complaint',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 650;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTight ? 14 : 24,
                vertical: isTight ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Bar ───────────────────────────────────────────────
                  Container(
                    padding: EdgeInsets.all(isTight ? 14 : 20),
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
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isTight ? 9 : 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Iconsax.messages_3,
                                  color: AppColors.primary, size: isTight ? 20 : 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Feedback & Grievances',
                                      style: TextStyle(
                                        fontSize: isTight ? 17 : 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        color: context.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_complaints.length} Total',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Iconsax.refresh, size: 18),
                              onPressed: _loadComplaints,
                              tooltip: 'Refresh',
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            if (!isTight) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: _showSubmitDialog,
                                icon: const Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                                label: const Text('Submit Feedback',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Confidential grievances, suggestions & resolution portal',
                          style: TextStyle(fontSize: isTight ? 11.5 : 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── KPI Summary Cards ─────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryMiniCard(
                          'Pending Review',
                          '$pendingCount',
                          'Needs Attention',
                          Iconsax.timer_1,
                          AppColors.warning,
                          isTight,
                        ),
                      ),
                      SizedBox(width: isTight ? 6 : 14),
                      Expanded(
                        child: _buildSummaryMiniCard(
                          'Resolved',
                          '$resolvedCount',
                          'Closed Cases',
                          Iconsax.tick_circle,
                          AppColors.success,
                          isTight,
                        ),
                      ),
                      SizedBox(width: isTight ? 6 : 14),
                      Expanded(
                        child: _buildSummaryMiniCard(
                          'Anonymous',
                          '$anonymousCount',
                          'Privacy Protected',
                          Iconsax.shield_security,
                          const Color(0xFF8B5CF6),
                          isTight,
                        ),
                      ),
                    ],
                  ),

              const SizedBox(height: 20),

              // ── Search & Filter Tabs ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.border, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText:
                            'Search complaints by subject, message, or submitter...',
                        prefixIcon:
                            const Icon(Iconsax.search_normal, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Iconsax.close_circle,
                                    size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                    if (_categories.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: const Text('All Categories'),
                                selected: _selectedCategoryId == null,
                                onSelected: (_) => setState(
                                    () => _selectedCategoryId = null),
                                selectedColor: AppColors.primary
                                    .withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _selectedCategoryId == null
                                      ? AppColors.primary
                                      : context.textPrimary,
                                ),
                              ),
                            ),
                            ..._categories.map((cat) {
                              final isSelected =
                                  _selectedCategoryId == cat['id'];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(cat['title'] ?? 'Category'),
                                  selected: isSelected,
                                  onSelected: (sel) => setState(() =>
                                      _selectedCategoryId =
                                          sel ? cat['id'] : null),
                                  selectedColor: AppColors.primary
                                      .withValues(alpha: 0.15),
                                  labelStyle: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.primary
                                        : context.textPrimary,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Iconsax.document_text, size: 18),
                              const SizedBox(width: 8),
                              Text('All (${_complaints.length})',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Iconsax.clock, size: 18),
                              const SizedBox(width: 8),
                              Text('Pending ($pendingCount)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Iconsax.tick_circle, size: 18),
                              const SizedBox(width: 8),
                              Text('Resolved ($resolvedCount)',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Complaints Content ───────────────────────────────────────
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                SizedBox(
                  height: 650,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildComplaintListView(
                          _getFilteredList('all'), isAdmin),
                      _buildComplaintListView(
                          _getFilteredList('pending'), isAdmin),
                      _buildComplaintListView(
                          _getFilteredList('reviewed'), isAdmin),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  ),
);
  }

  Widget _buildSummaryMiniCard(String title, String count, String subtitle,
      IconData icon, Color color, bool isTight) {
    if (isTight) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
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
                    fontSize: 12,
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

  Widget _buildComplaintListView(List<dynamic> list, bool isAdmin) {
    if (list.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.message_text,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isNotEmpty
                    ? 'No complaints match "$_searchQuery"'
                    : 'No complaints found in this category.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _showSubmitDialog,
                icon: const Icon(Iconsax.message_add,
                    size: 18, color: Colors.white),
                label: const Text('Submit New Feedback',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadComplaints,
      color: AppColors.primary,
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final c = list[i];
          final status = (c['status'] ?? 'pending').toString().toLowerCase();
          final isResolved = status == 'resolved' || status == 'reviewed';
          final isAnonymous = (c['visibility'] ?? 'anonymous') == 'anonymous';
          final title = c['title'] ?? 'Untitled Grievance';
          final desc = c['description'] ?? '';
          final ownerName = isAnonymous ? 'Anonymous Employee' : (c['owner_name'] ?? 'Staff Member');
          final catName = c['category_name'] ?? 'General Suggestion';
          final replies = (c['replies'] as List?) ?? [];
          final date = c['created_at'] != null ? c['created_at'].toString() : '';

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showComplaintDetails(c, isAdmin),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: context.isDark ? 0.2 : 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Category, Status, Privacy badge
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.tag,
                                      size: 13, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    catName,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isAnonymous
                                    ? const Color(0xFF8B5CF6)
                                        .withValues(alpha: 0.12)
                                    : AppColors.primary
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAnonymous
                                        ? Iconsax.shield_security
                                        : Iconsax.user,
                                    size: 12,
                                    color: isAnonymous
                                        ? const Color(0xFF8B5CF6)
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAnonymous ? 'Anonymous' : 'Identified',
                                    style: TextStyle(
                                      color: isAnonymous
                                          ? const Color(0xFF8B5CF6)
                                          : AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isResolved
                                    ? AppColors.success
                                    : AppColors.warning)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isResolved
                                    ? Iconsax.tick_circle
                                    : Iconsax.clock,
                                size: 13,
                                color: isResolved
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isResolved ? 'Resolved' : 'Pending',
                                style: TextStyle(
                                  color: isResolved
                                      ? AppColors.success
                                      : AppColors.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: context.textPrimary,
                      ),
                    ),

                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        desc,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    Divider(color: context.border, height: 1),
                    const SizedBox(height: 12),

                    // Bottom info: Submitter, date, reply count, and admin resolve actions
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
                              radius: 12,
                              backgroundColor: isAnonymous
                                  ? const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.15)
                                  : AppColors.primary
                                      .withValues(alpha: 0.15),
                              child: Icon(
                                isAnonymous ? Iconsax.user_cirlce_add : Iconsax.user,
                                size: 13,
                                color: isAnonymous
                                    ? const Color(0xFF8B5CF6)
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                ownerName,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: context.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (date.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Text('·',
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Text(
                                date,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Iconsax.message,
                                      size: 13, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${replies.length} Replies',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _toggleStatus(c),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isResolved
                                          ? AppColors.warning.withValues(alpha: 0.12)
                                          : const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isResolved
                                            ? AppColors.warning
                                            : const Color(0xFF10B981),
                                      ),
                                      boxShadow: isResolved
                                          ? null
                                          : [
                                              BoxShadow(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.28),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isResolved
                                              ? Iconsax.refresh_2
                                              : Iconsax.tick_circle,
                                          size: 13,
                                          color: isResolved
                                              ? AppColors.warning
                                              : Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          isResolved ? 'Reopen' : 'Resolve',
                                          style: TextStyle(
                                            color: isResolved
                                                ? AppColors.warning
                                                : Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Iconsax.trash,
                                    size: 16, color: AppColors.error),
                                tooltip: 'Delete Feedback',
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    _deleteComplaint(c['id'], title),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Submit Feedback / Complaint Sheet ─────────────────────────────────────────
class _SubmitComplaintSheet extends StatefulWidget {
  final List<dynamic> categories;
  final VoidCallback onSuccess;
  const _SubmitComplaintSheet(
      {required this.categories, required this.onSuccess});

  @override
  State<_SubmitComplaintSheet> createState() => _SubmitComplaintSheetState();
}

class _SubmitComplaintSheetState extends State<_SubmitComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  String _title = '', _description = '';
  String _visibility = 'anonymous';
  int? _categoryId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) {
      _categoryId = widget.categories.first['id'];
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    try {
      final data = {
        'title': _title.trim(),
        'description': _description.trim(),
        'visibility': _visibility,
        if (_categoryId != null) 'category': _categoryId,
      };

      await ApiService().post(
        '${AppConstants.feedbackBase}/',
        data: data,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Feedback submitted securely!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      constraints: const BoxConstraints(maxWidth: 580),
      padding: EdgeInsets.only(
        left: isMobile ? 18 : 28,
        right: isMobile ? 18 : 28,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Iconsax.message_add_1,
                              color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Submit Grievance / Idea',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Confidential & reviewed by HR',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
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
                    icon: const Icon(Iconsax.close_circle, size: 22),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: context.border),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Subject / Title *',
                  hintText: 'Brief summary of your grievance or suggestion',
                  prefixIcon: Icon(Iconsax.text, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Subject is required'
                    : null,
                onSaved: (v) => _title = v ?? '',
              ),
              const SizedBox(height: 14),

              // Category
              if (widget.categories.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: Icon(Iconsax.tag, size: 18),
                  ),
                  items: widget.categories.map((cat) {
                    return DropdownMenuItem<int>(
                      value: cat['id'] as int,
                      child: Text(cat['title'] ?? 'Category'),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 14),
              ],

              // Description
              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Detailed Description *',
                  hintText:
                      'Provide comprehensive context, dates, departments, or constructive solutions...',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
                onSaved: (v) => _description = v ?? '',
              ),
              const SizedBox(height: 16),

              // Visibility selection card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.security_safe,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Identity & Privacy Settings',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _visibility = 'anonymous'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _visibility == 'anonymous'
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _visibility == 'anonymous'
                                ? const Color(0xFF8B5CF6)
                                : context.border,
                            width: _visibility == 'anonymous' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _visibility == 'anonymous'
                                  ? Iconsax.shield_tick
                                  : Iconsax.shield_security,
                              color: const Color(0xFF8B5CF6),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '🔒 Anonymous (Recommended)',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Your name and email remain 100% confidential from administration.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _visibility = 'identified'),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _visibility == 'identified'
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _visibility == 'identified'
                                ? AppColors.primary
                                : context.border,
                            width: _visibility == 'identified' ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _visibility == 'identified'
                                  ? Iconsax.tick_circle
                                  : Iconsax.user,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '👤 Identified Profile',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Show your name to administration so they can contact you directly.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Button
              Container(
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.send_1,
                                size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Submit Complaint',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Complaint Details & Interactive Conversation Sheet ─────────────────────────
class _ComplaintDetailsSheet extends StatefulWidget {
  final Map complaint;
  final bool isAdmin;
  final VoidCallback onStatusToggle;
  final VoidCallback onDelete;
  final VoidCallback onReplySuccess;
  const _ComplaintDetailsSheet({
    required this.complaint,
    required this.isAdmin,
    required this.onStatusToggle,
    required this.onDelete,
    required this.onReplySuccess,
  });

  @override
  State<_ComplaintDetailsSheet> createState() => _ComplaintDetailsSheetState();
}

class _ComplaintDetailsSheetState extends State<_ComplaintDetailsSheet> {
  final _replyController = TextEditingController();
  bool _isReplying = false;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _submitReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isReplying = true);
    try {
      await ApiService().post(
        '${AppConstants.feedbackBase}/${widget.complaint['id']}/reply/',
        data: {'content': text},
      );
      if (mounted) {
        _replyController.clear();
        widget.onReplySuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Reply posted to conversation!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final isResolved =
        (c['status'] ?? 'pending').toString().toLowerCase() == 'reviewed' ||
        (c['status'] ?? 'pending').toString().toLowerCase() == 'resolved';
    final isAnonymous = (c['visibility'] ?? 'anonymous') == 'anonymous';
    final title = c['title'] ?? 'Feedback Details';
    final desc = c['description'] ?? 'No description provided';
    final ownerName =
        isAnonymous ? 'Anonymous Employee' : (c['owner_name'] ?? 'Staff Member');
    final catName = c['category_name'] ?? 'General Suggestion';
    final replies = (c['replies'] as List?) ?? [];
    final date = c['created_at'] != null ? c['created_at'].toString() : '';

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      padding: EdgeInsets.only(
        left: isMobile ? 16 : 24,
        right: isMobile ? 16 : 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        catName,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isResolved
                                ? AppColors.success
                                : AppColors.warning)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isResolved ? 'Resolved' : 'Pending Review',
                        style: TextStyle(
                          color: isResolved
                              ? AppColors.success
                              : AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.isAdmin) ...[
                      IconButton(
                        icon: Icon(
                          isResolved
                              ? Iconsax.refresh_2
                              : Iconsax.tick_circle,
                          color: isResolved
                              ? AppColors.warning
                              : AppColors.success,
                          size: 18,
                        ),
                        tooltip: isResolved
                            ? 'Reopen Case'
                            : 'Mark as Resolved',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onStatusToggle();
                        },
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Iconsax.trash,
                            color: AppColors.error, size: 18),
                        tooltip: 'Delete Complaint',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onDelete();
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Iconsax.close_circle, size: 22),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                color: context.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            // Author Info Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isAnonymous
                        ? const Color(0xFF8B5CF6).withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    child: Icon(
                      isAnonymous ? Iconsax.shield_security : Iconsax.user,
                      size: 15,
                      color: isAnonymous
                          ? const Color(0xFF8B5CF6)
                          : AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ownerName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          isAnonymous
                              ? 'Identity protected via zero-knowledge masking'
                              : 'Verified staff submission',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (date.isNotEmpty)
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Description Body
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: Text(
                desc,
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.textPrimary,
                  height: 1.5,
                ),
              ),
            ),

            if (widget.isAdmin) ...[
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.pop(context);
                    widget.onStatusToggle();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? AppColors.warning.withValues(alpha: 0.1)
                          : const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isResolved
                            ? AppColors.warning
                            : const Color(0xFF10B981),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isResolved ? Iconsax.refresh_2 : Iconsax.tick_circle,
                          size: 18,
                          color: isResolved ? AppColors.warning : const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isResolved
                              ? 'Reopen Grievance as Pending'
                              : 'Mark Feedback as Resolved',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: isResolved
                                ? AppColors.warning
                                : const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Conversation / Replies Section
            Row(
              children: [
                const Icon(Iconsax.messages_1,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Discussion & Resolution Thread (${replies.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: replies.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.border),
                      ),
                      child: const Text(
                        'No responses yet. Administration or employee can write below.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: replies.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final reply = replies[index];
                        final name = reply['employee_name'] ?? 'Administration';
                        final content = reply['content'] ?? '';
                        final replyDate = reply['created_at'] != null
                            ? reply['created_at'].toString()
                            : '';

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: context.card,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 11,
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.12),
                                        child: const Icon(Iconsax.user,
                                            size: 12, color: AppColors.primary),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (replyDate.isNotEmpty)
                                    Text(
                                      replyDate,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                content,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // Reply Composer Row
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: const InputDecoration(
                      hintText: 'Write a response or action note...',
                      prefixIcon: Icon(Iconsax.message_edit, size: 18),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _submitReply(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: IconButton(
                    onPressed: _isReplying ? null : _submitReply,
                    icon: _isReplying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Iconsax.send_1,
                            color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
