from django.contrib import admin

# Register your models here.
from .models import Campaign, Donation


@admin.register(Campaign)
class CampaignAdmin(admin.ModelAdmin):
    list_display = ['id', 'title', 'owner', 'status', 'target_amount', 'created_at']
    list_filter = ['status']
    search_fields = ['title', 'owner__username']


@admin.register(Donation)
class DonationAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'name', 'email', 'phone',
        'amount', 'status', 'campaign',
        'created_at',
    ]
    list_filter = ['status', 'created_at']
    search_fields = [
        'name', 'email', 'phone', 'tx_ref',
        'checkout_link', 'return_url',
    ]
    readonly_fields = ['checkout_link', 'return_url']