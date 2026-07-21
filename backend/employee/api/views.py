import time
from rest_framework import status
from rest_framework import generics
from rest_framework.permissions import IsAuthenticated

from employee.models import Contract
from .serializers import ContractSerializer


class ContractRetrieveUpdateDestroyAPIView(generics.RetrieveUpdateDestroyAPIView):
    model = Contract
    queryset = Contract.objects.all()
    serializer_class = ContractSerializer
    permission_classes = [IsAuthenticated]

    def dispatch(self, request, *args, **kwargs):
        time.sleep(2)
        return super().dispatch(request, *args, **kwargs)
