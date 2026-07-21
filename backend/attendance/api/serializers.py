from rest_framework import serializers

from organization.models import Employee
from attendance.models import CheckInOut, Attendance, RemoteWorkPermission


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
        fields = ['id', 'date', 'employee',
                  'check_ins_outs', 'total_working_hours']

    def get_total_working_hours(self, obj):
        return obj.total_working_hours


class RemoteWorkPermissionSerializer(serializers.ModelSerializer):
    class Meta:
        model = RemoteWorkPermission
        fields = '__all__'
