from django.shortcuts import render
from django.db import transaction

from rest_framework import generics
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAdminUser
from rest_framework.views import APIView

#from rest_framework.permissions import IsAuthenticated
from accounts.permissions import IsActiveUser

import uuid
import hashlib
import hmac
import json

from .models import Campaign, Donation
from .serializers import (
    CampaignFilterSerializer,
    CampaignListSerializer,
    CampaignSerializer,
    CampaignDetailSerializer,
    AdminCampaignStatusSerializer,
    
    DonationCreateSerializer
)
from .services.chapa import ChapaPaymentService
from django.conf import settings
from decimal import Decimal, InvalidOperation


class CampaignPagination(PageNumberPagination):
    page_size = 10

#GET, POST	List + create
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

        status = params.validated_data.get('status')

        if status:
            queryset = queryset.filter(status=status)

        return queryset

#GET	Return one object
class CampaignDetailView(generics.RetrieveAPIView):
    serializer_class = CampaignDetailSerializer

    def get_queryset(self):
        return Campaign.objects.filter(
            status__in=[
                Campaign.Status.ACTIVE,
                Campaign.Status.COMPLETED,
            ]
        )

#GET - Return a list    
class MyCampaignListView(generics.ListAPIView):
    serializer_class = CampaignListSerializer
    pagination_class = CampaignPagination
    permission_classes = [IsActiveUser]

    def get_queryset(self):
        return Campaign.objects.filter(
            owner=self.request.user
        ).order_by('-created_at')

#GET, PUT, PATCH, DELETE Full detail management    
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

        return Response({
            'success': True,
            'data': serializer.data
        })

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', False)
        instance = self.get_object()
        
        editable_fields = Campaign.get_editable_fields(
            instance.status
        )

        requested_fields = set(request.data.keys())

        not_allowed_fields = requested_fields - editable_fields
        
        if not_allowed_fields:
            return Response(
                {
                    'success': False,
                    'message': (
                        'You cannot update these fields while the '
                        f'campaign status is {instance.status}.'
                    ),
                    'not_allowed_fields': sorted(not_allowed_fields),
                    'editable_fields': sorted(editable_fields),
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = self.get_serializer(
            instance,
            data=request.data,
            partial=partial
        )

        serializer.is_valid(raise_exception=True)
        self.perform_update(serializer)

        return Response({
            'success': True,
            'data': serializer.data
        })
    
    def perform_update(self, serializer):
        old_image = self.get_object().image

        instance = serializer.save()

        if old_image and old_image != instance.image:
            old_image.delete(save=False)
            
    def perform_destroy(self, instance):
        if instance.image:
            instance.image.delete(save=False)

        instance.delete()
    

class SubmitCampaignForReviewView(APIView):
    permission_classes = [IsActiveUser]

    def post(self, request, pk):
        try:
            campaign = Campaign.objects.get(
                pk=pk,
                owner=request.user
            )
        except Campaign.DoesNotExist:
            return Response(
                {
                    'success': False,
                    'message': 'Campaign not found.'
                },
                status=status.HTTP_404_NOT_FOUND
            )

        if campaign.status != Campaign.Status.DRAFT:
            return Response(
                {
                    'success': False,
                    'message': 'Only draft campaigns can be submitted for review.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        campaign.status = Campaign.Status.PENDING_REVIEW
        campaign.save(update_fields=['status', 'updated_at'])

        serializer = CampaignDetailSerializer(campaign)

        return Response({
            'success': True,
            'data': serializer.data
        })

class CancelCampaignSubmissionView(APIView):
    permission_classes = [IsActiveUser]

    def post(self, request, pk):
        try:
            campaign = Campaign.objects.get(
                pk=pk,
                owner=request.user
            )
        except Campaign.DoesNotExist:
            return Response(
                {
                    'success': False,
                    'message': 'Campaign not found.'
                },
                status=status.HTTP_404_NOT_FOUND
            )

        if campaign.status != Campaign.Status.PENDING_REVIEW:
            return Response(
                {
                    'success': False,
                    'message': (
                        'Only campaigns pending review '
                        'can have their submission cancelled.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        campaign.status = Campaign.Status.DRAFT
        campaign.save(update_fields=['status', 'updated_at'])

        serializer = CampaignDetailSerializer(campaign)

        return Response({
            'success': True,
            'data': serializer.data
        })        

class MarkMyCampaignAsCompleteView(APIView):
    permission_classes = [IsActiveUser]

    def post(self, request, pk):
        try:
            campaign = Campaign.objects.get(
                pk=pk,
                owner=request.user
            )
        except Campaign.DoesNotExist:
            return Response(
                {
                    'success': False,
                    'message': 'Campaign not found.'
                },
                status=status.HTTP_404_NOT_FOUND
            )

        if campaign.status != Campaign.Status.ACTIVE:
            return Response(
                {
                    'success': False,
                    'message': (
                        'Only active campaigns can be completed.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        campaign.status = Campaign.Status.COMPLETED
        campaign.save(update_fields=['status', 'updated_at'])

        serializer = CampaignDetailSerializer(campaign)

        return Response({
            'success': True,
            'data': serializer.data
        })

#for admin
class AdminCampaignStatusUpdateView(APIView):
    permission_classes = [IsAdminUser]

    def patch(self, request, pk):
        try:
            campaign = Campaign.objects.get(pk=pk)
        except Campaign.DoesNotExist:
            return Response(
                {
                    'success': False,
                    'message': 'Campaign not found.'
                },
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = AdminCampaignStatusSerializer(
            data=request.data
        )
        serializer.is_valid(raise_exception=True)

        new_status = serializer.validated_data['status']
        
        if not Campaign.can_transition_status(
            campaign.status,
            new_status
        ):
            
            allowed_statuses = Campaign.get_allowed_next_statuses(
                campaign.status
            )

            return Response(
                {
                    'success': False,
                    'message': (
                        f'Cannot change campaign status from '
                        f'{campaign.status} to {new_status}.'
                    ),
                    'current_status': campaign.status,
                    'allowed_next_statuses': sorted(allowed_statuses),
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        campaign.status = new_status
        campaign.save(update_fields=['status', 'updated_at'])

        response_serializer = CampaignDetailSerializer(campaign)

        return Response({
            'success': True,
            'data': response_serializer.data
        })
        

#Donations
class CreateDonationView(APIView):
    def post(self, request, pk):
        try:
            campaign = Campaign.objects.get(
                pk=pk,
                status=Campaign.Status.ACTIVE
            )
        except Campaign.DoesNotExist:
            return Response(
                {
                    'success': False,
                    'message': 'Campaign not found or is not active or completed.'
                },
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = DonationCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        tx_ref = f'CAMP-{campaign.id}-{uuid.uuid4()}'

        donation = serializer.save(
            campaign=campaign,
            status=Donation.Status.PENDING,
            tx_ref=tx_ref
        )

        payment_service = ChapaPaymentService()

        response = payment_service.initialize_payment(
            tx_ref=donation.tx_ref,
            amount=donation.amount,
            email=donation.email,
            first_name=donation.name,
            last_name='',
            return_url = f"{settings.CHAPA_RETURN_URL.rstrip('/')}/api/v1/payments/return?tx_ref={donation.tx_ref}",
            customization={
                'title': campaign.title[:15],
                'description': 'Donation',
            }
        )

        if not response or response.get('status') != 'success':
            donation.status = Donation.Status.FAILED
            donation.save(update_fields=['status'])

            return Response(
                {
                    'success': False,
                    'message': (
                        response.get(
                            'message',
                            'Payment initialization failed.'
                        )
                        if response
                        else 'Payment initialization failed.'
                    ),
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        checkout_url = response.get('data', {}).get('checkout_url')

        if not checkout_url:
            donation.status = Donation.Status.FAILED
            donation.save(update_fields=['status'])

            return Response(
                {
                    'success': False,
                    'message': 'Chapa did not return a checkout URL.'
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        return Response(
            {
                'success': True,
                'data': {
                    'donation_id': donation.id,
                    'campaign_id': campaign.id,
                    'tx_ref': donation.tx_ref,
                    'status': donation.status,
                    'checkout_url': checkout_url,
                }
            },
            status=status.HTTP_201_CREATED
        )
        
#return and verify
class PaymentReturnView(APIView):

    def get(self, request):
        #  Get transaction reference from the return URL
        tx_ref = request.query_params.get('tx_ref')

        if not tx_ref:
            return Response(
                {
                    'success': False,
                    'message': 'Transaction reference is missing.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 2. Find the donation
        try:
            donation = Donation.objects.get(
                tx_ref=tx_ref
            )
        except Donation.DoesNotExist:
            return Response(
                {
                    'success': False,
                    'message': 'Donation not found.'
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # If already successful, don't verify again
        if donation.status == Donation.Status.SUCCESS:
            return Response(
                {
                    'success': True,
                    'message': 'Payment has already been verified.',
                    'data': {
                        'donation_id': donation.id,
                        'campaign_id': donation.campaign.id,
                        'tx_ref': donation.tx_ref,
                        'amount': donation.amount,
                        'status': donation.status,
                    }
                },
                status=status.HTTP_200_OK
            )

        # 4. Ask Chapa to verify the transaction
        payment_service = ChapaPaymentService()

        try:
            verification_response = (
                payment_service.verify_payment(
                    donation.tx_ref
                )
            )

        except Exception as error:
            print('CHAPA VERIFICATION ERROR:', error)

            return Response(
                {
                    'success': False,
                    'message': (
                        'Unable to verify payment with '
                        'the payment provider.'
                    )
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        print(
            'CHAPA VERIFICATION:',
            verification_response
        )

        #  Extract Chapa's transaction status
        chapa_status = (
            verification_response
            .get('data', {})
            .get('status')
        )

        #  Payment successful
        if chapa_status == 'success':

            donation.status = Donation.Status.SUCCESS

            donation.save(
                update_fields=['status']
            )

            return Response(
                {
                    'success': True,
                    'message': (
                        'Payment verified successfully.'
                    ),
                    'data': {
                        'donation_id': donation.id,
                        'campaign_id': donation.campaign.id,
                        'tx_ref': donation.tx_ref,
                        'amount': (
                            verification_response
                            .get('data', {})
                            .get('amount')
                        ),
                        'currency': (
                            verification_response
                            .get('data', {})
                            .get('currency')
                        ),
                        'status': donation.status,
                        #full response
                        'verification': verification_response,
                    }
                },
                status=status.HTTP_200_OK
            )

        # Payment failed
        if chapa_status == 'failed':

            donation.status = Donation.Status.FAILED

            donation.save(
                update_fields=['status']
            )

            return Response(
                {
                    'success': False,
                    'message': 'Payment failed.',
                    'data': {
                        'donation_id': donation.id,
                        'campaign_id': donation.campaign.id,
                        'tx_ref': donation.tx_ref,
                        'status': donation.status,
                    }
                },
                status=status.HTTP_200_OK
            )

        # Unexpected status
        return Response(
            {
                'success': False,
                'message': (
                    'Payment verification returned '
                    'an unexpected status.'
                ),
                'data': {
                    'donation_id': donation.id,
                    'campaign_id': donation.campaign.id,
                    'tx_ref': donation.tx_ref,
                    'chapa_status': chapa_status,
                    'status': donation.status,
                }
            },
            status=status.HTTP_502_BAD_GATEWAY
        )
        

class ChapaWebhookView(APIView):

    authentication_classes = []
    permission_classes = []

    def post(self, request):

        # 1. Get raw body
        raw_body = request.body

        # 2. Get Chapa signatures
        chapa_signature = request.headers.get(
            'Chapa-Signature'
        )

        x_chapa_signature = request.headers.get(
            'x-chapa-signature'
        )

        # 3. Calculate expected signatures
        expected_body_signature = hmac.new(
            settings.CHAPA_WEBHOOK_SECRET.encode(),
            raw_body,
            hashlib.sha256
        ).hexdigest()

        expected_secret_signature = hmac.new(
            settings.CHAPA_WEBHOOK_SECRET.encode(),
            settings.CHAPA_WEBHOOK_SECRET.encode(),
            hashlib.sha256
        ).hexdigest()

        body_signature_valid = (
            x_chapa_signature
            and hmac.compare_digest(
                x_chapa_signature,
                expected_body_signature
            )
        )

        secret_signature_valid = (
            chapa_signature
            and hmac.compare_digest(
                chapa_signature,
                expected_secret_signature
            )
        )

        # 4. Reject invalid signatures
        if not (
            body_signature_valid
            or secret_signature_valid
        ):
            return Response(
                {
                    'success': False,
                    'message': 'Invalid webhook signature.'
                },
                status=status.HTTP_401_UNAUTHORIZED
            )

        # 5. Parse payload
        try:
            payload = json.loads(
                raw_body.decode('utf-8')
            )
        except (UnicodeDecodeError, json.JSONDecodeError):
            return Response(
                {
                    'success': False,
                    'message': 'Invalid webhook payload.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        print('CHAPA WEBHOOK:', payload)

        # 6. Get transaction reference
        tx_ref = payload.get('tx_ref')

        if not tx_ref:
            return Response(
                {
                    'success': False,
                    'message': 'Transaction reference is missing.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 7. Find our donation
        try:
            donation = (
                Donation.objects
                .select_related('campaign')
                .get(tx_ref=tx_ref)
            )
        except Donation.DoesNotExist:
            return Response(
                {
                    'success': False,
                    'message': 'Donation not found.'
                },
                status=status.HTTP_404_NOT_FOUND
            )

        # 8. Verify directly with Chapa
        payment_service = ChapaPaymentService()

        try:
            verification_response = (
                payment_service.verify_payment(
                    donation.tx_ref
                )
            )
        except Exception as error:
            print(
                'CHAPA WEBHOOK VERIFICATION ERROR:',
                error
            )

            return Response(
                {
                    'success': False,
                    'message': 'Unable to verify payment.'
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        print(
            'CHAPA WEBHOOK VERIFICATION:',
            verification_response
        )

        # 9. Extract verified Chapa data
        chapa_data = verification_response.get(
            'data',
            {}
        )

        chapa_status = chapa_data.get(
            'status'
        )

        chapa_tx_ref = chapa_data.get(
            'tx_ref'
        )

        chapa_amount = chapa_data.get(
            'amount'
        )

        chapa_currency = chapa_data.get(
            'currency'
        )

        # 10. Make sure Chapa verified OUR transaction
        if chapa_tx_ref != donation.tx_ref:
            return Response(
                {
                    'success': False,
                    'message': 'Transaction reference mismatch.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 11. Make sure currency matches
        if chapa_currency != 'ETB':
            return Response(
                {
                    'success': False,
                    'message': 'Currency mismatch.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 12. Make sure amount matches
        try:
            if Decimal(str(chapa_amount)) != donation.amount:
                return Response(
                    {
                        'success': False,
                        'message': 'Donation amount mismatch.'
                    },
                    status=status.HTTP_400_BAD_REQUEST
                )
        except (
            TypeError,
            ValueError,
            InvalidOperation
        ):
            return Response(
                {
                    'success': False,
                    'message': 'Invalid payment amount.'
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        # 13. Payment succeeded
        if (
            verification_response.get('status') == 'success'
            and chapa_status == 'success'
        ):
            with transaction.atomic():

                # Lock the current database row
                donation = (
                    Donation.objects
                    .select_for_update()
                    .select_related('campaign')
                    .get(pk=donation.pk)
                )

                # Another request may have processed it
                if donation.status == Donation.Status.SUCCESS:
                    return Response(
                        {
                            'success': True,
                            'message': 'Donation already processed.',
                            'data': {
                                'donation_id': donation.id,
                                'campaign_id': donation.campaign.id,
                                'tx_ref': donation.tx_ref,
                                'amount': str(donation.amount),
                                'status': donation.status,
                            }
                        },
                        status=status.HTTP_200_OK
                    )

                # Update only after acquiring the lock
                donation.status = Donation.Status.SUCCESS

                donation.save(
                    update_fields=['status']
                )

                return Response(
                    {
                        'success': True,
                        'message': (
                            'Webhook payment processed successfully.'
                        ),
                        'data': {
                            'donation_id': donation.id,
                            'campaign_id': donation.campaign.id,
                            'tx_ref': donation.tx_ref,
                            'amount': str(donation.amount),
                            'currency': chapa_currency,
                            'status': donation.status,
                        }
                    },
                    status=status.HTTP_200_OK
                )

        # 14. Payment failed
        if chapa_status == 'failed':
            with transaction.atomic():

                # Lock the current database row
                donation = (
                    Donation.objects
                    .select_for_update()
                    .select_related('campaign')
                    .get(pk=donation.pk)
                )

                # Already processed successfully
                if donation.status == Donation.Status.SUCCESS:
                    return Response(
                        {
                            'success': True,
                            'message': 'Donation already processed.',
                            'data': {
                                'donation_id': donation.id,
                                'campaign_id': donation.campaign.id,
                                'tx_ref': donation.tx_ref,
                                'amount': str(donation.amount),
                                'status': donation.status,
                            }
                        },
                        status=status.HTTP_200_OK
                    )

                # Already failed
                if donation.status == Donation.Status.FAILED:
                    return Response(
                        {
                            'success': False,
                            'message': 'Donation already marked as failed.',
                            'data': {
                                'donation_id': donation.id,
                                'campaign_id': donation.campaign.id,
                                'tx_ref': donation.tx_ref,
                                'amount': str(donation.amount),
                                'status': donation.status,
                            }
                        },
                        status=status.HTTP_200_OK
                    )

                donation.status = Donation.Status.FAILED

                donation.save(
                    update_fields=['status']
                )

                return Response(
                    {
                        'success': False,
                        'message': 'Payment failed.',
                        'data': {
                            'donation_id': donation.id,
                            'campaign_id': donation.campaign.id,
                            'tx_ref': donation.tx_ref,
                            'amount': str(donation.amount),
                            'currency': chapa_currency,
                            'status': donation.status,
                        }
                    },
                    status=status.HTTP_200_OK
                )

        # 15. Unexpected status
        return Response(
            {
                'success': False,
                'message': 'Unexpected payment status.',
                'data': {
                    'donation_id': donation.id,
                    'tx_ref': donation.tx_ref,
                    'chapa_status': chapa_status,
                }
            },
            status=status.HTTP_502_BAD_GATEWAY
        )