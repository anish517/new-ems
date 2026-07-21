import base64
import uuid
import io
from PIL import Image
from rest_framework import serializers
from django.core.files.base import ContentFile
from django.core.exceptions import ValidationError
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password

from authentication.models import Account

User = get_user_model()


def validate_image_size(image):
    max_size_kb = 5120
    if image.size > max_size_kb * 5120:
        raise ValidationError(f"Image size should not exceed {max_size_kb} KB")


class Base64ImageField(serializers.ImageField):
    ALLOWED_TYPES = ('jpeg', 'jpg', 'png')

    def to_internal_value(self, data):
        if isinstance(data, str):
            if "data:" in data and ";base64," in data:
                header, data = data.split(";base64,")
            try:
                decoded_file = base64.b64decode(data)
            except TypeError:
                raise serializers.ValidationError("Invalid Base64 string.")

            try:
                img = Image.open(io.BytesIO(decoded_file))
                file_type = img.format.lower() if img.format else None
            except Exception:
                file_type = None

            if file_type not in self.ALLOWED_TYPES:
                raise serializers.ValidationError(
                    f"Unsupported image type '{file_type}'. Allowed: {', '.join(self.ALLOWED_TYPES)}."
                )
            file_name = f"{uuid.uuid4()}.{file_type}"
            data = ContentFile(decoded_file, name=file_name)
        return super().to_internal_value(data)


class AccountSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=False, style={'input_type': 'password'})
    profile_picture = Base64ImageField(required=False, allow_null=True)

    class Meta:
        model = Account
        fields = ['id', 'first_name', 'last_name', 'email', 'password',
                  'date_joined', 'last_login', 'is_staff', 'is_active',
                  'is_superuser', 'profile_picture']
        read_only_fields = ['date_joined', 'last_login']

    def validate_email(self, value):
        if self.instance:
            if Account.objects.filter(email=value).exclude(pk=self.instance.pk).exists():
                raise serializers.ValidationError("An account with this email already exists.")
        else:
            if Account.objects.filter(email=value).exists():
                raise serializers.ValidationError("An account with this email already exists.")
        return value

    def create(self, validated_data):
        password = validated_data.pop('password')
        account = Account(**validated_data)
        account.set_password(password)
        account.save()
        return account

    def update(self, instance, validated_data):
        if 'password' in validated_data:
            password = validated_data.pop('password')
            instance.set_password(password)
        if 'profile_picture' not in validated_data or validated_data['profile_picture'] is None:
            validated_data['profile_picture'] = instance.profile_picture
        return super().update(instance, validated_data)


class MeSerializer(serializers.ModelSerializer):
    """Returns the current logged-in user's profile with role and employee info."""
    role = serializers.SerializerMethodField()
    employee_id = serializers.SerializerMethodField()
    organization_id = serializers.SerializerMethodField()
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = Account
        fields = ['id', 'email', 'first_name', 'last_name', 'full_name',
                  'profile_picture', 'is_staff', 'is_superuser',
                  'role', 'employee_id', 'organization_id']

    def get_full_name(self, obj):
        return obj.full_name

    def get_role(self, obj):
        if obj.is_superuser:
            return 'super_admin'
        try:
            employee = obj.employee
            if employee.organization and obj in employee.organization.admin_users.all():
                return 'org_admin'
        except Exception:
            pass
        return 'employee'

    def get_employee_id(self, obj):
        try:
            return obj.employee.id
        except Exception:
            return None

    def get_organization_id(self, obj):
        try:
            return obj.employee.organization.id if obj.employee.organization else None
        except Exception:
            return None


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True)

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError("Old password is incorrect.")
        return value

    def validate_new_password(self, value):
        validate_password(value, self.context['request'].user)
        return value

