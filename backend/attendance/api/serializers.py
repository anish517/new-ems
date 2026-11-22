import nepali_datetime
from rest_framework import serializers

from organization.models import Employee
from attendance.models import CheckInOut, Attendance, RemoteWorkPermission, RemoteWorkRequest, AttendanceCorrectionRequest


class CheckInOutSerializer(serializers.ModelSerializer):
    class Meta:
        model = CheckInOut
        fields = ['id', 'check_in', 'check_out']
        order_by = 'id'


class EmployeeSerializer(serializers.ModelSerializer):
    first_name = serializers.CharField(
        source='user.first_name', read_only=True)
    last_name = serializers.CharField(source='user.last_name', read_only=True)
    email = serializers.CharField(source='user.email', read_only=True)

    class Meta:
        model = Employee
        fields = ['id', 'first_name', 'last_name', 'email']


class AttendanceSerializer(serializers.ModelSerializer):
    check_ins_outs = CheckInOutSerializer(many=True, read_only=True)
    employee = EmployeeSerializer()
    total_working_hours = serializers.SerializerMethodField()

    class Meta:
        model = Attendance
        fields = ['id', 'date', 'employee', 'is_remote',
                  'check_in_lat', 'check_in_lng', 'check_in_photo',
                  'check_out_lat', 'check_out_lng', 'check_out_photo',
                  'check_ins_outs', 'total_working_hours']

    def get_total_working_hours(self, obj):
        return obj.total_working_hours


class RemoteWorkPermissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = RemoteWorkPermission
        fields = '__all__'

class RemoteWorkRequestSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    employee_email = serializers.SerializerMethodField()

    class Meta:
        model = RemoteWorkRequest
        fields = '__all__'
        read_only_fields = ['employee', 'status', 'created_at']

    def get_employee_name(self, obj):
        if not obj.employee:
            return 'Employee'
        if obj.employee.user:
            name = getattr(obj.employee.user, 'full_name', '')
            if name and name.strip():
                return name.strip()
            first = obj.employee.user.first_name or ''
            last = obj.employee.user.last_name or ''
            full = f"{first} {last}".strip()
            if full:
                return full
            return obj.employee.user.email
        return f"Employee #{obj.employee.id}"

    def get_employee_email(self, obj):
        if obj.employee and obj.employee.user:
            return obj.employee.user.email
        return ''


def get_monthly_correction_stats(employee, nepali_year=None, nepali_month=None, org_settings=None):
    from calendar_app.utilities import total_days_in_month
    from organization.models import OrganizationSettings

    today = nepali_datetime.date.today()
    try:
        year = int(nepali_year) if nepali_year is not None else today.year
    except (TypeError, ValueError):
        year = today.year
    try:
        month = int(nepali_month) if nepali_month is not None else today.month
    except (TypeError, ValueError):
        month = today.month
    if not (1 <= month <= 12):
        month = today.month

    if org_settings is None and employee is not None:
        org = getattr(employee, 'organization', None)
        if org:
            org_settings = OrganizationSettings.objects.filter(organization=org).first()

    max_free = getattr(org_settings, 'max_free_corrections_per_month', 2) if org_settings else 2
    penalty_per_extra = float(getattr(org_settings, 'correction_penalty_points', 0.5)) if org_settings else 0.5
    count_rejected = bool(getattr(org_settings, 'count_rejected_corrections', False)) if org_settings else False

    count = 0
    if employee is not None:
        last_day = total_days_in_month(year, month)
        start_bs = nepali_datetime.date(year, month, 1)
        end_bs = nepali_datetime.date(year, month, last_day)
        qs = AttendanceCorrectionRequest.objects.filter(
            employee=employee,
            requested_date__gte=start_bs,
            requested_date__lte=end_bs,
        )
        if not count_rejected:
            qs = qs.exclude(status='rejected')
        count = qs.count()

    will_exceed_on_next = count >= max_free
    exceeds_limit = count > max_free
    excess_count = max(0, count - max_free)
    next_excess_count = max(0, (count + 1) - max_free)
    estimated_penalty = round(excess_count * penalty_per_extra, 2)
    next_estimated_penalty = round(next_excess_count * penalty_per_extra, 2)

    warning_message = None
    if will_exceed_on_next:
        warning_message = (
            f"You have already submitted {count} attendance correction(s) this month "
            f"(free limit: {max_free}). Submitting multiple attendance corrections will decrease your performance score."
        )

    return {
        "nepali_year": year,
        "nepali_month": month,
        "count": count,
        "max_free": max_free,
        "will_exceed_on_next": will_exceed_on_next,
        "exceeds_limit": exceeds_limit,
        "excess_count": excess_count,
        "penalty_per_extra": penalty_per_extra,
        "estimated_penalty": estimated_penalty,
        "next_estimated_penalty": next_estimated_penalty,
        "count_rejected_corrections": count_rejected,
        "warning_message": warning_message,
    }


class AttendanceCorrectionRequestSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    employee_email = serializers.SerializerMethodField()
    employee_id = serializers.IntegerField(source='employee.id', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    reviewed_by_name = serializers.SerializerMethodField()
    requested_date = serializers.CharField()
    monthly_correction_count = serializers.SerializerMethodField()
    max_free_corrections = serializers.SerializerMethodField()
    exceeds_monthly_limit = serializers.SerializerMethodField()
    estimated_penalty = serializers.SerializerMethodField()
    performance_warning = serializers.SerializerMethodField()

    class Meta:
        model = AttendanceCorrectionRequest
        fields = [
            'id', 'employee', 'employee_id', 'employee_name', 'employee_email',
            'requested_date', 'requested_check_in', 'requested_check_out',
            'reason', 'status', 'status_display',
            'admin_note', 'reviewed_by', 'reviewed_by_name',
            'monthly_correction_count', 'max_free_corrections',
            'exceeds_monthly_limit', 'estimated_penalty', 'performance_warning',
            'created_at', 'updated_at',
        ]
        read_only_fields = [
            'employee', 'status', 'admin_note', 'reviewed_by',
            'monthly_correction_count', 'max_free_corrections',
            'exceeds_monthly_limit', 'estimated_penalty', 'performance_warning',
            'created_at', 'updated_at',
        ]

    def _get_obj_monthly_stats(self, obj):
        today = nepali_datetime.date.today()
        y, m = today.year, today.month
        req_date = getattr(obj, 'requested_date', None)
        if isinstance(req_date, nepali_datetime.date):
            y, m = req_date.year, req_date.month
        elif req_date:
            try:
                parts = str(req_date).strip().split('-')
                if len(parts) >= 2:
                    y, m = int(parts[0]), int(parts[1])
            except (TypeError, ValueError):
                pass
        return get_monthly_correction_stats(obj.employee, y, m)

    def get_monthly_correction_count(self, obj):
        return self._get_obj_monthly_stats(obj)["count"]

    def get_max_free_corrections(self, obj):
        return self._get_obj_monthly_stats(obj)["max_free"]

    def get_exceeds_monthly_limit(self, obj):
        return self._get_obj_monthly_stats(obj)["exceeds_limit"]

    def get_estimated_penalty(self, obj):
        return self._get_obj_monthly_stats(obj)["estimated_penalty"]

    def get_performance_warning(self, obj):
        stats = self._get_obj_monthly_stats(obj)
        if stats["exceeds_limit"]:
            return (
                f"Multiple attendance corrections ({stats['count']}/{stats['max_free']} free this month). "
                "Excessive corrections decrease performance score."
            )
        return None

    def get_employee_name(self, obj):
        if not obj.employee:
            return 'Employee'
        if obj.employee.user:
            name = getattr(obj.employee.user, 'full_name', '')
            if name and name.strip():
                return name.strip()
            first = obj.employee.user.first_name or ''
            last = obj.employee.user.last_name or ''
            full = f"{first} {last}".strip()
            if full:
                return full
            return obj.employee.user.email
        return f"Employee #{obj.employee.id}"

    def get_employee_email(self, obj):
        if obj.employee and obj.employee.user:
            return obj.employee.user.email
        return ''

    def get_reviewed_by_name(self, obj):
        if obj.reviewed_by:
            name = getattr(obj.reviewed_by, 'full_name', '')
            if name and name.strip():
                return name.strip()
            return obj.reviewed_by.email
        return None

    def validate_requested_date(self, value):
        if isinstance(value, nepali_datetime.date):
            parsed_date = value
        else:
            raw = str(value).strip()
            parts = raw.split('-')
            if len(parts) != 3:
                raise serializers.ValidationError('Invalid Nepali date format. Expected YYYY-MM-DD.')
            try:
                y, m, d = map(int, parts)
                parsed_date = nepali_datetime.date(y, m, d)
            except (TypeError, ValueError):
                raise serializers.ValidationError('Invalid Nepali date. Please provide a valid B.S. date (YYYY-MM-DD).')

        today = nepali_datetime.date.today()
        if parsed_date > today:
            raise serializers.ValidationError('Attendance correction cannot be requested for a future date.')

        return str(parsed_date)

    def validate(self, attrs):
        cin = attrs.get('requested_check_in')
        cout = attrs.get('requested_check_out')
        if cin and cout and cout < cin and cout.hour < 12 and cin.hour >= 8:
            import datetime as _dt
            attrs['requested_check_out'] = _dt.time(cout.hour + 12, cout.minute, cout.second)
        return attrs


