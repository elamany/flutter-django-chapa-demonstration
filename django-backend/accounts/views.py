from rest_framework import generics, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .authentication import JWTAuthenticationAllowInactive
from .serializers import (
    RegisterSerializer,
    MeSerializer,
    UpdateProfileSerializer,
    ChangePasswordSerializer,
    LogoutSerializer
)


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer


class MeView(generics.RetrieveUpdateAPIView):
    """GET returns the current user. PATCH edits profile fields.

    GET works for inactive users (so Flutter can tell them why they
    can't log in). PATCH is blocked for inactive users.
    """

    authentication_classes = [JWTAuthenticationAllowInactive]
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user

    def get_serializer_class(self):
        if self.request.method in ('PUT', 'PATCH'):
            return UpdateProfileSerializer
        return MeSerializer

    def update(self, request, *args, **kwargs):
        # Explicitly block PATCH for deactivated users, since our relaxed
        # auth class lets them through to read /me/.
        if not request.user.is_active:
            return Response(
                {
                    'detail': 'Your account is inactive.',
                    'code': 'user_inactive',
                },
                status=status.HTTP_401_UNAUTHORIZED,
            )
        return super().update(request, *args, **kwargs)

    def patch(self, request, *args, **kwargs):
        # DRF's RetrieveUpdateAPIView already provides PATCH; this is
        # just here to make it obvious the endpoint supports partial updates.
        return self.partial_update(request, *args, **kwargs)


class ChangePasswordView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = ChangePasswordSerializer(
            data=request.data,
            context={'request': request},
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return Response(
            {
                'success': True,
                'message': 'Password changed successfully.',
                'data': {
                    'access': serializer.new_tokens['access'],
                    'refresh': serializer.new_tokens['refresh'],
                },
            },
            status=status.HTTP_200_OK,
        )
        
class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(
            {'success': True, 'message': 'Logged out.'},
            status=status.HTTP_200_OK,
        )