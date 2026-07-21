from rest_framework import serializers
from performance.models import PerformanceReview


class PerformanceReviewSerializer(serializers.ModelSerializer):
    reviewer_name = serializers.SerializerMethodField()
    employee_name = serializers.SerializerMethodField()

    class Meta:
        model = PerformanceReview
        fields = ['id', 'employee', 'reviewer', 'reviewer_name', 'employee_name',
                  'score', 'feedback', 'suggestion', 'reply', 'replied_at', 'created_at']
        read_only_fields = ['id', 'reviewer', 'replied_at', 'created_at']

    def get_reviewer_name(self, obj):
        if obj.reviewer:
            return f'{obj.reviewer.first_name} {obj.reviewer.last_name}'.strip() or obj.reviewer.email
        return 'Admin'

    def get_employee_name(self, obj):
        if obj.employee and obj.employee.user:
            return obj.employee.user.full_name
        return 'Unknown'
