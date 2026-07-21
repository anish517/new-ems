import json
import random
from datetime import timedelta
from nepali_datetime import datetime


def generate_dummy_attendance_data(employee_id=3, organization_id=1, start_date=None, end_date=None):
    # Validate and parse the dates
    start_date = datetime.strptime(start_date, "%Y-%m-%d").date()
    end_date = datetime.strptime(end_date, "%Y-%m-%d").date()

    # Initialize data list
    attendance_data = []

    current_date = start_date
    while current_date <= end_date:
        # Skip Saturdays (weekday value 5)
        if current_date.weekday() == 6:
            current_date += timedelta(days=1)
            continue

        check_in_time = datetime.combine(current_date, datetime.min.time()) + timedelta(
            hours=random.randint(10, 11), minutes=random.randint(0, 59)
        )
        check_out_time = check_in_time + timedelta(
            hours=random.randint(5, 6), minutes=random.randint(0, 59)
        )

        # Attendance entry for the day
        attendance_entry = {
            'organization_id': organization_id,
            'employee_id': employee_id,
            'date': str(current_date),
            'check_in_out': [
                {
                    'check_in': check_in_time.strftime("%H:%M:%S"),
                    'check_out': check_out_time.strftime("%H:%M:%S")
                }
            ]
        }
        attendance_data.append(attendance_entry)
        current_date += timedelta(days=1)

    # Write the data to a JSON file
    with open("attendance.json", 'w') as json_file:
        json.dump(attendance_data, json_file, indent=2)

    print(f"Data successfully exported to attendance.json")


dummy_data = generate_dummy_attendance_data(
    start_date="2081-01-01", end_date="2081-08-30")
