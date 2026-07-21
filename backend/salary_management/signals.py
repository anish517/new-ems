from django.db.models.signals import post_save
from django.dispatch import receiver

from organization.models import Employee
from .models import Salary


@receiver(post_save, sender=Employee)
def create_employee_salary_instance(sender, instance: Employee, created: bool, **kwargs):
    if created:
        Salary.objects.create(
            organization=instance.organization,
            employee=instance,
            basic_salary=0
        )
