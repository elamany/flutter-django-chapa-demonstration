from django.conf import settings
from django.db import transaction
from django.http import HttpResponse
from django.utils.html import escape
from django.core.cache import cache

from rest_framework import generics, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAdminUser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.exceptions import NotFound, PermissionDenied

from accounts.permissions import IsActiveUser

from decimal import Decimal, InvalidOperation
import hashlib
import hmac
import json
import logging
import uuid

from .models import Campaign, Donation
from .serializers import (
    CampaignFilterSerializer,
    CampaignListSerializer,
    CampaignSerializer,
    CampaignDetailSerializer,
    AdminCampaignStatusSerializer,
    DonationCreateSerializer,
    MobileDonationCreateSerializer,
    OwnerDonationListSerializer,
    PublicDonationListSerializer,
    DonationFilterSerializer,
)
from .services.chapa import ChapaPaymentService

logger = logging.getLogger(__name__)

CURRENCY = getattr(settings, 'CHAPA_CURRENCY', 'ETB')


# ---------------------------------------------------------------------------
# Response helpers
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Campaign helpers
# ---------------------------------------------------------------------------

def get_campaign(*, pk, owner=None, statuses=None, as_exception=False):
    """
    Unified campaign lookup.

    Returns (campaign, error_response_or_None).
    If as_exception=True, raises NotFound instead of returning an error response.
    """
    qs = Campaign.objects.filter(pk=pk)
    if owner is not None:
        qs = qs.filter(owner=owner)
    if statuses is not None:
        qs = qs.filter(status__in=statuses)

    campaign = qs.first()
    if campaign is None:
        if as_exception:
            raise NotFound('Campaign not found.')
        return None, error_response('Campaign not found.', status.HTTP_404_NOT_FOUND)
    return campaign, None


def serialize_campaign_with_totals(campaign):
    """Re-fetch campaign with donation totals and serialize it."""
    campaign = (
        Campaign.objects
        .with_donation_totals()
        .get(pk=campaign.pk)
    )
    return CampaignDetailSerializer(campaign).data


# ---------------------------------------------------------------------------
# Payment helpers
# ---------------------------------------------------------------------------

def find_donation_by_tx_ref(tx_ref):
    return (
        Donation.objects
        .select_related('campaign')
        .filter(tx_ref=tx_ref)
        .first()
    )


def verify_with_chapa(tx_ref):
    """Verify a payment with Chapa.
    Returns (verification_dict, error_response_or_None).
    """
    try:
        verification = ChapaPaymentService().verify_payment(tx_ref)
    except Exception:
        logger.exception('Chapa verification failed for tx_ref=%s', tx_ref)
        return None, error_response(
            'Unable to verify payment with the payment provider.',
            status.HTTP_502_BAD_GATEWAY,
        )
    return verification, None


def validate_chapa_payload(verification, donation):
    """Validate the Chapa verification result against our donation.
    Returns (chapa_data, error_response_or_None).
    """
    chapa_data = verification.get('data', {})

    if chapa_data.get('tx_ref') != donation.tx_ref:
        return None, error_response(
            'Transaction reference mismatch.',
            status.HTTP_400_BAD_REQUEST,
        )

    if chapa_data.get('currency') != CURRENCY:
        return None, error_response(
            'Currency mismatch.',
            status.HTTP_400_BAD_REQUEST,
        )

    try:
        amounts_match = (
            Decimal(str(chapa_data.get('amount'))) == donation.amount
        )
    except (TypeError, ValueError, InvalidOperation):
        return None, error_response(
            'Invalid payment amount.',
            status.HTTP_400_BAD_REQUEST,
        )

    if not amounts_match:
        return None, error_response(
            'Donation amount mismatch.',
            status.HTTP_400_BAD_REQUEST,
        )

    return chapa_data, None


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
            # Already in the other terminal state – never move it.
            return locked, False

        locked.status = target_status
        locked.save(update_fields=['status'])
        return locked, True


# Outcome constants used by settle_donation()
OUTCOME_SUCCESS = 'success'
OUTCOME_ALREADY_SUCCESS = 'already_success'
OUTCOME_FAILED = 'failed'
OUTCOME_ALREADY_FAILED = 'already_failed'
OUTCOME_UNEXPECTED = 'unexpected'


def settle_donation(donation, chapa_status):
    """Transition a donation based on a verified Chapa payment status.
    Returns (donation, outcome).
    """
    if chapa_status == 'success':
        donation, changed = finalize_donation(
            donation, Donation.Status.SUCCESS
        )
        return donation, (
            OUTCOME_SUCCESS if changed else OUTCOME_ALREADY_SUCCESS
        )

    if chapa_status == 'failed':
        donation, changed = finalize_donation(
            donation, Donation.Status.FAILED
        )
        if changed:
            return donation, OUTCOME_FAILED
        if donation.status == Donation.Status.FAILED:
            return donation, OUTCOME_ALREADY_FAILED
        # Donation is already SUCCESS – never downgrade a paid donation.
        return donation, OUTCOME_ALREADY_SUCCESS

    return donation, OUTCOME_UNEXPECTED


def process_payment_verification(donation):
    """Run verify -> validate -> settle for a donation.
    Returns a dict with keys:
      donation, chapa_data, chapa_status, outcome, error_response
    """
    verification, error = verify_with_chapa(donation.tx_ref)
    if error:
        return {'error_response': error}

    chapa_data, error = validate_chapa_payload(verification, donation)
    if error:
        return {'error_response': error}

    chapa_status = chapa_data.get('status')
    donation, outcome = settle_donation(donation, chapa_status)

    return {
        'donation': donation,
        'chapa_data': chapa_data,
        'chapa_status': chapa_status,
        'outcome': outcome,
        'error_response': None,
    }


def handle_payment_outcome(outcome, donation, chapa_data=None, *, for_webhook=False):
    """Map a settle outcome to an HTTP response (used by webhook & verify paths)."""
    currency = chapa_data.get('currency') if chapa_data else None

    if outcome in (OUTCOME_SUCCESS, OUTCOME_ALREADY_SUCCESS):
        if for_webhook:
            message = (
                'Webhook payment processed successfully.'
                if outcome == OUTCOME_SUCCESS
                else 'Donation already processed.'
            )
            return success_response(
                message=message,
                data=donation_payload(donation, currency=currency),
            )
        # Non-webhook callers usually just need the updated status.
        return success_response(
            data={'tx_ref': donation.tx_ref, 'status': donation.status}
        )

    if outcome in (OUTCOME_FAILED, OUTCOME_ALREADY_FAILED):
        message = (
            'Payment failed.'
            if outcome == OUTCOME_FAILED
            else 'Donation already marked as failed.'
        )
        return error_response(
            message,
            status.HTTP_200_OK,
            data=donation_payload(donation, currency=currency),
        )

    return error_response(
        'Unexpected payment status.',
        status.HTTP_502_BAD_GATEWAY,
        data={
            'donation_id': donation.id,
            'tx_ref': donation.tx_ref,
            'chapa_status': (chapa_data or {}).get('status'),
        },
    )


def create_pending_donation(campaign, serializer_class, data):
    """Shared logic for creating a PENDING donation + tx_ref."""
    serializer = serializer_class(data=data)
    serializer.is_valid(raise_exception=True)

    tx_ref = f'CAMP-{campaign.id}-{uuid.uuid4()}'
    donation = serializer.save(
        campaign=campaign,
        status=Donation.Status.PENDING,
        tx_ref=tx_ref,
    )
    return donation


# ---------------------------------------------------------------------------
# Campaign views
# ---------------------------------------------------------------------------

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

        params = CampaignFilterSerializer(data=self.request.query_params)
        params.is_valid(raise_exception=True)

        status_filter = params.validated_data.get('status')
        if status_filter:
            queryset = queryset.filter(status=status_filter)

        return queryset.with_donation_totals().order_by('-created_at')


class CampaignDetailView(generics.RetrieveAPIView):
    serializer_class = CampaignDetailSerializer

    def get_queryset(self):
        return Campaign.objects.filter(
            status__in=[
                Campaign.Status.ACTIVE,
                Campaign.Status.COMPLETED,
            ]
        ).with_donation_totals()


class MyCampaignListView(generics.ListAPIView):
    serializer_class = CampaignListSerializer
    pagination_class = CampaignPagination
    permission_classes = [IsActiveUser]

    def get_queryset(self):
        queryset = (
            Campaign.objects
            .filter(owner=self.request.user)
            .with_donation_totals()
            .order_by('-created_at')
        )

        status_filter = self.request.query_params.get('status')
        if status_filter:
            # Validate against real choices.
            valid = {c[0] for c in Campaign.Status.choices}
            normalized = status_filter.upper()
            if normalized in valid:
                queryset = queryset.filter(status=normalized)

        return queryset


class MyCampaignDetailView(generics.RetrieveUpdateDestroyAPIView):
    permission_classes = [IsActiveUser]

    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return CampaignSerializer
        return CampaignDetailSerializer

    def get_queryset(self):
        return (
            Campaign.objects
            .filter(owner=self.request.user)
            .with_donation_totals()
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
    """
    permission_classes = [IsActiveUser]

    from_status = None
    to_status = None
    deny_message = ''

    def post(self, request, pk):
        campaign, error = get_campaign(pk=pk, owner=request.user)
        if error:
            return error

        if campaign.status != self.from_status:
            return error_response(
                self.deny_message,
                status.HTTP_400_BAD_REQUEST,
            )

        campaign.status = self.to_status
        campaign.save(update_fields=['status', 'updated_at'])

        return success_response(
            data=serialize_campaign_with_totals(campaign)
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


# ---------------------------------------------------------------------------
# Admin
# ---------------------------------------------------------------------------

class AdminCampaignStatusUpdateView(APIView):
    permission_classes = [IsAdminUser]

    def patch(self, request, pk):
        campaign, error = get_campaign(pk=pk)
        if error:
            return error

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
            data=serialize_campaign_with_totals(campaign)
        )


# ---------------------------------------------------------------------------
# Donations / Payments
# ---------------------------------------------------------------------------

class CreateDonationView(APIView):
    """Web flow: create PENDING donation + initialize Chapa checkout."""

    def post(self, request, pk):
        campaign, error = get_campaign(
            pk=pk,
            statuses=[Campaign.Status.ACTIVE],
        )
        if error:
            return error_response(
                'Campaign not found or is not active.',
                status.HTTP_404_NOT_FOUND,
            )

        donation = create_pending_donation(
            campaign, DonationCreateSerializer, request.data
        )

        # Cancel any older PENDING donations from the same email on this campaign.
        #Donation.objects.filter(
        #    campaign=campaign,
        #    email=donation.email,
        #    status=Donation.Status.PENDING,
        #).exclude(pk=donation.pk).update(status=Donation.Status.FAILED)

        return_url = (
            f"{settings.CHAPA_RETURN_URL.rstrip('/')}"
            f"/api/v1/payments/return/?tx_ref={donation.tx_ref}"
        )

        payment_service = ChapaPaymentService()
        response = payment_service.initialize_payment(
            tx_ref=donation.tx_ref,
            amount=donation.amount,
            email=donation.email,
            first_name=donation.name,
            last_name='',
            return_url=return_url,
            customization={
                'title': campaign.title[:15],
                'description': 'Donation',
            },
        )

        def fail_initialization(message):
            donation.status = Donation.Status.FAILED
            donation.save(update_fields=['status'])
            return error_response(message, status.HTTP_400_BAD_REQUEST)

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

        donation.checkout_link = checkout_url
        donation.return_url = return_url
        donation.save(update_fields=['checkout_link', 'return_url'])

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


class CreateMobileDonationView(APIView):
    """Mobile SDK flow: create PENDING donation only (no server-side init)."""

    def post(self, request, pk):
        campaign, error = get_campaign(
            pk=pk,
            statuses=[Campaign.Status.ACTIVE],
        )
        if error:
            return error_response(
                'Campaign not found or is not active.',
                status.HTTP_404_NOT_FOUND,
            )

        donation = create_pending_donation(
            campaign, MobileDonationCreateSerializer, request.data
        )

        return success_response(
            data={
                'donation_id': donation.id,
                'campaign_id': campaign.id,
                'tx_ref': donation.tx_ref,
                'amount': str(donation.amount),
                'currency': CURRENCY,
                'campaign_title': campaign.title,
                'status': donation.status,
            },
            http_status=status.HTTP_201_CREATED,
        )


class PaymentReturnView(APIView):
    """Browser return URL after Chapa checkout."""

    def get(self, request):
        tx_ref = request.query_params.get('tx_ref')

        if not tx_ref:
            return payment_result_page(
                title='Payment Error',
                message='Transaction reference is missing.',
                status_text='ERROR',
            )

        donation = find_donation_by_tx_ref(tx_ref)
        if donation is None:
            return payment_result_page(
                title='Payment Error',
                message='Donation not found.',
                status_text='ERROR',
            )

        # Already verified – don't call Chapa again.
        if donation.status == Donation.Status.SUCCESS:
            return payment_result_page(
                title='Payment Successful',
                message='Your donation was successfully processed.',
                status_text='SUCCESS',
            )

        result = process_payment_verification(donation)

        if result.get('error_response') is not None:
            return payment_result_page(
                title='Payment Error',
                message='Unable to verify your payment.',
                status_text='ERROR',
            )

        outcome = result['outcome']

        if outcome in (OUTCOME_SUCCESS, OUTCOME_ALREADY_SUCCESS):
            return payment_result_page(
                title='Payment Successful',
                message='Your donation was successfully processed.',
                status_text='SUCCESS',
            )

        if outcome in (OUTCOME_FAILED, OUTCOME_ALREADY_FAILED):
            return payment_result_page(
                title='Payment Failed',
                message='Your payment was not completed.',
                status_text='FAILED',
            )

        return payment_result_page(
            title='Payment Pending',
            message='Your payment status could not be confirmed yet.',
            status_text='PENDING',
        )


def payment_result_page(title, message, status_text):
    title = escape(title)
    message = escape(message)
    status_text = escape(status_text)
    status_class = status_text.lower()

    html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <meta name="payment-status" content="{status_text}">
        <title>{title}</title>
        <style>
            * {{ box-sizing: border-box; }}
            body {{
                margin: 0;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 24px;
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                background: #f5f7fa;
                color: #1f2937;
            }}
            .payment-result {{
                width: 100%;
                max-width: 420px;
                padding: 32px 24px;
                text-align: center;
                background: #ffffff;
                border-radius: 16px;
                box-shadow: 0 8px 30px rgba(0, 0, 0, 0.08);
            }}
            .icon {{
                width: 64px;
                height: 64px;
                margin: 0 auto 20px;
                display: flex;
                align-items: center;
                justify-content: center;
                border-radius: 50%;
                font-size: 30px;
                font-weight: 700;
            }}
            .icon.success {{ background: #dcfce7; color: #166534; }}
            .icon.failed  {{ background: #fee2e2; color: #991b1b; }}
            .icon.pending,
            .icon.error   {{ background: #fef3c7; color: #92400e; }}
            h1 {{ margin: 0 0 12px; font-size: 24px; }}
            p  {{ margin: 0; line-height: 1.6; color: #6b7280; }}
            .status {{
                margin-top: 20px;
                font-size: 13px;
                font-weight: 600;
                text-transform: uppercase;
                letter-spacing: 0.08em;
            }}
            .status.success {{ color: #166534; }}
            .status.failed  {{ color: #991b1b; }}
            .status.pending,
            .status.error   {{ color: #92400e; }}
        </style>
    </head>
    <body>
        <main class="payment-result" data-payment-status="{status_text}">
            <div class="icon {status_class}">
                {"✓" if status_text == "SUCCESS" else "!"}
            </div>
            <h1>{title}</h1>
            <p>{message}</p>
            <div class="status {status_class}">{status_text}</div>
        </main>
    </body>
    </html>
    """
    return HttpResponse(html, content_type='text/html', status=200)


class DonationVerifyView(APIView):
    authentication_classes = []
    permission_classes = []

    VERIFY_COOLDOWN_SECONDS = 20

    def get(self, request, tx_ref):
        donation = find_donation_by_tx_ref(tx_ref)
        if donation is None:
            return error_response('Donation not found.', status.HTTP_404_NOT_FOUND)

        # Terminal – nothing to do.
        if donation.status in (
            Donation.Status.SUCCESS,
            Donation.Status.FAILED,
        ):
            return success_response(
                data={'tx_ref': donation.tx_ref, 'status': donation.status}
            )

        # Cooldown – avoid hammering Chapa.
        cache_key = f'chapa_verify:{tx_ref}'
        if cache.get(cache_key):
            return success_response(
                data={'tx_ref': donation.tx_ref, 'status': donation.status}
            )

        cache.set(cache_key, True, self.VERIFY_COOLDOWN_SECONDS)

        result = process_payment_verification(donation)
        if result.get('error_response') is not None:
            return success_response(
                data={'tx_ref': donation.tx_ref, 'status': donation.status}
            )

        return handle_payment_outcome(
            result['outcome'],
            result['donation'],
            result.get('chapa_data'),
        )


class DonationStatusView(APIView):
    authentication_classes = []
    permission_classes = []

    def get(self, request, tx_ref):
        donation = find_donation_by_tx_ref(tx_ref)
        if donation is None:
            return error_response(
                'Donation not found.',
                status.HTTP_404_NOT_FOUND,
            )
        return success_response(
            data={
                'tx_ref': donation.tx_ref,
                'status': donation.status,
            }
        )


# ---------------------------------------------------------------------------
# Chapa webhook
# ---------------------------------------------------------------------------

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

        if not chapa_signature_valid(raw_body, request.headers):
            return error_response(
                'Invalid webhook signature.',
                status.HTTP_401_UNAUTHORIZED,
            )

        try:
            payload = json.loads(raw_body.decode('utf-8'))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return error_response(
                'Invalid webhook payload.',
                status.HTTP_400_BAD_REQUEST,
            )

        logger.info('CHAPA WEBHOOK: %s', payload)

        tx_ref = payload.get('tx_ref')
        if not tx_ref:
            return error_response(
                'Transaction reference is missing.',
                status.HTTP_400_BAD_REQUEST,
            )

        donation = find_donation_by_tx_ref(tx_ref)
        if donation is None:
            return error_response(
                'Donation not found.',
                status.HTTP_404_NOT_FOUND,
            )

        # Always verify with Chapa – never trust the webhook body alone.
        result = process_payment_verification(donation)
        if result.get('error_response') is not None:
            return result['error_response']

        return handle_payment_outcome(
            result['outcome'],
            result['donation'],
            result.get('chapa_data'),
            for_webhook=True,
        )


# ---------------------------------------------------------------------------
# Donation list views
# ---------------------------------------------------------------------------

class DonationPagination(PageNumberPagination):
    page_size = 20


class BaseCampaignDonationsListView(generics.ListAPIView):
    """Shared base for campaign donation listings."""
    pagination_class = DonationPagination

    def get_campaign(self):
        raise NotImplementedError

    def get_base_queryset(self, campaign):
        return (
            Donation.objects
            .filter(campaign=campaign)
            .order_by('-created_at')
        )


class MyCampaignDonationsListView(BaseCampaignDonationsListView):
    """
    Donations for one campaign.

    - Owner: only their own campaign, only SUCCESS donations.
             ?status= may only be SUCCESS (or omitted).
    - Admin: any campaign, all statuses, ?status= freely filterable.
    """
    serializer_class = OwnerDonationListSerializer
    permission_classes = [IsActiveUser]

    def get_campaign(self):
        user = self.request.user
        is_admin = user.is_staff or user.is_superuser

        if is_admin:
            campaign, _ = get_campaign(pk=self.kwargs['pk'], as_exception=True)
        else:
            campaign, _ = get_campaign(
                pk=self.kwargs['pk'],
                owner=user,
                as_exception=True,
            )
        return campaign, is_admin

    def get_queryset(self):
        campaign, is_admin = self.get_campaign()
        queryset = self.get_base_queryset(campaign)

        params = DonationFilterSerializer(data=self.request.query_params)
        params.is_valid(raise_exception=True)
        status_filter = params.validated_data.get('status')

        if is_admin:
            if status_filter:
                queryset = queryset.filter(status=status_filter)
            return queryset

        if status_filter and status_filter != Donation.Status.SUCCESS:
            raise PermissionDenied(
                'Owners can only view successful donations.'
            )
        return queryset.filter(status=Donation.Status.SUCCESS)


class CampaignPublicDonationsListView(BaseCampaignDonationsListView):
    """
    Public list of SUCCESSFUL donations for a campaign.
    Pending and failed payments are never exposed.
    """
    serializer_class = PublicDonationListSerializer
    permission_classes = []
    authentication_classes = []

    def get_campaign(self):
        campaign, _ = get_campaign(
            pk=self.kwargs['pk'],
            statuses=[
                Campaign.Status.ACTIVE,
                Campaign.Status.COMPLETED,
            ],
            as_exception=True,
        )
        return campaign

    def get_queryset(self):
        campaign = self.get_campaign()
        return (
            self.get_base_queryset(campaign)
            .filter(status=Donation.Status.SUCCESS)
        )