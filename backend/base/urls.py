from django.contrib import admin
from django.shortcuts import redirect
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView


def index(request):
    # Land on the Flutter app; the legacy HTML UI stays reachable at /account/...
    return redirect('/app/')


urlpatterns = [
    path('', index, name='home'),
    path('account/', include('authentication.urls', namespace='authentication')),
    path('attendance/', include('attendance.urls', namespace='attendance')),
    path('calendar/', include('calendar_app.urls', namespace='calendar')),
    path("ckeditor5/", include('django_ckeditor_5.urls')),
    path('employees/', include('employee.urls', namespace='employee')),
    path('feedbacks/', include('feedback.urls', namespace='feedback')),
    path('fiscal-year/', include('fiscal_year.urls', namespace='fiscal_year')),
    path('supa-admin/', admin.site.urls),
    path('organization/', include('organization.urls', namespace='organization')),
    path('leave-tracker/', include('leave_management.urls', namespace='leave_management')),
    path('salary-management/', include('salary_management.urls', namespace='salary_management')),
    path('task-management/', include('task_management.urls', namespace='task_management')),
    path('notifications/', include('notification.urls', namespace='notification')),
    path('noticeboard/', include('noticeboard.urls', namespace='noticeboard')),
    path('tinymce/', include('tinymce.urls')),
]

api_routes = [
    # ── JWT Auth ──────────────────────────────────────────────
    path('api/auth/token/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),

    # ── Existing APIs ─────────────────────────────────────────
    path('api/auth/', include('authentication.api.routes')),
    path('api/employees/', include('employee.api.routes')),
    path('api/organization/', include('organization.api.routes')),
    path('api/attendance/', include('attendance.api.routes')),
    path('api/calendar/', include('calendar_app.api.routes')),
    path('api/salary-management/', include('salary_management.api.routes')),
    path('api/salary/', include('salary_management.api.routes')),
    path('api/leave-tracker/', include('leave_management.api.routes')),
    path('api/task-management/', include('task_management.api.routes')),
    path('api/noticeboard/', include('noticeboard.api.routes')),
    path('api/notifications/', include('notification.api.routes')),

    # ── New APIs for Flutter ──────────────────────────────────
    path('api/feedback/', include('feedback.api.routes')),
    path('api/fiscal-year/', include('fiscal_year.api.routes')),
    path('api/performance/', include('performance.urls')),
]

urlpatterns += api_routes
urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
