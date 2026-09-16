from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import (
    InvalidToken,
    AuthenticationFailed,
)
from rest_framework_simplejwt.settings import api_settings
from django.utils.translation import gettext_lazy as _


class JWTAuthenticationAllowInactive(JWTAuthentication):
    """JWT auth that skips the is_active check.
    Used ONLY on /auth/me/ so we can tell a deactivated user *why*
    they're being rejected, instead of a generic 401.
    Every other endpoint keeps the default JWTAuthentication, which
    rejects inactive users at the auth layer.
    """

    def get_user(self, validated_token):
        try:
            user_id = validated_token[api_settings.USER_ID_CLAIM]
        except KeyError:
            raise InvalidToken(
                _('Token contained no recognizable user identification')
            )

        try:
            user = self.user_model.objects.get(
                **{api_settings.USER_ID_FIELD: user_id}
            )
        except self.user_model.DoesNotExist:
            raise AuthenticationFailed(
                _('User not found'),
                code='user_not_found',
            )

        # Deliberately skip api_settings.USER_AUTHENTICATION_RULE(user)
        # so an inactive user still authenticates on this endpoint.
        return user
    
class ActiveOnlyJWTAuthentication(JWTAuthentication):
    """Global auth class.
    Same as JWTAuthentication but with a friendlier message for
    inactive users. Used as DEFAULT_AUTHENTICATION_CLASSES.
    """

    def get_user(self, validated_token):
        try:
            user_id = validated_token[api_settings.USER_ID_CLAIM]
        except KeyError:
            raise InvalidToken(
                _('Token contained no recognizable user identification')
            )

        try:
            user = self.user_model.objects.get(
                **{api_settings.USER_ID_FIELD: user_id}
            )
        except self.user_model.DoesNotExist:
            raise AuthenticationFailed(
                _('User not found'),
                code='user_not_found',
            )

        if not user.is_active:
            raise AuthenticationFailed(
                _('Your account has been deactivated. Please contact support.'),
                code='user_inactive',
            )

        return user