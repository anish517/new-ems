from rest_framework import serializers, generics
from rest_framework.permissions import IsAuthenticated
from fiscal_year.models import FiscalYear


class FiscalYearSerializer(serializers.ModelSerializer):
    class Meta:
        model = FiscalYear
        fields = ['id', 'title', 'organization']
