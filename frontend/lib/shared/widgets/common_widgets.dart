export 'app_shell.dart';
export 'responsive_grid_list.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';

/// Full-screen loading placeholder
class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: AppColors.primary),
      if (message != null) ...[
        const SizedBox(height: 16),
        Text(message!, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ]),
  );
}

/// Full-screen error state
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: AppColors.error, size: 48),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary)),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ]),
    ),
  );
}

/// Empty state placeholder
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  const EmptyStateWidget({
    super.key, required this.title, this.subtitle,
    this.icon, this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon ?? Icons.inbox_outlined,
            size: 64, color: AppColors.textSecondary.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center),
        ],
        if (action != null) ...[
          const SizedBox(height: 24),
          action!,
        ],
      ]),
    ),
  );
}

/// Status badge chip
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(label, style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

/// Shimmer loading card
class ShimmerCard extends StatelessWidget {
  final double height;
  const ShimmerCard({super.key, this.height = 80});

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: context.card,
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

/// Theme Toggle Button

class ThemeToggleBtn extends ConsumerWidget {
  const ThemeToggleBtn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    IconData icon = Icons.brightness_auto;
    if (mode == ThemeMode.light) icon = Icons.light_mode;
    if (mode == ThemeMode.dark) icon = Icons.dark_mode;

    return PopupMenuButton<ThemeMode>(
      icon: Icon(icon, color: context.textPrimary),
      tooltip: 'Change Theme',
      color: context.surface,
      onSelected: (m) => ref.read(themeProvider.notifier).setTheme(m),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: ThemeMode.system,
          child: Text('System Default', style: TextStyle(color: context.textPrimary)),
        ),
        PopupMenuItem(
          value: ThemeMode.light,
          child: Text('Light Mode', style: TextStyle(color: context.textPrimary)),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: Text('Dark Mode', style: TextStyle(color: context.textPrimary)),
        ),
      ],
    );
  }
}




