class UserProfile {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? profilePicture;
  final bool isStaff;
  final bool isSuperuser;
  final String role; // 'super_admin' | 'org_admin' | 'hr' | 'performance_reviewer' | 'employee'
  final int? employeeId;
  final int? organizationId;
  final bool hasApprovedPolicy;
  final String? employeeType;
  final bool isInProvision;
  final bool isPerformanceReviewer;
  final List<int> performanceCategoryIds;

  const UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.profilePicture,
    required this.isStaff,
    required this.isSuperuser,
    required this.role,
    this.employeeId,
    this.organizationId,
    this.hasApprovedPolicy = true,
    this.employeeType,
    this.isInProvision = false,
    this.isPerformanceReviewer = false,
    this.performanceCategoryIds = const [],
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as int,
        email: json['email'] as String,
        firstName: json['first_name'] as String,
        lastName: json['last_name'] as String,
        fullName: json['full_name'] as String? ??
            '${json['first_name']} ${json['last_name']}',
        profilePicture: json['profile_picture'] as String?,
        isStaff: json['is_staff'] as bool? ?? false,
        isSuperuser: json['is_superuser'] as bool? ?? false,
        role: json['role'] as String? ?? 'employee',
        employeeId: json['employee_id'] as int?,
        organizationId: json['organization_id'] as int?,
        hasApprovedPolicy: json['has_approved_policy'] as bool? ?? true,
        employeeType: json['employee_type'] as String?,
        isInProvision: json['is_in_provision'] as bool? ?? false,
        isPerformanceReviewer:
            json['is_performance_reviewer'] as bool? ?? false,
        performanceCategoryIds: (json['performance_category_ids'] as List?)
                ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
                .where((id) => id > 0)
                .toList() ??
            const [],
      );

  bool get isOrgAdmin => role == 'org_admin' || role == 'admin';
  bool get isSuperAdmin => role == 'super_admin' || isSuperuser;
  bool get isHr => role == 'hr';
  bool get isPerformanceReviewerRole =>
      role == 'performance_reviewer' || isPerformanceReviewer;
  bool get canManage =>
      isOrgAdmin || isSuperAdmin || isHr || isStaff || isSuperuser;
  bool get isEmployee =>
      role == 'employee' && !canManage && !isPerformanceReviewerRole;
}
