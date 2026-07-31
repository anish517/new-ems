import 'package:ems_app/shared/widgets/responsive_grid_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/providers/date_provider.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:intl/intl.dart';

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

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  List _reviews = [];
  List _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final futures = [
        ApiService().get('/api/performance/reviews/'),
      ];
      final isAdmin = ref.read(currentUserProvider)?.canManage ?? false;
      if (isAdmin) {
        futures.add(ApiService().get('/api/performance/categories/'));
      }
      final results = await Future.wait(futures);
      if (!mounted) return;
      setState(() {
        final res = results[0];
        _reviews =
            res.data is List ? res.data : (res.data['results'] ?? res.data);
        if (isAdmin && results.length > 1) {
          final catRes = results[1];
          _categories = catRes.data is List
              ? catRes.data
              : (catRes.data['results'] ?? catRes.data);
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadAll());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Performance & Scores')),
      floatingActionButton: isAdmin
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.extended(
                  heroTag: 'categories',
                  onPressed: () => _showManageCategories(context),
                  backgroundColor: AppColors.accent,
                  icon:
                      const Icon(Icons.category, size: 20, color: Colors.white),
                  label: const Text('Categories',
                      style: TextStyle(fontSize: 12, color: Colors.white)),
                ),
                const SizedBox(height: 12),
                FloatingActionButton.extended(
                  heroTag: 'review',
                  onPressed: () => _showCreateReview(context),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('New Review',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: _reviews.isEmpty
                  ? const Center(
                      child: Text('No performance reviews found',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ResponsiveGridList(
                      padding: const EdgeInsets.all(16),
                      itemCount: _reviews.length,
                      itemBuilder: (ctx, i) => _ReviewCard(
                        review: _reviews[i],
                        isAdmin: isAdmin,
                        onUpdate: _loadAll,
                      ),
                    ),
            ),
    );
  }

  void _showCreateReview(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 600),
        backgroundColor: ctx.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) =>
            _CreateReviewSheet(onSuccess: _loadAll, categories: _categories),
      );

  void _showManageCategories(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 600),
        backgroundColor: ctx.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) =>
            _ManageCategoriesSheet(categories: _categories, onUpdate: _loadAll),
      );
}

class _ReviewCard extends StatelessWidget {
  final Map review;
  final bool isAdmin;
  final VoidCallback onUpdate;
  const _ReviewCard(
      {required this.review, required this.isAdmin, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final score = review['score'] ?? 0;
    final hasReply =
        review['reply'] != null && review['reply'].toString().trim().isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                            isAdmin
                                ? review['employee_name'] ?? 'Unknown Employee'
                                : 'Review from ${review['reviewer_name']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(_fmtDate(review['created_at']),
                          style: AppTextStyles.caption),
                      if (review['category_name'] != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(review['category_name'],
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: score >= 8
                    ? AppColors.success.withValues(alpha: 0.15)
                    : score >= 5
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Iconsax.star1,
                    size: 14,
                    color: score >= 8
                        ? AppColors.success
                        : score >= 5
                            ? AppColors.warning
                            : AppColors.error),
                const SizedBox(width: 4),
                Text('$score / 10',
                    style: TextStyle(
                        color: score >= 8
                            ? AppColors.success
                            : score >= 5
                                ? AppColors.warning
                                : AppColors.error,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
          if (review['feedback'] != null && review['feedback'].isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Feedback', style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(review['feedback']),
          ],
          if (review['suggestion'] != null &&
              review['suggestion'].isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Suggestion', style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text(review['suggestion']),
          ],
          const SizedBox(height: 16),
          const Divider(),
          if (hasReply) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.reply,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(isAdmin ? 'Employee Reply' : 'Your Reply',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 6),
                    Text(review['reply'],
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                  ]),
            ),
          ] else if (!isAdmin) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showReplySheet(context),
                icon: const Icon(Icons.reply, size: 16),
                label: const Text('Reply to Review'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
          ]
        ]),
      ),
    );
  }

  void _showReplySheet(BuildContext ctx) {
    final ctrl = TextEditingController();
    bool saving = false;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: ctx.surface,
      builder: (sheetCtx) => StatefulBuilder(builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Reply to Review', style: AppTextStyles.pageTitle),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                      labelText: 'Your response', alignLabelWithHint: true),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (ctrl.text.trim().isEmpty) return;
                          setState(() => saving = true);
                          try {
                            await ApiService().patch(
                                '/api/performance/reviews/${review['id']}/reply/',
                                data: {'reply': ctrl.text.trim()});
                            if (context.mounted) {
                              Navigator.pop(context);
                              onUpdate();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(ApiService.getErrorMessage(e))));
                            }
                          } finally {
                            if (context.mounted) setState(() => saving = false);
                          }
                        },
                  child: saving
                      ? const CircularProgressIndicator()
                      : const Text('Submit Reply'),
                )
              ]),
        );
      }),
    );
  }
}

class _CreateReviewSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  final List categories;
  const _CreateReviewSheet({required this.onSuccess, required this.categories});
  @override
  State<_CreateReviewSheet> createState() => _CreateReviewSheetState();
}

class _CreateReviewSheetState extends State<_CreateReviewSheet> {
  List _employees = [];
  bool _loading = true;
  bool _saving = false;
  int? _selEmployee;
  int? _selCategory;
  double _score = 5;
  final _feedbackCtrl = TextEditingController();
  final _suggCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await ApiService().get('/api/organization/employees/');
      if (mounted) {
        setState(() {
          _employees =
              res.data is List ? res.data : (res.data['results'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select an employee',
              style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService().post('/api/performance/reviews/', data: {
        'employee': _selEmployee,
        if (_selCategory != null) 'category': _selCategory,
        'score': _score.toInt(),
        'feedback': _feedbackCtrl.text.trim(),
        'suggestion': _suggCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Review submitted!'),
            backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error));
      }
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
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('New Performance Review',
                  style: AppTextStyles.pageTitle),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selEmployee,
                hint: const Text('Select Employee'),
                items: _employees.map((e) {
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
              DropdownButtonFormField<int>(
                initialValue: _selCategory,
                hint: const Text('Select Category (Optional)'),
                items: widget.categories.map((c) {
                  return DropdownMenuItem<int>(
                    value: c['id'],
                    child: Text(c['name'] ?? ''),
                  );
                }).toList(),
                onChanged: (v) => setState(() => _selCategory = v),
              ),
              const SizedBox(height: 24),
              Row(children: [
                const Text('Score (1-10): ',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${_score.toInt()}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
              ]),
              Slider(
                value: _score,
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: _score >= 8
                    ? AppColors.success
                    : _score >= 5
                        ? AppColors.warning
                        : AppColors.error,
                onChanged: (v) => setState(() => _score = v),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _feedbackCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Feedback', alignLabelWithHint: true)),
              const SizedBox(height: 12),
              TextField(
                  controller: _suggCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Suggestion/Goals', alignLabelWithHint: true)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Submit Review'),
              )
            ]),
      ),
    );
  }
}

class _ManageCategoriesSheet extends StatefulWidget {
  final List categories;
  final VoidCallback onUpdate;
  const _ManageCategoriesSheet(
      {required this.categories, required this.onUpdate});

  @override
  State<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _addCategory() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService()
          .post('/api/performance/categories/', data: {'name': name});
      _nameCtrl.clear();
      widget.onUpdate();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ApiService.getErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Manage Categories', style: AppTextStyles.pageTitle),
            const SizedBox(height: 16),
            if (widget.categories.isNotEmpty) ...[
              const Text('Existing Categories',
                  style:
                      TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.categories
                    .map((c) => Chip(
                          label: Text(c['name'] ?? ''),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'New Category Name'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _addCategory,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Add Category'),
            )
          ]),
    );
  }
}
