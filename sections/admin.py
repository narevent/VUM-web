from django.contrib import admin
from parler.admin import TranslatableAdmin
from .models import Header, Banner, Story, Principle, Stat


@admin.register(Header)
class HeaderAdmin(TranslatableAdmin):
    list_display = ['title', 'page', 'created_at']
    list_filter = ['page']
    search_fields = ['title', 'content']
    readonly_fields = ['created_at']


@admin.register(Banner)
class BannerAdmin(TranslatableAdmin):
    list_display = ['title', 'page', 'order', 'created_at']
    list_filter = ['page', 'order']
    search_fields = ['title', 'content']
    readonly_fields = ['created_at']


@admin.register(Story)
class StoryAdmin(TranslatableAdmin):
    list_display = ['title', 'icon', 'order', 'created_at']
    list_filter = ['created_at']
    search_fields = ['title', 'content']
    readonly_fields = ['created_at']


@admin.register(Principle)
class PrincipleAdmin(TranslatableAdmin):
    list_display = ['title', 'icon', 'order']
    list_filter = []
    search_fields = ['title', 'content']
    readonly_fields = []


@admin.register(Stat)
class StatAdmin(TranslatableAdmin):
    list_display = ['name', 'count', 'order', 'created_at']
    list_filter = ['created_at']
    search_fields = ['name']
    readonly_fields = ['created_at']