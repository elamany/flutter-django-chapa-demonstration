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

    GET works for inactive users (so the app can tell them why they
    can't log in). PATCH is blocked for inactive users.

    Both GET and PATCH respond with the full user object, using
    MeSerializer, so the client always gets a consistent shape.
    """

    authentication_classes = [JWTAuthenticationAllowInactive]
    permission_classes = [IsAuthenticated]

    def get_object(self):
        return self.request.user

    def get_serializer_class(self):
        # Only used by DRF's internal flow; the response is re-serialized
        # with MeSerializer below, so the client always sees the full user.
        if self.request.method in ('PUT', 'PATCH'):
            return UpdateProfileSerializer
        return MeSerializer

    def update(self, request, *args, **kwargs):
        # Block PATCH for deactivated users.
        if not request.user.is_active:
            return Response(
                {
                    'detail': 'Your account is inactive.',
                    'code': 'user_inactive',
                },
                status=status.HTTP_401_UNAUTHORIZED,
            )

        # Let DRF validate + save using UpdateProfileSerializer.
        # We ignore its Response and re-serialize with MeSerializer.
        super().update(request, *args, **kwargs)

        # Return the full user, same shape as GET /auth/me/.
        return Response(
            MeSerializer(self.request.user).data,
            status=status.HTTP_200_OK,
        )



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