import time
import base64
import uuid
from django.core.files.base import ContentFile
from rest_framework import serializers

from authentication.api.serializers import AccountSerializer
from organization.models import (
    BankDetail,
    Document,
    Employee,
    EmployeeAnalysisReport,
    NationalIdDetail,
    OrganizationFile,
    Organization,
    Department,
    OrganizationFolder,
    Post,
    Address,
    Qualification,
)


class DepartmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Department
        fields = '__all__'


class OrganizationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Organization
        fields = ["id", "name"]  # Only include necessary fields


class OrganizationFolderSerializer(serializers.ModelSerializer):
    class Meta:
        model = OrganizationFolder
        fields = ["id", "title"]  # Customize fields as needed


class OrganizationFileSerializer(serializers.ModelSerializer):
    organization = OrganizationSerializer()  # Nest the serializer
    folder = OrganizationFolderSerializer()  # Nest the serializer

    class Meta:
        model = OrganizationFile
        fields = ["id", "title", "description",
                  "file", "organization", "folder"]


class OrganizationFileSerializer(serializers.ModelSerializer):
    file_size = serializers.SerializerMethodField()

    class Meta:
        model = OrganizationFile
        fields = [
            "id",
            "title",
            "description",
            "file",
            "organization",
            "folder",
            "file_size",
        ]
        depth = 1

    def get_file_size(self, obj):
        if obj.file and hasattr(obj.file, "size"):
            size = obj.file.size
            for unit in ["bytes", "KB", "MB", "GB", "TB"]:
                if size < 1024.0:
                    return f"{size:.2f} {unit}"
                size /= 1024.0
        return None


class EmployeeSerializer(serializers.ModelSerializer):
    user = AccountSerializer()
    post = serializers.PrimaryKeyRelatedField(queryset=Post.objects.all())
    date_of_birth = serializers.CharField(
        required=True, allow_null=True, style={"input_type": "password"}
    )
    department_name = serializers.SerializerMethodField()
    designation_title = serializers.SerializerMethodField()

    class Meta:
        model = Employee
        fields = [
            "id",
            "id_prefix",
            "user",
            "post",
            "gender",
            "date_of_birth",
            "father_name",
            "blood_group",
            "alternative_contact_number",
            "phone_no",
            "official_email",
            "personal_email",
            "is_active",
            "employee_type",
            "department_name",
            "designation_title",
        ]

    def get_department_name(self, obj):
        return obj.post.department.department_name if obj.post and obj.post.department else None

    def get_designation_title(self, obj):
        return obj.post.title if obj.post else None

    def create(self, validated_data):
        user_data = validated_data.pop("user")
        account_serializer = AccountSerializer(data=user_data)
        account_serializer.is_valid(raise_exception=True)
        account = account_serializer.save()
        employee = Employee.objects.create(user=account, **validated_data)
        return employee

    def update(self, instance, validated_data):
        user_data = validated_data.pop("user", None)
        if user_data:
            account_serializer = AccountSerializer(
                instance.user, data=user_data, partial=True
            )
            account_serializer.is_valid(raise_exception=True)
            account_serializer.save()

        return super().update(instance, validated_data)


class AddressSerializer(serializers.ModelSerializer):
    class Meta:
        model = Address
        fields = "__all__"


class NationalIDDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = NationalIdDetail
        fields = "__all__"


class QualificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Qualification
        fields = "__all__"


class BankDetailSerializer(serializers.ModelSerializer):
    class Meta:
        model = BankDetail
        fields = "__all__"


class Base64FileField(serializers.FileField):
    def to_internal_value(self, data):
        if isinstance(data, str) and data.startswith("data:"):
            format, file_str = data.split(";base64,")
            ext = format.split("/")[-1]
            file_name = f"{uuid.uuid4()}.{ext}"
            data = ContentFile(base64.b64decode(file_str), name=file_name)
        return super().to_internal_value(data)


class DocumentSerializer(serializers.ModelSerializer):

    file = Base64FileField(required=False, allow_null=True)

    class Meta:
        model = Document
        fields = ["id", "employee", "name", "file"]


class EmployeeAnalysisReportSerializer(serializers.ModelSerializer):
    analysis_score = serializers.ReadOnlyField()

    class Meta:
        model = EmployeeAnalysisReport
        fields = [
            "organization",
            "employee",
            "date",
            "task_score",
            "attendance_score",
            "analysis_score",
        ]
