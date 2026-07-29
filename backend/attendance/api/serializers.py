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
    employee_name = serializers.CharField(source='employee.user.full_name', read_only=True)

    class Meta:
        model = RemoteWorkRequest
        fields = '__all__'
        read_only_fields = ['employee', 'status', 'created_at']


class AttendanceCorrectionRequestSerializer(serializers.ModelSerializer):
    employee_name = serializers.CharField(source='employee.user.full_name', read_only=True)
    employee_id = serializers.IntegerField(source='employee.id', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)
    reviewed_by_name = serializers.SerializerMethodField()

    class Meta:
        model = AttendanceCorrectionRequest
        fields = [
            'id', 'employee', 'employee_id', 'employee_name',
            'requested_date', 'requested_check_in', 'requested_check_out',
            'reason', 'status', 'status_display',
            'admin_note', 'reviewed_by', 'reviewed_by_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['employee', 'status', 'admin_note', 'reviewed_by', 'created_at', 'updated_at']

    def get_reviewed_by_name(self, obj):
        if obj.reviewed_by:
            return obj.reviewed_by.get_full_name() or obj.reviewed_by.email
        return None

