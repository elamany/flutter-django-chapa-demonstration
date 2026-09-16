from django.contrib import admin

# Register your models here.
from .models import Campaign, Donation

admin.site.register(Campaign)
admin.site.register(Donation)