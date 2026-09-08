#!/usr/bin/env python
"""Post-deploy smoke test for omway-internal.

Runs as omway from /srv/ems/app:
    su omway -c "cd /srv/ems/app && /srv/ems/venv/bin/python /srv/ems/deploy/4-smoke.py"

Mints JWTs server-side for an org admin and a plain employee (no passwords needed), then
exercises real endpoints through nginx on 127.0.0.1 with the production Host header. Prints
status codes and counts only — never row contents. The one write it attempts is a plain
employee approving a leave request, which must be refused before anything is saved; the
row is re-read afterwards to prove it. Exit 1 on any failure.
"""
import os
import sys

import django

# The script lives in /srv/ems/deploy, so sys.path[0] is not the app; put it there explicitly.
APP_DIR = os.environ.get("EMS_APP_DIR", "/srv/ems/app")
sys.path.insert(0, APP_DIR)
os.chdir(APP_DIR)
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "base.settings")
django.setup()

import requests  # noqa: E402  (after django.setup on purpose)
from django.contrib.auth import get_user_model  # noqa: E402
from rest_framework_simplejwt.tokens import RefreshToken  # noqa: E402

from leave_management.models import LeaveRequest  # noqa: E402
from organization.models import Employee, Organization  # noqa: E402

# Port 80 now 301s to https (certbot --redirect), so talk to 443 on loopback. TLS is still
# fully verified: SNI is sent as the public name so nginx presents the EMS certificate, and
# the chain and hostname are checked against that name rather than 127.0.0.1. This is also
# exactly what Cloudflare's Full (strict) mode verifies at the origin.
BASE = os.environ.get("EMS_SMOKE_BASE", "https://127.0.0.1")
HOST = "ems.omwaytechnologies.com"


class OriginAdapter(requests.adapters.HTTPAdapter):
    def init_poolmanager(self, *args, **kwargs):
        kwargs["server_hostname"] = HOST
        kwargs["assert_hostname"] = HOST
        return super().init_poolmanager(*args, **kwargs)


SESSION = requests.Session()
SESSION.mount("https://", OriginAdapter())

org = Organization.objects.first()
# Production has no admin_users rows: admin access is carried by is_superuser. Try both.
admin = org.admin_users.first() or get_user_model().objects.filter(is_superuser=True).first()
plain = (
    Employee.objects.exclude(user__in=org.admin_users.all())
    .exclude(user__is_superuser=True)
    .select_related("user")
    .first()
    .user
)
leave = getattr(LeaveRequest, "all_objects", LeaveRequest.objects).order_by("id").first()
ADMIN = str(RefreshToken.for_user(admin).access_token)
PLAIN = str(RefreshToken.for_user(plain).access_token)
fails = []


def call(label, method, path, token=None, expect=(), **kw):
    headers = {"Host": HOST}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = SESSION.request(method, BASE + path, headers=headers, timeout=30, allow_redirects=False, **kw)
    ct = r.headers.get("content-type", "")
    payload = ""
    if "json" in ct:
        try:
            d = r.json()
            if isinstance(d, dict) and "count" in d:
                payload = f"count={d['count']}"
            elif isinstance(d, list):
                payload = f"list={len(d)}"
            elif isinstance(d, dict):
                payload = "keys=" + ",".join(list(d)[:4])
        except ValueError:
            pass
    elif "csv" in ct:
        payload = f"csv_rows={r.text.count(chr(10))}"
    ok = r.status_code in expect
    if not ok:
        fails.append(label)
    print(f"  {'ok  ' if ok else 'FAIL'} {label:54s} {r.status_code}  {payload}")
    if not ok and r.text:
        print(f"       body: {r.text[:200]!r}")
    return r


print(
    f"admin: superuser={admin.is_superuser} has_employee={hasattr(admin, 'employee')} | "
    f"plain: org_admin={plain.organization.exists()} | leave pk={leave.id if leave else None}"
)
print("== admin, real data")
call("GET /api/auth/me/", "GET", "/api/auth/me/", ADMIN, {200})
call("GET /api/organization/employees/", "GET", "/api/organization/employees/", ADMIN, {200})
call("GET /api/leave-tracker/leave-requests/", "GET", "/api/leave-tracker/leave-requests/", ADMIN, {200})
call("GET /api/noticeboard/notices/", "GET", "/api/noticeboard/notices/", ADMIN, {200})
call("GET /api/task-management/tasks/", "GET", "/api/task-management/tasks/", ADMIN, {200})
call("GET employees export-csv via ?token=", "GET", f"/api/organization/employees/export-csv/?token={ADMIN}", None, {200})
call(
    "GET salary generate-report (date range) via ?token=",
    "GET",
    f"/api/salary/generate-report/?token={ADMIN}&start_date=2083-01-01&end_date=2083-06-30",
    None,
    {200},
)

# Admin leave views. Both returned nothing for the production admin (superuser, no Employee,
# empty admin_users) until ca64d1e. Note: /leave-summary/ recomputes and persists LeaveBalance
# rows on every GET -- that is the application's own behaviour on every page view.
r = call("GET /api/leave-tracker/leave-summary/ (Staff Quotas)", "GET", "/api/leave-tracker/leave-summary/", ADMIN, {200})
if r.status_code == 200 and isinstance(r.json(), list) and len(r.json()) == 0:
    fails.append("leave-summary is empty for the admin")
    print("  FAIL leave-summary returned [] -- Staff Quotas tab would be empty")
r = call("GET leave-requests (whole FY, admin)", "GET", "/api/leave-tracker/leave-requests/?start_date=2083-01-01&end_date=2083-12-30", ADMIN, {200})
if r.status_code == 200 and isinstance(r.json(), dict) and r.json().get("count", 0) == 0:
    fails.append("leave-requests empty for the admin")
    print("  FAIL leave-requests count=0 for the admin over the whole fiscal year")

print("== plain employee: authorization gates")
call("GET /api/auth/me/", "GET", "/api/auth/me/", PLAIN, {200})
call("GET employees export-csv -> refused", "GET", "/api/organization/employees/export-csv/", PLAIN, {403})
call("GET salary generate-report -> refused", "GET", "/api/salary/generate-report/", PLAIN, {403})
if leave is not None:
    before = leave.is_approved
    call(
        f"PATCH leave {leave.id} final_approve -> refused",
        "PATCH",
        f"/api/leave-tracker/update/{leave.id}/",
        PLAIN,
        {403},
        json={"action": "final_approve"},
    )
    leave.refresh_from_db()
    unchanged = leave.is_approved == before
    if not unchanged:
        fails.append("leave request was mutated")
    print(f"  {'ok  ' if unchanged else 'FAIL'} leave {leave.id} unchanged (is_approved={leave.is_approved})")

print("== unauthenticated")
call("GET /api/auth/me/ -> 401", "GET", "/api/auth/me/", None, {401})
call("GET / -> 302 /app/", "GET", "/", None, {302})
call("GET /app/ -> 200", "GET", "/app/", None, {200})

print("== " + ("ALL PASSED" if not fails else "FAILED: " + "; ".join(fails)))
sys.exit(1 if fails else 0)
