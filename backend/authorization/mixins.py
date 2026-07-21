from django.shortcuts import redirect
from django.urls import reverse_lazy
from django.contrib import messages
from django.http import Http404

from organization.models import Organization, Employee


class CompanyAdminRequiredMixin:
    """
    Mixin to check if the user is a company admin.
    If not, redirect to the employee dashboard with an error message.
    """
    fallback_url = None

    def dispatch(self, request, *args, **kwargs):
        employee: Employee = request.user.employee
        if employee.is_company_admin():
            return super().dispatch(request, *args, **kwargs)
        else:
            messages.error(request, 'Unauthorized')
            return redirect(self.fallback_url or reverse_lazy('authentication:dashboard'))


class OwnerAndAdminOnlyMixin:
    """
    Mixin to check if the user is a company admin or owner of the instance.
    If not, redirect to the fallback_url or employee dashboard.
    """
    fallback_url = None

    def dispatch(self, request, *args, **kwargs):
        employee: Employee = request.user.employee
        owner = self.get_object().owner

        if employee.is_company_admin() or employee == owner:
            return super().dispatch(request, *args, **kwargs)
        else:
            messages.error(request, "Unauthorized")
            return redirect(self.fallback_url or reverse_lazy('authentication:dashboard'))


class OwnerOnlyMixin:
    fallback_url = None

    def dispatch(self, request, *args, **kwargs):
        pk = kwargs.get('pk')
        employee = getattr(request.user, 'employee', None)

        if not employee:
            messages.error(request, "Employee record not found")
            return redirect('authentication:logout')

        try:
            obj = self.model.objects.get(pk=pk)
            if obj.owner == employee:
                return super().dispatch(request, *args, **kwargs)
            else:
                messages.error(request, "Unauthorized")
                return redirect(self.fallback_url or reverse_lazy('authentication:dashboard'))
        except self.model.DoesNotExist:
            raise Http404("Not found")


class GuestOnlyMixin:
    """
    Mixin to check if the user is logged in.
    If user is logged in, redirect user to dashboard.
    """

    def dispatch(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            return redirect('authentication:dashboard')
        else:
            return super().dispatch(request, *args, **kwargs)
