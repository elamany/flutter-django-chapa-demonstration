from rest_framework import serializers

from .models import Campaign, Donation
from .image_utils import process_image

#POST /campaigns/, PATCH /my-campaigns/<id>/
class CampaignSerializer(serializers.ModelSerializer):
    class Meta:
        model = Campaign
        fields = [
            'id',
            'title',
            'description',
            'target_amount',
            'status',
            'image',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'status',
            'created_at',
        ]
        
    def validate_image(self, value):
        try:
            processed_image = process_image(value)
        except ValueError as error:
            raise serializers.ValidationError(str(error))

        return processed_image

#Small list response GET /campaigns/, GET /my-campaigns/
class CampaignListSerializer(serializers.ModelSerializer):
    owner_id = serializers.IntegerField(
        source='owner.id',
        read_only=True
    )

    owner_first_name = serializers.CharField(
        source='owner.first_name',
        read_only=True
    )

    owner_last_name = serializers.CharField(
        source='owner.last_name',
        read_only=True
    )

    class Meta:
        model = Campaign
        fields = [
            'id',
            'title',
            'created_at',
            'image',
            'status',
            'owner_id',
            'owner_first_name',
            'owner_last_name',
        ]
        read_only_fields = fields

#Full detail response GET /campaigns/<id>/, GET /my-campaigns/<id>/
class CampaignDetailSerializer(serializers.ModelSerializer):
    owner_id = serializers.IntegerField(
        source='owner.id',
        read_only=True
    )
    owner_first_name = serializers.CharField(
        source='owner.first_name',
        read_only=True
    )
    owner_last_name = serializers.CharField(
        source='owner.last_name',
        read_only=True
    )
    owner_username = serializers.CharField(
        source='owner.username',
        read_only=True
    )

    class Meta:
        model = Campaign
        fields = [
            'id',
            'title',
            'description',
            'target_amount',
            'status',
            'image',
            'created_at',
            'updated_at',
            'owner_id',
            'owner_username',
            'owner_first_name',
            'owner_last_name',
        ]
        read_only_fields = fields

#Validate query parameters GET /campaigns/?status=[valid stats]
class CampaignFilterSerializer(serializers.Serializer):
    status = serializers.CharField(required=False)

    def validate_status(self, value):
        value = value.upper()

        valid_statuses = {
            Campaign.Status.ACTIVE,
            Campaign.Status.COMPLETED,
        }

        if value not in valid_statuses:
            raise serializers.ValidationError(
                "Invalid campaign status."
            )

        return value
    

class AdminCampaignStatusSerializer(serializers.Serializer):
    status = serializers.CharField()

    def validate_status(self, value):
        value = value.upper()

        valid_statuses = {
            choice[0]
            for choice in Campaign.Status.choices
        }

        if value not in valid_statuses:
            raise serializers.ValidationError(
                "Invalid campaign status."
            )

        return value
    

#donation
class DonationCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Donation
        fields = [
            'name',
            'email',
            'amount',
            'is_anonymous',
        ]

    def validate(self, attrs):
        if attrs.get('is_anonymous'):
            attrs['name'] = 'Anonymous'

        return attrs

    def validate_email(self, value):
        return value.strip().lower()

    def validate_amount(self, value):
        if value < 1:
            raise serializers.ValidationError(
                'Donation amount must be greater than one.'
            )

        return value