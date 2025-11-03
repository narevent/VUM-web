from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from parler.models import TranslatableModel, TranslatedFields
from datetime import datetime
import stripe
from django.conf import settings
import uuid

class GameSession(TranslatableModel):
    """Represents a gaming session time slot"""
    GAME_TYPES = [
        ('rhythm', 'Rhythm Games'),
        ('action', 'Action Games'),
        ('puzzle', 'Puzzle Games'),
        ('adventure', 'Adventure Games'),
        ('mixed', 'Mixed Experience'),
    ]

    translations = TranslatedFields(
        name=models.CharField(max_length=200),
        description=models.TextField(),
        button=models.CharField(max_length=32, blank=True, null=True),
    )

    game_type = models.CharField(max_length=20, choices=GAME_TYPES, default='mixed')
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    max_participants = models.PositiveIntegerField(
        default=8,
        validators=[MinValueValidator(1), MaxValueValidator(20)]
    )
    price_per_person = models.DecimalField(max_digits=6, decimal_places=2)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        ordering = ['date', 'start_time']
        unique_together = ['date', 'start_time']
    
    def __str__(self):
        return f"{self.safe_translation_getter('name', any_language=True)} - {self.date} {self.start_time}"
    
    @property
    def available_spots(self):
        """Calculate remaining spots for this session"""
        booked_participants = sum(
            booking.participants for booking in self.bookings.filter(is_confirmed=True)
        )
        return max(0, self.max_participants - booked_participants)
    
    @property
    def is_full(self):
        return self.available_spots == 0
    
    @property
    def is_upcoming(self):
        """Checks if the session is in the future relative to the current time."""
        session_datetime = datetime.combine(self.date, self.start_time)
        # Make the naive session_datetime aware using the current timezone
        aware_session_datetime = timezone.make_aware(session_datetime)
        return aware_session_datetime > timezone.now()

class Booking(models.Model):
    """Represents a booking for a gaming session"""
    STATUS_CHOICES = [
        ('pending', 'Pending Confirmation'),
        ('confirmed', 'Confirmed'),
        ('cancelled', 'Cancelled'),
    ]
    access_token = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    session = models.ForeignKey(GameSession, on_delete=models.CASCADE, related_name='bookings')
    customer_name = models.CharField(max_length=100)
    customer_email = models.EmailField()
    customer_phone = models.CharField(max_length=20, blank=True)
    participants = models.PositiveIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(10)]
    )
    special_requests = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    is_confirmed = models.BooleanField(default=False)
    booking_reference = models.CharField(max_length=20, unique=True)
    total_price = models.DecimalField(max_digits=8, decimal_places=2)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    payment_status = models.CharField(
        max_length=20,
        choices=[
            ('pending', 'Payment Pending'),
            ('processing', 'Processing'),
            ('completed', 'Payment Completed'),
            ('failed', 'Payment Failed'),
            ('refunded', 'Refunded'),
        ],
        default='pending'
    )
    payment_method = models.CharField(max_length=20, choices=[
        ('card', 'Credit/Debit Card'),
        ('revolut', 'Revolut'),
        ('paypal', 'PayPal'),
        ('cash', 'Cash'),
    ], default='card')
    stripe_payment_intent_id = models.CharField(max_length=200, blank=True)
    payment_completed_at = models.DateTimeField(null=True, blank=True)
    
    def create_payment_intent(self):
        """Create Stripe payment intent"""
        if not settings.STRIPE_SECRET_KEY:
            return None
            
        stripe.api_key = settings.STRIPE_SECRET_KEY
        
        try:
            intent = stripe.PaymentIntent.create(
                amount=int(self.total_price * 100),  # Convert to cents
                currency='eur',
                metadata={
                    'booking_id': self.id,
                    'booking_reference': self.booking_reference,
                    'session_name': self.session.safe_translation_getter('name', any_language=True),
                }
            )
            self.stripe_payment_intent_id = intent.id
            self.payment_status = 'processing'
            self.save()
            return intent
        except Exception as e:
            print(f"Stripe error: {e}")
            return None
    
    def __str__(self):
        return f"{self.customer_name} - {self.session.safe_translation_getter('name', any_language=True)} ({self.participants} people)"
    
    def save(self, *args, **kwargs):
        if not self.booking_reference:
            import uuid
            self.booking_reference = str(uuid.uuid4())[:8].upper()
        
        self.total_price = self.participants * self.session.price_per_person
        super().save(*args, **kwargs)