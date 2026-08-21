from rest_framework import serializers
from performance.models import PerformanceReview, PerformanceCategory


class PerformanceCategorySerializer(serializers.ModelSerializer):
    reviews_count = serializers.SerializerMethodField()

    class Meta:
        model = PerformanceCategory
        fields = ['id', 'name', 'created_at', 'reviews_count']
        read_only_fields = ['id', 'created_at']

    def get_reviews_count(self, obj):
        try:
            return obj.reviews.filter(is_deleted=False).count()
        except Exception:
            return 0



class PerformanceReviewSerializer(serializers.ModelSerializer):
    reviewer_name = serializers.SerializerMethodField()
    employee_name = serializers.SerializerMethodField()
    category_name = serializers.SerializerMethodField()

    class Meta:
        model = PerformanceReview
        fields = ['id', 'employee', 'reviewer', 'reviewer_name', 'employee_name',
                  'category', 'category_name',
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
        
    def get_category_name(self, obj):
        if obj.category:
            return obj.category.name
        return None
