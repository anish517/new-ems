import os
import django
import sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'base.settings')
django.setup()

from organization.models import Organization, Employee
from noticeboard.models import Notice

print("Organizations:")
for org in Organization.objects.all():
    print(f"Org {org.id}: {org.name}, Admins: {[u.email for u in org.admin_users.all()]}")

print("\nEmployees:")
for emp in Employee.objects.all():
    org = emp.organization
    print(f"Emp {emp.id} ({emp.user.email}): Org -> {org.name if org else 'None'} (ID: {org.id if org else 'None'})")

print("\nNotices:")
for n in Notice.objects.all():
    print(f"Notice {n.id}: '{n.title}', Org -> {n.organization.name if n.organization else 'None'}")
