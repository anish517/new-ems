import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/providers/auth_provider.dart';

import 'dart:convert';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isUploading = false;
  List _myChangeRequests = [];

  @override
  void initState() {
    super.initState();
    _loadChangeRequests();
  }

  Future<void> _loadChangeRequests() async {
    final user = ref.read(currentUserProvider);
    if (user?.canManage == true) return; // admins don't need this
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
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image == null) return;
      
      setState(() => _isUploading = true);
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Send to backend
      final ext = image.name.split('.').last.toLowerCase();
      final dataUri = 'data:image/$ext;base64,$base64Image';
      
      await ApiService().patch('/api/auth/me/', data: {'profile_picture': dataUri});
      
      // Refresh user
      await ref.read(authProvider.notifier).refreshUser();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile picture updated successfully!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update picture: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Avatar
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  backgroundImage: user?.profilePicture != null
                      ? NetworkImage(user!.profilePicture!)
                      : null,
                  child: user?.profilePicture == null
                      ? Text(
                          user?.firstName[0].toUpperCase() ?? 'U',
                          style: const TextStyle(
                              fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                if (_isUploading)
                  const CircularProgressIndicator(color: Colors.white),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(user?.fullName ?? '—',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(user?.email ?? '—',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              user?.role.replaceAll('_', ' ').toUpperCase() ?? '',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),

          // Actions
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Iconsax.user),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showEditProfile(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Iconsax.lock),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showChangePassword(context),
              ),
            ]),
          ),

          // Employee-only: Request contact field changes
          if (!(user?.canManage ?? true)) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Contact Information',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: context.textPrimary)),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(children: [
                _ContactFieldTile(
                  icon: Iconsax.call,
                  label: 'Phone Number',
                  fieldName: 'phone_no',
                  pendingRequests: _myChangeRequests,
                  onRequest: (fieldName, newValue) => _submitContactChange(
                      fieldName, newValue),
                ),
                const Divider(height: 1),
                _ContactFieldTile(
                  icon: Iconsax.sms,
                  label: 'Personal Email',
                  fieldName: 'personal_email',
                  pendingRequests: _myChangeRequests,
                  onRequest: (fieldName, newValue) => _submitContactChange(
                      fieldName, newValue),
                ),
                const Divider(height: 1),
                _ContactFieldTile(
                  icon: Icons.emergency_outlined,
                  label: 'Emergency Contact',
                  fieldName: 'emergency_phone_number',
                  pendingRequests: _myChangeRequests,
                  onRequest: (fieldName, newValue) => _submitContactChange(
                      fieldName, newValue),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Changes require admin approval before taking effect.',
                style: TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
          ],

          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Iconsax.logout, color: AppColors.error),
              title: const Text('Logout',
                  style: TextStyle(color: AppColors.error)),
              onTap: () => _confirmLogout(context, ref),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _submitContactChange(String fieldName, String newValue) async {
    try {
      await ApiService().post(
        '/api/organization/profile-change-requests/',
        data: {'field_name': fieldName, 'new_value': newValue},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Change request submitted! Pending admin approval.'),
          backgroundColor: AppColors.success,
        ));
        _loadChangeRequests();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _showEditProfile(BuildContext ctx, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _EditProfileSheet(
        firstName: user?.firstName ?? '',
        lastName: user?.lastName ?? '',
        onSuccess: () => ref.read(authProvider.notifier).refreshUser(),
      ),
    );
  }

  void _showChangePassword(BuildContext ctx) => showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        constraints: const BoxConstraints(maxWidth: 600),
        backgroundColor: context.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => const _ChangePasswordSheet(),
      );

  void _confirmLogout(BuildContext ctx, WidgetRef ref) => showDialog(
        context: ctx,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Future.delayed(const Duration(milliseconds: 300), () {
                  ref.read(authProvider.notifier).logout();
                });
              },
              child: const Text('Logout',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      );
}

// ─── Edit Profile Sheet ───────────────────────────────────────────────────────
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
        data: {'first_name': _firstName, 'last_name': _lastName},
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Profile updated!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Edit Profile',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: TextFormField(
                initialValue: _firstName,
                decoration: const InputDecoration(labelText: 'First Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _firstName = v!,
              )),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(
                initialValue: _lastName,
                decoration: const InputDecoration(labelText: 'Last Name'),
                onSaved: (v) => _lastName = v ?? '',
              )),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ]),
        ),
      );
}

// ─── Change Password Sheet ────────────────────────────────────────────────────
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('New passwords do not match'),
        backgroundColor: AppColors.error,
      ));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Password changed successfully!'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${ApiService.getErrorMessage(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Change Password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextFormField(
              obscureText: _obscureOld,
              decoration: InputDecoration(
                labelText: 'Current Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureOld ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureOld = !_obscureOld),
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _oldPwd = v!,
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
              onSaved: (v) => _newPwd = v!,
            ),
            const SizedBox(height: 12),
            TextFormField(
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _confirmPwd = v!,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Change Password'),
            ),
          ]),
        ),
      );
}


// ─── Contact Field Tile (Employee self-edit) ──────────────────────────────────
class _ContactFieldTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String fieldName;
  final List pendingRequests;
  final void Function(String fieldName, String newValue) onRequest;

  const _ContactFieldTile({
    required this.icon,
    required this.label,
    required this.fieldName,
    required this.pendingRequests,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final pending = pendingRequests.where((r) =>
        r['field_name'] == fieldName && r['status'] == 'pending').toList();
    final hasPending = pending.isNotEmpty;

    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(label),
      subtitle: hasPending
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '⏳ Change pending: ${pending.first['new_value']}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.warning),
                  ),
                ),
              ],
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Iconsax.edit, size: 18, color: AppColors.primary),
        tooltip: 'Request change',
        onPressed: hasPending
            ? null
            : () {
                final ctrl = TextEditingController();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  constraints: const BoxConstraints(maxWidth: 600),
                  shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (ctx) => Padding(
                    padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        MediaQuery.of(ctx).viewInsets.bottom + 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Update $label',
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text(
                            'This change will be pending admin approval before it takes effect.',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: ctrl,
                          decoration: InputDecoration(
                            labelText: 'New $label',
                            prefixIcon: Icon(icon),
                          ),
                          keyboardType: fieldName == 'personal_email'
                              ? TextInputType.emailAddress
                              : TextInputType.text,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Iconsax.send_1),
                            label: const Text('Submit Request'),
                            onPressed: () {
                              if (ctrl.text.trim().isEmpty) return;
                              Navigator.pop(ctx);
                              onRequest(fieldName, ctrl.text.trim());
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
      ),
    );
  }
}





