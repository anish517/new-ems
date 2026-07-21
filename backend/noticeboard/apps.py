from django.apps import AppConfig


class NoticeboardConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'noticeboard'

    def ready(self):
        import noticeboard.signals
