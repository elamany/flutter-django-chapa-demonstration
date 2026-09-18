from django.contrib.auth.models import User
from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password
from rest_framework_simplejwt.token_blacklist.models import (
    OutstandingToken,
    BlacklistedToken,
)
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(
        write_only=True,
        min_length=8,
    )
    first_name = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
    )
    last_name = serializers.CharField(
        max_length=150,
        required=False,
        allow_blank=True,
    )

    class Meta:
        model = User
        fields = [
            'username',
            'email',
            'first_name',
            'last_name',
            'password',
        ]

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
        )
        return user

    def validate_password(self, value):
        validate_password(value)
        return value
    

class MeSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'first_name',
            'last_name',
            'is_staff',
            'is_superuser',
            'is_active',
        ]
        read_only_fields = fields
        
class UpdateProfileSerializer(serializers.ModelSerializer):
    """PATCH /auth/me/ — editable profile fields only."""

    class Meta:
        model = User
        fields = [
            'first_name',
            'last_name',
            'email',
        ]

    def validate_email(self, value):
        value = value.strip().lower()

        # Soft uniqueness check: Django's default User does NOT enforce
        # unique email at the DB level, so we do it here for UX.
        taken = (
            User.objects
            .exclude(pk=self.instance.pk)
            .filter(email__iexact=value)
            .exists()
        )
        if taken:
            raise serializers.ValidationError(
                'This email is already in use.'
            )
        return value


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)
    new_password_confirm = serializers.CharField(write_only=True, min_length=8)

    def validate_old_password(self, value):
        user = self.context['request'].user
        if not user.check_password(value):
            raise serializers.ValidationError(
                'Current password is incorrect.'
            )
        return value

    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError({
                'new_password_confirm': 'Passwords do not match.'
            })
        validate_password(
            attrs['new_password'],
            self.context['request'].user,
        )
        return attrs

    def save(self, **kwargs):
        user = self.context['request'].user

        user.set_password(self.validated_data['new_password'])
        user.save(update_fields=['password'])

        #  Kill every existing refresh token (other devices).
        for token in OutstandingToken.objects.filter(user=user):
            BlacklistedToken.objects.get_or_create(token=token)

        # Issue a fresh pair for THIS device so the user stays logged in.
        new_refresh = RefreshToken.for_user(user)
        self.new_tokens = {
            'access': str(new_refresh.access_token),
            'refresh': str(new_refresh),
        }
        return user
    
class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()

    def validate_refresh(self, value):
        try:
            self.token = RefreshToken(value)
        except TokenError:
            raise serializers.ValidationError('Invalid or expired token.')
        return value

    def save(self, **kwargs):
        self.token.blacklist()
        return None