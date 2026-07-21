import json
from attendance.models import Attendance, CheckInOut  # Adjust with your app name
from datetime import datetime


def load_attendance_data(file_path):
    with open(file_path, 'r') as json_file:
        data = json.load(json_file)

        for record in data:
            # Create or get Attendance instance
            attendance, created = Attendance.objects.get_or_create(
                organization_id=record['organization_id'],
                employee_id=record['employee_id'],
                date=record['date']
            )

            check_in_out = record['check_in_out'][0]
            CheckInOut.objects.create(
                attendance=attendance,
                check_in=datetime.strptime(
                    check_in_out['check_in'], "%H:%M:%S").time(),
                check_out=datetime.strptime(
                    check_in_out['check_out'], "%H:%M:%S").time()
            )

# Usage
# load_attendance_data('/home/aryan/Desktop/projects/omway_ems/attendance.json')
