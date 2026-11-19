from . import ckeditor_config
from pathlib import Path
from decouple import config
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY = config('SECRET_KEY', default='django-insecure-local-dev-key-change-in-production')
DEBUG = config('DEBUG', default=False, cast=bool)

# Comma-separated. The default matches the hand-patched production copy so this file is a
# drop-in replacement there; override per host with ALLOWED_HOSTS in the environment.
ALLOWED_HOSTS = [h.strip() for h in config(
    'ALLOWED_HOSTS', default='127.0.0.1,localhost,ems.omwaytechnologies.com').split(',') if h.strip()]

# TLS is terminated by nginx / Passenger in front of Django. Without these the admin
# rejects POSTs over HTTPS and session cookies are never marked secure.
CSRF_TRUSTED_ORIGINS = [o.strip() for o in config(
    'CSRF_TRUSTED_ORIGINS', default='https://ems.omwaytechnologies.com').split(',') if o.strip()]
SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
# Session/CSRF cookies are only used by the admin and the legacy HTML UI (the API is JWT).
# Secure by default; local HTTP development sets DEBUG=True and gets plain cookies.
SESSION_COOKIE_SECURE = config('SECURE_COOKIES', default=not DEBUG, cast=bool)
CSRF_COOKIE_SECURE = SESSION_COOKIE_SECURE

AUTH_USER_MODEL = 'authentication.Account'

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'nepali_datetime_field',
    'rest_framework',
    'rest_framework_simplejwt',
    'authentication',
    'authorization',
    'calendar_app',
    'organization',
    'leave_management',
    'salary_management',
    'fiscal_year',
    "corsheaders",
    'attendance',
    'feedback',
    'task_management',
    'notification',
    'noticeboard',
    'logs',
    'employee',
    'performance',
    'django_ckeditor_5',
    'tinymce',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    "corsheaders.middleware.CorsMiddleware",
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'base.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
                'notification.context_processors.notification_context',
                'notification.context_processors.greeting_context_processor',
            ],
        },
    },
]

WSGI_APPLICATION = 'base.wsgi.application'

# Database: one settings file for every target, selected by environment.
#   DATABASE_URL set  -> that database (PostgreSQL on omway-internal)
#   DB_NAME set       -> MySQL/MariaDB (cPanel production, via the Python Selector env)
#   neither           -> SQLite for local development
if config('DATABASE_URL', default=''):
    import dj_database_url
    DATABASES = {
        'default': dj_database_url.parse(config('DATABASE_URL'), conn_max_age=600),
    }
elif config('DB_NAME', default=''):
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.mysql',
            'NAME': config('DB_NAME'),
            'USER': config('DB_USER'),
            'PASSWORD': config('DB_PASSWORD'),
            'HOST': config('DB_HOST', default='localhost'),
            'PORT': config('DB_PORT', default='3306'),
            'OPTIONS': {
                'charset': 'utf8mb4',
                'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
            },
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    # Relaxed for development - tighten in production
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator', 'OPTIONS': {'min_length': 6}},
]

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'Asia/Kathmandu'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATIC_ROOT = BASE_DIR / config('STATIC_ROOT', default='staticfiles')

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / config('MEDIA_ROOT', default='media')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ─── CORS ─────────────────────────────────────────────────────────────────────
CORS_ALLOW_ALL_ORIGINS = True  # Lock down in production
CORS_ALLOW_HEADERS = [
    'accept', 'accept-encoding', 'authorization',
    'content-type', 'dnt', 'origin', 'user-agent',
    'x-csrftoken', 'x-requested-with',
]

# ─── Django REST Framework ─────────────────────────────────────────────────────
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'base.query_param_auth.QueryParamJWTAuthentication',
        'rest_framework_simplejwt.authentication.JWTAuthentication',
        'rest_framework.authentication.SessionAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
        'utils.filters.GlobalContextFilter',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}

# ─── JWT Configuration ─────────────────────────────────────────────────────────
SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=30),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': False,
    'AUTH_HEADER_TYPES': ('Bearer',),
    'USER_ID_FIELD': 'id',
    'USER_ID_CLAIM': 'user_id',
}

# ─── Email ─────────────────────────────────────────────────────────────────────
# Gmail SMTP — real email delivery
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')
DEFAULT_FROM_EMAIL = config('EMAIL_HOST_USER', default='noreply@ems.local')
FRONTEND_URL = config('FRONTEND_URL', default='http://localhost:56027/')

# ─── CKEditor ─────────────────────────────────────────────────────────────────
CKEDITOR_5_CONFIGS = ckeditor_config.CONFIGS
CKEDITOR_5_FILE_UPLOAD_PERMISSION = "authenticated"
