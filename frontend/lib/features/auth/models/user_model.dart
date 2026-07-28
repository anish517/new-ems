class UserProfile {
  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String fullName;
  final String? profilePicture;
  final bool isStaff;
  final bool isSuperuser;
  final String role;        // 'super_admin' | 'org_admin' | 'hr' | 'employee'
  final int? employeeId;
  final int? organizationId;

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
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id:             json['id']             as int,
    email:          json['email']          as String,
    firstName:      json['first_name']     as String,
    lastName:       json['last_name']      as String,
    fullName:       json['full_name']      as String? ?? '${json['first_name']} ${json['last_name']}',
    profilePicture: json['profile_picture'] as String?,
    isStaff:        json['is_staff']       as bool? ?? false,
    isSuperuser:    json['is_superuser']   as bool? ?? false,
    role:           json['role']           as String? ?? 'employee',
    employeeId:     json['employee_id']    as int?,
    organizationId: json['organization_id'] as int?,
  );

  bool get isOrgAdmin   => role == 'org_admin';
  bool get isSuperAdmin => role == 'super_admin';
  bool get isHr         => role == 'hr';
  bool get isEmployee   => role == 'employee';
  bool get canManage    => isOrgAdmin || isSuperAdmin || isHr;
}




