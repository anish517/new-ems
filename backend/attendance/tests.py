import nepali_datetime
from datetime import time
from datetime import timedelta
from django.test import TestCase
from attendance.models import Attendance, CheckInOut
from organization.models import Organization, Employee

# Create your tests here.

def create_dummy_attendance():
    counter = 0
    current_date = nepali_datetime.date(2080, 3, 1)
    while(counter < 25):
        organization = Organization.objects.get(id=1)
        employee = Employee.objects.get(id=6)
        attendance = Attendance.objects.create(organization=organization, employee=employee, date=current_date)
        check_in = time(10,30)
        check_out = time(17,30)
        CheckInOut.objects.create(attendance=attendance, check_in=check_in, check_out=check_out)

        time_delta = timedelta(days=5)
        current_date = current_date + time_delta

create_dummy_attendance()