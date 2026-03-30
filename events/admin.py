from django.contrib import admin
from parler.admin import TranslatableAdmin
from .models import Event, TicketType, GameSession, Booking


# ── TicketType inline (shown inside Event) ────────────────────────────────────

class TicketTypeInline(admin.TabularInline):
    model = TicketType
    extra = 1
    fields = ['name', 'description', 'price', 'participant_count', 'order', 'is_active']
    ordering = ['order', 'price']


# ── Event ─────────────────────────────────────────────────────────────────────

@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display  = ['name', 'session_count', 'ticket_type_count', 'is_active', 'created_at']
    list_filter   = ['is_active']
    search_fields = ['name', 'description']
    inlines       = [TicketTypeInline]

    def session_count(self, obj):
        return obj.sessions.count()
    session_count.short_description = 'Sessions'

    def ticket_type_count(self, obj):
        return obj.ticket_types.count()
    ticket_type_count.short_description = 'Ticket Types'


# ── TicketType (standalone, for quick edits) ──────────────────────────────────

@admin.register(TicketType)
class TicketTypeAdmin(admin.ModelAdmin):
    list_display  = ['name', 'event', 'price', 'participant_count', 'order', 'is_active']
    list_filter   = ['event', 'is_active']
    search_fields = ['name', 'event__name']
    ordering      = ['event', 'order', 'price']


# ── GameSession ───────────────────────────────────────────────────────────────

@admin.register(GameSession)
class GameSessionAdmin(TranslatableAdmin):
    list_display  = ['name', 'event', 'date', 'start_time', 'end_time',
                     'available_spots', 'max_participants', 'is_active']
    list_filter   = ['date', 'collab', 'is_active', 'event']
    search_fields = ['translations__name', 'translations__description']
    date_hierarchy = 'date'

    def available_spots(self, obj):
        return obj.available_spots
    available_spots.short_description = 'Available Spots'


# ── Booking ───────────────────────────────────────────────────────────────────

@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display  = ['customer_name', 'session', 'ticket_type', 'ticket_quantity',
                     'participants', 'total_price', 'booking_reference',
                     'payment_status', 'status', 'created_at']
    list_filter   = ['status', 'payment_status', 'session__date', 'ticket_type', 'created_at']
    search_fields = ['customer_name', 'customer_email', 'booking_reference']
    readonly_fields = ['booking_reference', 'total_price', 'participants', 'access_token']

    fieldsets = [
        ('Customer', {
            'fields': ['customer_name', 'customer_email', 'customer_phone', 'special_requests'],
        }),
        ('Booking', {
            'fields': ['session', 'ticket_type', 'ticket_quantity',
                       'participants', 'booking_reference', 'access_token'],
        }),
        ('Pricing', {
            'fields': ['total_price'],
        }),
        ('Status', {
            'fields': ['status', 'is_confirmed', 'payment_status',
                       'payment_method', 'stripe_payment_intent_id', 'payment_completed_at'],
        }),
    ]