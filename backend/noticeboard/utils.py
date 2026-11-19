import nepali_datetime
from organization.models import Organization
from .models import Notice


def get_notices(organization: Organization, year: int = None, month: int = None):
    today = nepali_datetime.date.today()
    year = today.year if year is None else year
    month = today.month if month is None else month
    notice_qs = Notice.objects.filter(organization=organization)
    id_list = []
    for notice in notice_qs:
        if notice.date.year == year and notice.date.month == month:
            id_list.append(notice.id)

    return notice_qs.filter(id__in=id_list)
