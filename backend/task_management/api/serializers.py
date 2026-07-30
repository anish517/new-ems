from rest_framework import serializers

from task_management.models import Task


class TaskSerializer(serializers.ModelSerializer):
    planned_start_date = serializers.CharField(required=False, allow_blank=True, allow_null=True)
    planned_end_date = serializers.CharField(required=False, allow_blank=True, allow_null=True)

    class Meta:
        model = Task
        fields = ['id', 'project', 'assigned_to', 'title',
                  'description', 'status', 'priority',
                  'planned_start_date', 'planned_end_date', 'rating']

    def create(self, validated_data):
        import nepali_datetime
        today = nepali_datetime.date.today()
        # Set defaults for required date fields
        if not validated_data.get('planned_start_date'):
            validated_data['planned_start_date'] = today
        if not validated_data.get('planned_end_date'):
            validated_data['planned_end_date'] = today
        return super().create(validated_data)

    def to_representation(self, instance):
        rep = super().to_representation(instance)
        rep['project'] = {
            'id': instance.project.id if instance.project else None,
            'name': instance.project.title if instance.project else None,
        }
        rep['assigned_to'] = {
            'id': instance.assigned_to.id if instance.assigned_to else None,
            'name': instance.assigned_to.user.full_name if instance.assigned_to and instance.assigned_to.user else None,
        }
        return rep

