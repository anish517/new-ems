from rest_framework import serializers

from salary_management.models import (
    Salary, SalaryTransaction,
    SalaryTaxBand, IncentiveTaxBand, BonusTaxBand
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
