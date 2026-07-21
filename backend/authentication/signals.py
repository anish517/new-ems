from user_agents import parse
from django.contrib.auth.signals import user_logged_in
from django.dispatch import receiver

from notification.models import Notification
from organization.models import (Organization, Department, Post, Employee)
from .models import LoginHistory


def get_browser_device(user_agent):
    ua = parse(user_agent)
    return {
        'browser': ua.browser.family,
        'browser_version': ua.browser.version_string,
        'device': ua.device.family,
        'os': ua.os.family,
        'os_version': ua.os.version_string
    }


@receiver(user_logged_in)
def log_user_login(sender, request, user, **kwargs):
    organization: Organization = user.employee.organization
    admin_users = organization.admin_users.all()
    user_agent = request.META.get('HTTP_USER_AGENT', '')
    user_agent_info = get_browser_device(user_agent=user_agent)

    LoginHistory.objects.create(
        user=user,
        browser=f"{user_agent_info.get('browser')}, V{user_agent_info.get('browser_version')}",
        os=f"{user_agent_info.get('os')}"
    )

    notification = Notification.objects.create(
        user=user,
        title=f"{user.full_name} logged in",
        message=f"{user.full_name} logged in from {user_agent_info.get('browser')}, {user_agent_info.get('os')}",
        is_read=False
    )
    print("Admin users: ", admin_users)
    for admin_user in admin_users:
        notification = Notification.objects.create(
            user=admin_user,
            title=f"{user.full_name} logged in",
            message=f"{user.full_name} logged in from {user_agent_info.get('browser')}, {user_agent_info.get('os')}",
            is_read=False
        )
