from rest_framework import generics
from rest_framework.permissions import IsAuthenticated
from rest_framework.generics import RetrieveAPIView
from .serializers import RegisterSerializer, MeSerializer
from .authentication import JWTAuthenticationAllowInactive


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    
class MeView(RetrieveAPIView):
    serializer_class = MeSerializer
    authentication_classes = [JWTAuthenticationAllowInactive]
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user
