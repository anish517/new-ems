import os
import sys
import django
from datetime import datetime

# Setup Django environment
sys.path.append(r'f:\emp\ems-full-stack\backend')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'base.settings')
django.setup()

from attendance.models import Attendance
from organization.models import Employee
from django.test import RequestFactory
from attendance.api.views import RetrieveTotalWorkingHourAPIView

print("Django setup complete.")

def test_api():
    # Find any employee with attendance
    emp = Employee.objects.filter(attendance__isnull=False).first()
    if not emp:
        print("No employee with attendance found to test.")
        emp = Employee.objects.first()
        if not emp:
            print("No employees found.")
            return

    print(f"Testing for Employee ID: {emp.id} ({emp.user.email})")

    factory = RequestFactory()
    
    # We force authenticate using the employee's user
    def get_auth_request(url):
        req = factory.get(url)
        req.user = emp.user
        return req
    
    # Test without date range (default)
    request1 = get_auth_request(f'/api/attendance/total-working-hour/{emp.id}/')
    view = RetrieveTotalWorkingHourAPIView.as_view()
    response1 = view(request1, employee_id=emp.id)
    print("Response (No Date Range):", response1.data)

    # Just use current nepali date for start and end
    import nepali_datetime
    today = nepali_datetime.date.today()
    start = f"{today.year}-{today.month:02d}-01"
    end = f"{today.year}-{today.month:02d}-{today.day:02d}"

    request2 = get_auth_request(f'/api/attendance/total-working-hour/{emp.id}/?start_date={start}&end_date={end}')
    response2 = view(request2, employee_id=emp.id)
    print(f"Response (With Date Range {start} to {end}):", response2.data)

    request3 = get_auth_request(f'/api/attendance/total-working-hour/{emp.id}/?start_date=2000-01-01&end_date=2000-01-02')
    response3 = view(request3, employee_id=emp.id)
    print(f"Response (With Empty Date Range 2000-01-01 to 2000-01-02):", response3.data)

if __name__ == '__main__':
    test_api()
