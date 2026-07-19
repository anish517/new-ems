import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Calendar')),
    body: const Center(child: Text('Calendar view coming soon\n(Nepali BS calendar)',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textSecondary))),
  );
}
