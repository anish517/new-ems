import time
import nepali_datetime
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .serializers import NoticeSerializer
from noticeboard.models import Notice


class NoticeboardListView(generics.ListCreateAPIView):
    serializer_class = NoticeSerializer
    permission_classes = [IsAuthenticated]

    def _get_employee(self):
        try:
            return self.request.user.employee
        except Exception:
            return None

    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        employee = self._get_employee()
        if not employee:
            orgs = user.organization.all()
            if orgs.exists():
                return Notice.objects.filter(Q(organization__in=orgs) | Q(organization__isnull=True)).order_by('-id')
            if user.is_superuser:
                return Notice.objects.all().order_by('-id')
            return Notice.objects.none()
            
        return Notice.objects.filter(
            Q(organization=employee.organization) | Q(organization__isnull=True)
        ).order_by('-id')

    def perform_create(self, serializer):
        user = self.request.user
        employee = self._get_employee()
        
        # Use provided date if available, else today
        today = nepali_datetime.date.today()
        provided_date_str = self.request.data.get('date')
        if provided_date_str:
            try:
                y, m, d = map(int, provided_date_str.split('-'))
                date_val = nepali_datetime.date(y, m, d)
            except Exception:
                date_val = today
        else:
            date_val = today

        if employee:
            serializer.save(
                organization=employee.organization,
                created_by=employee,
                date=date_val,
                created_at=today,
            )
        else:
            orgs = user.organization.all()
            if orgs.exists():
                serializer.save(organization=orgs.first(), date=date_val, created_at=today)
            else:
                serializer.save(date=date_val, created_at=today)

