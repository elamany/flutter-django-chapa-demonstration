from django.urls import path

from .views import (
    CampaignListView,
    CampaignDetailView,
    DonationStatusView,
    MyCampaignListView,
    MyCampaignDetailView,
    SubmitCampaignForReviewView,
    CancelCampaignSubmissionView,
    MarkMyCampaignAsCompleteView,
    AdminCampaignStatusUpdateView,
    
    
    CreateDonationView,
    CreateMobileDonationView,
    PaymentReturnView,
    ChapaWebhookView,
    DonationVerifyView,
    
    MyCampaignDonationsListView,
    CampaignPublicDonationsListView
)

urlpatterns = [
    path(
        'campaigns/', 
        CampaignListView.as_view(), 
        name='campaign-list'),
    path(
        'campaigns/<int:pk>/',
        CampaignDetailView.as_view(),
        name='campaign-detail'
    ),
    path(
        'my-campaigns/',
        MyCampaignListView.as_view(),
        name='my-campaign-list'
    ),
    path(
        'my-campaigns-detail/<int:pk>/',
        MyCampaignDetailView.as_view(),
        name='my-campaign-detail'
    ),
    path(
        'my-campaigns/<int:pk>/submit-for-review/',
        SubmitCampaignForReviewView.as_view(),
        name='submit-campaign'
    ),
    path(
    'my-campaigns/<int:pk>/cancel-review-submission/',
        CancelCampaignSubmissionView.as_view(),
        name='cancel-campaign-submission'
    ),
    path(
        'my-campaigns/<int:pk>/mark-campaign-complete/',
        MarkMyCampaignAsCompleteView.as_view(),
        name='complete-campaign'
    ),
    
    path(
        'admin/campaigns/<int:pk>/status/',
        AdminCampaignStatusUpdateView.as_view(),
        name='status-campaign'
    ),
    
    path(
        'campaigns/<int:pk>/donate/',
        CreateDonationView.as_view(),
        name='create-donation'
    ),
    
    path(
        'payments/return/',
        PaymentReturnView.as_view(),
        name='payment-return'
    ),
    
    path(
        'payments/verify/<str:tx_ref>/',
        DonationVerifyView.as_view(),
        name='donation-verify',
    ),
    
    path(
        'payments/status/<str:tx_ref>/',
        DonationStatusView.as_view(),
        name='donation-status',
    ),
    
    path(
        'payments/webhook/',
        ChapaWebhookView.as_view(),
        name='chapa-webhook'
    ),
    
    path(
        'my-campaigns/<int:pk>/donations/',
        MyCampaignDonationsListView.as_view(),
        name='my-campaign-donations'
    ),
    
    path(
        'campaigns/<int:pk>/donations/',
        CampaignPublicDonationsListView.as_view(),
        name='campaign-public-donations'
    ),
    
    path(
        'campaigns/<int:pk>/donate/mobile/',
        CreateMobileDonationView.as_view(),
        name='create-mobile-donation',
    ),
]