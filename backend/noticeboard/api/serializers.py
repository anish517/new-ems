from rest_framework import serializers

from noticeboard.models import Notice, CompanyPolicy, PolicyApproval


class NoticeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notice
        fields = '__all__'


class CompanyPolicySerializer(serializers.ModelSerializer):
    created_by_name = serializers.SerializerMethodField()

    class Meta:
        model = CompanyPolicy
        fields = [
            'id', 'organization', 'title', 'content', 'category',
            'is_active', 'created_by', 'created_by_name',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['organization', 'created_by', 'created_at', 'updated_at']

    def get_created_by_name(self, obj):
        if obj.created_by:
            return getattr(obj.created_by, 'full_name', None) or obj.created_by.email
        return None


class PolicyApprovalSerializer(serializers.ModelSerializer):
    user_email = serializers.ReadOnlyField(source='user.email')
    user_name = serializers.SerializerMethodField()
    employee_name = serializers.SerializerMethodField()

    class Meta:
        model = PolicyApproval
        fields = [
            'id', 'user', 'user_email', 'user_name', 'employee', 'employee_name',
            'is_approved', 'approved_at', 'device_name', 'os', 'browser', 'ip_address',
        ]
        read_only_fields = ['id', 'user', 'approved_at']

    def get_user_name(self, obj):
        return getattr(obj.user, 'full_name', None) or f"{obj.user.first_name} {obj.user.last_name}".strip() or obj.user.email

    def get_employee_name(self, obj):
        if obj.employee and obj.employee.user:
            return getattr(obj.employee.user, 'full_name', None) or f"{obj.employee.user.first_name} {obj.employee.user.last_name}".strip()
        return None