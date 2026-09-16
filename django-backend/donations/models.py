from django.db import models
from decimal import Decimal
from django.core.validators import MinValueValidator
from django.contrib.auth.models import User
from django.db.models import Sum, Count, DecimalField, Value, Q
from django.db.models.functions import Coalesce


class CampaignQuerySet(models.QuerySet):
    """QuerySet for Campaign with donation totals annotated in."""

    def with_donation_totals(self):
        """Annotate raised_amount and donation_count from SUCCESS donations.
        - raised_amount: sum of successful donations, 0.00 if none
        - donation_count: number of successful donations
        """
        success_filter = Q(donations__status=Donation.Status.SUCCESS)

        return self.annotate(
            raised_amount=Coalesce(
                Sum('donations__amount', filter=success_filter),
                Value(Decimal('0.00')),
                output_field=DecimalField(
                    max_digits=12,
                    decimal_places=2,
                ),
            ),
            donation_count=Count('donations', filter=success_filter),
        )

class Campaign(models.Model):
    class Status(models.TextChoices):
        DRAFT = 'DRAFT', 'Draft'
        PENDING_REVIEW = 'PENDING_REVIEW', 'Pending Review'
        ACTIVE = 'ACTIVE', 'Active'
        COMPLETED = 'COMPLETED', 'Completed'
        REJECTED = 'REJECTED', 'Rejected'
    objects = CampaignQuerySet.as_manager()
    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='campaigns'
    )   
    title = models.CharField(max_length=200)
    description = models.TextField()
    target_amount = models.DecimalField(max_digits=12, decimal_places=2)
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.DRAFT
    )
    image = models.ImageField(upload_to='campaign_image/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    @classmethod
    def can_transition_status(cls, current_status, new_status):
        allowed_transitions = {
            cls.Status.DRAFT: {
                cls.Status.PENDING_REVIEW,
            },
            cls.Status.PENDING_REVIEW: {
                cls.Status.ACTIVE,
                cls.Status.REJECTED,
            },
            cls.Status.ACTIVE: {
                cls.Status.COMPLETED,
            },
            cls.Status.REJECTED: {
                cls.Status.DRAFT,
            },
            cls.Status.COMPLETED: set(),
        }

        return new_status in allowed_transitions.get(
            current_status,
            set()
        )
        
    @classmethod
    def get_allowed_next_statuses(cls, current_status):
        allowed_transitions = {
            cls.Status.DRAFT: {
                cls.Status.PENDING_REVIEW,
            },
            cls.Status.PENDING_REVIEW: {
                cls.Status.ACTIVE,
                cls.Status.REJECTED,
                cls.Status.DRAFT,
            },
            cls.Status.ACTIVE: {
                cls.Status.COMPLETED,
                cls.Status.PENDING_REVIEW,
            },
            cls.Status.REJECTED: {
                cls.Status.DRAFT,
            },
            cls.Status.COMPLETED: set(),
        }

        return allowed_transitions.get(current_status, set())
    
    @classmethod
    def get_editable_fields(cls, status):
        if status == cls.Status.DRAFT:
            return {
                'title',
                'description',
                'target_amount',
                'image',
            }

        if status == cls.Status.ACTIVE:
            return {
                'target_amount',
            }

        return set()
    
    def delete_old_image(self):
        if self.image:
            self.image.delete(save=False)

class Donation(models.Model):
    class Status(models.TextChoices):
        PENDING = 'PENDING', 'Pending'
        SUCCESS = 'SUCCESS', 'Success'
        FAILED = 'FAILED', 'Failed'
    
        
    campaign = models.ForeignKey(
        Campaign,
        on_delete=models.CASCADE,
        related_name='donations'
    )
    name = models.CharField(max_length=100)
    email = models.EmailField()
    is_anonymous = models.BooleanField(default=False)
    amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        validators=[MinValueValidator(Decimal('1.00'))]
    )
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING
    )
    tx_ref = models.CharField(max_length=100, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)