import nepali_datetime
from organization.models import Organization
from .models import Notice


TODAY = nepali_datetime.date.today()


def get_notices(organization: Organization, year: int = TODAY.year, month: int = TODAY.month):
    notice_qs = Notice.objects.filter(organization=organization)
    id_list = []
    for notice in notice_qs:
        if notice.date.year == year and notice.date.month == month:
            id_list.append(notice.id)

    return notice_qs.filter(id__in=id_list)
