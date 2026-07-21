from django.apps import AppConfig


class SalaryManagementConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'salary_management'

    def ready(self) -> None:
        from . import signals
