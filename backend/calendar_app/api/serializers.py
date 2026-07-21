from rest_framework import serializers
from calendar_app.models import Event, Category


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = '__all__'


class EventSerializer(serializers.ModelSerializer):
    category = CategorySerializer()

    class Meta:
        model = Event
        fields = '__all__'
