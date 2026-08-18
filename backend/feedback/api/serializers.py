from rest_framework import serializers
from feedback.models import Complain, ComplainReply, ComplainCategory


class ComplainCategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = ComplainCategory
        fields = ['id', 'title', 'created_at', 'updated_at']


class ComplainReplySerializer(serializers.ModelSerializer):
    employee_name = serializers.SerializerMethodField()

    class Meta:
        model = ComplainReply
        fields = ['id', 'employee', 'employee_name', 'content', 'created_at', 'updated_at']
        read_only_fields = ['employee', 'created_at', 'updated_at']

    def get_employee_name(self, obj):
        return obj.employee.user.full_name if obj.employee else 'Administration'


class ComplainSerializer(serializers.ModelSerializer):
    replies = ComplainReplySerializer(many=True, read_only=True)
    category_name = serializers.SerializerMethodField()
    owner_name = serializers.SerializerMethodField()

    class Meta:
        model = Complain
        fields = ['id', 'title', 'category', 'category_name', 'description',
                  'visibility', 'status', 'owner', 'owner_name',
                  'created_at', 'updated_at', 'replies']
        read_only_fields = ['owner', 'created_at', 'updated_at']

    def get_category_name(self, obj):
        return obj.category.title if obj.category else None

    def get_owner_name(self, obj):
        if obj.visibility == 'anonymous':
            return 'Anonymous'
        return obj.owner.user.full_name if obj.owner else None
