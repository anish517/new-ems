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

class PerformanceScreen extends ConsumerStatefulWidget {
  const PerformanceScreen({super.key});

  @override
  ConsumerState<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends ConsumerState<PerformanceScreen> {
  int _selectedTab = 0; // 0: Reviews & Appraisals, 1: Review Categories
  List<dynamic> _reviews = [];
  List<dynamic> _categories = [];
  bool _loading = true;
  String _scoreFilter = 'all';
  String _categoryFilter = 'all';
  String _searchQuery = '';
  String _catSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _catSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _catSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService().get('/api/performance/reviews/'),
        ApiService().get('/api/performance/categories/'),
      ]);
      if (!mounted) return;
      setState(() {
        final res = results[0];
        _reviews = res.data is List ? res.data as List : ((res.data['results'] ?? res.data) as List);
        final catRes = results[1];
        _categories = catRes.data is List ? catRes.data as List : ((catRes.data['results'] ?? catRes.data) as List);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateReview(BuildContext context) async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      await showDialog(
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
              child: _CreateReviewSheet(onSuccess: _loadAll, categories: _categories),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _CreateReviewSheet(onSuccess: _loadAll, categories: _categories),
      );
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Iconsax.category, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Create Review Category', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add a new performance review category (e.g., Code Quality, Punctuality, Leadership).',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Category Name *',
                  hintText: 'e.g. Communication & Teamwork',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter a category name';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() == true) Navigator.pop(ctx, true);
            },
            child: const Text('Create Category'),
          ),
        ],
      ),
    );

    if (created == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        await ApiService().post('/api/performance/categories/', data: {'name': nameCtrl.text.trim()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Performance category created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _loadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
  }

  Future<void> _showEditCategoryDialog(Map cat) async {
    final nameCtrl = TextEditingController(text: cat['name'] ?? '');
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Iconsax.edit_2, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Edit Review Category', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Modify the name of this performance category. Existing appraisals linked to this category will automatically update.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Category Name *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter a category name';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (formKey.currentState?.validate() == true) Navigator.pop(ctx, true);
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    if (updated == true && nameCtrl.text.trim().isNotEmpty) {
      try {
        await ApiService().patch('/api/performance/categories/${cat['id']}/', data: {'name': nameCtrl.text.trim()});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category renamed successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _loadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
  }

  Future<void> _deleteCategory(Map cat) async {
    final reviewsCount = cat['reviews_count'] ?? 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Iconsax.trash, color: AppColors.error, size: 20),
            SizedBox(width: 8),
            Text('Delete Category', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to remove the category "${cat['name']}"?'),
            if (reviewsCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.info_circle, color: AppColors.warning, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$reviewsCount appraisal(s) are currently linked to this category.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Category'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/api/performance/categories/${cat['id']}/');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category deleted successfully.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _loadAll();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (_, __) => _loadAll());
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;
    final isTight = MediaQuery.of(context).size.width < 650;

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _selectedTab == 0
                  ? () => _showCreateReview(context)
                  : () => _showAddCategoryDialog(),
              backgroundColor: AppColors.primary,
              elevation: 6,
              icon: Icon(
                _selectedTab == 0 ? Iconsax.add_circle : Iconsax.folder_add,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                _selectedTab == 0 ? 'New Appraisal' : 'Add Category',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isTight ? 14 : 24,
            vertical: isTight ? 16 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Card with Segmented Switcher ──────────────────
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
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Iconsax.star_1,
                            color: const Color(0xFFF59E0B),
                            size: isTight ? 20 : 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Performance & Appraisals',
                                      style: TextStyle(
                                        fontSize: isTight ? 17 : 20,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
                                        color: context.textPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (!isAdmin) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_reviews.length} Appraisals',
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isAdmin
                                    ? 'Employee evaluations, scoring, KPI reviews & category management'
                                    : 'Your evaluations, performance scoring, feedback & career growth goals',
                                style: TextStyle(fontSize: isTight ? 11 : 12, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Iconsax.refresh, size: 18),
                          tooltip: 'Refresh All',
                          onPressed: _loadAll,
                          style: IconButton.styleFrom(
                            backgroundColor: context.card,
                            side: BorderSide(color: context.border),
                            padding: const EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),

                    // ── Segmented Tab Switcher (Admins Only) ────────────────
                    if (isAdmin) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSegmentButton(
                                index: 0,
                                label: 'Appraisals & Reviews (${_reviews.length})',
                                icon: Iconsax.document_text,
                                isSelected: _selectedTab == 0,
                              ),
                            ),
                            Expanded(
                              child: _buildSegmentButton(
                                index: 1,
                                label: 'Review Categories (${_categories.length})',
                                icon: Iconsax.category,
                                isSelected: _selectedTab == 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Active Tab View ──────────────────────────────────────────
              if (!isAdmin || _selectedTab == 0)
                _buildReviewsTab(isAdmin, isDark, isTight)
              else
                _buildCategoriesTab(isAdmin, isDark, isTight),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required int index,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : context.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 1: REVIEWS & APPRAISALS VIEW
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildReviewsTab(bool isAdmin, bool isDark, bool isTight) {
    final filteredReviews = _reviews.where((r) {
      final score = (r['score'] as num?)?.toDouble() ?? 0;
      if (_scoreFilter == 'high' && score < 8) return false;
      if (_scoreFilter == 'medium' && (score < 5 || score >= 8)) return false;
      if (_scoreFilter == 'low' && score >= 5) return false;

      if (_categoryFilter != 'all') {
        final catName = (r['category_name'] ?? '').toString().toLowerCase();
        if (catName != _categoryFilter.toLowerCase()) return false;
      }

      if (_searchQuery.isEmpty) return true;
      final emp = (r['employee_name'] ?? '').toString().toLowerCase();
      final reviewer = (r['reviewer_name'] ?? '').toString().toLowerCase();
      final feedback = (r['feedback'] ?? '').toString().toLowerCase();
      final cat = (r['category_name'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return emp.contains(query) || reviewer.contains(query) || feedback.contains(query) || cat.contains(query);
    }).toList();

    final totalCount = _reviews.length;
    final avgScore = totalCount > 0
        ? _reviews.map((r) => (r['score'] as num?)?.toDouble() ?? 0).reduce((a, b) => a + b) / totalCount
        : 0.0;
    final topPerformersCount = _reviews.where((r) => ((r['score'] as num?)?.toDouble() ?? 0) >= 8).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Executive KPI Row ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Average Score',
                '${avgScore.toStringAsFixed(1)} / 10',
                Iconsax.star,
                const Color(0xFFF59E0B),
                isTight,
              ),
            ),
            SizedBox(width: isTight ? 6 : 12),
            Expanded(
              child: _buildKpiCard(
                'Total Appraisals',
                '$totalCount Records',
                Iconsax.document_text,
                AppColors.primary,
                isTight,
              ),
            ),
            SizedBox(width: isTight ? 6 : 12),
            Expanded(
              child: _buildKpiCard(
                'Top Performers',
                '$topPerformersCount Top Tier',
                Iconsax.award,
                AppColors.success,
                isTight,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Search & Filter Bar ────────────────────────────────────────────
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
                  hintText: 'Search reviews by employee name, feedback, or category...',
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
              const SizedBox(height: 12),

              // Filter Pills (Score + Category)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildScoreFilterChip('all', 'All Scores', AppColors.primary, Iconsax.category),
                    _buildScoreFilterChip('high', '🌟 High (8-10)', AppColors.success, Iconsax.star_1),
                    _buildScoreFilterChip('medium', '⚡ Average (5-7)', AppColors.warning, Iconsax.flash),
                    _buildScoreFilterChip('low', '⚠️ Needs Support (1-4)', AppColors.error, Iconsax.danger),

                    if (_categories.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(width: 1, height: 24, color: context.border),
                      const SizedBox(width: 12),
                      _buildCategoryFilterChip('all', 'All Categories'),
                      ..._categories.map((c) => _buildCategoryFilterChip(c['name'] ?? '', c['name'] ?? '')),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Reviews List ───────────────────────────────────────────────────
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (filteredReviews.isEmpty)
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
                const Icon(Iconsax.star_slash, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  _searchQuery.isNotEmpty ? 'No reviews matching "$_searchQuery"' : 'No performance appraisals found.',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Performance evaluations submitted by team managers will appear here.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredReviews.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (ctx, i) => _ReviewCard(
              review: filteredReviews[i],
              isAdmin: isAdmin,
              onUpdate: _loadAll,
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryFilterChip(String key, String label) {
    final isSelected = _categoryFilter.toLowerCase() == key.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _categoryFilter = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF59E0B).withValues(alpha: 0.15) : context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFFF59E0B) : context.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFFF59E0B) : context.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TAB 2: REVIEW CATEGORIES VIEW (INDEPENDENT MANAGEMENT)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildCategoriesTab(bool isAdmin, bool isDark, bool isTight) {
    final filteredCategories = _categories.where((c) {
      if (_catSearchQuery.isEmpty) return true;
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(_catSearchQuery.toLowerCase());
    }).toList();

    final activeCount = _categories.where((c) => (c['reviews_count'] ?? 0) > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Categories KPI Row ─────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                'Total Categories',
                '${_categories.length} Categories',
                Iconsax.category_2,
                AppColors.primary,
                isTight,
              ),
            ),
            SizedBox(width: isTight ? 6 : 12),
            Expanded(
              child: _buildKpiCard(
                'In Active Use',
                '$activeCount Linked',
                Iconsax.task,
                AppColors.success,
                isTight,
              ),
            ),
            SizedBox(width: isTight ? 6 : 12),
            Expanded(
              child: _buildKpiCard(
                'Management',
                isAdmin ? 'Super Admin' : 'Read Only',
                Iconsax.shield_tick,
                const Color(0xFFF59E0B),
                isTight,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Search & Add Category Header Bar ───────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _catSearchController,
                  decoration: InputDecoration(
                    hintText: 'Search categories by name...',
                    prefixIcon: const Icon(Iconsax.search_normal, size: 20),
                    suffixIcon: _catSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Iconsax.close_circle, size: 18),
                            onPressed: () {
                              _catSearchController.clear();
                              setState(() => _catSearchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _catSearchQuery = v),
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _showAddCategoryDialog,
                  icon: const Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                  label: const Text(
                    'Add Category',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(horizontal: isTight ? 12 : 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Categories List ────────────────────────────────────────────────
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (filteredCategories.isEmpty)
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
                const Icon(Iconsax.category, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 12),
                Text(
                  _catSearchQuery.isNotEmpty
                      ? 'No categories matching "$_catSearchQuery"'
                      : 'No performance categories created yet.',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Categories help organize employee reviews into KPIs like Leadership, Teamwork, and Technical skills.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddCategoryDialog,
                    icon: const Icon(Iconsax.add, size: 16, color: Colors.white),
                    label: const Text('Create First Category', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredCategories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final cat = filteredCategories[i];
              final catName = cat['name'] ?? 'Category';
              final reviewsCount = cat['reviews_count'] ?? 0;
              final createdDateStr = _fmtDate(cat['created_at']?.toString());

              return Container(
                padding: EdgeInsets.all(isTight ? 14 : 18),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Category Icon Avatar
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      child: const Icon(Iconsax.category, color: Color(0xFFF59E0B), size: 18),
                    ),
                    const SizedBox(width: 14),

                    // Category Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            catName,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: reviewsCount > 0
                                      ? AppColors.success.withValues(alpha: 0.1)
                                      : AppColors.textSecondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  reviewsCount > 0
                                      ? '🎯 $reviewsCount Appraisal(s) Linked'
                                      : '0 Appraisals',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: reviewsCount > 0 ? AppColors.success : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (createdDateStr.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '•  Added $createdDateStr',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Admin Action Buttons
                    if (isAdmin) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => _showEditCategoryDialog(cat),
                        icon: const Icon(Iconsax.edit_2, size: 17, color: AppColors.primary),
                        tooltip: 'Rename Category',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: () => _deleteCategory(cat),
                        icon: const Icon(Iconsax.trash, size: 17, color: AppColors.error),
                        tooltip: 'Delete Category',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.error.withValues(alpha: 0.08),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
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
                    fontSize: 14.5,
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

  Widget _buildScoreFilterChip(String key, String label, Color color, IconData icon) {
    final isSelected = _scoreFilter.toLowerCase() == key.toLowerCase();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _scoreFilter = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.15) : context.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? color : context.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: isSelected ? color : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? color : context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Review Card ─────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final Map review;
  final bool isAdmin;
  final VoidCallback onUpdate;
  const _ReviewCard({required this.review, required this.isAdmin, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final score = (review['score'] as num?)?.toDouble() ?? 0;
    final hasReply = review['reply'] != null && review['reply'].toString().trim().isNotEmpty;
    final isDark = context.isDark;

    final scoreColor = score >= 8
        ? AppColors.success
        : score >= 5
            ? AppColors.warning
            : AppColors.error;

    final empName = review['employee_name'] ?? 'Employee';
    final reviewerName = review['reviewer_name'] ?? 'Management';

    final isMobile = MediaQuery.of(context).size.width < 600;

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
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    empName.isNotEmpty ? empName[0].toUpperCase() : 'E',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAdmin ? empName : 'Evaluation from $reviewerName',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _fmtDate(review['created_at']),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                          if (review['category_name'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                review['category_name'],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Iconsax.star1, size: 14, color: scoreColor),
                      const SizedBox(width: 4),
                      Text(
                        '${score.toInt()} / 10',
                        style: TextStyle(color: scoreColor, fontWeight: FontWeight.w900, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: context.border),
            const SizedBox(height: 12),

            if (review['feedback'] != null && review['feedback'].toString().isNotEmpty) ...[
              const Text(
                'Manager Feedback',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                review['feedback'],
                style: TextStyle(fontSize: 13, color: context.textPrimary, height: 1.4),
              ),
            ],

            if (review['suggestion'] != null && review['suggestion'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Iconsax.lamp_on, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Goals & Suggestions', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(
                            review['suggestion'],
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            if (hasReply) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.message_text, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          isAdmin ? 'Employee Response' : 'Your Response',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.primary, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      review['reply'],
                      style: TextStyle(fontSize: 12.5, color: context.textPrimary),
                    ),
                  ],
                ),
              ),
            ] else if (!isAdmin) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _showReplySheet(context),
                  icon: const Icon(Iconsax.message_edit, size: 15),
                  label: const Text('Reply to Appraisal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReplySheet(BuildContext ctx) {
    final ctrl = TextEditingController();
    bool saving = false;
    final isMobile = MediaQuery.of(ctx).size.width < 600;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: ctx.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setStateModal) {
          return Padding(
            padding: EdgeInsets.only(
              left: isMobile ? 18 : 24,
              right: isMobile ? 18 : 24,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Reply to Appraisal',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Iconsax.close_circle, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ctrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Your Response / Acknowledgement',
                      hintText: 'Share reflections on the feedback or steps planned...',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (ctrl.text.trim().isEmpty) return;
                            setStateModal(() => saving = true);
                            try {
                              await ApiService().patch(
                                '/api/performance/reviews/${review['id']}/reply/',
                                data: {'reply': ctrl.text.trim()},
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                                onUpdate();
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ApiService.getErrorMessage(e))),
                                );
                              }
                            } finally {
                              if (context.mounted) setStateModal(() => saving = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Submit Response', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Create Review Sheet ─────────────────────────────────────────────────────
class _CreateReviewSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  final List categories;
  const _CreateReviewSheet({required this.onSuccess, required this.categories});

  @override
  State<_CreateReviewSheet> createState() => _CreateReviewSheetState();
}

class _CreateReviewSheetState extends State<_CreateReviewSheet> {
  List _employees = [];
  late List _localCategories;
  bool _loading = true;
  bool _saving = false;
  int? _selEmployee;
  int? _selCategory;
  double _score = 8;
  final _feedbackCtrl = TextEditingController();
  final _suggCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localCategories = List.from(widget.categories);
    _loadEmployees();
  }

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    _suggCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await ApiService().get('/api/organization/employees/');
      if (mounted) {
        setState(() {
          _employees = res.data is List ? res.data as List : ((res.data['results'] ?? []) as List);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _quickAddCategory() async {
    final ctrl = TextEditingController();
    final newCatName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Iconsax.category, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Text('New Evaluation Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Code Quality, Punctuality, Leadership',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ctx.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (newCatName != null && newCatName.isNotEmpty) {
      try {
        final res = await ApiService().post('/api/performance/categories/', data: {'name': newCatName});
        final newCat = res.data;
        setState(() {
          _localCategories.add(newCat);
          _selCategory = newCat['id'] as int?;
        });
        widget.onSuccess();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
        }
      }
    }
  }

  Future<void> _submit() async {
    if (_selEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Performance review submitted!'),
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
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    final isMobile = MediaQuery.of(context).size.width < 600;

    final scoreColor = _score >= 8
        ? AppColors.success
        : _score >= 5
            ? AppColors.warning
            : AppColors.error;

    return Padding(
      padding: EdgeInsets.only(
        left: isMobile ? 18 : 24,
        right: isMobile ? 18 : 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.star_1, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'New Performance Review',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: context.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Appraise team member deliverables & score KPI',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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

            DropdownButtonFormField<int>(
              initialValue: _selEmployee,
              hint: const Text('Select Employee *'),
              decoration: const InputDecoration(
                prefixIcon: Icon(Iconsax.user, size: 18),
              ),
              items: _employees.map((e) {
                final user = e['user'] ?? {};
                final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
                return DropdownMenuItem<int>(
                  value: e['id'],
                  child: Text(name.isNotEmpty ? name : 'Employee #${e['id']}'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selEmployee = v),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selCategory,
                    hint: const Text('Evaluation Category (Optional)'),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Iconsax.category, size: 18),
                    ),
                    items: _localCategories.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'],
                        child: Text(c['name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selCategory = v),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _quickAddCategory,
                  icon: const Icon(Iconsax.add, size: 20),
                  tooltip: 'Add New Category',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Overall Score (1 - 10):', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scoreColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_score.toInt()} / 10',
                          style: TextStyle(color: scoreColor, fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _score,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    activeColor: scoreColor,
                    onChanged: (v) => setState(() => _score = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _feedbackCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Strengths & Evaluation Notes',
                hintText: 'Highlight achievements, work quality and punctuality...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Iconsax.note_text, size: 18),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _suggCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Suggestions & Growth Goals',
                hintText: 'Areas for advancement and target milestones...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Iconsax.lamp_on, size: 18),
              ),
            ),
            const SizedBox(height: 22),

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
                          Text('Submit Appraisal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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

// ─── Manage Categories Sheet ─────────────────────────────────────────────────
class _ManageCategoriesSheet extends StatefulWidget {
  final List categories;
  final VoidCallback onUpdate;
  const _ManageCategoriesSheet({required this.categories, required this.onUpdate});

  @override
  State<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  late List _localCategories;
  final _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _localCategories = List.from(widget.categories);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final res = await ApiService().post('/api/performance/categories/', data: {'name': name});
      _nameCtrl.clear();
      setState(() {
        _localCategories.add(res.data);
      });
      widget.onUpdate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category added successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _renameCategory(Map category) async {
    final ctrl = TextEditingController(text: category['name'] ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Rename Category', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ctx.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = ctrl.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await ApiService().patch('/api/performance/categories/${category['id']}/', data: {'name': newName});
        setState(() {
          category['name'] = newName;
        });
        widget.onUpdate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category renamed!'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
        }
      }
    }
  }

  Future<void> _deleteCategory(int catId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Category', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to delete this evaluation category?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: ctx.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/api/performance/categories/$catId/');
        setState(() {
          _localCategories.removeWhere((c) => c['id'] == catId);
        });
        widget.onUpdate();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted!'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiService.getErrorMessage(e))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: EdgeInsets.only(
        left: isMobile ? 18 : 24,
        right: isMobile ? 18 : 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Iconsax.category, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Evaluation Categories',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: context.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text(
                              'Classify appraisals into areas of impact',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New Category Name',
                      hintText: 'e.g. Code Quality, Punctuality, Leadership',
                      prefixIcon: Icon(Iconsax.add_circle, size: 18),
                    ),
                    onSubmitted: (_) => _addCategory(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _saving ? null : _addCategory,
                  icon: _saving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Iconsax.add, size: 18, color: Colors.white),
                  label: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            const Text(
              'Active Categories',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            if (_localCategories.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No categories created yet. Add your first category above!',
                    style: TextStyle(fontSize: 13, color: context.textSecondary),
                  ),
                ),
              )
            else
              ..._localCategories.map((c) {
                final id = c['id'] as int;
                final name = (c['name'] ?? '').toString();

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Iconsax.category, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _renameCategory(c),
                        icon: const Icon(Iconsax.edit_2, size: 16, color: AppColors.accent),
                        tooltip: 'Rename',
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        onPressed: () => _deleteCategory(id),
                        icon: const Icon(Iconsax.trash, size: 16, color: AppColors.error),
                        tooltip: 'Delete',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
