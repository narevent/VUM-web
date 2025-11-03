from django.contrib import admin
from parler.admin import TranslatableAdmin
from .models import Instrument, GameTitle


@admin.register(GameTitle)
class GameTitleAdmin(TranslatableAdmin):
    list_display = ['title', 'min_players', 'max_players', 'difficulty_level', 'is_featured']
    list_filter = ['difficulty_level', 'is_featured']
    search_fields = ['title', 'description']


@admin.register(Instrument)
class InstrumentAdmin(TranslatableAdmin):
    list_display = ['name', 'is_available']
    list_filter = ['is_available']