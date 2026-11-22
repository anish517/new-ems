import 'package:material_ui/material_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/date_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class FinanceChartsTab extends ConsumerStatefulWidget {
  const FinanceChartsTab({super.key});

  @override
  ConsumerState<FinanceChartsTab> createState() => _FinanceChartsTabState();
}

class _FinanceChartsTabState extends ConsumerState<FinanceChartsTab> {
  bool _loading = true;
  String? _error;
  String _chartMode = 'monthly'; // 'monthly' | 'yearly'
  int? _selectedYear;
  int? _selectedMonth; // null = full year
  Map<String, dynamic> _data = {};

  static const _monthNames = [
    '',
    'Baishakh',
    'Jestha',
    'Ashadh',
    'Shrawan',
    'Bhadra',
    'Ashwin',
    'Kartik',
    'Mangsir',
    'Poush',
    'Magh',
    'Falgun',
    'Chaitra',
  ];

  final _nprFmt = NumberFormat('#,##0');

  @override
  void initState() {
    super.initState();
    final globalDate = ref.read(nepaliDateProvider);
    _selectedYear = globalDate.year;
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{};
      if (_selectedYear != null) params['year'] = _selectedYear;
      if (_selectedMonth != null) {
        params['month'] = _selectedMonth;
      } else {
        params['month'] = 'all';
      }
      final res = await ApiService().get(
        '/api/salary-management/analytics/summary/',
        queryParams: params,
      );
      if (!mounted) return;
      final map = res.data is Map
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};
      setState(() {
        _data = map;
        if (_selectedYear == null && map['selected_year'] is int) {
          _selectedYear = map['selected_year'] as int;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiService.getErrorMessage(e);
        _loading = false;
      });
    }
  }

  String _fmtNpr(num val) => 'NPR ${_nprFmt.format(val.round())}';

  String _fmtCompact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(nepaliDateProvider, (prev, next) {
      if (prev?.year != next.year) {
        setState(() => _selectedYear = next.year);
        _loadAnalytics();
      }
    });

    final isDark = context.isDark;
    final isTight = MediaQuery.of(context).size.width < 680;
    final isWide = MediaQuery.of(context).size.width >= 920;

    final availableYears = ((_data['available_years'] as List?) ?? [])
        .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
        .where((y) => y > 0)
        .toList();
    if (_selectedYear != null && !availableYears.contains(_selectedYear)) {
      availableYears.insert(0, _selectedYear!);
    }

    final kpis = (_data['kpis'] is Map)
        ? Map<String, dynamic>.from(_data['kpis'] as Map)
        : <String, dynamic>{};
    final monthly = (_data['monthly'] as List?) ?? const [];
    final yearly = (_data['yearly'] as List?) ?? const [];
    final breakdown = (_data['deduction_breakdown'] is Map)
        ? Map<String, dynamic>.from(_data['deduction_breakdown'] as Map)
        : <String, dynamic>{};
    final byDept = (_data['by_department'] as List?) ?? const [];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isTight ? 14 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Controls Bar ──────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.all(isTight ? 14 : 16),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Monthly / Yearly Toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _modePill('monthly', 'Monthly Chart', Iconsax.chart_2),
                          const SizedBox(width: 4),
                          _modePill('yearly', 'Yearly Chart', Iconsax.trend_up),
                        ],
                      ),
                    ),

                    // Year + Month Filters + Refresh
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (availableYears.isNotEmpty)
                          SizedBox(
                            width: 128,
                            child: DropdownButtonFormField<int>(
                              key: ValueKey('fin_year_$_selectedYear'),
                              initialValue: _selectedYear,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Year (BS)',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              items: availableYears
                                  .map((y) => DropdownMenuItem<int>(
                                        value: y,
                                        child: Text(
                                          '$y BS',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _selectedYear = v);
                                _loadAnalytics();
                              },
                            ),
                          ),
                        SizedBox(
                          width: 158,
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey('fin_month_$_selectedMonth'),
                            initialValue: _selectedMonth,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Breakdown Scope',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  'All 12 Months',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              for (int m = 1; m <= 12; m++)
                                DropdownMenuItem<int?>(
                                  value: m,
                                  child: Text(
                                    _monthNames[m],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              setState(() => _selectedMonth = v);
                              _loadAnalytics();
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: _loadAnalytics,
                          icon: const Icon(Iconsax.refresh, size: 18),
                          tooltip: 'Refresh Analytics',
                          style: IconButton.styleFrom(
                            backgroundColor: context.card,
                            side: BorderSide(color: context.border),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  const Icon(Iconsax.warning_2,
                      color: AppColors.error, size: 32),
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                      onPressed: _loadAnalytics, child: const Text('Retry')),
                ],
              ),
            )
          else ...[
            // ── KPI Summary Grid ────────────────────────────────────────────
            _buildKpiGrid(kpis, isTight),
            const SizedBox(height: 16),

            // ── Primary Monthly / Yearly Chart Card ─────────────────────────
            if (_chartMode == 'monthly')
              _buildMonthlyChartCard(monthly, isDark, isTight)
            else
              _buildYearlyChartCard(yearly, isDark, isTight),

            const SizedBox(height: 16),

            // ── Secondary Breakdown Row (Deduction Donut + Department Cost) ─
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildDeductionDonutCard(breakdown, isDark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 6,
                    child: _buildDepartmentCard(byDept, isDark),
                  ),
                ],
              )
            else ...[
              _buildDeductionDonutCard(breakdown, isDark),
              const SizedBox(height: 16),
              _buildDepartmentCard(byDept, isDark),
            ],
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  Widget _modePill(String key, String label, IconData icon) {
    final active = _chartMode == key;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => setState(() => _chartMode = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? Colors.white : context.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiGrid(Map<String, dynamic> kpis, bool isTight) {
    final totalExp = (kpis['total_expense'] as num?)?.toDouble() ?? 0;
    final totalNet = (kpis['total_net'] as num?)?.toDouble() ?? 0;
    final totalTds = (kpis['total_tds'] as num?)?.toDouble() ?? 0;
    final ssfEpf = ((kpis['total_ssf'] as num?)?.toDouble() ?? 0) +
        ((kpis['total_epf'] as num?)?.toDouble() ?? 0);
    final payoutCount = (kpis['payout_count'] as num?)?.toInt() ?? 0;
    final avgMonthly = (kpis['avg_monthly_expense'] as num?)?.toDouble() ?? 0;

    final cards = [
      _kpiCard(
        title: 'Total Payroll Expense',
        value: _fmtNpr(totalExp),
        subtitle: _selectedMonth == null
            ? 'Avg ${_fmtNpr(avgMonthly)} / active mo'
            : '${_monthNames[_selectedMonth!]} $_selectedYear',
        icon: Iconsax.money_send,
        color: AppColors.primary,
      ),
      _kpiCard(
        title: 'Net Salary Paid',
        value: _fmtNpr(totalNet),
        subtitle: '$payoutCount payout${payoutCount == 1 ? '' : 's'} processed',
        icon: Iconsax.wallet_check,
        color: AppColors.success,
      ),
      _kpiCard(
        title: 'Total TDS Tax',
        value: _fmtNpr(totalTds),
        subtitle: 'Salary + Incentive + Bonus tax',
        icon: Iconsax.receipt_2,
        color: AppColors.error,
      ),
      _kpiCard(
        title: 'SSF + EPF Funds',
        value: _fmtNpr(ssfEpf),
        subtitle: 'Statutory retirement funds',
        icon: Iconsax.shield_tick,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 900 ? 4 : 2;
        final spacing = isTight ? 10.0 : 12.0;
        final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map((c) => SizedBox(width: itemWidth, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(18),
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: context.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChartCard(List monthly, bool isDark, bool isTight) {
    double maxY = 0;
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < monthly.length; i++) {
      final m = monthly[i] as Map;
      final exp = (m['total_expense'] as num?)?.toDouble() ?? 0;
      final net = (m['net'] as num?)?.toDouble() ?? 0;
      final tds = (m['tds'] as num?)?.toDouble() ?? 0;
      if (exp > maxY) maxY = exp;
      if (net > maxY) maxY = net;

      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 3,
          barRods: [
            BarChartRodData(
              toY: exp,
              color: AppColors.primary,
              width: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: net,
              color: AppColors.success,
              width: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            BarChartRodData(
              toY: tds,
              color: AppColors.error,
              width: 8,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
    }

    final hasData = maxY > 0;
    maxY = hasData ? maxY * 1.18 : 100;

    return Container(
      padding: EdgeInsets.all(isTight ? 14 : 20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Payroll & TDS Overview ($_selectedYear BS)',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '12-month comparison across Baishakh to Chaitra',
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _legendDot(AppColors.primary, 'Total Expense'),
                  _legendDot(AppColors.success, 'Net Paid'),
                  _legendDot(AppColors.error, 'TDS'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasData)
            _emptyChartPlaceholder(
                'No salary payouts recorded for $_selectedYear BS yet.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth =
                    constraints.maxWidth < 620 ? 620.0 : constraints.maxWidth;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: chartWidth,
                    height: 270,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: context.border, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (v, _) => Text(
                                _fmtCompact(v),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= monthly.length) {
                                  return const SizedBox.shrink();
                                }
                                final label =
                                    (monthly[idx]['short_label'] ?? '').toString();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    label,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: groups,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final m = monthly[group.x.toInt()] as Map;
                              final mName = (m['label'] ?? '').toString();
                              final metric = rodIndex == 0
                                  ? 'Expense'
                                  : rodIndex == 1
                                      ? 'Net Paid'
                                      : 'TDS';
                              return BarTooltipItem(
                                '$mName\n$metric: ${_fmtNpr(rod.toY)}',
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildYearlyChartCard(List yearly, bool isDark, bool isTight) {
    double maxY = 0;
    final expSpots = <FlSpot>[];
    final netSpots = <FlSpot>[];
    final tdsSpots = <FlSpot>[];
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < yearly.length; i++) {
      final y = yearly[i] as Map;
      final exp = (y['total_expense'] as num?)?.toDouble() ?? 0;
      final net = (y['net'] as num?)?.toDouble() ?? 0;
      final tds = (y['tds'] as num?)?.toDouble() ?? 0;
      if (exp > maxY) maxY = exp;
      if (net > maxY) maxY = net;

      expSpots.add(FlSpot(i.toDouble(), exp));
      netSpots.add(FlSpot(i.toDouble(), net));
      tdsSpots.add(FlSpot(i.toDouble(), tds));

      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 6,
          barRods: [
            BarChartRodData(
              toY: exp,
              color: AppColors.primary,
              width: 18,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            BarChartRodData(
              toY: net,
              color: AppColors.success,
              width: 18,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
            BarChartRodData(
              toY: tds,
              color: AppColors.error,
              width: 18,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
    }

    final hasData = maxY > 0;
    maxY = hasData ? maxY * 1.18 : 100;

    return Container(
      padding: EdgeInsets.all(isTight ? 14 : 20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yearly Payroll & TDS Trend',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Annual comparison across Nepali fiscal years',
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _legendDot(AppColors.primary, 'Total Expense'),
                  _legendDot(AppColors.success, 'Net Paid'),
                  _legendDot(AppColors.error, 'TDS'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!hasData)
            _emptyChartPlaceholder('No yearly payroll transactions recorded yet.')
          else ...[
            SizedBox(
              height: 260,
              child: yearly.length >= 2
                  ? LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: context.border, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (v, _) => Text(
                                _fmtCompact(v),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= yearly.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${yearly[idx]['label']} BS',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: expSpots,
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.primary.withValues(alpha: 0.10),
                            ),
                          ),
                          LineChartBarData(
                            spots: netSpots,
                            isCurved: true,
                            color: AppColors.success,
                            barWidth: 2.5,
                            dotData: const FlDotData(show: true),
                          ),
                          LineChartBarData(
                            spots: tdsSpots,
                            isCurved: true,
                            color: AppColors.error,
                            barWidth: 2,
                            dashArray: [5, 3],
                            dotData: const FlDotData(show: true),
                          ),
                        ],
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: context.border, strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (v, _) => Text(
                                _fmtCompact(v),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= yearly.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    '${yearly[idx]['label']} BS',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: groups,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Divider(color: context.border),
            const SizedBox(height: 10),
            // Year-over-year summary cards
            ...yearly.reversed.map((y) {
              final map = y as Map;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${map['label']} BS (${map['payout_count'] ?? 0} payouts)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Expense: ${_fmtNpr((map['total_expense'] as num?) ?? 0)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary),
                        ),
                        Text(
                          'Net: ${_fmtNpr((map['net'] as num?) ?? 0)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success),
                        ),
                        Text(
                          'TDS: ${_fmtNpr((map['tds'] as num?) ?? 0)}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildDeductionDonutCard(Map<String, dynamic> b, bool isDark) {
    final net = (b['net'] as num?)?.toDouble() ?? 0;
    final tds = (b['tds'] as num?)?.toDouble() ?? 0;
    final ssf = (b['ssf'] as num?)?.toDouble() ?? 0;
    final epf = (b['epf'] as num?)?.toDouble() ?? 0;
    final other = ((b['cit'] as num?)?.toDouble() ?? 0) +
        ((b['insurance'] as num?)?.toDouble() ?? 0);
    final total = net + tds + ssf + epf + other;

    final slices = [
      ('Net Paid', net, AppColors.success),
      ('TDS Tax', tds, AppColors.error),
      ('SSF', ssf, AppColors.primary),
      ('EPF', epf, const Color(0xFF8B5CF6)),
      ('CIT & Ins.', other, AppColors.warning),
    ].where((s) => s.$2 > 0).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payout & Deduction Breakdown',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _selectedMonth == null
                ? 'Full year $_selectedYear BS'
                : '${_monthNames[_selectedMonth!]} $_selectedYear BS',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (total <= 0)
            _emptyChartPlaceholder('No breakdown data for this period.')
          else
            Column(
              children: [
                SizedBox(
                  height: 185,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      sections: slices.map((s) {
                        final pct = (s.$2 / total) * 100;
                        return PieChartSectionData(
                          color: s.$3,
                          value: s.$2,
                          radius: 44,
                          title: pct >= 6 ? '${pct.toStringAsFixed(0)}%' : '',
                          titleStyle: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ...slices.map((s) {
                  final pct = ((s.$2 / total) * 100).toStringAsFixed(1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.$3,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            s.$1,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${_fmtNpr(s.$2)} ($pct%)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDepartmentCard(List byDept, bool isDark) {
    final totalAll = byDept.fold<double>(
      0,
      (sum, item) => sum + ((item['total_expense'] as num?)?.toDouble() ?? 0),
    );

    const palette = [
      AppColors.primary,
      AppColors.success,
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFF06B6D4),
      AppColors.error,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Department Payroll Cost',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _selectedMonth == null
                ? 'Ranked by total employer cost ($_selectedYear BS)'
                : 'Ranked by cost (${_monthNames[_selectedMonth!]} $_selectedYear BS)',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          if (byDept.isEmpty || totalAll <= 0)
            _emptyChartPlaceholder('No department payroll data for this period.')
          else
            ...List.generate(byDept.length, (i) {
              final d = byDept[i] as Map;
              final name = (d['department'] ?? 'Unassigned').toString();
              final exp = (d['total_expense'] as num?)?.toDouble() ?? 0;
              final tds = (d['tds'] as num?)?.toDouble() ?? 0;
              final count = (d['payout_count'] as num?)?.toInt() ?? 0;
              final ratio = (exp / totalAll).clamp(0.0, 1.0);
              final color = palette[i % palette.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name ($count)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fmtNpr(exp),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: context.border,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${(ratio * 100).toStringAsFixed(1)}% of payroll · TDS ${_fmtNpr(tds)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _emptyChartPlaceholder(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Column(
        children: [
          const Icon(Iconsax.chart, size: 34, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
