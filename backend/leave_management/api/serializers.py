from rest_framework import serializers

from leave_management.models import LeaveBalance, LeaveRequest, LeaveType
from organization.api.serializers import EmployeeSerializer


class LeaveTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaveType
        fields = ['id', 'name', 'quota']


class LeaveBalanceSerializer(serializers.ModelSerializer):
    leave_type = LeaveTypeSerializer()

    class Meta:
        model = LeaveBalance
        fields = ['id', 'leave_type', 'quota', 'leaves_taken']


class EmployeeLeaveBalanceSerializer(serializers.Serializer):
    employee = EmployeeSerializer()
    leave_balances = LeaveBalanceSerializer(many=True)


class LeaveRequestSerializer(serializers.ModelSerializer):
    no_days = serializers.ReadOnlyField()
    employee = serializers.PrimaryKeyRelatedField(read_only=True)
    organization = serializers.PrimaryKeyRelatedField(read_only=True)

    class Meta:
        model = LeaveRequest
        fields = [
            'id', 'created_at', 'no_days',
            'from_date', 'till_date', 'subject',
            'is_approved', 'is_reviewed', 'is_paid',
            'remarks', 'employee', 'organization',
            'is_half_day', 'half_day_period',
        ]
        read_only_fields = ['id', 'created_at', 'no_days']
        extra_kwargs = {
            'remarks': {'required': False, 'allow_blank': True, 'default': ''},
        }

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        if instance.employee and getattr(instance.employee, 'user', None):
            rep['employee_name'] = instance.employee.user.full_name
        else:
            rep['employee_name'] = 'Unknown Employee'
        return rep

