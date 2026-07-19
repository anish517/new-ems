import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          CircleAvatar(radius: 48, backgroundColor: AppColors.primary,
            child: Text(user?.firstName[0].toUpperCase() ?? 'U',
              style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))),
          const SizedBox(height: 16),
          Text(user?.fullName ?? '—', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(user?.email ?? '—', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Text(user?.role.replaceAll('_', ' ').toUpperCase() ?? '',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12))),
          const SizedBox(height: 32),
          ListTile(leading: const Icon(Iconsax.user), title: const Text('Edit Profile'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ListTile(leading: const Icon(Iconsax.lock), title: const Text('Change Password'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          ListTile(leading: const Icon(Iconsax.document), title: const Text('My Documents'), trailing: const Icon(Icons.chevron_right), onTap: () {}),
          const Divider(),
          ListTile(
            leading: const Icon(Iconsax.logout, color: AppColors.error),
            title: const Text('Logout', style: TextStyle(color: AppColors.error)),
            onTap: () => ref.read(authProvider.notifier).logout(),
          ),
        ]),
      ),
    );
  }
}
