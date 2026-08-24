from rest_framework import serializers

from leave_management.models import LeaveBalance, LeaveRequest, LeaveType, LeaveSetting
from organization.api.serializers import EmployeeSerializer


class LeaveSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaveSetting
        fields = ['id', 'organization', 'paid_leave_during_provision', 'allow_intern_leave']


class LeaveTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = LeaveType
        fields = ['id', 'name', 'quota', 'is_sick_leave', 'is_casual_leave']


class LeaveBalanceSerializer(serializers.ModelSerializer):
    leave_type = LeaveTypeSerializer()
    leaves_taken = serializers.SerializerMethodField()
    accrued_to_date = serializers.SerializerMethodField()
    available_this_month = serializers.SerializerMethodField()
    paid_taken = serializers.SerializerMethodField()
    unpaid_taken = serializers.SerializerMethodField()
    half_day_count = serializers.SerializerMethodField()
    half_day_days = serializers.SerializerMethodField()
    remaining_annual = serializers.SerializerMethodField()

    class Meta:
        model = LeaveBalance
        fields = [
            'id', 'leave_type', 'quota', 'leaves_taken',
            'accrued_to_date', 'available_this_month',
            'paid_taken', 'unpaid_taken',
            'half_day_count', 'half_day_days',
            'remaining_annual',
        ]

    def _get_metrics(self, obj):
        if not hasattr(obj, '_cached_metrics'):
            import nepali_datetime
            request = self.context.get('request')
            today = nepali_datetime.date.today()
            ny = int(request.GET.get('nepali_year', today.year)) if request else today.year
            nm = int(request.GET.get('nepali_month', today.month)) if request else today.month

            annual_quota = float(obj.quota or 0.0)
            monthly_rate = annual_quota / 12.0
            accrued_to_date = min(annual_quota, round(monthly_rate * nm, 2))

            approved = LeaveRequest.objects.filter(
                employee=obj.employee,
                is_approved=True,
                is_reviewed=True,
            )
            year_approved = [
                lr for lr in approved
                if lr.from_date and getattr(lr.from_date, 'year', None) == ny
                and (lr.type_id == obj.leave_type_id or (lr.type is None and obj.leave_type and ('casual' in obj.leave_type.name.lower() or 'paid' in obj.leave_type.name.lower())))
            ]

            paid_taken = float(sum(lr.no_days for lr in year_approved if lr.is_paid))
            unpaid_taken = float(sum(lr.no_days for lr in year_approved if not lr.is_paid))
            half_day_reqs = [lr for lr in year_approved if lr.is_half_day]
            half_day_count = len(half_day_reqs)
            half_day_days = float(sum(lr.no_days for lr in half_day_reqs))
            available_this_month = max(0.0, round(accrued_to_date - paid_taken, 2))
            remaining_annual = max(0.0, round(annual_quota - paid_taken, 2))

            obj._cached_metrics = {
                'leaves_taken': paid_taken,
                'accrued_to_date': accrued_to_date,
                'available_this_month': available_this_month,
                'paid_taken': paid_taken,
                'unpaid_taken': unpaid_taken,
                'half_day_count': half_day_count,
                'half_day_days': half_day_days,
                'remaining_annual': remaining_annual,
            }
        return obj._cached_metrics

    def get_leaves_taken(self, obj):
        return self._get_metrics(obj)['leaves_taken']

    def get_accrued_to_date(self, obj):
        return self._get_metrics(obj)['accrued_to_date']

    def get_available_this_month(self, obj):
        return self._get_metrics(obj)['available_this_month']

    def get_paid_taken(self, obj):
        return self._get_metrics(obj)['paid_taken']

    def get_unpaid_taken(self, obj):
        return self._get_metrics(obj)['unpaid_taken']

    def get_half_day_count(self, obj):
        return self._get_metrics(obj)['half_day_count']

    def get_half_day_days(self, obj):
        return self._get_metrics(obj)['half_day_days']

    def get_remaining_annual(self, obj):
        return self._get_metrics(obj)['remaining_annual']



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


