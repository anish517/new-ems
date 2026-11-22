from django.db import transaction
from rest_framework import serializers

from authentication.models import Account
from organization.models import Employee
from performance.models import PerformanceReview, PerformanceCategory, PerformanceReviewerAccess


def _can_see_reviewer_identity(request):
    """Admins, HR, and active Performance Reviewers can see reviewer names; Employees cannot."""
    if not request or not getattr(request, 'user', None) or not request.user.is_authenticated:
        return False
    user = request.user
    if user.is_superuser or user.organization.exists() or getattr(user, 'is_hr', False):
        return True
    if getattr(user, 'is_performance_reviewer', False):
        access = getattr(user, 'performance_access', None)
        if access and access.is_active:
            return True
    return False


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

    def validate_score(self, value):
        if value < 1 or value > 10:
            raise serializers.ValidationError('Score must be between 1 and 10.')
        return value

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

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        request = self.context.get('request')
        # Hide reviewer identity from regular employees
        if request is not None and not _can_see_reviewer_identity(request):
            rep['reviewer'] = None
            rep['reviewer_name'] = None
        return rep


class PerformanceReviewerAccessSerializer(serializers.ModelSerializer):
    reviewer_id = serializers.IntegerField(source='reviewer.id', read_only=True)
    email = serializers.EmailField(source='reviewer.email', required=False)
    first_name = serializers.CharField(source='reviewer.first_name', required=False)
    last_name = serializers.CharField(source='reviewer.last_name', required=False)
    full_name = serializers.SerializerMethodField()
    password = serializers.CharField(write_only=True, required=False, allow_blank=True)
    linked_employee_name = serializers.SerializerMethodField()
    categories = serializers.SerializerMethodField()
    category_ids = serializers.ListField(
        child=serializers.IntegerField(), write_only=True, required=False
    )
    reviews_given_count = serializers.SerializerMethodField()

    class Meta:
        model = PerformanceReviewerAccess
        fields = [
            'id', 'reviewer_id', 'email', 'first_name', 'last_name', 'full_name',
            'password', 'linked_employee', 'linked_employee_name',
            'categories', 'category_ids', 'is_active', 'created_at', 'updated_at',
            'reviews_given_count',
        ]
        read_only_fields = ['id', 'reviewer_id', 'created_at', 'updated_at']

    def get_full_name(self, obj):
        return f'{obj.reviewer.first_name} {obj.reviewer.last_name}'.strip() or obj.reviewer.email

    def get_linked_employee_name(self, obj):
        if obj.linked_employee and obj.linked_employee.user:
            return obj.linked_employee.user.full_name
        return None

    def get_categories(self, obj):
        return [{'id': c.id, 'name': c.name} for c in obj.categories.all()]

    def get_reviews_given_count(self, obj):
        return PerformanceReview.objects.filter(reviewer=obj.reviewer, is_deleted=False).count()

    def validate_password(self, value):
        if value and len(value) < 6:
            raise serializers.ValidationError('Password must be at least 6 characters.')
        return value

    def validate_category_ids(self, value):
        org = self.instance.organization if self.instance else self.context.get('organization')
        if org and value:
            valid_ids = set(
                PerformanceCategory.objects.filter(organization=org, id__in=value).values_list('id', flat=True)
            )
            invalid = [cid for cid in value if cid not in valid_ids]
            if invalid:
                raise serializers.ValidationError(
                    f'Categories {invalid} do not belong to this organization.'
                )
        return value

    def validate_linked_employee(self, value):
        if value is None:
            return None
        org = self.instance.organization if self.instance else self.context.get('organization')
        emp_org = value.organization
        if org and emp_org and emp_org.id != org.id:
            raise serializers.ValidationError('Linked employee must belong to this organization.')
        return value

    def update(self, instance, validated_data):
        reviewer_data = validated_data.pop('reviewer', {})
        password = validated_data.pop('password', None)
        category_ids = validated_data.pop('category_ids', None)

        reviewer = instance.reviewer
        reviewer_changed = False

        if 'email' in reviewer_data:
            new_email = reviewer_data['email'].strip().lower()
            if Account.objects.filter(email__iexact=new_email).exclude(pk=reviewer.pk).exists():
                raise serializers.ValidationError({'email': 'An account with this email already exists.'})
            reviewer.email = new_email
            reviewer_changed = True
        if 'first_name' in reviewer_data:
            reviewer.first_name = reviewer_data['first_name'].strip()
            reviewer_changed = True
        if 'last_name' in reviewer_data:
            reviewer.last_name = reviewer_data['last_name'].strip()
            reviewer_changed = True
        if password:
            reviewer.set_password(password)
            reviewer_changed = True

        if 'is_active' in validated_data:
            instance.is_active = validated_data['is_active']
            # For standalone reviewer accounts (no employee profile, not superuser), sync login active state
            if not hasattr(reviewer, 'employee') and not reviewer.is_superuser:
                reviewer.is_active = instance.is_active
                reviewer_changed = True

        if 'linked_employee' in validated_data:
            instance.linked_employee = validated_data['linked_employee']

        with transaction.atomic():
            if reviewer_changed:
                reviewer.save()
            instance.save()
            if category_ids is not None:
                cats = PerformanceCategory.objects.filter(
                    organization=instance.organization, id__in=category_ids
                )
                instance.categories.set(cats)

        return instance


class PerformanceReviewerCreateSerializer(serializers.Serializer):
    email = serializers.EmailField()
    first_name = serializers.CharField(max_length=50)
    last_name = serializers.CharField(max_length=50)
    password = serializers.CharField(write_only=True, min_length=6)
    linked_employee = serializers.PrimaryKeyRelatedField(
        queryset=Employee.objects.all(), required=False, allow_null=True
    )
    category_ids = serializers.ListField(
        child=serializers.IntegerField(), required=False, default=list
    )
    is_active = serializers.BooleanField(default=True)

    def validate_email(self, value):
        normalized = value.strip().lower()
        if Account.objects.filter(email__iexact=normalized).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return normalized

    def validate_linked_employee(self, value):
        if value is None:
            return None
        org = self.context.get('organization')
        emp_org = value.organization
        if org and emp_org and emp_org.id != org.id:
            raise serializers.ValidationError('Linked employee must belong to this organization.')
        return value

    def validate_category_ids(self, value):
        org = self.context.get('organization')
        if org and value:
            valid_ids = set(
                PerformanceCategory.objects.filter(organization=org, id__in=value).values_list('id', flat=True)
            )
            invalid = [cid for cid in value if cid not in valid_ids]
            if invalid:
                raise serializers.ValidationError(
                    f'Categories {invalid} do not belong to this organization.'
                )
        return value

    def create(self, validated_data):
        org = self.context['organization']
        category_ids = validated_data.pop('category_ids', [])
        linked_employee = validated_data.pop('linked_employee', None)
        is_active = validated_data.pop('is_active', True)
        password = validated_data.pop('password')

        with transaction.atomic():
            account = Account.objects.create_user(
                first_name=validated_data['first_name'].strip(),
                last_name=validated_data['last_name'].strip(),
                email=validated_data['email'],
                password=password,
            )
            account.is_performance_reviewer = True
            account.is_active = is_active
            account.save(update_fields=['is_performance_reviewer', 'is_active'])

            access = PerformanceReviewerAccess.objects.create(
                organization=org,
                reviewer=account,
                linked_employee=linked_employee,
                is_active=is_active,
            )
            if category_ids:
                cats = PerformanceCategory.objects.filter(organization=org, id__in=category_ids)
                access.categories.set(cats)

        return access


class ReviewableEmployeeSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()
    email = serializers.SerializerMethodField()
    post_title = serializers.SerializerMethodField()
    department_name = serializers.SerializerMethodField()
    user = serializers.SerializerMethodField()

    class Meta:
        model = Employee
        fields = ['id', 'full_name', 'email', 'post_title', 'department_name', 'user']

    def get_full_name(self, obj):
        if obj.user:
            return obj.user.full_name.strip() or obj.user.email
        return f'Employee #{obj.id}'

    def get_email(self, obj):
        return obj.user.email if obj.user else None

    def get_post_title(self, obj):
        return obj.post.title if obj.post else None

    def get_department_name(self, obj):
        if obj.post and obj.post.department:
            return obj.post.department.department_name
        return None

    def get_user(self, obj):
        if not obj.user:
            return None
        return {
            'id': obj.user.id,
            'first_name': obj.user.first_name,
            'last_name': obj.user.last_name,
            'full_name': obj.user.full_name,
            'email': obj.user.email,
        }
