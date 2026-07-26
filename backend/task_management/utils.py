import nepali_datetime
from organization.models import Organization, Employee

from .models import Project, Task


TODAY = nepali_datetime.date.today()


def get_employees_list_with_task(organization: Organization) -> list:
    employees = organization.employees
    result = []
    for employee in employees:
        tasks = Task.objects.filter(assigned_to=employee)
        data = {
            'id': employee.id,
            'name': employee.user.full_name,
            'email': employee.official_email,
            'profile_picture': getattr(employee.user.profile_picture, 'url') if employee.user.profile_picture else None,
            'pending_tasks': tasks.filter(status='to-do'),
            'on_going_tasks': tasks.filter(status='in-progress'),
            'completed_tasks': tasks.filter(status='done'),
        }
        result.append(data)
    return result


def get_employee_task_summary(employee: Employee, year: int = TODAY.year, month: int = TODAY.month):
    tasks = Task.objects.filter(assigned_to=employee)
    filtered_tasks_id = []

    for task in tasks:
        if task.planned_start_date.year == year and task.planned_start_date.month == month:
            filtered_tasks_id.append(task.pk)

    tasks = tasks.filter(id__in=filtered_tasks_id)

    if tasks.count() == 0:
        data = {
            'name': employee.user.full_name,
            'email': employee.official_email,
            'profile_picture': getattr(employee.user.profile_picture, 'url') if employee.user.profile_picture else None,
            'pending_tasks': 0,
            'on_going_tasks': 0,
            'completed_tasks': 100
        }
    else:
        data = {
            'name': employee.user.full_name,
            'email': employee.official_email,
            'profile_picture': getattr(employee.user.profile_picture, 'url') if employee.user.profile_picture else None,
            'pending_tasks': tasks.filter(status='to-do').count(),
            'on_going_tasks': tasks.filter(status='in-progress').count(),
            'completed_tasks': tasks.filter(status='done').count()
        }

    return data


def get_organization_task_summary(organization: Organization, year: int = TODAY.year, month: int = TODAY.month):
    tasks = Task.objects.filter(
        created_by__post__department__organization=organization)
        
    filtered_tasks_id = []
    for task in tasks:
        if getattr(task.planned_start_date, 'year', None) == year and getattr(task.planned_start_date, 'month', None) == month:
            filtered_tasks_id.append(task.pk)
    tasks = tasks.filter(id__in=filtered_tasks_id)

    data = {
        'name': organization.name,
        'pending_tasks': tasks.filter(status='to-do').count(),
        'on_going_tasks': tasks.filter(status='in-progress').count(),
        'completed_tasks': tasks.filter(status='done').count()
    }
    return data


def get_project_task_summary(project: Project, year: int = TODAY.year, month: int = TODAY.month):
    tasks = Task.objects.filter(project=project)
    
    filtered_tasks_id = []
    for task in tasks:
        if getattr(task.planned_start_date, 'year', None) == year and getattr(task.planned_start_date, 'month', None) == month:
            filtered_tasks_id.append(task.pk)
    tasks = tasks.filter(id__in=filtered_tasks_id)

    data = {
        'id': project.pk,
        'name': project.title,
        'pending_tasks': tasks.filter(status='to-do').count(),
        'on_going_tasks': tasks.filter(status='in-progress').count(),
        'completed_tasks': tasks.filter(status='done').count()
    }
    return data


def get_organization_project_summary(organization: Organization) -> list:

    projects = Project.objects.filter(organization=organization)

    summary = []

    for project in projects:
        data = {
            'id': project.id,
            'title': project.title,
            'symbol': project.abbreviation,
            'todo': project.get_pending_task().count(),
            'in_progress': project.get_on_going_tasks().count(),
            'completed': project.get_completed_tasks().count()
        }
        summary.append(data)

    return summary
