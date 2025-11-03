from django.contrib import admin
from parler.admin import TranslatableAdmin
from .models import GameSession, Booking


@admin.register(GameSession)
class GameSessionAdmin(TranslatableAdmin):
    list_display = ['name', 'date', 'start_time', 'end_time', 'available_spots', 'max_participants', 'is_active']
    list_filter = ['date', 'game_type', 'is_active']
    search_fields = ['name', 'description']
    date_hierarchy = 'date'
    
    def available_spots(self, obj):
        return obj.available_spots
    available_spots.short_description = 'Available Spots'


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ['customer_name', 'session', 'participants', 'booking_reference', 'status', 'created_at']
    list_filter = ['status', 'session__date', 'created_at']
    search_fields = ['customer_name', 'customer_email', 'booking_reference']
    readonly_fields = ['booking_reference', 'total_price']