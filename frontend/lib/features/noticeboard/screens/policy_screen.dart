import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class PolicyScreen extends ConsumerStatefulWidget {
  const PolicyScreen({super.key});

  @override
  ConsumerState<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends ConsumerState<PolicyScreen> {
  List<dynamic> _policies = [];
  bool _isLoading = false;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPolicies() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().get('/api/noticeboard/policies/');
      if (mounted) {
        setState(() {
          _policies = res.data is List ? res.data as List : ((res.data['results'] ?? []) as List);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showPolicyForm({Map? existing}) async {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final categoryCtrl = TextEditingController(text: existing?['category'] ?? '');
    final contentCtrl = TextEditingController(text: existing?['content'] ?? '');
    final isEdit = existing != null;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    Widget formContent = StatefulBuilder(
      builder: (ctx, setModalState) {
        final isMobile = MediaQuery.of(ctx).size.width < 600;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 18 : 24,
            20,
            isMobile ? 18 : 24,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                            child: Icon(isEdit ? Iconsax.edit : Iconsax.document_text, color: AppColors.primary, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'Edit Company Policy' : 'Publish New Policy',
                                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: context.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Text(
                                  'Corporate handbook rules & employee guidelines',
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
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Iconsax.close_circle, size: 20),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Divider(color: context.border),
              const SizedBox(height: 16),

              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Policy Title *',
                  hintText: 'e.g. Remote Work Policy & Security Norms',
                  prefixIcon: Icon(Iconsax.document_text, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g. HR & Leaves, IT Security, General)',
                  hintText: 'HR, Operations, IT, Code of Conduct',
                  prefixIcon: Icon(Iconsax.category, size: 18),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Policy Content & Clauses *',
                  hintText: 'Detail the guidelines, prerequisites, responsibilities and consequences...',
                  prefixIcon: Icon(Iconsax.note_text, size: 18),
                  alignLabelWithHint: true,
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
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Title and Content are required.')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      if (isEdit) {
                        await ApiService().patch(
                          '/api/noticeboard/policies/${existing['id']}/',
                          data: {
                            'title': titleCtrl.text.trim(),
                            'category': categoryCtrl.text.trim(),
                            'content': contentCtrl.text.trim(),
                          },
                        );
                      } else {
                        await ApiService().post(
                          '/api/noticeboard/policies/',
                          data: {
                            'title': titleCtrl.text.trim(),
                            'category': categoryCtrl.text.trim(),
                            'content': contentCtrl.text.trim(),
                          },
                        );
                      }
                      _showSnack(isEdit ? 'Policy updated successfully!' : 'New policy published!', AppColors.success);
                      _loadPolicies();
                    } catch (e) {
                      _showSnack(ApiService.getErrorMessage(e), AppColors.error);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isEdit ? Iconsax.tick_circle : Iconsax.send_1, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        isEdit ? 'Save Policy Changes' : 'Publish Policy',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

    if (isDesktop) {
      await showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: formContent,
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => formContent,
      );
    }
  }

  void _deletePolicy(int policyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Policy'),
        content: const Text('Are you sure you want to permanently remove this policy clause?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService().delete('/api/noticeboard/policies/$policyId/');
        _showSnack('Policy removed.', AppColors.success);
        _loadPolicies();
      } catch (e) {
        _showSnack(ApiService.getErrorMessage(e), AppColors.error);
      }
    }
  }

  Map<String, List<dynamic>> _groupByCategory(List<dynamic> policies) {
    final Map<String, List<dynamic>> grouped = {};
    for (final p in policies) {
      final cat = (p['category'] as String?)?.trim().isNotEmpty == true ? p['category'] as String : 'General';
      grouped.putIfAbsent(cat, () => []).add(p);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;
    final isDark = context.isDark;

    // Filter by category and search
    final filteredPolicies = _policies.where((p) {
      final cat = (p['category'] as String?)?.trim().isNotEmpty == true ? p['category'] as String : 'General';
      if (_selectedCategory != 'all' && cat.toLowerCase() != _selectedCategory.toLowerCase()) {
        return false;
      }
      if (_searchQuery.isEmpty) return true;
      final title = (p['title'] ?? '').toString().toLowerCase();
      final content = (p['content'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || content.contains(query) || cat.toLowerCase().contains(query);
    }).toList();

    final categories = ['all', ..._policies.map((p) => (p['category'] as String?)?.trim()).where((c) => c != null && c.isNotEmpty).toSet()];

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: const Icon(Iconsax.add_circle, color: Colors.white, size: 20),
              label: const Text('Add Policy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              onPressed: () => _showPolicyForm(),
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
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(Iconsax.shield_security,
                                  color: const Color(0xFF10B981), size: isTight ? 20 : 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Company Policies',
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
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${_policies.length} Policies',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Iconsax.refresh, size: 18),
                              tooltip: 'Refresh Policies',
                              onPressed: _loadPolicies,
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            if (!isTight && isAdmin) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: () => _showPolicyForm(),
                                icon: const Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                                label: const Text('Add Policy',
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
                          'Workplace code of conduct, leave regulations & compliance guidelines',
                          style: TextStyle(fontSize: isTight ? 11.5 : 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Search & Category Filter ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.border, width: 1),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search policies by title, category, or clauses...',
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
                        if (categories.length > 2) ...[
                          const SizedBox(height: 14),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((cat) {
                                final catStr = cat.toString();
                                final isSel = _selectedCategory.toLowerCase() == catStr.toLowerCase();
                                final label = catStr == 'all' ? 'All Categories' : catStr;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => setState(() => _selectedCategory = catStr),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSel ? AppColors.primary.withValues(alpha: 0.15) : context.card,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSel ? AppColors.primary : context.border,
                                            width: isSel ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                                            color: isSel ? AppColors.primary : context.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Policy Content ───────────────────────────────────────────
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (filteredPolicies.isEmpty)
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
                          const Icon(Iconsax.document_1, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No policies matching "$_searchQuery"'
                                : 'No company policies published yet.',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Check back later for organizational rules and guidelines.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._groupByCategory(filteredPolicies).entries.map((entry) => _PolicyCategorySection(
                          category: entry.key,
                          policies: entry.value,
                          isAdmin: isAdmin,
                          onEdit: (p) => _showPolicyForm(existing: p),
                          onDelete: (id) => _deletePolicy(id),
                        )),

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PolicyCategorySection extends StatefulWidget {
  final String category;
  final List<dynamic> policies;
  final bool isAdmin;
  final void Function(Map) onEdit;
  final void Function(int) onDelete;

  const _PolicyCategorySection({
    required this.category,
    required this.policies,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PolicyCategorySection> createState() => _PolicyCategorySectionState();
}

class _PolicyCategorySectionState extends State<_PolicyCategorySection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.category.toUpperCase(),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${widget.policies.length} ${widget.policies.length == 1 ? 'Clause' : 'Clauses'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (_expanded)
          ...widget.policies.map((p) => _PolicyCard(
                policy: p,
                isAdmin: widget.isAdmin,
                onEdit: () => widget.onEdit(p),
                onDelete: () => widget.onDelete(p['id']),
              )),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PolicyCard extends StatefulWidget {
  final Map policy;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PolicyCard({
    required this.policy,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_PolicyCard> createState() => _PolicyCardState();
}

class _PolicyCardState extends State<_PolicyCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final content = widget.policy['content'] as String? ?? '';
    final createdAt = widget.policy['created_at']?.toString().split('T')[0] ?? '';
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _expanded ? AppColors.primary.withValues(alpha: 0.4) : context.border,
          width: _expanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.all(isMobile ? 13 : 18),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isMobile ? 8 : 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Iconsax.document_text, size: isMobile ? 18 : 22, color: AppColors.primary),
                    ),
                    SizedBox(width: isMobile ? 10 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.policy['title'] ?? 'Policy',
                            style: TextStyle(
                              fontSize: isMobile ? 14.5 : 15.5,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                            ),
                          ),
                          if (createdAt.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Published on $createdAt',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.isAdmin) ...[
                      IconButton(
                        icon: const Icon(Iconsax.edit, size: 17, color: AppColors.primary),
                        tooltip: 'Edit Policy',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 2),
                      IconButton(
                        icon: const Icon(Iconsax.trash, size: 17, color: AppColors.error),
                        tooltip: 'Delete Policy',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: widget.onDelete,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              if (_expanded) ...[
                Divider(color: context.border, height: 1),
                Container(
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(19)),
                  ),
                  padding: const EdgeInsets.all(22),
                  child: SelectableText(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.textPrimary,
                      height: 1.7,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
