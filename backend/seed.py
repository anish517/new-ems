import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "base.settings")
django.setup()

from organization.models import Organization, Department, Post, OrganizationType

org_type, _ = OrganizationType.objects.get_or_create(name='Tech')
org, _ = Organization.objects.get_or_create(name='Default Org', type_of_organization=org_type)
dept, _ = Department.objects.get_or_create(department_name='Engineering', organization=org)
post, _ = Post.objects.get_or_create(title='Software Engineer', department=dept)
print('Seeded Post ID:', post.id)
