from django.apps import AppConfig


class CalendarAppConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "calendar_app"

    def ready(self):
        import os
        # Prevent starting scheduler twice when Django dev server auto-reloads
        if os.environ.get('RUN_MAIN', None) == 'true':
            from . import scheduler
            scheduler.start()
