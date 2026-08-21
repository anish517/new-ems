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
  List<dynamic> _approvals = [];
  bool _isLoading = false;
  bool _isLoadingApprovals = false;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  int _currentTab = 0; // 0 = Policies, 1 = Approval Audit Log
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPolicies();
    _loadApprovals();
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

  Future<void> _loadApprovals() async {
    final isAdmin = ref.read(currentUserProvider)?.canManage ?? false;
    if (!isAdmin) return;
    setState(() => _isLoadingApprovals = true);
    try {
      final res = await ApiService().get('/api/noticeboard/policies/approvals/');
      if (mounted) {
        setState(() {
          final data = res.data;
          _approvals = data is List ? data : ((data?['results'] ?? []) as List);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingApprovals = false);
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

  void _insertFormatting(TextEditingController ctrl, String prefix, String suffix) {
    final text = ctrl.text;
    final selection = ctrl.selection;

    if (!selection.isValid || selection.isCollapsed) {
      final pos = selection.isValid ? selection.baseOffset : text.length;
      final newText = text.substring(0, pos) + prefix + suffix + text.substring(pos);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: pos + prefix.length),
      );
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.substring(0, selection.start) + prefix + selectedText + suffix + text.substring(selection.end);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.start + prefix.length + selectedText.length,
        ),
      );
    }
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
                    labelText: 'Category (e.g. HR & Leaves, IT Security, Code of Conduct)',
                    hintText: 'HR, Operations, IT, Code of Conduct',
                    prefixIcon: Icon(Iconsax.category, size: 18),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Bold Professional Text Formatting Toolbar ───────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    border: Border.all(color: context.border),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildEditorToolChip(
                          label: 'Bold',
                          icon: Icons.format_bold,
                          onTap: () => _insertFormatting(contentCtrl, '**', '**'),
                          context: context,
                        ),
                        _buildEditorToolChip(
                          label: 'Italic',
                          icon: Icons.format_italic,
                          onTap: () => _insertFormatting(contentCtrl, '*', '*'),
                          context: context,
                        ),
                        _buildEditorToolChip(
                          label: 'Heading',
                          icon: Icons.title,
                          onTap: () => _insertFormatting(contentCtrl, '\n### ', '\n'),
                          context: context,
                        ),
                        _buildEditorToolChip(
                          label: 'Bullet',
                          icon: Icons.format_list_bulleted,
                          onTap: () => _insertFormatting(contentCtrl, '\n• ', ''),
                          context: context,
                        ),
                        _buildEditorToolChip(
                          label: 'Numbered',
                          icon: Icons.format_list_numbered,
                          onTap: () => _insertFormatting(contentCtrl, '\n1. ', ''),
                          context: context,
                        ),
                        _buildEditorToolChip(
                          label: 'Warning',
                          icon: Icons.warning_amber_rounded,
                          onTap: () => _insertFormatting(contentCtrl, '\n> ⚠️ Warning: ', '\n'),
                          context: context,
                          color: AppColors.warning,
                        ),
                        _buildEditorToolChip(
                          label: 'Security',
                          icon: Icons.security,
                          onTap: () => _insertFormatting(contentCtrl, '\n> 🔒 Confidentiality: ', '\n'),
                          context: context,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),

                TextField(
                  controller: contentCtrl,
                  maxLines: 7,
                  decoration: InputDecoration(
                    hintText: 'Detail the guidelines, prerequisites, responsibilities and consequences...\nTip: Use toolbar above for Bold, Headings, Bullets, and Callouts.',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: context.surface,
                    border: OutlineInputBorder(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                    ),
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
            constraints: const BoxConstraints(maxWidth: 620),
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

  Widget _buildEditorToolChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required BuildContext context,
    Color? color,
  }) {
    final toolColor = color ?? context.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: toolColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: toolColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: toolColor),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: toolColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _deletePolicy(int policyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Policy'),
        content: const Text('Are you sure you want to permanently remove this policy clause?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
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

    // Filter policies by category and search
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

    // Filter approvals by search
    final filteredApprovals = _approvals.where((a) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final name = (a['employee_name'] ?? a['user_name'] ?? '').toString().toLowerCase();
      final email = (a['user_email'] ?? '').toString().toLowerCase();
      final ip = (a['ip_address'] ?? '').toString().toLowerCase();
      final device = (a['device_name'] ?? '').toString().toLowerCase();
      return name.contains(query) || email.contains(query) || ip.contains(query) || device.contains(query);
    }).toList();

    final categories = ['all', ..._policies.map((p) => (p['category'] as String?)?.trim()).where((c) => c != null && c.isNotEmpty).toSet()];

    return Scaffold(
      backgroundColor: context.bg,
      floatingActionButton: (isAdmin && _currentTab == 0)
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
            final isTight = constraints.maxWidth < 750;

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
                                  Text(
                                    'Company Policies',
                                    style: TextStyle(
                                      fontSize: isTight ? 17 : 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: context.textPrimary,
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
                              tooltip: 'Refresh',
                              onPressed: () {
                                _loadPolicies();
                                _loadApprovals();
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: context.card,
                                side: BorderSide(color: context.border),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                            if (isAdmin && !isTight && _currentTab == 0) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _showPolicyForm(),
                                icon: const Icon(Iconsax.add_circle, size: 18, color: Colors.white),
                                label: const Text('Add Policy',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Workplace code of conduct, leave regulations & employee compliance handbook',
                          style: TextStyle(fontSize: isTight ? 11.5 : 12, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Admin Tab Switcher (Policies vs Approval Audit Log) ──────
                  if (isAdmin) ...[
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              label: 'Policy Handbook',
                              icon: Iconsax.document_text,
                              count: _policies.length,
                              isSelected: _currentTab == 0,
                              onTap: () => setState(() => _currentTab = 0),
                              context: context,
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              label: 'Approval Audit Log',
                              icon: Iconsax.finger_scan,
                              count: _approvals.length,
                              isSelected: _currentTab == 1,
                              badgeColor: AppColors.success,
                              onTap: () {
                                setState(() => _currentTab = 1);
                                _loadApprovals();
                              },
                              context: context,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Search & Filter Bar ──────────────────────────────────────
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
                            hintText: _currentTab == 0
                                ? 'Search policies by title or content...'
                                : 'Search audit log by employee, IP, or device...',
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
                        if (_currentTab == 0 && categories.length > 1) ...[
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: categories.map((cat) {
                                final isSelected = _selectedCategory.toLowerCase() == (cat ?? '').toLowerCase();
                                final label = cat == 'all' ? 'All Policies' : cat!;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => setState(() => _selectedCategory = cat!),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : context.card,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? AppColors.primary : context.border,
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Text(
                                          label,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            color: isSelected ? AppColors.primary : context.textPrimary,
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

                  // ── Tab 0: Policy Clauses ────────────────────────────────────
                  if (_currentTab == 0) ...[
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
                            const Icon(Iconsax.shield_slash, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? 'No policies matching "$_searchQuery"' : 'No policies published yet.',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Company rules and guidelines will appear here once published.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._groupByCategory(filteredPolicies).entries.map((entry) => _PolicyCategorySection(
                            categoryName: entry.key,
                            policies: entry.value,
                            isAdmin: isAdmin,
                            onEdit: (p) => _showPolicyForm(existing: p),
                            onDelete: (id) => _deletePolicy(id),
                          )),
                  ]

                  // ── Tab 1: Admin Approval Audit Log ─────────────────────────
                  else ...[
                    if (_isLoadingApprovals)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      )
                    else if (filteredApprovals.isEmpty)
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
                            const Icon(Iconsax.finger_scan, size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty ? 'No approvals matching "$_searchQuery"' : 'No policy approvals recorded yet.',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Approvals will appear here in real-time when employees acknowledge policies upon login.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredApprovals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final a = filteredApprovals[i];
                          final empName = a['employee_name'] ?? a['user_name'] ?? 'Employee';
                          final empEmail = a['user_email'] ?? '';
                          final approvedAt = a['approved_at']?.toString().split('.')[0].replaceFirst('T', ' ') ?? '';
                          final device = a['device_name'] ?? a['os'] ?? 'Unknown Device';
                          final ip = a['ip_address'] ?? '127.0.0.1';

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: context.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.success.withValues(alpha: 0.12),
                                  child: const Icon(Iconsax.verify, color: AppColors.success, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              empName,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: context.textPrimary,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Iconsax.tick_circle, color: AppColors.success, size: 12),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Approved',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.success,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (empEmail.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          empEmail,
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _buildAuditBadge(
                                            icon: Iconsax.monitor,
                                            label: 'Device',
                                            value: device,
                                            color: AppColors.primary,
                                          ),
                                          _buildAuditBadge(
                                            icon: Iconsax.calendar_1,
                                            label: 'Timestamp',
                                            value: approvedAt,
                                            color: const Color(0xFFF59E0B),
                                          ),
                                          _buildAuditBadge(
                                            icon: Iconsax.global,
                                            label: 'IP Address',
                                            value: ip,
                                            color: const Color(0xFF10B981),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
    required BuildContext context,
    Color? badgeColor,
  }) {
    final effectiveBadgeColor = badgeColor ?? AppColors.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: AppColors.primary.withValues(alpha: 0.3)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: isSelected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : context.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: effectiveBadgeColor.withValues(alpha: isSelected ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: effectiveBadgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuditBadge({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.8)),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

class _PolicyCategorySection extends StatefulWidget {
  final String categoryName;
  final List<dynamic> policies;
  final bool isAdmin;
  final void Function(Map) onEdit;
  final void Function(int) onDelete;

  const _PolicyCategorySection({
    required this.categoryName,
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
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.categoryName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${widget.policies.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(20),
                  child: _buildRichPolicyContent(content, context),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRichPolicyContent(String rawContent, BuildContext context) {
    final cleanContent = rawContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final lines = cleanContent.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) return const SizedBox(height: 8);

        // Heading format (### or ## or #)
        if (trimmed.startsWith('#')) {
          final headingText = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              headingText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: context.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          );
        }

        // Callout warning / security block (> ⚠️ or > 🔒 or >)
        if (trimmed.startsWith('>')) {
          final calloutText = trimmed.replaceFirst(RegExp(r'^>\s*'), '');
          final isWarning = calloutText.contains('⚠️') || calloutText.toLowerCase().contains('warning');
          final calloutColor = isWarning ? AppColors.warning : AppColors.primary;

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: calloutColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: calloutColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isWarning ? Iconsax.warning_2 : Iconsax.security_safe, color: calloutColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    calloutText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Bullet point (• or - or *)
        if (trimmed.startsWith('•') || trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          final bulletText = trimmed.replaceFirst(RegExp(r'^[•\-\*]\s*'), '');
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 7, right: 8),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: _buildInlineBoldText(bulletText, context),
                ),
              ],
            ),
          );
        }

        // Regular paragraph with potential bold spans
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _buildInlineBoldText(trimmed, context),
        );
      }).toList(),
    );
  }

  Widget _buildInlineBoldText(String text, BuildContext context) {
    // Parses **bold** spans
    final parts = text.split('**');
    if (parts.length == 1) {
      return Text(
        text,
        style: TextStyle(fontSize: 13.5, color: context.textPrimary, height: 1.5),
      );
    }

    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: TextStyle(
            fontWeight: isBold ? FontWeight.w900 : FontWeight.normal,
            color: isBold ? context.textPrimary : context.textPrimary.withValues(alpha: 0.88),
            fontSize: 13.5,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans, style: const TextStyle(height: 1.5)),
    );
  }
}
