import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;
  Map<String, dynamic>? _employeeDetails;
  List<dynamic> _myChangeRequests = [];

  @override
  void initState() {
    super.initState();
    _loadAllProfileData();
  }

  Future<void> _loadAllProfileData() async {
    _loadChangeRequests();
    _loadEmployeeDetails();
  }

  Future<void> _loadEmployeeDetails() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      // If user has employee profile or is staff
      final res = await ApiService().get('${AppConstants.organizationBase}/employees/');
      final list = res.data is List ? res.data : (res.data['results'] ?? res.data);
      if (list is List && list.isNotEmpty) {
        final myEmp = list.firstWhere(
          (e) => (e['user']?['id'] == user.id) || (e['user']?['email'] == user.email),
          orElse: () => list.first,
        );
        if (mounted && myEmp != null) {
          // Fetch full employee detail
          final empId = myEmp['id'];
          final detailRes = await ApiService().get('${AppConstants.organizationBase}/employees/$empId/');
          Map<String, dynamic> empData = detailRes.data is Map
              ? Map<String, dynamic>.from(detailRes.data)
              : Map<String, dynamic>.from(myEmp);

          // Fetch address fallback if not already in detail
          if (empData['address'] == null || (empData['address'] is List && (empData['address'] as List).isEmpty)) {
            try {
              final addrRes = await ApiService().get('${AppConstants.organizationBase}/addresses/?employee=$empId');
              final addrs = addrRes.data is List ? addrRes.data : (addrRes.data['results'] ?? []);
              if (addrs is List && addrs.isNotEmpty) {
                empData['address'] = addrs;
              }
            } catch (_) {}
          }

          if (mounted) {
            setState(() {
              _employeeDetails = empData;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _loadChangeRequests() async {
    final user = ref.read(currentUserProvider);
    if (user?.canManage == true) return;
    try {
      final res = await ApiService().get('/api/organization/profile-change-requests/');
      if (mounted) {
        setState(() {
          _myChangeRequests = res.data is List ? res.data : (res.data['results'] ?? []);
        });
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (image == null) return;

      setState(() => _isUploading = true);
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final ext = image.name.split('.').last.toLowerCase();
      final dataUri = 'data:image/$ext;base64,$base64Image';

      await ApiService().patch('/api/auth/me/', data: {'profile_picture': dataUri});
      await ref.read(authProvider.notifier).refreshUser();
      _loadEmployeeDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Profile photo updated successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update picture: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submitContactChange(String fieldName, String newValue) async {
    try {
      await ApiService().post(
        '/api/organization/profile-change-requests/',
        data: {'field_name': fieldName, 'new_value': newValue},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(child: Text('Change request submitted for admin review!')),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _loadChangeRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showEditProfile() {
    final user = ref.read(currentUserProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: ctx.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: ctx.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _EditProfileSheet(
              firstName: user?.firstName ?? '',
              lastName: user?.lastName ?? '',
              onSuccess: () {
                ref.read(authProvider.notifier).refreshUser();
                _loadEmployeeDetails();
              },
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => _EditProfileSheet(
          firstName: user?.firstName ?? '',
          lastName: user?.lastName ?? '',
          onSuccess: () {
            ref.read(authProvider.notifier).refreshUser();
            _loadEmployeeDetails();
          },
        ),
      );
    }
  }

  void _showChangePassword() {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: ctx.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: BorderSide(color: ctx.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: const _ChangePasswordSheet(),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => const _ChangePasswordSheet(),
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: ctx.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Iconsax.logout, color: AppColors.error, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: ctx.textPrimary,
                            ),
                          ),
                          const Text(
                            'End your current active session',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Are you sure you want to log out of the Employee Management System?',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: ctx.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(authProvider.notifier).logout();
                          if (mounted) {
                            context.go('/login');
                          }
                        },
                        child: const Text(
                          'Log Out',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'N/A',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isDark = context.isDark;
    final emp = _employeeDetails;

    final post = emp != null ? emp['post'] : null;
    final designation = (emp != null ? emp['designation_title'] : null) ??
        (post is Map ? post['title'] : null) ??
        (user?.role.replaceAll('_', ' ').toUpperCase() ?? 'Staff Member');
    final phone = emp?['phone_no'] ?? 'Not provided';
    final personalEmail = emp?['personal_email'] ?? user?.email ?? 'Not provided';
    final emergencyPhone = emp?['emergency_phone_number'] ??
        emp?['alternative_contact_number'] ??
        'Not provided';
    final fatherName = (emp?['father_name'] != null && emp!['father_name'].toString().isNotEmpty)
        ? emp['father_name'].toString()
        : 'Not provided';
    final dob = (emp?['date_of_birth'] != null && emp!['date_of_birth'].toString().isNotEmpty)
        ? emp['date_of_birth'].toString()
        : 'Not provided';
    final empType = emp?['employee_type'] ?? 'full_time';

    // Address extraction
    final addresses = (emp?['address'] is List) ? (emp!['address'] as List) : [];
    final permanent = addresses.firstWhere(
      (a) => a['type'] == 'permanent',
      orElse: () => addresses.isNotEmpty ? addresses.first : null,
    );
    final permanentAddress = permanent != null
        ? [
            permanent['street']?.toString().trim(),
            permanent['district']?.toString().trim(),
            permanent['state']?.toString().trim(),
          ]
            .where((s) => s != null && s.isNotEmpty)
            .join(', ')
        : '';
    final addressDisplay = permanentAddress.isNotEmpty ? permanentAddress : 'Not provided';

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTight = constraints.maxWidth < 650;
            final availableWidth = constraints.maxWidth - (isTight ? 28 : 48);
            final targetWidth = availableWidth < 860 ? availableWidth : 860.0;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: isTight ? 14 : 24,
                vertical: isTight ? 16 : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: targetWidth,
                    maxWidth: 860,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // ── Hero Profile Card ─────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Gradient Top Banner
                        Container(
                          height: 100,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),

                        // Profile Info & Avatar Row
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Avatar floating over banner
                              Transform.translate(
                                offset: const Offset(0, -40),
                                child: Stack(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: context.surface,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 46,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                                        backgroundImage: user?.profilePicture != null
                                            ? NetworkImage(user!.profilePicture!)
                                            : null,
                                        child: user?.profilePicture == null
                                            ? Text(
                                                (user?.firstName.isNotEmpty == true)
                                                    ? user!.firstName[0].toUpperCase()
                                                    : 'U',
                                                style: const TextStyle(
                                                  fontSize: 34,
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.primary,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: _isUploading ? null : _pickAndUploadImage,
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: context.surface, width: 2.5),
                                          ),
                                          child: _isUploading
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Iconsax.camera, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),

                              // Name & Designation Details
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      final isTight = c.maxWidth < 450;

                                      return Flex(
                                        direction: isTight ? Axis.vertical : Axis.horizontal,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: isTight
                                            ? CrossAxisAlignment.start
                                            : CrossAxisAlignment.center,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    user?.fullName ?? 'User Profile',
                                                    style: TextStyle(
                                                      fontSize: isTight ? 19 : 22,
                                                      fontWeight: FontWeight.w900,
                                                      letterSpacing: -0.4,
                                                      color: context.textPrimary,
                                                    ),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      user?.role.replaceAll('_', ' ').toUpperCase() ?? 'STAFF',
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: AppColors.primary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                '$designation · ${empType == 'full_time' ? 'Full-Time' : empType == 'part_time' ? 'Part-Time' : 'Intern'}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(Iconsax.sms, size: 13, color: AppColors.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    user?.email ?? 'No email',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          if (isTight) const SizedBox(height: 12),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: _showEditProfile,
                                                icon: const Icon(Iconsax.edit, size: 16),
                                                label: const Text('Edit Name'),
                                                style: OutlinedButton.styleFrom(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Iconsax.key, size: 18, color: AppColors.primary),
                                                tooltip: 'Change Password',
                                                onPressed: _showChangePassword,
                                                style: IconButton.styleFrom(
                                                  backgroundColor: context.card,
                                                  side: BorderSide(color: context.border),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Contact Information Section (Self-service Change Requests) ─
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Iconsax.call_calling, color: AppColors.primary, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Contact Details & Self-Edit Requests',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (_myChangeRequests.any((r) => r['status'] == 'pending'))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '⏳ Change Pending Review',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'You can request updates to your contact channels. Changes take effect upon HR approval.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),

                        // Contact items with self-edit buttons
                        LayoutBuilder(
                          builder: (context, c) {
                            final cols = c.maxWidth < 650 ? 1 : 3;
                            return GridView.count(
                              crossAxisCount: cols,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: cols == 1 ? 4.5 : 2.5,
                              children: [
                                _ContactFieldTile(
                                  icon: Iconsax.call,
                                  label: 'Primary Phone',
                                  value: phone,
                                  fieldName: 'phone_no',
                                  pendingRequests: _myChangeRequests,
                                  onRequest: (f, v) => _submitContactChange(f, v),
                                ),
                                _ContactFieldTile(
                                  icon: Iconsax.sms,
                                  label: 'Personal Email',
                                  value: personalEmail,
                                  fieldName: 'personal_email',
                                  pendingRequests: _myChangeRequests,
                                  onRequest: (f, v) => _submitContactChange(f, v),
                                ),
                                _ContactFieldTile(
                                  icon: Iconsax.call_slash,
                                  label: 'Emergency Phone',
                                  value: emergencyPhone,
                                  fieldName: 'emergency_phone_number',
                                  pendingRequests: _myChangeRequests,
                                  onRequest: (f, v) => _submitContactChange(f, v),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Statutory & Personal Information ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Iconsax.user_octagon, color: AppColors.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Personal & Statutory Information',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, c) {
                            final cols = c.maxWidth < 600 ? 1 : 3;
                            return GridView.count(
                              crossAxisCount: cols,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              childAspectRatio: cols == 1 ? 4.5 : 2.5,
                              children: [
                                _buildInfoTile(Iconsax.user, "Father's Name", fatherName),
                                _buildInfoTile(Iconsax.calendar_1, 'Date of Birth (B.S.)', dob),
                                _buildInfoTile(
                                  Iconsax.location,
                                  'Permanent Address',
                                  addressDisplay,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Account Actions (Logout) ─────────────────────────────────
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _confirmLogout,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Iconsax.logout, color: AppColors.error, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign Out of EMS',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Safely terminate your current active session',
                                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.error.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Iconsax.logout, size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'Log Out',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  ),
);
}
}

// ─── Contact Field Tile (With Inline Request Change Modal) ──────────────────────
class _ContactFieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String fieldName;
  final List pendingRequests;
  final void Function(String fieldName, String newValue) onRequest;

  const _ContactFieldTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.fieldName,
    required this.pendingRequests,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final pending = pendingRequests.where((r) =>
        r['field_name'] == fieldName && r['status'] == 'pending').toList();
    final hasPending = pending.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasPending ? AppColors.warning.withValues(alpha: 0.5) : context.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'Not set',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (hasPending) ...[
                  const SizedBox(height: 2),
                  Text(
                    '⏳ Pending: ${pending.first['new_value']}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.edit_2, size: 15, color: AppColors.primary),
            tooltip: 'Request $label Update',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              final ctrl = TextEditingController(
                  text: value == 'Not provided' || value == 'Not set' ? '' : value);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                constraints: const BoxConstraints(maxWidth: 500),
                backgroundColor: context.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (ctx) => Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Request $label Update',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Iconsax.close_circle, size: 20),
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Updates to statutory contact details require HR verification before becoming active.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          labelText: 'New $label',
                          hintText: 'Enter new contact value',
                          prefixIcon: Icon(icon, size: 18),
                        ),
                        keyboardType: fieldName == 'personal_email'
                            ? TextInputType.emailAddress
                            : TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () {
                            if (ctrl.text.trim().isEmpty) return;
                            Navigator.pop(ctx);
                            onRequest(fieldName, ctrl.text.trim());
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Iconsax.send_1, size: 16, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Submit Change Request',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
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
          ),
        ],
      ),
    );
  }
}

// ─── Edit Profile Name Modal ──────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final String firstName, lastName;
  final VoidCallback onSuccess;
  const _EditProfileSheet({
    required this.firstName,
    required this.lastName,
    required this.onSuccess,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _firstName, _lastName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _firstName = widget.firstName;
    _lastName = widget.lastName;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _isLoading = true);
    try {
      await ApiService().patch(
        AppConstants.meEndpoint,
        data: {'first_name': _firstName.trim(), 'last_name': _lastName.trim()},
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Display name updated successfully!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.user_edit, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Edit Display Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.close_circle, size: 20),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _firstName,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      prefixIcon: Icon(Iconsax.user, size: 18),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onSaved: (v) => _firstName = v ?? '',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _lastName,
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      prefixIcon: Icon(Iconsax.user, size: 18),
                    ),
                    onSaved: (v) => _lastName = v ?? '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save Name Changes',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Change Password Modal ────────────────────────────────────────────────────
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  String _oldPwd = '', _newPwd = '', _confirmPwd = '';
  bool _isLoading = false;
  bool _obscureOld = true, _obscureNew = true, _obscureConfirm = true;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    if (_newPwd != _confirmPwd) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Iconsax.warning_2, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('New passwords do not match'),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ApiService().post(
        '/api/auth/change-password/',
        data: {'old_password': _oldPwd, 'new_password': _newPwd},
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text('Password changed securely!'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${ApiService.getErrorMessage(e)}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.key, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Update Account Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Iconsax.close_circle, size: 20),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: _obscureOld,
              decoration: InputDecoration(
                labelText: 'Current Password *',
                prefixIcon: const Icon(Iconsax.lock, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureOld ? Iconsax.eye_slash : Iconsax.eye, size: 18),
                  onPressed: () => setState(() => _obscureOld = !_obscureOld),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Current password is required' : null,
              onSaved: (v) => _oldPwd = v ?? '',
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password *',
                hintText: 'Min 6 characters',
                prefixIcon: const Icon(Iconsax.lock_1, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Iconsax.eye_slash : Iconsax.eye, size: 18),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters required' : null,
              onSaved: (v) => _newPwd = v ?? '',
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password *',
                prefixIcon: const Icon(Iconsax.lock_circle, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Iconsax.eye_slash : Iconsax.eye, size: 18),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Please confirm your password' : null,
              onSaved: (v) => _confirmPwd = v ?? '',
            ),
            const SizedBox(height: 22),
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Change Password',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
