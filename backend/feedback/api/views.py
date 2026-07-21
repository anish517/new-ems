from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from feedback.models import Complain, ComplainReply, ComplainCategory
from .serializers import ComplainSerializer, ComplainReplySerializer, ComplainCategorySerializer
import nepali_datetime


class ComplainCategoryListView(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ComplainCategorySerializer

    def get_queryset(self):
        org = self.request.user.employee.organization
        return ComplainCategory.objects.filter(organization=org)


class ComplainListCreateView(generics.ListCreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ComplainSerializer

    def _get_employee(self):
        try:
            return self.request.user.employee
        except Exception:
            return None

    def get_queryset(self):
        user = self.request.user
        employee = self._get_employee()
        
        if not employee:
            orgs = user.organization.all()
            if orgs.exists():
                return Complain.objects.filter(organization__in=orgs).order_by('-id')
            if user.is_superuser:
                return Complain.objects.all().order_by('-id')
            return Complain.objects.none()
            
        org = employee.organization
        if org and user in org.admin_users.all():
            return Complain.objects.filter(organization=org).order_by('-id')
        return Complain.objects.filter(owner=employee).order_by('-id')

    def perform_create(self, serializer):
        user = self.request.user
        employee = self._get_employee()
        today = nepali_datetime.date.today()
        if employee:
            serializer.save(
                owner=employee,
                organization=employee.organization,
                created_at=today,
                updated_at=today,
            )
        else:
            orgs = user.organization.all()
            if orgs.exists():
                serializer.save(organization=orgs.first(), created_at=today, updated_at=today)
            else:
                serializer.save(created_at=today, updated_at=today)


class ComplainDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ComplainSerializer

    def get_queryset(self):
        user = self.request.user
        try:
            employee = user.employee
            return Complain.objects.filter(organization=employee.organization)
        except Exception:
            orgs = user.organization.all()
            if orgs.exists():
                return Complain.objects.filter(organization__in=orgs)
            if user.is_superuser:
                return Complain.objects.all()
            return Complain.objects.none()


class ComplainReplyCreateView(generics.CreateAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = ComplainReplySerializer

    def perform_create(self, serializer):
        user = self.request.user
        today = nepali_datetime.date.today()
        complain_id = self.kwargs.get('pk')
        try:
            employee = user.employee
            serializer.save(
                employee=employee,
                organization=employee.organization,
                complain_id=complain_id,
                created_at=today,
                updated_at=today,
            )
        except Exception:
            orgs = user.organization.all()
            if orgs.exists():
                serializer.save(
                    organization=orgs.first(),
                    complain_id=complain_id,
                    created_at=today,
                    updated_at=today,
                )
            else:
                serializer.save(complain_id=complain_id, created_at=today, updated_at=today)
