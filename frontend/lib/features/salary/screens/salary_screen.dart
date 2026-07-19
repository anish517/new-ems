import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';

class SalaryScreen extends ConsumerWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salary')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Latest payslip card
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF0F2D4A)]),
              borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Current Month Salary', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('NPR —', style: TextStyle(color: Colors.white,
                  fontSize: 32, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24, height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
                _PayslipItem('Basic', '—'),
                _PayslipItem('Remote', '—'),
                _PayslipItem('Deduction', '—'),
              ]),
            ]),
          ),
          const SizedBox(height: 24),

          // Breakdown cards
          const Text('Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          _InfoRow(Iconsax.calendar, 'Days Present', '—'),
          _InfoRow(Iconsax.sun_1, 'Holidays', '—'),
          _InfoRow(Iconsax.calendar_remove, 'Paid Leaves', '—'),
          _InfoRow(Iconsax.minus_cirlce, 'TDS / SSF', '—'),
          const Divider(height: 32),
          _InfoRow(Iconsax.money_recive, 'Net Salary', '—', bold: true),
        ]),
      ),
    );
  }
}

class _PayslipItem extends StatelessWidget {
  final String label, value;
  const _PayslipItem(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
  ]);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool bold;
  const _InfoRow(this.icon, this.label, this.value, {this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          color: bold ? AppColors.success : null)),
    ]),
  );
}
