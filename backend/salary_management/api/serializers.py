from django.db import transaction
from rest_framework import serializers

from authentication.models import Account
from salary_management.models import (
    Salary, SalaryTransaction,
    SalaryTaxBand, IncentiveTaxBand, BonusTaxBand,
    FinanceAccess,
)
from organization.api.serializers import EmployeeSerializer


class SalarySerializer(serializers.ModelSerializer):
    class Meta:
        model = Salary
        fields = ['id', 'employee', 'basic_salary', 'remote_salary',
                  'ssf', 'tds', 'epf', 'citizen_investment_trust',
                  'insurance', 'tax_rate']
        extra_kwargs = {
            'employee': {
                'validators': []
            }
        }


class SalaryTransactionSerializer(serializers.ModelSerializer):
    net_salary = serializers.ReadOnlyField()
    gross_salary = serializers.ReadOnlyField()
    holidays = serializers.ReadOnlyField()
    no_of_days_present = serializers.ReadOnlyField()
    paid_leaves = serializers.ReadOnlyField()
    unpaid_leaves = serializers.ReadOnlyField()
    half_leaves = serializers.ReadOnlyField()
    deduction = serializers.ReadOnlyField()
    employee_name = serializers.CharField(source='salary.employee.user.get_full_name', read_only=True)

    class Meta:
        model = SalaryTransaction
        fields = [
            'id', 'organization', 'salary', 'employee_name', 'fiscal_year', 'date', 'content',
            'status', 'net_salary', 'gross_salary',
            'incentive', 'bonus', 'total_expense',
            'holidays', 'no_of_days_present', 'paid_leaves', 'unpaid_leaves',
            'half_leaves', 'deduction', 'manual_net_salary',
            'transaction_ssf', 'transaction_epf', 'transaction_tds',
        ]

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        rep['salary'] = instance.salary.basic_salary if instance.salary else None
        rep['employee'] = instance.salary.employee.id if instance.salary and hasattr(instance.salary, 'employee') else None
        rep['employee_name'] = instance.salary.employee.user.full_name if instance.salary and hasattr(instance.salary, 'employee') else None
        rep['fiscal_year'] = instance.fiscal_year.title if instance.fiscal_year else None
        return rep


class NetSalarySerializer(serializers.Serializer):
    net_salary = serializers.FloatField()
    holidays = serializers.FloatField()
    no_of_days_present = serializers.FloatField()
    paid_leaves = serializers.FloatField()
    unpaid_leaves = serializers.FloatField()
    half_leaves = serializers.FloatField()
    tds = serializers.FloatField(required=False)
    ssf = serializers.FloatField(required=False)
    epf = serializers.FloatField(required=False)


class SalaryTaxBandSerializer(serializers.ModelSerializer):
    class Meta:
        model = SalaryTaxBand
        fields = ['id', 'organization', 'marital_status', 'min_salary', 'max_salary', 'tax_percentage', 'order']
        read_only_fields = ['organization']


class IncentiveTaxBandSerializer(serializers.ModelSerializer):
    class Meta:
        model = IncentiveTaxBand
        fields = ['id', 'organization', 'min_amount', 'max_amount', 'tax_percentage', 'order']
        read_only_fields = ['organization']


class BonusTaxBandSerializer(serializers.ModelSerializer):
    class Meta:
        model = BonusTaxBand
        fields = ['id', 'organization', 'min_amount', 'max_amount', 'tax_percentage', 'order']
        read_only_fields = ['organization']


class FinanceAccessSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    email = serializers.EmailField(source='user.email', required=False)
    first_name = serializers.CharField(source='user.first_name', required=False)
    last_name = serializers.CharField(source='user.last_name', required=False)
    full_name = serializers.SerializerMethodField()
    password = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = FinanceAccess
        fields = [
            'id', 'user_id', 'email', 'first_name', 'last_name', 'full_name',
            'password', 'is_active', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'user_id', 'created_at', 'updated_at']

    def get_full_name(self, obj):
        return f'{obj.user.first_name} {obj.user.last_name}'.strip() or obj.user.email

    def validate_password(self, value):
        if value and len(value) < 6:
            raise serializers.ValidationError('Password must be at least 6 characters.')
        return value

    def update(self, instance, validated_data):
        user_data = validated_data.pop('user', {})
        password = validated_data.pop('password', None)

        account = instance.user
        user_changed = False

        if 'email' in user_data:
            new_email = user_data['email'].strip().lower()
            if Account.objects.filter(email__iexact=new_email).exclude(pk=account.pk).exists():
                raise serializers.ValidationError({'email': 'An account with this email already exists.'})
            account.email = new_email
            user_changed = True
        if 'first_name' in user_data:
            account.first_name = user_data['first_name'].strip()
            user_changed = True
        if 'last_name' in user_data:
            account.last_name = user_data['last_name'].strip()
            user_changed = True
        if password:
            account.set_password(password)
            user_changed = True

        if 'is_active' in validated_data:
            instance.is_active = validated_data['is_active']
            if not hasattr(account, 'employee') and not account.is_superuser:
                account.is_active = instance.is_active
                user_changed = True

        with transaction.atomic():
            if user_changed:
                account.save()
            instance.save()

        return instance


class FinanceAccessCreateSerializer(serializers.Serializer):
    email = serializers.EmailField()
    first_name = serializers.CharField(max_length=50)
    last_name = serializers.CharField(max_length=50)
    password = serializers.CharField(write_only=True, min_length=6)
    is_active = serializers.BooleanField(default=True)

    def validate_email(self, value):
        normalized = value.strip().lower()
        if Account.objects.filter(email__iexact=normalized).exists():
            raise serializers.ValidationError('An account with this email already exists.')
        return normalized

    def create(self, validated_data):
        org = self.context['organization']
        is_active = validated_data.pop('is_active', True)
        password = validated_data.pop('password')

        with transaction.atomic():
            account = Account.objects.create_user(
                first_name=validated_data['first_name'].strip(),
                last_name=validated_data['last_name'].strip(),
                email=validated_data['email'],
                password=password,
            )
            account.is_finance = True
            account.is_active = is_active
            account.save(update_fields=['is_finance', 'is_active'])

            access = FinanceAccess.objects.create(
                organization=org,
                user=account,
                is_active=is_active,
            )
        return access
