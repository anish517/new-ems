import time
import nepali_datetime
from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .serializers import NoticeSerializer, CompanyPolicySerializer, PolicyApprovalSerializer
from noticeboard.models import Notice, CompanyPolicy, PolicyApproval



class NoticeboardListView(generics.ListCreateAPIView):
    serializer_class = NoticeSerializer
    permission_classes = [IsAuthenticated]

    def _get_employee(self):
        try:
            return self.request.user.employee
        except Exception:
            return None

    def _get_org(self):
        user = self.request.user
        org = getattr(user.employee, 'organization', None) if hasattr(user, 'employee') else None
        if not org:
            if user.organization.exists():
                org = user.organization.first()
            elif getattr(user, 'is_superuser', False) or getattr(user, 'is_hr', False):
                from organization.models import Organization
                org = Organization.objects.first()
        return org

    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        org = self._get_org()
        
        if not org:
            if user.is_superuser:
                return Notice.objects.all().order_by('-id')
            return Notice.objects.none()
            
        return Notice.objects.filter(
            Q(organization=org) | Q(organization__isnull=True)
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

        org = self._get_org()
        if employee:
            serializer.save(
                organization=org,
                created_by=employee,
                date=date_val,
                created_at=today,
            )
        else:
            serializer.save(
                organization=org,
                date=date_val,
                created_at=today,
            )

class NoticeDetailView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = NoticeSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        from django.db.models import Q
        user = self.request.user
        try:
            employee = user.employee
            return Notice.objects.filter(Q(organization=employee.organization) | Q(organization__isnull=True))
        except Exception:
            orgs = user.organization.all()
            if orgs.exists():
                return Notice.objects.filter(Q(organization__in=orgs) | Q(organization__isnull=True))
            if user.is_superuser:
                return Notice.objects.all()
            return Notice.objects.none()


# ─── Company Policy ─────────────────────────────────────────────────

class CompanyPolicyListCreateView(generics.ListCreateAPIView):
    """GET: all active policies for the org. POST: admin only."""
    serializer_class = CompanyPolicySerializer
    permission_classes = [IsAuthenticated]

    def _get_org(self):
        user = self.request.user
        try:
            return user.employee.organization
        except Exception:
            orgs = user.organization.all()
            return orgs.first() if orgs.exists() else None

    def get_queryset(self):
        org = self._get_org()
        if not org:
            return CompanyPolicy.objects.none()
        qs = CompanyPolicy.objects.filter(organization=org, is_active=True)
        category = self.request.query_params.get('category')
        if category:
            qs = qs.filter(category__iexact=category)
        return qs

    def perform_create(self, serializer):
        from rest_framework.exceptions import PermissionDenied
        user = self.request.user
        is_admin = user.organization.exists() or user.is_superuser
        if not is_admin:
            raise PermissionDenied('Only admins can create policies.')
        org = self._get_org()
        serializer.save(organization=org, created_by=user)


class CompanyPolicyDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Admin: full CRUD. Employee: read-only GET."""
    serializer_class = CompanyPolicySerializer
    permission_classes = [IsAuthenticated]
    queryset = CompanyPolicy.objects.all()
    http_method_names = ['get', 'patch', 'delete']

    def update(self, request, *args, **kwargs):
        if not (request.user.organization.exists() or request.user.is_superuser):
            return Response({'error': 'Only admins can edit policies.'}, status=status.HTTP_403_FORBIDDEN)
        return super().update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        if not (request.user.organization.exists() or request.user.is_superuser):
            return Response({'error': 'Only admins can delete policies.'}, status=status.HTTP_403_FORBIDDEN)
        return super().destroy(request, *args, **kwargs)


def get_client_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


class PolicyApproveView(generics.GenericAPIView):
    """
    POST: Employee submits approval of company policy.
    Records approval status, exact date/time, device name, OS, browser, IP address, and User-Agent.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        user = request.user
        employee = getattr(user, 'employee', None)
        org = None
        if employee and getattr(employee, 'organization', None):
            org = employee.organization
        elif user.organization.exists():
            org = user.organization.first()

        device_name = request.data.get('device_name', '')
        os_info = request.data.get('os', '')
        browser_info = request.data.get('browser', '')
        ip = get_client_ip(request)
        ua = request.META.get('HTTP_USER_AGENT', '')

        # Auto-parse browser/OS from User-Agent
        if (not os_info or os_info in ('Web', 'Client Device', 'Unknown Platform')) and ua:
            if 'Windows NT 10.0' in ua or 'Windows NT 11.0' in ua or 'Windows' in ua:
                os_info = 'Windows Desktop'
            elif 'Android' in ua:
                os_info = 'Android Mobile'
            elif 'iPhone' in ua:
                os_info = 'iPhone'
            elif 'iPad' in ua:
                os_info = 'iPad'
            elif 'Macintosh' in ua or 'Mac OS' in ua:
                os_info = 'macOS Desktop'
            elif 'Linux' in ua:
                os_info = 'Linux Workstation'
            else:
                os_info = 'Web Platform'

        if (not browser_info or browser_info == 'Web Browser') and ua:
            if 'Edg/' in ua:
                browser_info = 'Microsoft Edge'
            elif 'Chrome/' in ua and 'Edg/' not in ua:
                browser_info = 'Google Chrome'
            elif 'Firefox/' in ua:
                browser_info = 'Mozilla Firefox'
            elif 'Safari/' in ua and 'Chrome/' not in ua:
                browser_info = 'Apple Safari'
            else:
                browser_info = 'Web Browser'

        if not device_name or device_name in ('Web Browser', 'Workstation'):
            device_name = f"{os_info} • {browser_info}"


        # Create or update Master Approval record
        approval, _ = PolicyApproval.objects.update_or_create(
            user=user,
            policy=None,
            defaults={
                'employee': employee,
                'organization': org,
                'is_approved': True,
                'device_name': device_name,
                'os': os_info,
                'browser': browser_info,
                'ip_address': ip,
                'user_agent': ua,
            }
        )

        # Also link individual active policies if any
        if org:
            for p in CompanyPolicy.objects.filter(organization=org, is_active=True):
                PolicyApproval.objects.update_or_create(
                    user=user,
                    policy=p,
                    defaults={
                        'employee': employee,
                        'organization': org,
                        'is_approved': True,
                        'device_name': device_name,
                        'os': os_info,
                        'browser': browser_info,
                        'ip_address': ip,
                        'user_agent': ua,
                    }
                )

        return Response({
            'success': True,
            'message': 'Company policies approved successfully.',
            'approved_at': approval.approved_at,
            'device_name': approval.device_name,
            'has_approved_policy': True,
        }, status=status.HTTP_200_OK)


class PolicyApprovalStatusView(generics.GenericAPIView):
    """GET: Check if the current user has approved the policies."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        last_approval = PolicyApproval.objects.filter(user=user, is_approved=True).order_by('-approved_at').first()
        has_approved = bool(last_approval) or user.is_superuser
        return Response({
            'has_approved': has_approved,
            'approved_at': last_approval.approved_at if last_approval else None,
            'device_name': last_approval.device_name if last_approval else None,
            'os': last_approval.os if last_approval else None,
            'browser': last_approval.browser if last_approval else None,
        })


class PolicyApprovalAuditListView(generics.ListAPIView):
    """Admin GET: Lists all policy approval records with date, time, employee, and device."""
    serializer_class = PolicyApprovalSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        is_admin = user.organization.exists() or user.is_superuser
        if not is_admin:
            return PolicyApproval.objects.none()

        org = user.organization.first() if user.organization.exists() else None
        qs = PolicyApproval.objects.filter(policy__isnull=True)
        if org:
            qs = qs.filter(organization=org)
        return qs.select_related('user', 'employee', 'employee__user').order_by('-approved_at')


