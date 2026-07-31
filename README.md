# 🏢 OmWay EMS — Employee Management System

A full-stack **Employee Management System** built for Nepali companies. It features a **Django REST Framework** backend and a **Flutter** web/mobile frontend with role-based access, Nepali calendar support, GPS attendance, payroll, push notifications, and more.

---

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Local Development Setup](#local-development-setup)
  - [Backend (Django)](#backend-django)
  - [Frontend (Flutter)](#frontend-flutter)
- [Environment Configuration](#environment-configuration)
- [API Reference](#api-reference)
- [Salary Calculation Logic](#salary-calculation-logic)
- [Deployment Guidelines](#deployment-guidelines)
  - [Backend (Production)](#backend-production)
  - [Frontend (Web — Flutter Build)](#frontend-web--flutter-build)
  - [Frontend (Android APK)](#frontend-android-apk)
- [Roles & Permissions](#roles--permissions)
- [Firebase Setup](#firebase-setup)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Frontend)                │
│         Web  ·  Android  ·  iOS (PWA ready)             │
│  Riverpod (State) · GoRouter (Navigation) · Dio (HTTP) │
└───────────────────────┬─────────────────────────────────┘
                        │  REST API (JSON + JWT Bearer)
┌───────────────────────▼─────────────────────────────────┐
│                 Django REST Framework (Backend)          │
│         JWT Auth · CORS · Custom Middleware              │
│  Gunicorn + WhiteNoise · APScheduler (cron jobs)        │
└───────────────────────┬─────────────────────────────────┘
                        │
          ┌─────────────┴──────────┐
          │                        │
   ┌──────▼──────┐        ┌────────▼────────┐
   │  SQLite     │        │  Firebase Admin  │
   │  (dev)      │        │  (FCM Push       │
   │  MySQL/PG   │        │   Notifications) │
   │  (prod)     │        └─────────────────┘
   └─────────────┘
```

---

## Features

| Module | Description |
|---|---|
| 🔐 **Authentication** | JWT login, token refresh, password reset, email verification |
| 👥 **Employee Management** | Profile, documents, role-based access (Super Admin / Org Admin / HR / Employee) |
| ✅ **Attendance** | GPS-based check-in/check-out (site & remote), geo-fence validation (500m radius) |
| 📅 **Leave Management** | Full/Half/Paid/Unpaid leave requests, approval workflow, leave balance tracking |
| 💰 **Payroll (Salary)** | 30-day basis calculation, auto holiday deduction, TDS/SSF/EPF, salary slip email |
| 📆 **Nepali Calendar** | Event scheduling, holiday marking, push notification triggers |
| 📣 **Noticeboard** | Rich text (CKEditor) notices and company-wide policies |
| 🔔 **Notifications** | Firebase FCM push notifications (foreground + background), in-app notification centre |
| 📊 **Performance** | Employee performance reviews and ratings |
| ✅ **Task Management** | Assign, track, and complete tasks across teams |
| 💬 **Feedback** | Anonymous or attributed employee feedback system |
| 🏦 **Accounts / Payroll** | Tax Bands, Global Settings, base salary, fiscal year management |

---

## Tech Stack

### Backend
| Layer | Technology |
|---|---|
| Language | Python 3.11+ |
| Framework | Django 5.0, Django REST Framework 3.15 |
| Auth | `djangorestframework-simplejwt` (JWT) |
| Database | SQLite (dev) · MySQL / PostgreSQL (production) |
| Push Notifications | `firebase-admin` (FCM) |
| Scheduler | `APScheduler` (background cron jobs for early notifications) |
| Rich Text | `django-ckeditor-5`, `django-tinymce` |
| File Serving | `whitenoise` |
| Email | Gmail SMTP |
| CORS | `django-cors-headers` |
| Nepali Date | `nepali-datetime`, `django-nepali-datetime-field` |

### Frontend
| Layer | Technology |
|---|---|
| Language | Dart 3.x |
| Framework | Flutter 3.x (Web + Android + iOS) |
| State Management | `flutter_riverpod` + `riverpod_generator` |
| Navigation | `go_router` |
| HTTP Client | `dio` |
| Notifications | `firebase_messaging` + `flutter_local_notifications` |
| Maps | `google_maps_flutter` |
| Nepali Calendar | `nepali_utils` |
| Charts | `fl_chart` |
| Secure Storage | `flutter_secure_storage` |

---

## Repository Structure

```
ems-full-stack/
├── backend/                    # Django REST API
│   ├── authentication/         # User accounts, JWT
│   ├── authorization/          # Role-based permissions
│   ├── attendance/             # Check-in/out, GPS validation
│   ├── calendar_app/           # Events, holidays, push notification scheduler
│   ├── employee/               # Employee profiles
│   ├── feedback/               # Employee feedback
│   ├── fiscal_year/            # Nepali fiscal year management
│   ├── leave_management/       # Leave requests, approval
│   ├── logs/                   # Activity logging
│   ├── noticeboard/            # Company notices and policies
│   ├── notification/           # FCM push notifications, device tokens
│   ├── organization/           # Company settings, org structure
│   ├── performance/            # Performance reviews
│   ├── salary_management/      # Payroll, TDS, salary slips
│   ├── task_management/        # Task assignment and tracking
│   ├── base/                   # Django settings, URLs, WSGI
│   ├── utils/                  # Shared filters, helpers
│   └── requirements.txt
│
├── frontend/                   # Flutter Application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/      # AppConstants (base URL, endpoints)
│   │   │   ├── services/       # ApiService, FirebaseNotificationService
│   │   │   └── theme/          # AppTheme, AppColors
│   │   ├── features/           # One folder per feature (auth, attendance, etc.)
│   │   │   ├── accounts/
│   │   │   ├── attendance/
│   │   │   ├── calendar/
│   │   │   ├── dashboard/
│   │   │   ├── employee/
│   │   │   ├── feedback/
│   │   │   ├── leave/
│   │   │   ├── noticeboard/
│   │   │   ├── notifications/
│   │   │   ├── performance/
│   │   │   ├── profile/
│   │   │   ├── salary/
│   │   │   └── tasks/
│   │   └── shared/
│   │       └── widgets/        # Reusable widgets
│   ├── android/                # Android-specific (manifest, icons, signing)
│   ├── assets/                 # Images, icons, Lottie animations
│   └── pubspec.yaml
│
└── README.md
```

---

## Local Development Setup

### Backend (Django)

#### Prerequisites
- Python 3.11+
- pip

#### Steps

```bash
# 1. Navigate to backend
cd ems-full-stack/backend

# 2. Create and activate virtual environment
python -m venv venv
# Windows:
.\venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Copy and configure environment variables
copy .env.example .env   # Windows
cp .env.example .env     # macOS/Linux
# Edit .env with your values (see Environment Configuration below)

# 5. Run database migrations
python manage.py migrate

# 6. Create a superuser
python manage.py createsuperuser

# 7. Collect static files
python manage.py collectstatic --noinput

# 8. Start the development server
python manage.py runserver 0.0.0.0:8000
```

The backend will be available at `http://localhost:8000`.
Admin panel: `http://localhost:8000/supa-admin/`

---

### Frontend (Flutter)

#### Prerequisites
- Flutter SDK 3.x (`flutter --version`)
- Dart SDK 3.x
- Android Studio / VS Code with Flutter plugin

#### Steps

```bash
# 1. Navigate to frontend
cd ems-full-stack/frontend

# 2. Install packages
flutter pub get

# 3. Set your backend server IP
# Edit lib/core/constants/app_constants.dart
# Change `baseUrl` to your machine's local IP:
# static const String baseUrl = 'http://YOUR_IP:8000';

# 4. Run on Chrome (Web)
flutter run -d chrome

# 5. Run on connected Android device
flutter run -d android

# 6. Run on Windows desktop
flutter run -d windows
```

---

## Environment Configuration

Create a `.env` file in the `backend/` directory. All keys are loaded via `python-decouple`.

```ini
# ─── Security ──────────────────────────────────────────
SECRET_KEY=your-very-long-random-secret-key-here
DEBUG=False                         # Set to False in production

# ─── Database (Production — MySQL) ─────────────────────
DB_NAME=ems_db
DB_USER=ems_user
DB_PASSWORD=strong_password
DB_HOST=localhost
DB_PORT=3306

# ─── Static / Media Files ──────────────────────────────
STATIC_ROOT=staticfiles
MEDIA_ROOT=media

# ─── Email (Gmail SMTP) ────────────────────────────────
EMAIL_HOST_USER=yourapp@gmail.com
EMAIL_HOST_PASSWORD=your_app_password     # Use Gmail App Password, not your login password

# ─── Frontend URL (used in email reset links) ──────────
FRONTEND_URL=https://yourdomain.com/
```

> **Note:** The `firebase-service-account.json` file must be placed in the `backend/` root directory. Never commit this file to version control — it is already in `.gitignore`.

---

## API Reference

All REST API endpoints are prefixed with `/api/`. Authentication uses **JWT Bearer tokens**.

| Prefix | Module |
|---|---|
| `GET/POST /api/auth/token/` | Obtain JWT token pair |
| `POST /api/auth/token/refresh/` | Refresh access token |
| `GET /api/auth/me/` | Current user profile |
| `/api/employees/` | Employee CRUD |
| `/api/organization/` | Organization settings |
| `/api/attendance/` | Check-in, check-out, attendance records |
| `/api/calendar/` | Events, holidays |
| `/api/salary-management/` | Salary records, issue salary, tax bands |
| `/api/leave-tracker/` | Leave requests, approvals |
| `/api/task-management/` | Task CRUD |
| `/api/noticeboard/` | Notices, policies |
| `/api/notifications/` | In-app notifications, FCM device token registration |
| `/api/feedback/` | Employee feedback |
| `/api/fiscal-year/` | Fiscal year management |
| `/api/performance/` | Performance reviews |

---

## Salary Calculation Logic

The system uses a strict **30-day basis** for all monthly salary calculations.

### Formula

```
Daily Rate        = Base Salary / 30

Total Paid Days   = Site Attendance + Remote Attendance + Paid Leaves + Calendar Holidays

# Unpaid Half Leave Fix: if an employee clocked in on an unpaid half-leave day,
# subtract 0.5 from Total Paid Days.

Unpaid Absences   = max(0, Actual Days in Month − Total Paid Days)

Base Payout       = Base Salary − (Unpaid Absences × Daily Rate)

# Remote Swap Adjustment: swap Base Rate → Remote Rate for remote days
Remote Adjustment = Remote Attendance × (Remote Rate − Daily Rate)

Gross Salary      = Base Payout + Remote Adjustment
Net Salary        = Gross Salary + Incentive + Bonus − TDS − SSF − EPF
```

### Key Behaviors
- **Calendar Holidays** are automatically fetched (all Saturdays + custom marked holidays).
- **Mid-month joiners** are prorated automatically — missing days become unpaid absences.
- **Zero base salary** employees are fully supported (no division errors).
- **31-day months** are handled correctly — the 30-day divisor is fixed regardless of actual month length.

---

## Deployment Guidelines

### Backend (Production)

#### 1. Server Requirements
- Ubuntu 22.04 LTS (recommended)
- Python 3.11+
- MySQL 8.0 or PostgreSQL 14+
- Nginx + Gunicorn

#### 2. Configure Production Database

In `backend/base/settings.py`, uncomment and configure the MySQL/PostgreSQL section:

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST'),
        'PORT': config('DB_PORT'),
    }
}
```

#### 3. Production `.env` Changes

```ini
DEBUG=False
SECRET_KEY=<generate a 50+ character random key>
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com
CORS_ALLOW_ALL_ORIGINS=False         # Set to False and whitelist your frontend
```

> In `settings.py` change `CORS_ALLOW_ALL_ORIGINS = False` and add:
> ```python
> CORS_ALLOWED_ORIGINS = ['https://yourdomain.com']
> ```

#### 4. Install & Run with Gunicorn

```bash
# Install gunicorn (already in requirements.txt)
pip install gunicorn

# Collect static files
python manage.py collectstatic --noinput

# Run migrations
python manage.py migrate

# Start Gunicorn
gunicorn base.wsgi:application --bind 0.0.0.0:8000 --workers 3
```

#### 5. Nginx Configuration

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    location /static/ {
        alias /path/to/backend/staticfiles/;
    }

    location /media/ {
        alias /path/to/backend/media/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

#### 6. Systemd Service (Auto-restart)

```ini
# /etc/systemd/system/ems-backend.service
[Unit]
Description=EMS Django Backend
After=network.target

[Service]
User=www-data
WorkingDirectory=/path/to/ems-full-stack/backend
ExecStart=/path/to/venv/bin/gunicorn base.wsgi:application --bind 127.0.0.1:8000 --workers 3
Restart=always

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable ems-backend
sudo systemctl start ems-backend
```

---

### Frontend (Web — Flutter Build)

```bash
cd ems-full-stack/frontend

# 1. Update the production backend URL
# Edit lib/core/constants/app_constants.dart:
# static const String baseUrl = 'https://api.yourdomain.com';

# 2. Build for web (production)
flutter build web --release

# 3. The output is in: build/web/
# Upload the contents of build/web/ to your Nginx/Apache web root or CDN.
```

**Serving with Nginx:**
```nginx
server {
    listen 80;
    server_name app.yourdomain.com;
    root /var/www/ems-web/;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;  # Required for Flutter web routing
    }
}
```

---

### Frontend (Android APK)

```bash
cd ems-full-stack/frontend

# 1. Update base URL to production server
# Edit lib/core/constants/app_constants.dart

# 2. Configure signing keystore (for release)
# Add your keystore details to android/key.properties

# 3. Build release APK
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk

# 4. Build App Bundle (for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Roles & Permissions

| Role | Access Level |
|---|---|
| `super_admin` | Full access across all organizations |
| `org_admin` | Full access within their organization |
| `hr` | Can manage employees, leaves, salary, attendance |
| `employee` | Can view own data, submit leaves, check-in/out |

---

## Firebase Setup

Firebase powers **push notifications** (FCM) for the app.

### Backend
1. Go to [Firebase Console](https://console.firebase.google.com) → Project Settings → Service Accounts.
2. Generate a new private key and download the JSON file.
3. Place it as `backend/firebase-service-account.json`.
4. The backend uses `firebase-admin` SDK to send push notifications via APScheduler (triggered by calendar events).

### Frontend
1. Register your Flutter app in Firebase Console (Android + Web).
2. Download `google-services.json` and place it in `frontend/android/app/`.
3. The `firebase_options.dart` file in `lib/` is auto-generated by the FlutterFire CLI.
4. The `AndroidManifest.xml` includes:
   - `com.google.android.geo.API_KEY` — Google Maps API key
   - `com.google.firebase.messaging.default_notification_icon` — Custom notification icon (`ic_stat_notify`)

---

## Contributing

1. Create a feature branch from `master`.
2. Follow the existing folder structure (one folder per feature in `lib/features/`).
3. Backend: follow DRF ViewSet conventions, add migrations for any model changes.
4. Open a Merge Request on GitLab with a clear description of changes.

---

*Maintained by OmWay Technologies. Timezone: Asia/Kathmandu (NPT).*
