import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../salary/screens/salary_screen.dart';
import '../../../shared/widgets/nepali_date_picker.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = ref.read(currentUserProvider)?.canManage ?? false;
    _tabController = TabController(length: _isAdmin ? 4 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    if (!_isAdmin) {
      return const SalaryScreen();
    }

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Card ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Iconsax.wallet_3, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Financial Accounts & Governance',
                                    style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Admin Console',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Manage company payroll, statutory tax bands, geofence rules & audit logs',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: context.border),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicatorColor: AppColors.primary,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        tabs: const [
                          Tab(icon: Icon(Iconsax.money_send, size: 18), text: 'Payroll Operations'),
                          Tab(icon: Icon(Iconsax.receipt, size: 18), text: 'Tax Bands & Brackets'),
                          Tab(icon: Icon(Iconsax.setting_2, size: 18), text: 'Global & Geofence'),
                          Tab(icon: Icon(Iconsax.chart, size: 18), text: 'Audit Reports & CSV'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Tab Views ──────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  SalaryScreen(),
                  _TaxManagementTab(),
                  _GlobalSettingsTab(),
                  _ReportsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Tax Band Management
// ─────────────────────────────────────────────────────────────────────────────
class _TaxManagementTab extends ConsumerStatefulWidget {
  const _TaxManagementTab();

  @override
  ConsumerState<_TaxManagementTab> createState() => _TaxManagementTabState();
}

class _TaxManagementTabState extends ConsumerState<_TaxManagementTab> with SingleTickerProviderStateMixin {
  late TabController _inner;
  List<dynamic> _salaryBandsSingle = [];
  List<dynamic> _salaryBandsMarried = [];
  List<dynamic> _incentiveBands = [];
  List<dynamic> _bonusBands = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 3, vsync: this);
    _loadBands();
  }

  @override
  void dispose() {
    _inner.dispose();
    super.dispose();
  }

  Future<void> _loadBands() async {
    setState(() => _loading = true);
    try {
      final salaryRes = await ApiService().get('${AppConstants.salaryBase}/tax-bands/salary/');
      final incentiveRes = await ApiService().get('${AppConstants.salaryBase}/tax-bands/incentive/');
      final bonusRes = await ApiService().get('${AppConstants.salaryBase}/tax-bands/bonus/');

      final allSalary = salaryRes.data is List ? salaryRes.data : (salaryRes.data['results'] ?? []);
      final allIncentive = incentiveRes.data is List ? incentiveRes.data : (incentiveRes.data['results'] ?? []);
      final allBonus = bonusRes.data is List ? bonusRes.data : (bonusRes.data['results'] ?? []);

      setState(() {
        _salaryBandsSingle = allSalary.where((b) => b['marital_status'] == 'single').toList();
        _salaryBandsMarried = allSalary.where((b) => b['marital_status'] == 'married').toList();
        _incentiveBands = allIncentive;
        _bonusBands = allBonus;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addBand(String type, {String marital = 'single'}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TaxBandDialog(type: type, marital: marital),
    );
    if (result == null) return;
    try {
      String url;
      if (type == 'salary') {
        url = '${AppConstants.salaryBase}/tax-bands/salary/';
      } else if (type == 'incentive') {
        url = '${AppConstants.salaryBase}/tax-bands/incentive/';
      } else {
        url = '${AppConstants.salaryBase}/tax-bands/bonus/';
      }
      await ApiService().post(url, data: result);
      _loadBands();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax band added successfully'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiService.getErrorMessage(e)}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteBand(String type, int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tax Band'),
        content: const Text('Are you sure you want to remove this statutory tax bracket?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    String url;
    if (type == 'salary') {
      url = '${AppConstants.salaryBase}/tax-bands/salary/$id/';
    } else if (type == 'incentive') {
      url = '${AppConstants.salaryBase}/tax-bands/incentive/$id/';
    } else {
      url = '${AppConstants.salaryBase}/tax-bands/bonus/$id/';
    }
    try {
      await ApiService().delete(url);
      _loadBands();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tax band deleted'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${ApiService.getErrorMessage(e)}'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.border),
            ),
            child: TabBar(
              controller: _inner,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Salary Tax Brackets'),
                Tab(text: 'Incentive Tax Brackets'),
                Tab(text: 'Bonus Tax Brackets'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _inner,
                    children: [
                      // Salary Tax Bands
                      _buildSalaryBandsView(),
                      // Incentive Tax Bands
                      _buildBandList(
                        bands: _incentiveBands,
                        type: 'incentive',
                        label: 'Incentive',
                        amountKey1: 'min_amount',
                        amountKey2: 'max_amount',
                      ),
                      // Bonus Tax Bands
                      _buildBandList(
                        bands: _bonusBands,
                        type: 'bonus',
                        label: 'Bonus',
                        amountKey1: 'min_amount',
                        amountKey2: 'max_amount',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryBandsView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border),
            ),
            child: const TabBar(
              indicatorColor: Color(0xFF10B981),
              labelColor: Color(0xFF10B981),
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: 'Unmarried Individual Status'),
                Tab(text: 'Married Couple Status'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              children: [
                _buildBandList(
                  bands: _salaryBandsSingle,
                  type: 'salary',
                  label: 'Salary (Single)',
                  amountKey1: 'min_salary',
                  amountKey2: 'max_salary',
                  marital: 'single',
                ),
                _buildBandList(
                  bands: _salaryBandsMarried,
                  type: 'salary',
                  label: 'Salary (Married)',
                  amountKey1: 'min_salary',
                  amountKey2: 'max_salary',
                  marital: 'married',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBandList({
    required List<dynamic> bands,
    required String type,
    required String label,
    required String amountKey1,
    required String amountKey2,
    String marital = 'single',
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBand(type, marital: marital),
        backgroundColor: AppColors.primary,
        elevation: 6,
        icon: const Icon(Iconsax.add_circle, color: Colors.white, size: 20),
        label: Text('Add $label Bracket', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: bands.isEmpty
          ? Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.receipt_2, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  Text(
                    'No $label tax brackets defined.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Configure statutory brackets to automatically calculate TDS on payroll.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: bands.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final b = bands[i];
                final min = b[amountKey1] ?? 0;
                final max = b[amountKey2];
                final pct = b['tax_percentage'] ?? 0;

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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NPR ${_fmt(min)}  →  ${max == null ? 'Above (No Limit)' : 'NPR ${_fmt(max)}'}',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                            const Text(
                              'Tax rate applies to earnings within this band',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.trash, color: AppColors.error, size: 18),
                        tooltip: 'Delete bracket',
                        onPressed: () => _deleteBand(type, b['id'] as int),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final d = (v as num).toDouble();
    return d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(2);
  }
}

class _TaxBandDialog extends StatefulWidget {
  final String type;
  final String marital;
  const _TaxBandDialog({required this.type, required this.marital});

  @override
  State<_TaxBandDialog> createState() => _TaxBandDialogState();
}

class _TaxBandDialogState extends State<_TaxBandDialog> {
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _pct = TextEditingController();

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _pct.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSalary = widget.type == 'salary';
    final label1 = isSalary ? 'Min Annual Salary (NPR) *' : 'Min Amount (NPR) *';
    final label2 = isSalary ? 'Max Annual Salary (NPR, leave blank for ∞)' : 'Max Amount (NPR, leave blank for ∞)';

    return AlertDialog(
      backgroundColor: context.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Iconsax.receipt_2, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Text(
            'Add ${widget.type[0].toUpperCase()}${widget.type.substring(1)} Tax Bracket',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _min,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: label1,
                prefixIcon: const Icon(Iconsax.money, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _max,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: label2,
                prefixIcon: const Icon(Iconsax.money_recive, size: 18),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pct,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Statutory Tax Rate (%) *',
                hintText: 'e.g. 1, 10, 20, 30, 36',
                prefixIcon: Icon(Iconsax.percentage_circle, size: 18),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () {
            final minV = double.tryParse(_min.text) ?? 0;
            final maxV = double.tryParse(_max.text);
            final pctV = double.tryParse(_pct.text) ?? 0;
            final data = {
              if (isSalary) 'min_salary': minV else 'min_amount': minV,
              if (maxV != null) (isSalary ? 'max_salary' : 'max_amount'): maxV,
              'tax_percentage': pctV,
              'order': 0,
              if (isSalary) 'marital_status': widget.marital,
            };
            Navigator.pop(context, data);
          },
          child: const Text('Save Bracket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3: Global Settings
// ─────────────────────────────────────────────────────────────────────────────
class _GlobalSettingsTab extends ConsumerStatefulWidget {
  const _GlobalSettingsTab();

  @override
  ConsumerState<_GlobalSettingsTab> createState() => _GlobalSettingsTabState();
}

class _GlobalSettingsTabState extends ConsumerState<_GlobalSettingsTab> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radius = TextEditingController();
  bool _inOffice = true;
  bool _remote = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().get('${AppConstants.organizationBase}/settings/');
      final d = res.data;
      setState(() {
        _lat.text = '${d['office_latitude'] ?? ''}';
        _lng.text = '${d['office_longitude'] ?? ''}';
        _radius.text = '${d['allowed_attendance_radius'] ?? 100}';
        _inOffice = d['enable_in_office_attendance'] ?? true;
        _remote = d['enable_remote_attendance'] ?? true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = {
        'office_latitude': double.tryParse(_lat.text),
        'office_longitude': double.tryParse(_lng.text),
        'allowed_attendance_radius': int.tryParse(_radius.text) ?? 100,
        'enable_in_office_attendance': _inOffice,
        'enable_remote_attendance': _remote,
      };
      await ApiService().patch(
        '${AppConstants.organizationBase}/settings/',
        data: payload,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Text('Governance & Geofence settings saved!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: ${ApiService.getErrorMessage(e)}'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Geofence Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.location, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Office Coordinates & Geofencing',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: context.border),
                const SizedBox(height: 14),

                TextField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Office Latitude *',
                    hintText: 'e.g. 27.7172',
                    prefixIcon: Icon(Iconsax.map, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _lng,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: const InputDecoration(
                    labelText: 'Office Longitude *',
                    hintText: 'e.g. 85.3240',
                    prefixIcon: Icon(Iconsax.map_1, size: 18),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _radius,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Allowed Check-In Radius (Meters) *',
                    hintText: 'e.g. 100',
                    prefixIcon: Icon(Iconsax.radar, size: 18),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Attendance Policy Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.calendar_tick, color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Attendance Enforcement Policies',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: context.border),
                const SizedBox(height: 8),

                SwitchListTile(
                  title: const Text('Enable In-Office Geofenced Attendance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Enforces GPS radius check when clocking in at the office', style: TextStyle(fontSize: 12)),
                  value: _inOffice,
                  onChanged: (v) => setState(() => _inOffice = v),
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Enable Remote / WFH Attendance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: const Text('Allows approved staff to check in while working remotely', style: TextStyle(fontSize: 12)),
                  value: _remote,
                  onChanged: (v) => setState(() => _remote = v),
                  activeThumbColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            ),
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
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
                        Icon(Iconsax.save_2, size: 16, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Save Governance Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4: Reports
// ─────────────────────────────────────────────────────────────────────────────
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  String? _selectedEmployee;
  List<dynamic> _employees = [];
  List<dynamic> _transactions = [];
  bool _loading = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    final now = NepaliDateTime.now();
    _startDateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    _endDateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.month > 6 ? 30 : 31}';
    _loadInitialData();
  }

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final res = await ApiService().get('/api/organization/employees/');
      if (mounted) {
        setState(() {
          if (res.data is List) {
            _employees = res.data;
          } else if (res.data != null && res.data['results'] is List) {
            _employees = res.data['results'];
          } else {
            _employees = [];
          }
        });
      }
      _fetchData();
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      String url =
          '/api/salary-management/transactions/organization/?start_date=${_startDateController.text.trim()}&end_date=${_endDateController.text.trim()}';
      if (_selectedEmployee != null && _selectedEmployee!.isNotEmpty && _selectedEmployee != 'null') {
        url += '&employee=$_selectedEmployee';
      }
      final res = await ApiService().get(url);
      if (mounted) {
        setState(() {
          if (res.data is List) {
            _transactions = res.data;
          } else if (res.data != null && res.data['results'] is List) {
            _transactions = res.data['results'];
          } else {
            _transactions = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: ${ApiService.getErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadReport() async {
    setState(() => _downloading = true);
    try {
      String url =
          '/api/salary-management/generate-report/?start_date=${_startDateController.text.trim()}&end_date=${_endDateController.text.trim()}';
      if (_selectedEmployee != null && _selectedEmployee!.isNotEmpty && _selectedEmployee != 'null') {
        url += '&employee=$_selectedEmployee';
      }
      final res = await ApiService().get(url);
      final csvData = res.data.toString();

      if (kIsWeb) {
        final bytes = utf8.encode(csvData);
        final blob = html.Blob([bytes]);
        final urlObj = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: urlObj)
          ..setAttribute("download", "salary_report_${_startDateController.text}_to_${_endDateController.text}.csv")
          ..click();
        html.Url.revokeObjectUrl(urlObj);
      } else {
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Salary Report',
          fileName: 'salary_report_${_startDateController.text}_to_${_endDateController.text}.csv',
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(csvData);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report generated successfully.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: ${ApiService.getErrorMessage(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Bar Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.border),
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 14,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: _startDateController,
                    readOnly: true,
                    onTap: () async {
                      final now = NepaliDateTime.now();
                      NepaliDateTime? initial;
                      try {
                        if (_startDateController.text.isNotEmpty) {
                          initial = NepaliDateTime.parse(_startDateController.text);
                        }
                      } catch (_) {}

                      final start = await showDialog<NepaliDateTime>(
                        context: context,
                        builder: (ctx) => NepaliDatePickerDialog(
                          title: 'Select Start Date',
                          initial: initial ?? now,
                        ),
                      );
                      if (start != null && mounted) {
                        setState(() {
                          _startDateController.text = start.toString().substring(0, 10);
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Start Date (B.S.)',
                      prefixIcon: Icon(Iconsax.calendar_1, size: 18),
                    ),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: TextField(
                    controller: _endDateController,
                    readOnly: true,
                    onTap: () async {
                      final now = NepaliDateTime.now();
                      NepaliDateTime? initial;
                      try {
                        if (_endDateController.text.isNotEmpty) {
                          initial = NepaliDateTime.parse(_endDateController.text);
                        }
                      } catch (_) {}

                      final end = await showDialog<NepaliDateTime>(
                        context: context,
                        builder: (ctx) => NepaliDatePickerDialog(
                          title: 'Select End Date',
                          initial: initial ?? now,
                        ),
                      );
                      if (end != null && mounted) {
                        setState(() {
                          _endDateController.text = end.toString().substring(0, 10);
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'End Date (B.S.)',
                      prefixIcon: Icon(Iconsax.calendar_2, size: 18),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String?>(
                    // ignore: deprecated_member_use
                    value: _selectedEmployee,
                    dropdownColor: context.surface,
                    decoration: const InputDecoration(
                      labelText: 'Staff Filter',
                      prefixIcon: Icon(Iconsax.user, size: 18),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Team Members')),
                      ..._employees.map((e) {
                        final u = e['user'] ?? {};
                        final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                        return DropdownMenuItem(
                          value: e['id'].toString(),
                          child: Text(name.isEmpty ? 'Emp #${e['id']}' : name),
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _selectedEmployee = v),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _fetchData,
                  icon: const Icon(Iconsax.filter, size: 16, color: Colors.white),
                  label: const Text('Filter Audit Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _downloading ? null : _downloadReport,
                  icon: _downloading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Iconsax.document_download, size: 16, color: Colors.white),
                  label: Text(_downloading ? 'Exporting...' : 'Export CSV', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data Table Card
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.border),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _transactions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Iconsax.document_text, size: 48, color: AppColors.textSecondary),
                              const SizedBox(height: 12),
                              Text(
                                'No payroll transactions found for selected filters.',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Adjust the date range or select all members to view disbursements.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(context.card),
                                headingTextStyle: TextStyle(fontWeight: FontWeight.w900, color: context.textPrimary, fontSize: 13),
                                dataTextStyle: TextStyle(color: context.textPrimary, fontSize: 13),
                                horizontalMargin: 20,
                                columnSpacing: 28,
                                columns: const [
                                  DataColumn(label: Text('Payment Date')),
                                  DataColumn(label: Text('Employee Name')),
                                  DataColumn(label: Text('Net Disbursed')),
                                  DataColumn(label: Text('Incentive')),
                                  DataColumn(label: Text('Bonus')),
                                  DataColumn(label: Text('TDS (Tax)')),
                                  DataColumn(label: Text('SSF / EPF')),
                                ],
                                rows: _transactions.map((t) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(t['date']?.toString() ?? '')),
                                      DataCell(Text(t['employee_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                                      DataCell(Text('NPR ${t['net_salary'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                                      DataCell(Text('NPR ${t['incentive'] ?? 0}')),
                                      DataCell(Text('NPR ${t['bonus'] ?? 0}')),
                                      DataCell(Text(
                                        t['transaction_tds'] != null
                                            ? (t['transaction_tds'] is num
                                                ? 'NPR ${(t['transaction_tds'] as num).toStringAsFixed(2)}'
                                                : 'NPR ${t['transaction_tds']}')
                                            : 'NPR 0',
                                        style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                                      )),
                                      DataCell(Text('${t['transaction_ssf'] ?? 0} / ${t['transaction_epf'] ?? 0}')),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
