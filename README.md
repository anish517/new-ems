# EMS Full Stack — Employee Management System
## Django REST API + Flutter (Android / iOS / Web)

```
ems-full-stack/
├── backend/        Django 5 REST API with JWT
└── frontend/       Flutter 3.44 app (Android, iOS, Web)
```

---

## 🚀 Quick Start

### 1. Backend (Django API)

```powershell
cd backend

# Create & activate virtual environment (Python 3.13)
python -m venv venv
.\venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run migrations
python manage.py migrate

# Create admin user
python manage.py createsuperuser

# Start server
python manage.py runserver 8000
```

> API available at: `http://127.0.0.1:8000/`
> Admin panel: `http://127.0.0.1:8000/supa-admin/`

---

### 2. Flutter App

```powershell
cd frontend

# Install dependencies
flutter pub get

# Run on Android
flutter run -d android

# Run on iOS (macOS only)
flutter run -d ios

# Run on Web
flutter run -d chrome

# Build APK
flutter build apk --release
```

> **Important:** Set your server IP in [lib/core/constants/app_constants.dart](frontend/lib/core/constants/app_constants.dart):
> ```dart
> static const String baseUrl = 'http://YOUR_SERVER_IP:8000';
> ```

---

## 🔑 Key API Endpoints

### Authentication
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/token/` | Login → get JWT tokens |
| `POST` | `/api/auth/token/refresh/` | Refresh access token |
| `GET`  | `/api/auth/me/` | Current user profile + role |
| `PATCH`| `/api/auth/me/` | Update own profile |

### Attendance (GPS-based)
| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/attendance/check-in/` | Check in with `{latitude, longitude}` |
| `POST` | `/api/attendance/check-out/` | Check out with `{latitude, longitude}` |
| `GET`  | `/api/attendance/total-working-hour/{id}/` | Monthly working hours |
| `GET`  | `/api/attendance/yearly/{id}/` | Yearly attendance history |

### All Modules
| Module | Base URL |
|--------|----------|
| Auth / Users | `/api/auth/` |
| Organization / Employees | `/api/organization/` |
| Attendance | `/api/attendance/` |
| Leave Management | `/api/leave-tracker/` |
| Salary | `/api/salary-management/` |
| Tasks & Projects | `/api/task-management/` |
| Calendar / Events | `/api/calendar/` |
| Noticeboard | `/api/noticeboard/` |
| Notifications | `/api/notifications/` |
| Feedback / Complaints | `/api/feedback/` |
| Fiscal Year | `/api/fiscal-year/` |

---

## 👥 Role-Based Access

| Role | How Determined | Access |
|------|---------------|--------|
| `super_admin` | `is_superuser=True` | Everything |
| `org_admin` | Listed in `Organization.admin_users` | Full org management |
| `employee` | Has `Employee` record | Own data only |

Role is returned from `/api/auth/me/` in the `role` field.

---

## 📱 Flutter App Structure

```
frontend/lib/
├── core/
│   ├── constants/      API endpoints, storage keys, roles
│   ├── theme/          Dark/light theme, colors (AppColors)
│   ├── services/       ApiService (Dio + JWT), AuthService
│   └── router.dart     GoRouter with role-based redirect
├── features/
│   ├── auth/           Login, providers, UserProfile model
│   ├── dashboard/      Employee + Admin dashboards
│   ├── attendance/     GPS check-in/out screen
│   ├── leave/          Leave requests + approval
│   ├── salary/         Payslip viewer
│   ├── tasks/          Kanban task board
│   ├── calendar/       Nepali BS calendar + events
│   ├── noticeboard/    Organization notices
│   ├── notifications/  Notification list + badge
│   ├── feedback/       Complaints + replies
│   ├── employee/       Employee management (admin)
│   └── profile/        User profile + logout
└── shared/
    └── widgets/        Common widgets (loading, error, empty state)
```

---

## 🏗️ Architecture

```
Flutter App
    │
    ├── Dio HTTP Client (auto JWT refresh on 401)
    │
    └── Django REST API
            │
            ├── JWT (SimpleJWT) authentication
            ├── Role detection via /api/auth/me/
            ├── GPS radius check (Haversine)
            ├── Nepali BS calendar date fields
            └── SQLite (dev) / MySQL (prod)
```

---

## ⚙️ Environment Variables (`backend/.env`)

```env
SECRET_KEY=your-secret-key-here
DEBUG=True
STATIC_ROOT=staticfiles
MEDIA_ROOT=media

# For MySQL production:
# DB_NAME=ems_db
# DB_USER=root
# DB_PASSWORD=yourpassword
# DB_HOST=localhost
# DB_PORT=3306
```

---

## 📦 Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | Django 5.0 + DRF 3.15 |
| Auth | JWT (djangorestframework-simplejwt) |
| Database | SQLite (dev) / MySQL (prod) |
| Date System | Nepali/BS Calendar |
| Frontend | Flutter 3.44 |
| State Mgmt | Riverpod |
| HTTP | Dio (with JWT interceptor) |
| Navigation | GoRouter |
| Storage | flutter_secure_storage |
| GPS | geolocator |

---

## 🔧 Default Login

After running migrations and creating superuser:
- **Email:** your superuser email
- **Password:** your superuser password

Or use the Django admin at `/supa-admin/` to create employees.
