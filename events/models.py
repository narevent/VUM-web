from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils import timezone
from parler.models import TranslatableModel, TranslatedFields
from datetime import datetime
import stripe
from django.conf import settings
import uuid


class Event(models.Model):
    """
    Groups multiple GameSessions under a single named event.
    e.g. "Summer VUM Cup 2025" can contain several weekly sessions.
    """
    name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.name


class TicketType(models.Model):
    """
    A flexible pricing tier attached to a specific Event.
    Examples: Individual €10, Duo €15, Family €20, Student €5.
    New tiers can be added at any time without code changes.
    """
    event = models.ForeignKey(Event, on_delete=models.CASCADE, related_name='ticket_types')
    name = models.CharField(max_length=100)          # e.g. "Individual", "Duo"
    description = models.CharField(max_length=255, blank=True)  # e.g. "Up to 2 people"
    price = models.DecimalField(max_digits=8, decimal_places=2)
    # How many participant slots this ticket occupies (used for capacity tracking)
    participant_count = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1), MaxValueValidator(20)],
        help_text="Number of spots this ticket type occupies."
    )
    is_active = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0, help_text="Display order (lower = first)")

    class Meta:
        ordering = ['order', 'price']

    def __str__(self):
        return f"{self.event.name} — {self.name} (€{self.price})"


class GameSession(TranslatableModel):
    """Represents a gaming session time slot"""
    translations = TranslatedFields(
        name=models.CharField(max_length=200),
        description=models.TextField(),
        button=models.CharField(max_length=32, blank=True, null=True),
    )

    # Link to an Event (nullable so existing rows survive migration)
    event = models.ForeignKey(
        Event,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='sessions',
    )

    collab = models.CharField(max_length=20, blank=True)
    address = models.CharField(max_length=200, blank=True)
    city = models.CharField(max_length=100, blank=True)
    date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    max_participants = models.PositiveIntegerField(
        default=1,
        validators=[MinValueValidator(1), MaxValueValidator(20)]
    )
    # price_per_person is kept for backwards-compatibility and as a fallback
    # when no Event / TicketType is configured.
    price_per_person = models.DecimalField(max_digits=6, decimal_places=2, default=0)
    private = models.BooleanField(default=False)
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
        aware_session_datetime = timezone.make_aware(session_datetime)
        return aware_session_datetime > timezone.now()

    @property
    def ticket_types(self):
        """
        Returns active TicketTypes for this session's event, or an empty
        queryset when the session has no event attached.
        """
        if self.event_id:
            return self.event.ticket_types.filter(is_active=True)
        return TicketType.objects.none()

    @property
    def has_ticket_types(self):
        return self.event_id is not None and self.ticket_types.exists()


class Booking(models.Model):
    """Represents a booking for a gaming session"""
    STATUS_CHOICES = [
        ('pending', 'Pending Confirmation'),
        ('confirmed', 'Confirmed'),
        ('cancelled', 'Cancelled'),
    ]
    access_token = models.UUIDField(default=uuid.uuid4, editable=False, unique=True)
    session = models.ForeignKey(GameSession, on_delete=models.CASCADE, related_name='bookings')

    # Optional: which ticket type was chosen (null = legacy / fallback pricing)
    ticket_type = models.ForeignKey(
        TicketType,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='bookings',
    )
    # Number of tickets purchased (each ticket = ticket_type.participant_count spots)
    ticket_quantity = models.PositiveIntegerField(default=1)

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
                    'booking_id': str(self.id),
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
            self.booking_reference = str(uuid.uuid4())[:8].upper()

        # Price calculation:
        # 1. If a TicketType is set → price = ticket_type.price × ticket_quantity
        # 2. Fallback → legacy price_per_person × participants (existing behaviour)
        if self.ticket_type_id:
            self.total_price = self.ticket_type.price * self.ticket_quantity
            # Keep participants in sync with how many spots the tickets occupy
            self.participants = self.ticket_type.participant_count * self.ticket_quantity
        else:
            self.total_price = self.participants * self.session.price_per_person

        super().save(*args, **kwargs)