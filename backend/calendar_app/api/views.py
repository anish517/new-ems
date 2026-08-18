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
        
        saturdays = sum(1 for i in range(1, days_in_month + 1) if nepali_datetime.date(year, month, i).weekday() == 6)
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
        import nepali_datetime
        import datetime
        first_day = nepali_datetime.date(year, month, 1)
        if month == 12:
            next_month = nepali_datetime.date(year + 1, 1, 1)
        else:
            next_month = nepali_datetime.date(year, month + 1, 1)
        last_day = next_month - datetime.timedelta(days=1)
        return last_day.day

    def count_saturdays(self, year, month):
        import nepali_datetime
        days_in_month = self.total_days_in_month(year, month)
        saturdays = sum(1 for day in range(1, days_in_month + 1)
                        if nepali_datetime.date(year, month, day).weekday() == 6)
        return saturdays

    def _is_admin(self, user):
        return (
            user.is_superuser or 
            user.organization.exists() or 
            getattr(user, 'is_hr', False) or 
            (hasattr(user, 'employee') and user.employee.post and getattr(user.employee.post, 'can_manage_calendar', False))
        )

    def create(self, request):
        if not self._is_admin(request.user):
            return Response(
                {'detail': 'You do not have permission to add calendar events or holidays. Only administrators can manage the calendar.'},
                status=status.HTTP_403_FORBIDDEN
            )

        import nepali_datetime
        title = request.data.get('title')
        start_str = request.data.get('start')
        end_str = request.data.get('end', start_str)
        is_important = request.data.get('is_important', False)
        if str(is_important).lower() == 'true': is_important = True
        elif str(is_important).lower() == 'false': is_important = False

        is_holiday = request.data.get('is_holiday', False)
        if str(is_holiday).lower() == 'true': is_holiday = True
        elif str(is_holiday).lower() == 'false': is_holiday = False
        
        try:
            y, m, d = map(int, start_str.split('-'))
            start_date = nepali_datetime.date(y, m, d)
            y2, m2, d2 = map(int, end_str.split('-'))
            end_date = nepali_datetime.date(y2, m2, d2)
        except Exception as e:
            return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)
            
        org = self._get_org(request.user)
        event = Event.objects.create(
            title=title,
            start=start_date,
            end=end_date,
            is_important=is_important,
            is_holiday=is_holiday,
            organization=org
        )
        serializer = EventSerializer(event)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def retrieve(self, request, pk=None):
        try:
            event = Event.objects.get(pk=pk)
        except Event.DoesNotExist:
            return Response(status=status.HTTP_404_NOT_FOUND)
        serializer = EventSerializer(event)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def destroy(self, request, pk=None):
        if not self._is_admin(request.user):
            return Response(
                {'detail': 'You do not have permission to delete calendar events.'},
                status=status.HTTP_403_FORBIDDEN
            )
        try:
            event = Event.objects.get(pk=pk)
            event.delete()
            return Response(status=status.HTTP_204_NO_CONTENT)
        except Event.DoesNotExist:
            return Response({'error': 'Event not found'}, status=status.HTTP_404_NOT_FOUND)


class CategoryViewSet(viewsets.ModelViewSet):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer

    def get_queryset(self):
        organization = self.request.user.employee.organization
        return Category.objects.filter(organization=organization)
