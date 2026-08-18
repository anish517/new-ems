export 'app_shell.dart';
export 'responsive_grid_list.dart';
export 'nepali_date_picker.dart';
export 'global_month_year_picker.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';

/// Full-screen or container loading widget with sleek spinner and optional message
class LoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  const LoadingWidget({super.key, this.message, this.size = 36});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.primary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Modernized Error State Card with Retry Action
class AppErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const AppErrorWidget({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(28),
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.warning_2, color: AppColors.error, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Something Went Wrong',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Iconsax.refresh, size: 16, color: Colors.white),
              label: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Modern Empty State Placeholder with optional action
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? action;
  const EmptyStateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(32),
      constraints: const BoxConstraints(maxWidth: 460),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Iconsax.folder_open,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    ),
  );
}

/// Status badge pill with dot indicator
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.showDot = true,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

/// Shimmer loading placeholder card
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;
  const ShimmerCard({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: width,
    decoration: BoxDecoration(
      color: context.card,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: context.border),
    ),
  );
}

/// Reusable Theme Toggle Popup Button
class ThemeToggleBtn extends ConsumerWidget {
  const ThemeToggleBtn({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    IconData icon = Iconsax.sun_1;
    if (mode == ThemeMode.light) icon = Iconsax.sun_1;
    if (mode == ThemeMode.dark) icon = Iconsax.moon;

    return PopupMenuButton<ThemeMode>(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.border),
        ),
        child: Icon(icon, color: context.textPrimary, size: 18),
      ),
      tooltip: 'Select Color Theme',
      color: context.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (m) => ref.read(themeProvider.notifier).setTheme(m),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: ThemeMode.system,
          child: Row(
            children: [
              const Icon(Iconsax.monitor, size: 18),
              const SizedBox(width: 10),
              Text('System Default', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.light,
          child: Row(
            children: [
              const Icon(Iconsax.sun_1, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 10),
              Text('Light Theme', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        PopupMenuItem(
          value: ThemeMode.dark,
          child: Row(
            children: [
              const Icon(Iconsax.moon, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Dark Theme', style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
