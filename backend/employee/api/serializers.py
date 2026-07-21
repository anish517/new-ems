from rest_framework import serializers


from organization.models import Employee
from employee.models import Contract


class EmployeeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Employee


class ContractSerializer(serializers.ModelSerializer):
    class Meta:
        model = Contract
        fields = '__all__'
