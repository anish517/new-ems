import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:nepali_utils/nepali_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/api_service.dart';
import '../../auth/providers/auth_provider.dart';

class PolicyApprovalScreen extends ConsumerStatefulWidget {
  const PolicyApprovalScreen({super.key});

  @override
  ConsumerState<PolicyApprovalScreen> createState() => _PolicyApprovalScreenState();
}

class _PolicyApprovalScreenState extends ConsumerState<PolicyApprovalScreen> {
  List<dynamic> _policies = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _agreed = false;
  String _deviceSummary = '';
  String _osName = '';
  String _browserName = '';

  @override
  void initState() {
    super.initState();
    _detectDevice();
    _loadPolicies();
  }

  void _detectDevice() {
    if (kIsWeb) {
      _osName = 'Web';
      _browserName = 'Web Browser';
      _deviceSummary = 'Web Browser';
    } else {
      try {
        if (Platform.isWindows) {
          _osName = 'Windows';
          _deviceSummary = 'Windows Desktop';
        } else if (Platform.isAndroid) {
          _osName = 'Android';
          _deviceSummary = 'Android Device';
        } else if (Platform.isIOS) {
          _osName = 'iOS';
          _deviceSummary = 'iOS Device';
        } else if (Platform.isMacOS) {
          _osName = 'macOS';
          _deviceSummary = 'Mac Desktop';
        } else if (Platform.isLinux) {
          _osName = 'Linux';
          _deviceSummary = 'Linux Workstation';
        } else {
          _osName = 'Unknown Platform';
          _deviceSummary = 'Workstation';
        }
      } catch (_) {
        _osName = 'Client Device';
        _deviceSummary = 'Workstation';
      }
    }
  }

  Future<void> _loadPolicies() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService().get('/api/noticeboard/policies/');
      if (mounted) {
        setState(() {
          _policies = res.data is List ? res.data as List : ((res.data['results'] ?? []) as List);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitApproval() async {
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check the agreement box confirming you have read and agree to the policies.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ApiService().post(
        '/api/noticeboard/policies/approve/',
        data: {
          'device_name': _deviceSummary,
          'os': _osName,
          'browser': _browserName,
        },
      );

      // Refresh the user auth state so router knows policy is approved
      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company policy accepted. Welcome to your workspace!'),
          backgroundColor: AppColors.success,
        ),
      );

      // Redirect to dashboard
      context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiService.getErrorMessage(e)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isTight = MediaQuery.of(context).size.width < 700;
    final currentUser = ref.watch(currentUserProvider);

    final nowGregorian = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.now());
    String nowNepali = '';
    try {
      nowNepali = NepaliDateFormat('dd MMMM yyyy, hh:mm a').format(NepaliDateTime.now());
    } catch (_) {
      nowNepali = nowGregorian;
    }

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTight ? 16 : 28,
                vertical: isTight ? 18 : 28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Top Corporate Banner ──────────────────────────────────
                  Container(
                    padding: EdgeInsets.all(isTight ? 18 : 24),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Iconsax.shield_tick, color: AppColors.primary, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Company Policy & Code of Conduct',
                                    style: TextStyle(
                                      fontSize: isTight ? 18 : 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Mandatory Employee Agreement & Onboarding Acknowledgment',
                                    style: TextStyle(
                                      fontSize: isTight ? 11.5 : 12.5,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Iconsax.info_circle, color: Color(0xFFF59E0B), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Welcome ${currentUser?.fullName ?? 'Team Member'}! Please read and acknowledge our workplace policies to unlock your dashboard and workspace.',
                                  style: TextStyle(
                                    fontSize: isTight ? 12 : 12.5,
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Policy Clauses Content ────────────────────────────────
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    )
                  else if (_policies.isEmpty)
                    _buildDefaultPoliciesCard(context)
                  else
                    ..._policies.map((p) => _buildPolicyItemCard(context, p, isTight)),

                  const SizedBox(height: 20),

                  // ── Audit Verification & Agreement Card ───────────────────
                  Container(
                    padding: EdgeInsets.all(isTight ? 16 : 22),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.border, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Iconsax.finger_scan, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Acknowledgment & Digital Audit Record',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'In accordance with our digital compliance rules, your approval date, timestamp, and device fingerprint will be securely recorded in the company audit log.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),

                        // Device & Timestamp Pills
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _buildInfoPill(
                              icon: Iconsax.monitor,
                              label: 'Device',
                              value: _deviceSummary,
                              context: context,
                            ),
                            _buildInfoPill(
                              icon: Iconsax.calendar_1,
                              label: 'Date & Time',
                              value: nowNepali.isNotEmpty ? nowNepali : nowGregorian,
                              context: context,
                            ),
                            _buildInfoPill(
                              icon: Iconsax.user_tick,
                              label: 'Employee',
                              value: currentUser?.fullName ?? currentUser?.email ?? 'Authorized User',
                              context: context,
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 14),

                        // Checkbox Agreement
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => setState(() => _agreed = !_agreed),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _agreed,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    onChanged: (val) => setState(() => _agreed = val ?? false),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        'I confirm that I have read, understood, and formally agree to strictly comply with all stated company policies, workplace standards, confidentiality obligations, and code of conduct.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: context.textPrimary,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Accept & Proceed Button
                        Container(
                          height: 52,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: _agreed
                                ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark])
                                : null,
                            color: _agreed ? null : AppColors.textSecondary.withValues(alpha: 0.2),
                          ),
                          child: ElevatedButton(
                            onPressed: (_isSubmitting || !_agreed) ? null : _submitApproval,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Iconsax.tick_circle, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Accept & Proceed to Dashboard',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String label,
    required String value,
    required BuildContext context,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyItemCard(BuildContext context, Map policy, bool isTight) {
    final title = policy['title'] ?? 'Policy Clause';
    final category = policy['category'] ?? 'General Policy';
    final rawContent = policy['content'] ?? '';
    final cleanContent = rawContent.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.all(isTight ? 16 : 20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Icon(Iconsax.verify, color: AppColors.success, size: 18),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cleanContent.isNotEmpty ? cleanContent : 'Please adhere to all guidelines stated under this corporate clause.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultPoliciesCard(BuildContext context) {
    return Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Standard Corporate Guidelines',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'General Code of Conduct & Operational Integrity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary),
          ),
          const SizedBox(height: 10),
          const Text(
            '1. Professional Conduct: All employees are expected to maintain the highest standards of integrity, respect, and professionalism in all communications and duties.\n\n'
            '2. Data Protection & Confidentiality: Company proprietary code, customer records, and internal assets must remain strictly confidential and protected.\n\n'
            '3. Attendance & Punctuality: Employees must accurately log attendance, request leaves in advance, and notify managers of any unexpected schedule delays.\n\n'
            '4. Equal Opportunity: We are committed to a safe, inclusive, and harassment-free work environment for everyone.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
