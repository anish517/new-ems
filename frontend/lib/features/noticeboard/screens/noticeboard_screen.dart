import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/providers/date_provider.dart';
import '../../../shared/widgets/nepali_date_picker.dart';

String _fmtDate(String? raw, {String? fallback}) {
  if (raw == null && fallback == null) return '';
  final s = raw ?? fallback!;
  try {
    if (s.contains('T')) {
      return NepaliDateFormat('dd MMMM yyyy').format(DateTime.parse(s).toNepaliDateTime());
    }
    return NepaliDateFormat('dd MMMM yyyy').format(NepaliDateTime.parse(s));
  } catch (_) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }
}

class NoticeboardScreen extends ConsumerStatefulWidget {
  const NoticeboardScreen({super.key});
  @override
  ConsumerState<NoticeboardScreen> createState() => _NoticeboardScreenState();
}

class _NoticeboardScreenState extends ConsumerState<NoticeboardScreen> {
  List<dynamic> _notices = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotices() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get(AppConstants.noticesEndpoint);
      if (!mounted) return;
      setState(() {
        _notices = res.data is List ? res.data as List : ((res.data['results'] ?? res.data) as List);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateNotice(BuildContext context) async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      final created = await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Container(
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: _CreateNoticeSheet(onSuccess: _loadNotices),
            ),
          ),
        ),
      );
      if (created == true) _loadNotices();
    } else {
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _CreateNoticeSheet(onSuccess: _loadNotices),
      );
      if (created == true) _loadNotices();
    }
  }

  void _showNoticeDetail(BuildContext ctx, Map n, bool isAdmin) {
    final desc = n['description'] ?? n['content'] ?? '';
    final cleanDesc = desc.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final dateStr = _fmtDate(n['date']?.toString(), fallback: n['created_at']?.toString());

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 680),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Iconsax.calendar, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Iconsax.close_circle, size: 20),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              n['title'] ?? 'Company Announcement',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 16),
            SelectableText(
              cleanDesc.isNotEmpty ? cleanDesc : 'No further content published for this notice.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.7,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: const Icon(Iconsax.verify, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Official Corporate Broadcast', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        Text('Published by Management / Human Resources', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isAdmin && n['id'] != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Delete Notice'),
                      content: const Text('Are you sure you want to remove this announcement?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    try {
                      await ApiService().delete('${AppConstants.noticesEndpoint}${n['id']}/');
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _loadNotices();
                      }
                    } catch (_) {}
                  }
                },
                icon: const Icon(Iconsax.trash, size: 16, color: AppColors.error),
                label: const Text('Delete Notice', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadNotices());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;

    final filteredNotices = _notices.where((n) {
      if (_searchQuery.isEmpty) return true;
      final title = (n['title'] ?? '').toString().toLowerCase();
      final desc = (n['description'] ?? n['content'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || desc.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateNotice(context),
              backgroundColor: AppColors.primary,
              elevation: 6,
              icon: const Icon(Iconsax.add_circle, color: Colors.white, size: 20),
              label: const Text(
                'Post Notice',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            )
          : null,
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
                  // ── Top Header Card ──────────────────────────────────────────
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
                              child: Icon(Iconsax.notification_bing,
                                  color: AppColors.primary, size: isTight ? 20 : 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Notice Board',
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
                                      '${_notices.length} Total',
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
                              tooltip: 'Refresh Notices',
                              onPressed: _loadNotices,
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            if (isAdmin && !isTight) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _showCreateNotice(context),
                                icon: const Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                                label: const Text('Post Notice',
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
                          'Official circulars, holiday announcements & corporate updates',
                          style: TextStyle(fontSize: isTight ? 11.5 : 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Notice Metrics KPI Row ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _buildKpiCard(
                          'Total Published',
                          '${_notices.length} Notices',
                          Iconsax.notification_status,
                          AppColors.primary,
                          isTight,
                        ),
                      ),
                      SizedBox(width: isTight ? 6 : 12),
                      Expanded(
                        child: _buildKpiCard(
                          'Recent Updates',
                          'Active Feed',
                          Iconsax.timer_start,
                          AppColors.warning,
                          isTight,
                        ),
                      ),
                      SizedBox(width: isTight ? 6 : 12),
                      Expanded(
                        child: _buildKpiCard(
                          'Target Audience',
                          'All Staff',
                          Iconsax.people,
                          AppColors.success,
                          isTight,
                        ),
                      ),
                    ],
                  ),

              const SizedBox(height: 20),

              // ── Search Bar ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.border, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notices by title, date, or keywords...',
                    prefixIcon: const Icon(Iconsax.search_normal, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Iconsax.close_circle, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

              const SizedBox(height: 20),

              // ── Notices Grid / List ──────────────────────────────────────
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                )
              else if (filteredNotices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Iconsax.notification_1, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty ? 'No notices matching "$_searchQuery"' : 'No announcements published yet.',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Check back later for company updates and circulars.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth < 680
                        ? 1
                        : constraints.maxWidth < 1100
                            ? 2
                            : 3;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: cols == 1 ? 2.8 : 1.75,
                      ),
                      itemCount: filteredNotices.length,
                      itemBuilder: (ctx, i) {
                        final n = filteredNotices[i];
                        final desc = n['description'] ?? n['content'] ?? '';
                        final cleanDesc = desc.replaceAll(RegExp(r'<[^>]*>'), '').trim();
                        final dateStr = _fmtDate(n['date']?.toString(), fallback: n['created_at']?.toString());

                        return Container(
                          decoration: BoxDecoration(
                            color: context.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: context.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showNoticeDetail(ctx, n, isAdmin),
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            dateStr,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      n['title'] ?? 'Notice',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                        color: context.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: Text(
                                        cleanDesc.isNotEmpty ? cleanDesc : 'Tap to read full announcement...',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    ),
  ),
);
  }

  Widget _buildKpiCard(String title, String count, IconData icon, Color color, bool isTight) {
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
                    fontSize: 15,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                    color: context.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
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
}

// ─── Create Notice Sheet ─────────────────────────────────────────────────────
class _CreateNoticeSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _CreateNoticeSheet({required this.onSuccess});

  @override
  State<_CreateNoticeSheet> createState() => _CreateNoticeSheetState();
}

class _CreateNoticeSheetState extends State<_CreateNoticeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dateCtrl = TextEditingController();
  String _title = '', _description = '', _date = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = NepaliDateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _date = todayStr;
    _dateCtrl.text = todayStr;
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final nepaliPicked = await showDialog<NepaliDateTime>(
      context: context,
      builder: (ctx) => NepaliDatePickerDialog(
        title: 'Select Notice Date',
        initial: NepaliDateTime.now(),
      ),
    );
    if (nepaliPicked != null && mounted) {
      setState(() {
        final dateStr =
            '${nepaliPicked.year}-${nepaliPicked.month.toString().padLeft(2, '0')}-${nepaliPicked.day.toString().padLeft(2, '0')}';
        _date = dateStr;
        _dateCtrl.text = dateStr;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      await ApiService().post(
        AppConstants.noticesEndpoint,
        data: {
          'title': _title.trim(),
          'description': _description.trim(),
          if (_date.isNotEmpty) 'date': _date.trim(),
        },
      );
      if (mounted) {
        Navigator.pop(context, true);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Notice broadcast successfully!'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
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
                        child: const Icon(Iconsax.notification_bing, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Post Company Notice',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary),
                          ),
                          const Text(
                            'Broadcast official updates to all staff',
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
                decoration: const InputDecoration(
                  labelText: 'Notice Title *',
                  hintText: 'e.g. Office Closure for Dashain Festival',
                  prefixIcon: Icon(Iconsax.document_text, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Notice title is required' : null,
                onSaved: (v) => _title = v ?? '',
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Broadcast Date (B.S.)',
                  prefixIcon: Icon(Iconsax.calendar, size: 18),
                  suffixIcon: Icon(Iconsax.arrow_down_1, size: 16),
                ),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),

              TextFormField(
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Notice Content / Body *',
                  hintText: 'Provide full announcement details, directives, or schedules...',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Iconsax.note_text, size: 18),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Content is required' : null,
                onSaved: (v) => _description = v ?? '',
              ),
              const SizedBox(height: 22),

              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.send_1, size: 16, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Publish Notice Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
