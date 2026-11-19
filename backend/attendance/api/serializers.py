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


class AttendanceCorrectionRequestSerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()
    employee_email = serializers.SerializerMethodField()
    employee_id = serializers.IntegerField(source='employee.id', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    reviewed_by_name = serializers.SerializerMethodField()
    requested_date = serializers.CharField()

    class Meta:
        model = AttendanceCorrectionRequest
        fields = [
            'id', 'employee', 'employee_id', 'employee_name', 'employee_email',
            'requested_date', 'requested_check_in', 'requested_check_out',
            'reason', 'status', 'status_display',
            'admin_note', 'reviewed_by', 'reviewed_by_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['employee', 'status', 'admin_note', 'reviewed_by', 'created_at', 'updated_at']

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


