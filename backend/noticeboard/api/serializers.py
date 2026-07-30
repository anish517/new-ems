from rest_framework import serializers

from noticeboard.models import Notice, CompanyPolicy


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
            return obj.created_by.full_name or obj.created_by.email
        return None