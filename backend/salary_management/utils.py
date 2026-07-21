from django.db.models import Avg, Sum
from organization.models import Organization
from .models import Salary, SalaryTransaction


def get_average_salary(organization) -> float | int:
    """
    Calculate the average basic salary for all employees in a given organization.

    Args:
        organization (Organization): The organization for which to calculate the average salary.

    Returns:
        float: The average basic salary of employees in the organization.
               Returns None if there are no salaries available for the organization.
    """
    average_salary = Salary.objects.filter(organization=organization).aggregate(
        Avg('basic_salary'))['basic_salary__avg'] or 0
    return round(average_salary, 2)


def get_total_salary(organization) -> float | int:
    """
    Calculate the total basic salary for all employees in a given organization.

    Args:
        organization (Organization): The organization for which to calculate the total salary.

    Returns:
        float: The total basic salary of all employees in the organization.
               Returns 0 if there are no salaries available for the organization.
    """
    total_salary = Salary.objects.filter(organization=organization).aggregate(
        Sum('basic_salary')
    )['basic_salary__sum'] or 0  # Return 0 if there are no salaries
    return total_salary


def get_net_salary_list(organization, year: int, month: int) -> list:
    salary_list = Salary.objects.filter(organization=organization)
    employee_salary_list = []
    for salary in salary_list:
        employee_salary_list.append({
            'salary': salary,
            'net_pay': Salary.calculate_net_salary(employee=salary.employee, year=year, month=month)
        })

    return employee_salary_list
