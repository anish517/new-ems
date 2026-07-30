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

class _AccountsScreenState extends ConsumerState<AccountsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // Read role before first frame so tab count is correct
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
    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        title: Text(
          _isAdmin ? 'Accounts' : 'Payroll',
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold),
        ),
        bottom: _isAdmin
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.primary,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                tabs: const [
                  Tab(icon: Icon(Iconsax.money_send), text: 'Payroll'),
                  Tab(icon: Icon(Iconsax.receipt), text: 'Tax Bands'),
                  Tab(icon: Icon(Iconsax.setting_2), text: 'Global Settings'),
                  Tab(icon: Icon(Iconsax.chart), text: 'Reports'),
                ],
              )
            : null,
      ),
      body: _isAdmin
          ? TabBarView(
              controller: _tabController,
              children: const [
                // Tab 1: Payroll — embed existing SalaryScreen
                SalaryScreen(),
                // Tab 2: Tax Band Management
                _TaxManagementTab(),
                // Tab 3: Global Settings (Geolocation, Attendance)
                _GlobalSettingsTab(),
                // Tab 4: Reports
                _ReportsTab(),
              ],
            )
          // Employee: directly shows Payroll (no tab bar)
          : const SalaryScreen(),
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

class _TaxManagementTabState extends ConsumerState<_TaxManagementTab>
    with SingleTickerProviderStateMixin {
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
      final salaryRes = await ApiService()
          .get('${AppConstants.salaryBase}/tax-bands/salary/');
      final incentiveRes = await ApiService()
          .get('${AppConstants.salaryBase}/tax-bands/incentive/');
      final bonusRes =
          await ApiService().get('${AppConstants.salaryBase}/tax-bands/bonus/');
      final allSalary = salaryRes.data is List
          ? salaryRes.data
          : (salaryRes.data['results'] ?? []);
      final allIncentive = incentiveRes.data is List
          ? incentiveRes.data
          : (incentiveRes.data['results'] ?? []);
      final allBonus = bonusRes.data is List
          ? bonusRes.data
          : (bonusRes.data['results'] ?? []);
      setState(() {
        _salaryBandsSingle = allSalary
            .where((b) => b['marital_status'] == 'single')
            .toList();
        _salaryBandsMarried = allSalary
            .where((b) => b['marital_status'] == 'married')
            .toList();
        _incentiveBands = allIncentive;
        _bonusBands = allBonus;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
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
      // FIX: `data` is a named parameter on ApiService.post()
      await ApiService().post(url, data: result);
      _loadBands();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteBand(String type, int id) async {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _inner,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Salary Tax'),
            Tab(text: 'Incentive Tax'),
            Tab(text: 'Bonus Tax'),
          ],
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
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
    );
  }

  Widget _buildSalaryBandsView() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: context.surface,
            child: const TabBar(
              indicatorColor: Colors.green,
              labelColor: Colors.green,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: [Tab(text: 'Single'), Tab(text: 'Married')],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildBandList(
                    bands: _salaryBandsSingle,
                    type: 'salary',
                    label: 'Salary (Single)',
                    amountKey1: 'min_salary',
                    amountKey2: 'max_salary',
                    marital: 'single'),
                _buildBandList(
                    bands: _salaryBandsMarried,
                    type: 'salary',
                    label: 'Salary (Married)',
                    amountKey1: 'min_salary',
                    amountKey2: 'max_salary',
                    marital: 'married'),
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
      backgroundColor: context.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBand(type, marital: marital),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text('Add $label Band'),
      ),
      body: bands.isEmpty
          ? Center(
              child: Text('No $label tax bands yet.',
                  style: const TextStyle(color: AppColors.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bands.length,
              itemBuilder: (ctx, i) {
                final b = bands[i];
                final min = b[amountKey1] ?? 0;
                final max = b[amountKey2];
                final pct = b['tax_percentage'] ?? 0;
                return Card(
                  color: context.surface,
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text('${pct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              color: AppColors.primary, fontSize: 11)),
                    ),
                    title: Text(
                      'NPR ${_fmt(min)} – ${max == null ? '∞' : 'NPR ${_fmt(max)}'}',
                      style: TextStyle(color: context.textPrimary),
                    ),
                    subtitle: Text('Tax: $pct%',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteBand(type, b['id']),
                    ),
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
    final label1 = isSalary ? 'Min Salary (NPR)' : 'Min Amount (NPR)';
    final label2 =
        isSalary ? 'Max Salary (NPR, blank=∞)' : 'Max Amount (NPR, blank=∞)';
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      title: Text(
          'Add ${widget.type[0].toUpperCase()}${widget.type.substring(1)} Tax Band',
          style: TextStyle(color: context.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_min, label1),
          const SizedBox(height: 12),
          _field(_max, label2),
          const SizedBox(height: 12),
          _field(_pct, 'Tax Percentage (%)'),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                Text('Cancel', style: TextStyle(color: context.textSecondary))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.textSecondary),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: context.border)),
        focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary)),
      ),
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
      final res =
          await ApiService().get('${AppConstants.organizationBase}/settings/');
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
      setState(() => _loading = false);
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
      // FIX: `data` is a named parameter on ApiService.patch()
      await ApiService().patch(
        '${AppConstants.organizationBase}/settings/',
        data: payload,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Office Geolocation', Iconsax.location),
          const SizedBox(height: 16),
          _inputField(_lat, 'Office Latitude', 'e.g. 27.7172'),
          const SizedBox(height: 12),
          _inputField(_lng, 'Office Longitude', 'e.g. 85.3240'),
          const SizedBox(height: 12),
          _inputField(_radius, 'Allowed Radius (meters)', 'e.g. 100',
              isInt: true),
          const SizedBox(height: 28),
          _sectionHeader('Attendance Rules', Iconsax.calendar_tick),
          const SizedBox(height: 16),
          _toggleCard(
            title: 'Enable In-Office Attendance',
            subtitle: 'Allow employees to check in from the office location',
            value: _inOffice,
            onChanged: (v) => setState(() => _inOffice = v),
          ),
          const SizedBox(height: 12),
          _toggleCard(
            title: 'Enable Remote Attendance',
            subtitle: 'Allow employees to check in while working from home',
            value: _remote,
            onChanged: (v) => setState(() => _remote = v),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Iconsax.save_2, color: Colors.white),
              label: Text(_saving ? 'Saving...' : 'Save Settings',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _inputField(TextEditingController c, String label, String hint,
      {bool isInt = false}) {
    return TextField(
      controller: c,
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true, signed: true),
      style: TextStyle(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: context.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _toggleCard(
      {required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        title:
            Text(title, style: TextStyle(color: context.textPrimary)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppColors.textSecondary)),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4: Reports Placeholder
// ─────────────────────────────────────────────────────────────────────────────
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
    } catch (e) {
      debugPrint('Error loading employees: $e');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      String url = '/api/salary-management/transactions/organization/?start_date=${_startDateController.text.trim()}&end_date=${_endDateController.text.trim()}';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load data: ${ApiService.getErrorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadReport() async {
    setState(() => _downloading = true);
    try {
      String url = '/api/salary-management/generate-report/?start_date=${_startDateController.text.trim()}&end_date=${_endDateController.text.trim()}';
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report generated successfully.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate report: ${ApiService.getErrorMessage(e)}')));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 200,
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
                      } catch (e) {
                        // ignore error
                      }

                      final NepaliDateTime? start = await showDialog<NepaliDateTime>(
                        context: context,
                        builder: (ctx) => NepaliDatePickerDialog(
                          title: 'Select Start Date',
                          initial: initial ?? now,
                        ),
                      );
                      if (start != null) {
                        setState(() {
                          _startDateController.text = start.toString().substring(0, 10);
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Start Date (YYYY-MM-DD)', 
                      filled: true,
                      suffixIcon: Icon(Icons.calendar_month),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
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
                      } catch (e) {
                        // ignore error
                      }
                      
                      NepaliDateTime? minDate;
                      try {
                        if (_startDateController.text.isNotEmpty) {
                          minDate = NepaliDateTime.parse(_startDateController.text);
                        }
                      } catch (e) {
                        // ignore error
                      }

                      final NepaliDateTime? end = await showDialog<NepaliDateTime>(
                        context: context,
                        builder: (ctx) => NepaliDatePickerDialog(
                          title: 'Select End Date',
                          initial: initial ?? now,
                          minDate: minDate,
                        ),
                      );
                      if (end != null) {
                        setState(() {
                          _endDateController.text = end.toString().substring(0, 10);
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'End Date (YYYY-MM-DD)', 
                      filled: true,
                      suffixIcon: Icon(Icons.calendar_month),
                    ),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _selectedEmployee,
                    dropdownColor: context.surface,
                    style: TextStyle(color: context.textPrimary),
                    decoration: const InputDecoration(labelText: 'Employee', filled: true),
                    items: [
                      DropdownMenuItem(value: null, child: Text('All Members', style: TextStyle(color: context.textPrimary))),
                      ..._employees.map((e) {
                        final u = e['user'] ?? {};
                        final name = '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim();
                        return DropdownMenuItem(
                          value: e['id'].toString(), 
                          child: Text(name.isEmpty ? 'Emp #${e['id']}' : name, style: TextStyle(color: context.textPrimary))
                        );
                      }),
                    ],
                    onChanged: (v) => setState(() => _selectedEmployee = v),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _fetchData,
                  icon: const Icon(Iconsax.filter),
                  label: const Text('Filter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _downloading ? null : _downloadReport,
                  icon: _downloading 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Iconsax.document_download),
                  label: Text(_downloading ? 'Exporting...' : 'Export CSV'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Data Table
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? Center(child: Text('No salary transactions found for the selected criteria.', style: TextStyle(color: context.textSecondary)))
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingTextStyle: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                            dataTextStyle: TextStyle(color: context.textSecondary),
                            columns: const [
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Employee')),
                              DataColumn(label: Text('Net Salary')),
                              DataColumn(label: Text('Incentive')),
                              DataColumn(label: Text('Bonus')),
                              DataColumn(label: Text('Total TDS')),
                              DataColumn(label: Text('SSF / EPF')),
                            ],
                            rows: _transactions.map((t) {
                              return DataRow(cells: [
                                DataCell(Text(t['date']?.toString() ?? '')),
                                DataCell(Text(t['employee_name']?.toString() ?? '')),
                                DataCell(Text('NPR ${t['net_salary'] ?? 0}')),
                                DataCell(Text('${t['incentive'] ?? 0}')),
                                DataCell(Text('${t['bonus'] ?? 0}')),
                                DataCell(Text(t['transaction_tds'] != null ? (t['transaction_tds'] is num ? (t['transaction_tds'] as num).toStringAsFixed(2) : t['transaction_tds'].toString()) : '0')),
                                DataCell(Text('${t['transaction_ssf'] ?? 0} / ${t['transaction_epf'] ?? 0}')),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}








