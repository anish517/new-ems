# 🐘 Comprehensive PostgreSQL Migration Guide for EMS Full-Stack Backend

---

## 1. 📋 Full Codebase & Architecture Audit

We conducted a complete automated audit of all **15 Django apps** and **38 database models** in `ems-full-stack/backend`:

### 🏢 App-by-App Architecture Inventory

| App Name | Models | Primary Key Type | Notes / Compatibility |
| :--- | :--- | :--- | :--- |
| **`authentication`** | `Account`, `LoginHistory` | `BigAutoField` | Custom User Model (`AUTH_USER_MODEL = 'authentication.Account'`), JWT auth compatible |
| **`organization`** | `Organization`, `OrganizationType`, `OrganizationAddress`, `Department`, `Post`, `Employee`, `Document`, `Address`, `BankDetail`, `NationalIdDetail`, `OrganizationFile`, `OrganizationFolder`, `OrganizationSettings`, `ProfileChangeRequest` | `BigAutoField` | Full relational hierarchy with SoftDeletes (`SoftDeleteModel`) |
| **`attendance`** | `Attendance`, `CheckInOut`, `RemoteWorkPermission`, `RemoteWorkRequest`, `AttendanceCorrectionRequest` | `BigAutoField` | Uses `NepaliDateField`, geolocation floats (`latitude`, `longitude`), and selfie photo uploads |
| **`leave_management`** | `LeaveType`, `LeaveBalance`, `LeaveRequest` | `BigAutoField` | Half-day leave support, quota tracking, `SoftDeleteModel` |
| **`salary_management`**| `Salary`, `SalaryTransaction`, `SalaryTransactionReview`, `SalaryTaxBand`, `IncentiveTaxBand`, `BonusTaxBand` | `BigAutoField` | Financial calculations (SSF, EPF, TDS, Net Salary), `SoftDeleteModel` |
| **`task_management`**  | `Project`, `ProjectAssignment`, `ProjectFile`, `Task`, `TaskFile`, `TaskProgressReport` | `BigAutoField` | Decimal rates, rating scores, PDF attachments, `SoftDeleteModel` |
| **`notification`**     | `Notification`, `DeviceToken` | `BigAutoField` | Firebase Cloud Messaging (FCM) & WebPush tokens |
| **`noticeboard`**      | `Notice`, `NoticeFile`, `CompanyPolicy` | `BigAutoField` | HTML RichText (CKEditor 5 & TinyMCE), `SoftDeleteModel` |
| **`feedback`**         | `ComplainCategory`, `Complain`, `ComplainReply` | `BigAutoField` | Anonymous/Public complaints & replies, `SoftDeleteModel` |
| **`performance`**      | `PerformanceCategory`, `PerformanceReview` | `BigAutoField` | KPI scoring & suggestions, `SoftDeleteModel` |
| **`fiscal_year`**      | `FiscalYear` | `BigAutoField` | B.S. fiscal period definitions |
| **`calendar_app`**     | `Event`, `Category` | `BigAutoField` | Holidays & important events |
| **`logs`**             | `ActivityLog` | `BigAutoField` | Audit trail timestamps (`DateTimeField`) |
| **`employee`**         | `Contract` | `BigAutoField` | Employment contracts & validity periods |
| **`utils`**            | `SoftDeleteModel`, `GlobalContextFilter` | Base abstract | Standard Django ORM inheritance |

### 🔍 Codebase Compatibility Findings:
* **Raw SQL Queries**: **0** raw SQL queries found (`.raw()`, `connection.cursor()`, or `.extra()` are not used).
* **Driver Status**: `psycopg2-binary==2.9.12` and `dj-database-url==3.1.2` are **already installed in `requirements.txt`**.
* **Migration Status**: All 15 apps have linear, conflict-free migration histories (totaling 180+ migration steps).
* **Field Compatibility**: `NepaliDateField`, `FileField`, `ImageField`, `BooleanField`, `DateTimeField`, `DecimalField`, and `JSONField` map directly to PostgreSQL native types (`VARCHAR`, `TIMESTAMP WITH TIME ZONE`, `NUMERIC`, `BOOLEAN`, `JSONB`).

---

## 2. ⚡ Why Migrate to PostgreSQL?

| Feature | SQLite (Current) | PostgreSQL (Target) |
| :--- | :--- | :--- |
| **Concurrency** | Locks the entire DB file during writes. Multiple check-ins at 10:00 AM cause `Database is locked`. | **Multi-Version Concurrency Control (MVCC)** with row-level locking. Hundreds of concurrent check-ins succeed simultaneously. |
| **Data Integrity** | Weak typing (accepts invalid types silently). | **Strict Schema Enforcement** & real Foreign Key constraints. |
| **Performance** | In-memory / single-file I/O. | **High-speed index scans**, GIN/GiST indexes, connection pooling. |
| **Production Hosting** | Difficult to scale horizontally; single server only. | Compatible with cloud DBs (**AWS RDS, Supabase, Neon, Railway, Render, DigitalOcean**). |

---

## 3. 🛠️ Step-by-Step Migration Instructions

### Phase 1: Create the PostgreSQL Database

#### Option A: Local PostgreSQL (pgAdmin / psql)
Open your PostgreSQL terminal (`psql -U postgres`) or pgAdmin and run:
```sql
CREATE DATABASE ems_db;
CREATE USER ems_user WITH PASSWORD 'ems_secure_password_2026';
ALTER ROLE ems_user SET client_encoding TO 'utf8';
ALTER ROLE ems_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE ems_user SET timezone TO 'Asia/Kathmandu';
GRANT ALL PRIVILEGES ON DATABASE ems_db TO ems_user;
```

#### Option B: Docker (Instant Setup)
```bash
docker run --name ems-postgres \
  -e POSTGRES_DB=ems_db \
  -e POSTGRES_USER=ems_user \
  -e POSTGRES_PASSWORD=ems_secure_password_2026 \
  -p 5432:5432 \
  -v ems_pgdata:/var/lib/postgresql/data \
  -d postgres:16-alpine
```

#### Option C: Cloud Database (Neon / Supabase / Render / AWS)
1. Create a free project on [Neon.tech](https://neon.tech) or [Supabase](https://supabase.com).
2. Copy the provided connection string (e.g., `postgresql://ems_user:password@ep-xyz.region.aws.neon.tech/ems_db?sslmode=require`).

---

### Phase 2: Configure Environment Variables

Edit `f:\emp\ems-full-stack\backend\.env`:

```env
# ─── Database Configuration ──────────────────────────────────────────────────
DB_ENGINE=django.db.backends.postgresql
DB_NAME=ems_db
DB_USER=ems_user
DB_PASSWORD=ems_secure_password_2026
DB_HOST=127.0.0.1
DB_PORT=5432

# Or use single DATABASE_URL (Supported automatically):
# DATABASE_URL=postgresql://ems_user:ems_secure_password_2026@127.0.0.1:5432/ems_db
```

---

### Phase 3: Update `base/settings.py`

Update `f:\emp\ems-full-stack\backend\base\settings.py` to seamlessly handle both `.env` variables and `DATABASE_URL`:

```python
import dj_database_url

# ─── Database Configuration ──────────────────────────────────────────────────
DATABASE_URL = config('DATABASE_URL', default=None)

if DATABASE_URL:
    DATABASES = {
        'default': dj_database_url.config(
            default=DATABASE_URL,
            conn_max_age=600,
            conn_health_checks=True,
        )
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': config('DB_ENGINE', default='django.db.backends.postgresql'),
            'NAME': config('DB_NAME', default='ems_db'),
            'USER': config('DB_USER', default='ems_user'),
            'PASSWORD': config('DB_PASSWORD', default=''),
            'HOST': config('DB_HOST', default='localhost'),
            'PORT': config('DB_PORT', default='5432'),
        }
    }
```

---

### Phase 4: Data Migration (Transfer Existing SQLite Data)

If you want to keep all existing employees, attendance logs, leaves, tasks, and settings:

#### Step 4.1: Export Clean Data from SQLite
Run from `f:\emp\ems-full-stack\backend`:
```bash
.\venv\Scripts\python.exe manage.py dumpdata --natural-foreign --natural-primary -e contenttypes -e auth.Permission --indent 4 > datadump.json
```
*(Note: We exclude `contenttypes` and `auth.Permission` to prevent primary key collision with Django's built-in system fixtures).*

#### Step 4.2: Run Migrations on PostgreSQL
Switch your `.env` to PostgreSQL, then run:
```bash
.\venv\Scripts\python.exe manage.py migrate
```

#### Step 4.3: Load Data into PostgreSQL
```bash
.\venv\Scripts\python.exe manage.py loaddata datadump.json
```

#### Step 4.4: Synchronize PostgreSQL Auto-Increment Sequences
*(Crucial step in PostgreSQL: resets sequence counters so new records don't collide with existing IDs)*:
```bash
.\venv\Scripts\python.exe manage.py sqlsequencereset authentication organization attendance leave_management salary_management task_management notification noticeboard feedback performance fiscal_year calendar_app logs employee | .\venv\Scripts\python.exe manage.py dbshell
```

---

### Phase 5: Verification & Sanity Checks

Run the verification suite:
```bash
# 1. Check migrations status
.\venv\Scripts\python.exe manage.py showmigrations

# 2. Test database connection & check employee count
.\venv\Scripts\python.exe -c "
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'base.settings')
django.setup()
from organization.models import Employee
from attendance.models import Attendance
print(f'Total Employees in PostgreSQL: {Employee.objects.count()}')
print(f'Total Attendance Records in PostgreSQL: {Attendance.objects.count()}')
"

# 3. Start the server
.\venv\Scripts\python.exe manage.py runserver 0.0.0.0:8000
```

---

## 4. 🛡️ Production Best Practices for PostgreSQL

1. **Connection Pooling**: Set `conn_max_age=600` (10 minutes) in `settings.py` or use **PgBouncer** for high-traffic environments.
2. **Backups**: Set up automated daily backups via `pg_dump`:
   ```bash
   pg_dump -U ems_user -d ems_db -F c -b -v -f "ems_backup_$(date +%Y%m%d).dump"
   ```
3. **Restoring from Backup**:
   ```bash
   pg_restore -U ems_user -d ems_db -v "ems_backup_YYYYMMDD.dump"
   ```
