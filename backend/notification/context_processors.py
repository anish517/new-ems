from nepali_datetime import datetime


def notification_context(request):
    if request.user.is_authenticated and hasattr(request.user, 'employee'):
        return {
            "current_date": datetime.today().strftime("%Y-%m-%d"),
            "current_date_in_words": datetime.today().strftime("%N %D"),
            "employee": request.user.employee,
        }
    else:
        return {}


def greeting_context_processor(request):
    current_hour = datetime.now().hour
    if 5 <= current_hour < 12:
        greeting = "Good morning"
    elif 12 <= current_hour < 17:
        greeting = "Good afternoon"
    else:
        greeting = "Good evening"

    return {"greeting": greeting}
