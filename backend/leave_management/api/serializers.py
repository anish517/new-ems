from rest_framework import serializers

from leave_management.models import LeaveBalance, LeaveRequest, LeaveType
from organization.api.serializers import EmployeeSerializer


class LeaveTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaveType
        fields = ['id', 'name', 'quota', 'is_sick_leave', 'is_casual_leave']


class LeaveBalanceSerializer(serializers.ModelSerializer):
    leave_type = LeaveTypeSerializer()
    leaves_taken = serializers.SerializerMethodField()

    class Meta:
        model = LeaveBalance
        fields = ['id', 'leave_type', 'quota', 'leaves_taken']

    def get_leaves_taken(self, obj):
        if not obj.employee or not obj.leave_type:
            return float(obj.leaves_taken or 0.0)
        approved = LeaveRequest.objects.filter(
            employee=obj.employee,
            type=obj.leave_type,
            is_approved=True,
            is_reviewed=True
        )
        return float(sum(lr.no_days for lr in approved))



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
            'type', 'is_initial_approved', 'initial_approved_by',
            'initial_approved_at', 'rejection_reason', 'document',
        ]
        read_only_fields = ['id', 'created_at', 'no_days', 'initial_approved_by', 'initial_approved_at']
        extra_kwargs = {
            'remarks': {'required': False, 'allow_blank': True, 'default': ''},
            'rejection_reason': {'required': False, 'allow_blank': True, 'default': ''},
            'type': {'required': False, 'allow_null': True},
            'document': {'required': False, 'allow_null': True},
        }

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        if instance.employee and getattr(instance.employee, 'user', None):
            rep['employee_name'] = instance.employee.user.full_name
        else:
            rep['employee_name'] = 'Unknown Employee'
        
        if instance.type:
            rep['leave_type_name'] = instance.type.name
            rep['is_sick_leave'] = instance.type.is_sick_leave
            rep['is_casual_leave'] = instance.type.is_casual_leave
        else:
            rep['leave_type_name'] = 'Paid Leave' if instance.is_paid else 'Unpaid Leave'
            rep['is_sick_leave'] = False
            rep['is_casual_leave'] = False

        if instance.initial_approved_by:
            rep['initial_approved_by_name'] = getattr(instance.initial_approved_by, 'full_name', str(instance.initial_approved_by))
        else:
            rep['initial_approved_by_name'] = None

        if instance.document:
            request = self.context.get('request')
            if request:
                rep['document_url'] = request.build_absolute_uri(instance.document.url)
            else:
                rep['document_url'] = instance.document.url
        else:
            rep['document_url'] = None

        return rep


