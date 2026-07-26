from rest_framework.filters import BaseFilterBackend
from django.db.models import Q
import nepali_datetime
import datetime

class GlobalContextFilter(BaseFilterBackend):
    """
    Combines Nepali Month/Year filtering and Soft Delete status filtering 
    so they don't overwrite each other's querysets.
    """
    def filter_queryset(self, request, queryset, view):
        nepali_year = request.query_params.get('nepali_year')
        nepali_month = request.query_params.get('nepali_month')
        status_param = request.query_params.get('status')
        
        # 1. Base Queryset adjustment for Soft Deletes
        has_soft_delete = hasattr(queryset.model, 'is_deleted')
        if has_soft_delete and hasattr(queryset.model, 'all_objects'):
            # Always start with all_objects so we can manually filter time-travel or archived
            queryset = queryset.model.all_objects.all()

        # 2. Date Filtering
        date_field = getattr(view, 'nepali_date_filter_field', None)
        if date_field is not False:
            model_fields = {f.name: f for f in queryset.model._meta.get_fields()}
            if not date_field:
                if 'date' in model_fields:
                    date_field = 'date'
                elif 'created_at' in model_fields:
                    date_field = 'created_at'
            
            if nepali_year and nepali_month and date_field and date_field in model_fields:
                ny = int(nepali_year)
                nm = int(nepali_month)
                field_type = type(model_fields[date_field]).__name__
                
                if field_type in ['CharField', 'TextField']:
                    month_str = str(nm).zfill(2)
                    prefix = f"{ny}-{month_str}"
                    queryset = queryset.filter(**{f"{date_field}__startswith": prefix})
                elif field_type in ['DateTimeField', 'DateField']:
                    try:
                        start_nepali = nepali_datetime.date(ny, nm, 1)
                        from calendar_app.utilities import total_days_in_month
                        days = total_days_in_month(ny, nm)
                        end_nepali = nepali_datetime.date(ny, nm, days)
                        
                        start_greg = start_nepali.to_datetime_date()
                        end_greg = end_nepali.to_datetime_date()
                        
                        queryset = queryset.filter(**{
                            f"{date_field}__date__gte": start_greg,
                            f"{date_field}__date__lte": end_greg,
                        })
                    except Exception:
                        pass
                elif field_type == 'NepaliDateField':
                    try:
                        start_nepali = nepali_datetime.date(ny, nm, 1)
                        from calendar_app.utilities import total_days_in_month
                        days = total_days_in_month(ny, nm)
                        end_nepali = nepali_datetime.date(ny, nm, days)
                        queryset = queryset.filter(**{
                            f"{date_field}__gte": start_nepali,
                            f"{date_field}__lte": end_nepali,
                        })
                    except Exception:
                        pass

        # 3. Apply final Status Filter (Active vs Archived)
        if has_soft_delete:
            if status_param == 'archived':
                queryset = queryset.filter(is_deleted=True)
            else:
                # Normal active query. But if it's Employee and we already time-traveled, 
                # we don't strictly filter is_deleted=False because a time-traveled employee might be deleted NOW.
                # If we queried a past month for Employee, the time-travel logic above already handled the active scope!
                # So we ONLY filter is_deleted=False if we did NOT time-travel, or for non-Employee models.
                if queryset.model.__name__ == 'Employee' and nepali_year and nepali_month and date_field is not False:
                    pass # Handled by time travel logic
                else:
                    queryset = queryset.filter(is_deleted=False)

        return queryset

