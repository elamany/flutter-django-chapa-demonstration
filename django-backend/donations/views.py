from django.conf import settings
from django.db import transaction

from rest_framework import generics, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsActiveUser

from decimal import Decimal, InvalidOperation
import hashlib
import hmac
import json
import uuid

from .models import Campaign, Donation
from .serializers import (
    CampaignFilterSerializer,
    CampaignListSerializer,
    CampaignSerializer,
    CampaignDetailSerializer,
    AdminCampaignStatusSerializer,
    DonationCreateSerializer,
)
from .services.chapa import ChapaPaymentService


# Response helpers
def success_response(data=None, message=None, http_status=status.HTTP_200_OK):
    body = {'success': True}
    if message is not None:
        body['message'] = message
    if data is not None:
        body['data'] = data
    return Response(body, status=http_status)


def error_response(message, http_status, **extra):
    body = {'success': False, 'message': message}
    body.update(extra)
    return Response(body, status=http_status)


def donation_payload(donation, **extra):
    data = {
        'donation_id': donation.id,
        'campaign_id': donation.campaign.id,
        'tx_ref': donation.tx_ref,
        'amount': str(donation.amount),
        'status': donation.status,
    }
    data.update(extra)
    return data


# Shared lookup / verification helpers
def get_user_campaign_or_404(pk, user):
    try:
        return Campaign.objects.get(pk=pk, owner=user)
    except Campaign.DoesNotExist:
        return None

def campaign_not_found():
    return error_response(
        'Campaign not found.',
        status.HTTP_404_NOT_FOUND,
    )

def verify_with_chapa(tx_ref):
    """Returns (verification_response, error_response_or_None)."""
    try:
        verification = ChapaPaymentService().verify_payment(tx_ref)
    except Exception as error:
        #print('CHAPA VERIFICATION ERROR:', error)
        return None, error_response(
            'Unable to verify payment with the payment provider.',
            status.HTTP_502_BAD_GATEWAY,
        )
    #print('CHAPA VERIFICATION:', verification)
    return verification, None


def finalize_donation(donation, target_status):
    """Idempotently move a donation to a terminal status under a row lock.
    Returns (locked_donation, changed: bool).
    """
    with transaction.atomic():
        locked = (
            Donation.objects
            .select_for_update()
            .select_related('campaign')
            .get(pk=donation.pk)
        )

        if locked.status == target_status:
            return locked, False

        if locked.status in (
            Donation.Status.SUCCESS,
            Donation.Status.FAILED,
        ):
            # Already in the other terminal state - never move it.
            return locked, False

        locked.status = target_status
        locked.save(update_fields=['status'])
        return locked, True


# Campaigns
class CampaignPagination(PageNumberPagination):
    page_size = 10

class CampaignListView(generics.ListCreateAPIView):
    pagination_class = CampaignPagination

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return CampaignSerializer
        return CampaignListSerializer

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsActiveUser()]
        return []

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    def get_queryset(self):
        queryset = Campaign.objects.filter(
            status__in=[
                Campaign.Status.ACTIVE,
                Campaign.Status.COMPLETED,
            ]
        )

        params = CampaignFilterSerializer(
            data=self.request.query_params
        )
        params.is_valid(raise_exception=True)

        status_filter = params.validated_data.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        return queryset

class CampaignDetailView(generics.RetrieveAPIView):
    serializer_class = CampaignDetailSerializer

    def get_queryset(self):
        return Campaign.objects.filter(
            status__in=[
                Campaign.Status.ACTIVE,
                Campaign.Status.COMPLETED,
            ]
        )

class MyCampaignListView(generics.ListAPIView):
    serializer_class = CampaignListSerializer
    pagination_class = CampaignPagination
    permission_classes = [IsActiveUser]

    def get_queryset(self):
        return Campaign.objects.filter(
            owner=self.request.user
        ).order_by('-created_at')

class MyCampaignDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsActiveUser]

    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return CampaignSerializer
        return CampaignDetailSerializer

    def get_queryset(self):
        return Campaign.objects.filter(
            owner=self.request.user
        )

    def retrieve(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        return success_response(data=serializer.data)

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()

        editable_fields = Campaign.get_editable_fields(instance.status)
        requested_fields = set(request.data.keys())
        not_allowed_fields = requested_fields - editable_fields

        if not_allowed_fields:
            return error_response(
                (
                    'You cannot update these fields while the '
                    f'campaign status is {instance.status}.'
                ),
                status.HTTP_400_BAD_REQUEST,
                not_allowed_fields=sorted(not_allowed_fields),
                editable_fields=sorted(editable_fields),
            )

        serializer = self.get_serializer(
            instance,
            data=request.data,
            partial=partial,
        )
        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        return success_response(data=serializer.data)

    def perform_update(self, serializer):
        old_image = self.get_object().image
        instance = serializer.save()

        if old_image and old_image != instance.image:
            old_image.delete(save=False)

    def perform_destroy(self, instance):
        if instance.image:
            instance.image.delete(save=False)
        instance.delete()

class CampaignStatusActionView(APIView):
    """Generic owner-side campaign status transition.
    Subclasses set from_status / to_status / deny_message.
    Kept as separate view classes below so existing URL names still work.
    """
    permission_classes = [IsActiveUser]

    from_status = None
    to_status = None
    deny_message = ''

    def post(self, request, pk):
        campaign = get_user_campaign_or_404(pk, request.user)
        if campaign is None:
            return campaign_not_found()

        if campaign.status != self.from_status:
            return error_response(
                self.deny_message,
                status.HTTP_400_BAD_REQUEST,
            )

        campaign.status = self.to_status
        campaign.save(update_fields=['status', 'updated_at'])

        return success_response(
            data=CampaignDetailSerializer(campaign).data
        )

class SubmitCampaignForReviewView(CampaignStatusActionView):
    from_status = Campaign.Status.DRAFT
    to_status = Campaign.Status.PENDING_REVIEW
    deny_message = 'Only draft campaigns can be submitted for review.'

class CancelCampaignSubmissionView(CampaignStatusActionView):
    from_status = Campaign.Status.PENDING_REVIEW
    to_status = Campaign.Status.DRAFT
    deny_message = (
        'Only campaigns pending review can have their submission cancelled.'
    )

class MarkMyCampaignAsCompleteView(CampaignStatusActionView):
    from_status = Campaign.Status.ACTIVE
    to_status = Campaign.Status.COMPLETED
    deny_message = 'Only active campaigns can be completed.'

# Admin
class AdminCampaignStatusUpdateView(APIView):
    permission_classes = [IsAdminUser]

    def patch(self, request, pk):
        try:
            campaign = Campaign.objects.get(pk=pk)
        except Campaign.DoesNotExist:
            return campaign_not_found()

        serializer = AdminCampaignStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        new_status = serializer.validated_data['status']

        if not Campaign.can_transition_status(campaign.status, new_status):
            allowed_statuses = Campaign.get_allowed_next_statuses(
                campaign.status
            )
            return error_response(
                (
                    f'Cannot change campaign status from '
                    f'{campaign.status} to {new_status}.'
                ),
                status.HTTP_400_BAD_REQUEST,
                current_status=campaign.status,
                allowed_next_statuses=sorted(allowed_statuses),
            )

        campaign.status = new_status
        campaign.save(update_fields=['status', 'updated_at'])

        return success_response(
            data=CampaignDetailSerializer(campaign).data
        )

# Donations Payments
class CreateDonationView(APIView):
    def post(self, request, pk):
        try:
            campaign = Campaign.objects.get(
                pk=pk,
                status=Campaign.Status.ACTIVE,
            )
        except Campaign.DoesNotExist:
            return error_response(
                'Campaign not found or is not active or completed.',
                status.HTTP_404_NOT_FOUND,
            )

        serializer = DonationCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        tx_ref = f'CAMP-{campaign.id}-{uuid.uuid4()}'

        donation = serializer.save(
            campaign=campaign,
            status=Donation.Status.PENDING,
            tx_ref=tx_ref,
        )

        payment_service = ChapaPaymentService()

        response = payment_service.initialize_payment(
            tx_ref=donation.tx_ref,
            amount=donation.amount,
            email=donation.email,
            first_name=donation.name,
            last_name='',
            return_url=(
                f"{settings.CHAPA_RETURN_URL.rstrip('/')}"
                f"/api/v1/payments/return?tx_ref={donation.tx_ref}"
            ),
            customization={
                'title': campaign.title[:15],
                'description': 'Donation',
            },
        )

        def fail_initialization(message):
            donation.status = Donation.Status.FAILED
            donation.save(update_fields=['status'])
            return error_response(
                message,
                status.HTTP_400_BAD_REQUEST,
            )

        if not response or response.get('status') != 'success':
            return fail_initialization(
                response.get('message', 'Payment initialization failed.')
                if response
                else 'Payment initialization failed.'
            )

        checkout_url = response.get('data', {}).get('checkout_url')
        if not checkout_url:
            return fail_initialization(
                'Chapa did not return a checkout URL.'
            )

        return success_response(
            data={
                'donation_id': donation.id,
                'campaign_id': campaign.id,
                'tx_ref': donation.tx_ref,
                'status': donation.status,
                'checkout_url': checkout_url,
            },
            http_status=status.HTTP_201_CREATED,
        )

class PaymentReturnView(APIView):
    def get(self, request):
        tx_ref = request.query_params.get('tx_ref')
        if not tx_ref:
            return error_response(
                'Transaction reference is missing.',
                status.HTTP_400_BAD_REQUEST,
            )

        donation = (
            Donation.objects
            .select_related('campaign')
            .filter(tx_ref=tx_ref)
            .first()
        )
        if donation is None:
            return error_response(
                'Donation not found.',
                status.HTTP_404_NOT_FOUND,
            )

        # If already successful, don't verify again
        if donation.status == Donation.Status.SUCCESS:
            return success_response(
                message='Payment has already been verified.',
                data=donation_payload(donation),
            )

        verification, error = verify_with_chapa(donation.tx_ref)
        if error:
            return error

        chapa_data = verification.get('data', {})
        chapa_status = chapa_data.get('status')

        if chapa_status == 'success':
            donation.status = Donation.Status.SUCCESS
            donation.save(update_fields=['status'])
            return success_response(
                message='Payment verified successfully.',
                data=donation_payload(
                    donation,
                    amount=chapa_data.get('amount'),
                    currency=chapa_data.get('currency'),
                    verification=verification,
                ),
            )

        if chapa_status == 'failed':
            donation.status = Donation.Status.FAILED
            donation.save(update_fields=['status'])
            return error_response(
                'Payment failed.',
                status.HTTP_200_OK,
                data=donation_payload(donation),
            )

        return error_response(
            'Payment verification returned an unexpected status.',
            status.HTTP_502_BAD_GATEWAY,
            data=donation_payload(donation, chapa_status=chapa_status),
        )

# Chapa webhook
def _hmac_sha256(key_bytes, msg_bytes):
    return hmac.new(key_bytes, msg_bytes, hashlib.sha256).hexdigest()


def chapa_signature_valid(raw_body, headers):
    secret = settings.CHAPA_WEBHOOK_SECRET.encode()

    x_chapa_signature = headers.get('x-chapa-signature')
    chapa_signature = headers.get('Chapa-Signature')

    expected_body_sig = _hmac_sha256(secret, raw_body)
    expected_secret_sig = _hmac_sha256(secret, secret)

    body_valid = (
        x_chapa_signature
        and hmac.compare_digest(x_chapa_signature, expected_body_sig)
    )
    secret_valid = (
        chapa_signature
        and hmac.compare_digest(chapa_signature, expected_secret_sig)
    )
    return bool(body_valid or secret_valid)

class ChapaWebhookView(APIView):
    authentication_classes = []
    permission_classes = []

    def post(self, request):
        raw_body = request.body

        # Verify webhook signature
        if not chapa_signature_valid(raw_body, request.headers):
            return error_response(
                'Invalid webhook signature.',
                status.HTTP_401_UNAUTHORIZED,
            )

        # Parse payload
        try:
            payload = json.loads(raw_body.decode('utf-8'))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return error_response(
                'Invalid webhook payload.',
                status.HTTP_400_BAD_REQUEST,
            )

        print('CHAPA WEBHOOK:', payload)

        # Find our donation
        tx_ref = payload.get('tx_ref')
        if not tx_ref:
            return error_response(
                'Transaction reference is missing.',
                status.HTTP_400_BAD_REQUEST,
            )

        donation = (
            Donation.objects
            .select_related('campaign')
            .filter(tx_ref=tx_ref)
            .first()
        )
        if donation is None:
            return error_response(
                'Donation not found.',
                status.HTTP_404_NOT_FOUND,
            )

        #  Verify directly with Chapa (never trust the webhook alone)
        verification, error = verify_with_chapa(donation.tx_ref)
        if error:
            return error

        #Extract verified Chapa data
        chapa_data = verification.get('data', {})
        chapa_status = chapa_data.get('status')
        chapa_amount = chapa_data.get('amount')
        chapa_currency = chapa_data.get('currency')

        # Sanity checks: reference, currency, amount
        if chapa_data.get('tx_ref') != donation.tx_ref:
            return error_response(
                'Transaction reference mismatch.',
                status.HTTP_400_BAD_REQUEST,
            )

        if chapa_currency != 'ETB':
            return error_response(
                'Currency mismatch.',
                status.HTTP_400_BAD_REQUEST,
            )

        try:
            amounts_match = Decimal(str(chapa_amount)) == donation.amount
        except (TypeError, ValueError, InvalidOperation):
            return error_response(
                'Invalid payment amount.',
                status.HTTP_400_BAD_REQUEST,
            )

        if not amounts_match:
            return error_response(
                'Donation amount mismatch.',
                status.HTTP_400_BAD_REQUEST,
            )

        # Payment succeeded
        if (
            verification.get('status') == 'success'
            and chapa_status == 'success'
        ):
            donation, changed = finalize_donation(
                donation, Donation.Status.SUCCESS
            )
            message = (
                'Webhook payment processed successfully.'
                if changed
                else 'Donation already processed.'
            )
            return success_response(
                message=message,
                data=donation_payload(donation, currency=chapa_currency),
            )

        # Payment failed
        if chapa_status == 'failed':
            donation, changed = finalize_donation(
                donation, Donation.Status.FAILED
            )
            if changed:
                return error_response(
                    'Payment failed.',
                    status.HTTP_200_OK,
                    data=donation_payload(donation, currency=chapa_currency),
                )
            if donation.status == Donation.Status.FAILED:
                return error_response(
                    'Donation already marked as failed.',
                    status.HTTP_200_OK,
                    data=donation_payload(donation),
                )
            # Was already SUCCESS - keep the success state
            return success_response(
                message='Donation already processed.',
                data=donation_payload(donation),
            )

        # Unexpected status
        return error_response(
            'Unexpected payment status.',
            status.HTTP_502_BAD_GATEWAY,
            data={
                'donation_id': donation.id,
                'tx_ref': donation.tx_ref,
                'chapa_status': chapa_status,
            },
        )
        
