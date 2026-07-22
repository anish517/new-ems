import nepali_datetime
import datetime
from rest_framework import viewsets
from rest_framework import status
from datetime import timedelta
from rest_framework.decorators import action
from rest_framework.response import Response

from calendar_app.models import Event, Category
from .serializers import EventSerializer, CategorySerializer
from rest_framework.permissions import IsAuthenticated


class DateViewSet(viewsets.ViewSet):
    @action(detail=False, methods=['get'])
    def month_dates(self, request):
        import nepali_datetime
        # Get the month and year from the request's query parameters (already Nepali)
        year_np = int(request.query_params.get(
            'year', nepali_datetime.datetime.now().year))
        month_np = int(request.query_params.get(
            'month', nepali_datetime.datetime.now().month))
        
        # Generate list of dates for the given month and year
        dates = self.get_dates_for_month(year_np, month_np)
        first_day = nepali_datetime.datetime(year_np, month_np, 1)
        data = {
            'first_day': first_day.weekday(),
            'month': first_day.strftime("%B"),
            'year': first_day.strftime("%Y"),
            'no_of_saturdays': self.count_saturdays(year_np, month_np),
            'dates': dates,
        }
        return Response(data=data)

    # Helper function to generate list of dates for a given month and year
    def get_dates_for_month(self, year: int, month: int):
        import nepali_datetime
        import datetime
        first_day = nepali_datetime.date(year, month, 1)
        if month == 12:
            next_month = nepali_datetime.date(year + 1, 1, 1)
        else:
            next_month = nepali_datetime.date(year, month + 1, 1)
        
        last_day = next_month - datetime.timedelta(days=1)
        
        date_list = [(first_day + datetime.timedelta(days=i)).strftime('%Y-%m-%d')
                     for i in range((last_day - first_day).days + 1)]
        return date_list

    def count_saturdays(self, year, month):
        import nepali_datetime
        import datetime
        first_day = nepali_datetime.date(year, month, 1)
        if month == 12:
            next_month = nepali_datetime.date(year + 1, 1, 1)
        else:
            next_month = nepali_datetime.date(year, month + 1, 1)
            
        last_day = next_month - datetime.timedelta(days=1)
        days_in_month = last_day.day
        
        saturdays = sum(1 for i in range(1, days_in_month + 1) if nepali_datetime.date(year, month, i).weekday() == 5)
        return saturdays


class EventViewSet(viewsets.ViewSet):
    permission_classes = [IsAuthenticated]

    def _get_org(self, user):
        try:
            return user.employee.post.department.organization
        except Exception:
            return user.organization.first()

    def list(self, request):
        now_np = nepali_datetime.datetime.now()
        # Treat params as Nepali year/month directly (not Gregorian)
        year_np = int(request.query_params.get('year', now_np.year))
        month_np = int(request.query_params.get('month', now_np.month))

        # Validate range (Nepali years are 2000–2099)
        if not (2000 <= year_np <= 2099 and 1 <= month_np <= 12):
            year_np = now_np.year
            month_np = now_np.month

        org = self._get_org(request.user)
        queryset = []
        events = Event.objects.filter(organization=org).order_by('start')

        holidays = 0
        other_events = 0
        for event in events:
            if event.start.year == year_np and event.start.month == month_np:
                queryset.append(event)
                if event.is_holiday:
                    holidays += event.duration
                else:
                    other_events += 1

        serializer = EventSerializer(queryset, many=True)

        data = {
            'events': serializer.data,
            'holidays': holidays + self.count_saturdays(year_np, month_np),
            'working_days': self.total_days_in_month(year_np, month_np) - (holidays + self.count_saturdays(year_np, month_np)),
            'other_events': other_events,
        }
        return Response(data=data)


    def total_days_in_month(self, year, month):
        # Start on the first day of the month
        first_day = datetime.date(year, month, 1)

        # Find the number of days in the month by advancing to the next month and subtracting one day
        if month == 12:
            next_month = datetime.date(year + 1, 1, 1)
        else:
            next_month = datetime.date(year, month + 1, 1)

        days_in_month = (next_month - first_day).days
        return days_in_month - 1

    def count_saturdays(self, year, month):

        days_in_month = self.total_days_in_month(year, month)

        # Count Saturdays
        saturdays = sum(1 for day in range(1, days_in_month + 1)
                        if datetime.date(year, month, day).weekday() == 5)
        return saturdays

    def retrieve(self, request, pk=None):
        try:
            event = Event.objects.get(pk=pk)
        except Event.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)
        serializer = EventSerializer(event)
        return Response(serializer.data, status=status.HTTP_200_OK)


class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

    def get_queryset(self):
        organization = self.request.user.employee.organization
        return Category.objects.filter(organization=organization)
