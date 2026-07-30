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
  List _policies = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPolicies();
  }

  Future<void> _loadPolicies() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().get('/api/noticeboard/policies/');
      if (mounted) {
        setState(() {
          _policies = res.data is List ? res.data : (res.data['results'] ?? []);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }



  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating));
  }

  void _showPolicyForm({Map? existing}) {
    final titleCtrl = TextEditingController(text: existing?['title'] ?? '');
    final categoryCtrl = TextEditingController(text: existing?['category'] ?? '');
    final contentCtrl = TextEditingController(text: existing?['content'] ?? '');
    final isEdit = existing != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(isEdit ? Iconsax.edit : Iconsax.add_circle, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(isEdit ? 'Edit Policy' : 'Add Policy',
                    style: AppTextStyles.sectionTitle),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Policy Title *',
                  prefixIcon: Icon(Iconsax.document_text),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Category (e.g. HR, IT, General)',
                  prefixIcon: Icon(Iconsax.category),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Content *',
                  hintText: 'Write the policy details here...',
                  prefixIcon: Icon(Iconsax.note_text),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(isEdit ? Iconsax.tick_circle : Iconsax.send_1),
                  label: Text(isEdit ? 'Save Changes' : 'Add Policy'),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Title and Content are required.')));
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
                      _showSnack(isEdit ? 'Policy updated!' : 'Policy added!', AppColors.success);
                      _loadPolicies();
                    } catch (e) {
                      _showSnack(ApiService.getErrorMessage(e), AppColors.error);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, List> _groupByCategory(List policies) {
    final Map<String, List> grouped = {};
    for (final p in policies) {
      final cat = (p['category'] as String?)?.trim().isNotEmpty == true ? p['category'] as String : 'General';
      grouped.putIfAbsent(cat, () => []).add(p);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        title: Text('Company Policy',
            style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPolicies),
        ],
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Policy'),
              onPressed: _showPolicyForm,
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _policies.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Iconsax.document_text, size: 56, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    const Text('No policies published yet.',
                        style: TextStyle(color: AppColors.textSecondary)),
                    if (isAdmin) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        icon: const Icon(Icons.add),
                        label: const Text('Add First Policy'),
                        onPressed: _showPolicyForm,
                      ),
                    ],
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _loadPolicies,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _groupByCategory(_policies)
                        .entries
                        .map((entry) => _PolicyCategory(
                              category: entry.key,
                              policies: entry.value,
                              isAdmin: isAdmin,
                              onEdit: (p) => _showPolicyForm(existing: p),
                            ))
                        .toList(),
                  ),
                ),
    );
  }
}

class _PolicyCategory extends StatefulWidget {
  final String category;
  final List policies;
  final bool isAdmin;
  final void Function(Map) onEdit;
  const _PolicyCategory({required this.category, required this.policies, required this.isAdmin, required this.onEdit});
  @override
  State<_PolicyCategory> createState() => _PolicyCategoryState();
}

class _PolicyCategoryState extends State<_PolicyCategory> {
  bool _expanded = true;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    InkWell(
      onTap: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(widget.category,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text('${widget.policies.length} policies', style: AppTextStyles.caption),
          const Spacer(),
          Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.textSecondary),
        ]),
      ),
    ),
    if (_expanded)
      ...widget.policies.map((p) => _PolicyCard(
        policy: p, isAdmin: widget.isAdmin,
        onEdit: () => widget.onEdit(p),
      )),
    const SizedBox(height: 8),
  ]);
}

class _PolicyCard extends StatefulWidget {
  final Map policy;
  final bool isAdmin;
  final VoidCallback onEdit;
  const _PolicyCard({required this.policy, required this.isAdmin, required this.onEdit});
  @override
  State<_PolicyCard> createState() => _PolicyCardState();
}

class _PolicyCardState extends State<_PolicyCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final content = widget.policy['content'] as String? ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Iconsax.document_text, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.policy['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
              if (widget.isAdmin) ...[
                IconButton(
                  icon: const Icon(Iconsax.edit, size: 16, color: AppColors.primary),
                  onPressed: widget.onEdit,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
              ],
              Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18, color: AppColors.textSecondary),
            ]),
            if (_expanded) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text(content, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            ],
          ]),
        ),
      ),
    );
  }
}
