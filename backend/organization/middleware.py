from django.shortcuts import redirect, get_object_or_404
from django.urls import reverse, resolve
from django.core.exceptions import ObjectDoesNotExist
from django.utils.deprecation import MiddlewareMixin
from django.contrib import messages
from django.http import HttpResponseForbidden
from .models import Organization


class OrganizationCheckMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Define URLs to avoid redirect loops
        sign_in_url = reverse("authentication:signin")
        sign_up_url = reverse("authentication:signup")
        organization_page_url = reverse("organization:detail")
        organization_create_page_url = reverse("organization:create")
        admin_url_prefix = reverse("admin:index")
        logout_url = reverse("authentication:signout")

        # Check if the request is for the admin site
        if request.path.startswith(admin_url_prefix):
            return self.get_response(request)

        if request.user.is_authenticated:
            try:
                employee = request.user.employee
                # Avoid redirect loops for certain paths
                if request.path not in [
                    organization_page_url,
                    organization_create_page_url,
                    sign_in_url,
                    sign_up_url,
                    logout_url,
                ]:
                    if employee.organization:
                        response = self.get_response(request)
                        return response
                    else:
                        return redirect(organization_create_page_url)
            except ObjectDoesNotExist:
                # Log message and redirect to the organization create page if user has no associated employee
                if request.path not in [organization_create_page_url, logout_url]:
                    return redirect(organization_create_page_url)
        else:
            # Redirect to sign-in if the user is not authenticated and not already on sign-in/sign-up pages
            if request.path not in [sign_in_url, sign_up_url, logout_url]:
                return redirect(sign_in_url)

        response = self.get_response(request)
        return response


class OrganizationAdminMiddleware(MiddlewareMixin):
    def process_view(self, request, view_func, view_args, view_kwargs):

        RESTRICTED_URL = [
            reverse("organization:detail"),
            reverse("organization:department_list"),
            reverse("organization:create_department"),
            reverse("organization:post_list"),
            reverse("organization:create_post"),
            reverse("organization:employee_list"),
            reverse("organization:add_employee"),
            reverse("leave_management:list"),
            reverse("leave_management:leave_type_list"),
            reverse("salary_management:salary_list"),
            reverse("salary_management:salary_transaction_list_view"),
            reverse("salary_management:salary_transaction_create_view"),
            reverse("attendance:employee_attendance"),
            reverse("task:employee_task"),
            reverse("noticeboard:notice_create"),
            reverse("fiscal_year:list"),
            reverse('calendar_app:event-add'),
        ]

        if view_kwargs.get("pk"):
            RESTRICTED_URL.append(
                reverse(
                    "organization:employee_detail", kwargs={"pk": view_kwargs.get("pk")}
                )
            )

        if request.path in RESTRICTED_URL:
            if request.user.is_authenticated:
                if request.user.employee:
                    organization = request.user.employee.organization
                    if organization.admin_users.filter(id=request.user.id).exists():
                        return None
                    else:
                        messages.error(request, "Unauthorized")
                        return redirect("home")
                else:
                    return redirect("organization:create")
            else:
                return redirect("authentication:signin")


class AdminUsersOnlyMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Get the current resolved URL name
        resolved_url = resolve(request.path_info)

        # Define the URL names that should be restricted
        restricted_urls = [
            "organization:detail",
        ]

        if resolved_url.url_name in restricted_urls:
            organization = request.user.employee.organization
            if not organization.admin_users.filter(id=request.user.id).exists():
                return HttpResponseForbidden(
                    "You do not have permission to access this page."
                )

        response = self.get_response(request)
        return response
