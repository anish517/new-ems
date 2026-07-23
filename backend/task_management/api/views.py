import time
from rest_framework import status
from rest_framework import generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import permissions

from organization.models import Employee, Organization
from task_management.models import Project, Task
from task_management.utils import get_employee_task_summary, get_organization_project_summary, get_organization_task_summary, get_project_task_summary
from .serializers import TaskSerializer


class TaskListCreateAPIView(generics.ListCreateAPIView):
    serializer_class = TaskSerializer
    permission_classes = [permissions.IsAuthenticated]

    def _get_employee(self):
        try:
            return self.request.user.employee
        except Exception:
            return None
            
    def _get_org(self, employee):
        if employee:
            return employee.organization
        orgs = self.request.user.organization.all()
        if orgs.exists():
            return orgs.first()
        return None

    def get_queryset(self):
        user = self.request.user
        employee = self._get_employee()
        org = self._get_org(employee)
        if not org:
            return Task.objects.none()
        projects = Project.objects.filter(organization=org)
        all_tasks = Task.objects.filter(project__in=projects)
        # Admins see all tasks; employees only see tasks assigned to them
        is_admin = user.organization.exists() or user.is_superuser
        if is_admin:
            return all_tasks.order_by('-id')
        if employee:
            return all_tasks.filter(assigned_to=employee).order_by('-id')
        return Task.objects.none()

    def perform_create(self, serializer):
        import nepali_datetime
        today = nepali_datetime.date.today()
        employee = self._get_employee()
        serializer.save(
            created_by=employee,
            created_at=today,
            updated_at=today,
        )

class TaskRetrieveUpdateDestroyView(generics.RetrieveUpdateDestroyAPIView):
    model = Task
    serializer_class = TaskSerializer
    permission_classes = [permissions.IsAuthenticated]

    def _get_employee(self):
        try:
            return self.request.user.employee
        except Exception:
            return None
            
    def _get_org(self, employee):
        if employee:
            return employee.organization
        orgs = self.request.user.organization.all()
        if orgs.exists():
            return orgs.first()
        return None

    def get_queryset(self):
        employee = self._get_employee()
        org = self._get_org(employee)
        if not org:
            return Task.objects.none()
        projects = Project.objects.filter(organization=org)
        return Task.objects.filter(project__in=projects)


class EmployeeTaskSummaryAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, employee_id):
        try:
            employee = Employee.objects.get(id=employee_id)
        except Employee.DoesNotExist:
            return Response(data={'error': 'Employee not found'}, status=status.HTTP_404_NOT_FOUND)
        data = get_employee_task_summary(employee=employee)
        return Response(data=data, status=status.HTTP_200_OK)


class OrganizationTaskSummaryAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, organization_id):
        try:
            organization = Organization.objects.get(id=organization_id)
        except Organization.DoesNotExist:
            return Response(data={'error': 'Organization not found'}, status=status.HTTP_404_NOT_FOUND)
        data = get_organization_task_summary(organization=organization)
        return Response(data=data, status=status.HTTP_200_OK)


class ProjectTaskSummaryAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, project_id):
        try:
            project = Project.objects.get(id=project_id)

        except Project.DoesNotExist:
            return Response(data={'error': 'Project not found'}, status=status.HTTP_404_NOT_FOUND)

        data = get_project_task_summary(project=project)
        return Response(data=data, status=status.HTTP_200_OK)


class OrganizationProjectSummary(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, organization_id):
        try:
            organization = Organization.objects.get(id=organization_id)
        except Organization.DoesNotExist:
            return Response(data={'error': 'Organization no found'}, status=status.HTTP_404_NOT_FOUND)

        data = get_organization_project_summary(organization=organization)
        return Response(data=data, status=status.HTTP_200_OK)

class ProjectListAPIView(APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def get(self, request):
        try:
            org = request.user.employee.organization
        except Exception:
            orgs = request.user.organization.all()
            if orgs.exists():
                org = orgs.first()
            else:
                return Response([])
                
        projects = Project.objects.filter(organization=org)
        data = [{'id': p.id, 'title': p.title} for p in projects]
        return Response(data)
