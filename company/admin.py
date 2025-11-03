from django.contrib import admin
from parler.admin import TranslatableAdmin
from .models import CompanyInfo, ContactInfo, Employee, FAQ

from django.contrib import messages
from googletrans import Translator
import time

translator = Translator()


@admin.register(CompanyInfo)
class CompanyInfoAdmin(TranslatableAdmin):
    list_display = ['about_us', 'updated_at']
    list_filter = ['updated_at']
    search_fields = ['about_us', 'mission', 'vision']
    readonly_fields = ['updated_at']

    actions = ['auto_translate_to_croatian']
    
    def auto_translate_to_croatian(self, request, queryset):
        """Auto-translate English to Croatian"""
        try:
            for obj in queryset:
                obj.set_current_language('en')
                
                # Translate
                about_hr = translator.translate(obj.about_us, src='en', dest='hr').text
                time.sleep(1)
                mission_hr = translator.translate(obj.mission, src='en', dest='hr').text
                time.sleep(1)
                vision_hr = translator.translate(obj.vision, src='en', dest='hr').text
                
                # Save Croatian
                obj.set_current_language('hr', initialize=True)
                obj.about_us = about_hr
                obj.mission = mission_hr
                obj.vision = vision_hr
                obj.save()
            
            messages.success(request, f'✓ Translated {queryset.count()} item(s) to Croatian')
        except Exception as e:
            messages.error(request, f'✗ Translation error: {e}')
    
    auto_translate_to_croatian.short_description = "🇭🇷 Auto-translate to Croatian"


@admin.register(ContactInfo)
class ContactInfoAdmin(admin.ModelAdmin):
    list_display = ['name', 'address', 'postal_code', 'city', 'email', 'phone']
    list_filter = ['name']
    search_fields = ['name', 'address', 'email']
    readonly_fields = []


@admin.register(Employee)
class EmployeeAdmin(admin.ModelAdmin):
    list_display = ['name', 'role', 'social']
    list_filter = ['name', 'role']
    search_fields = ['name', 'role']
    readonly_fields = []


@admin.register(FAQ)
class FAQAdmin(TranslatableAdmin):
    list_display = ['question', 'order']
    list_filter = ['order']
    search_fields = ['question', 'answer']
    readonly_fields = []

    actions = ['auto_translate_to_croatian']
    
    def auto_translate_to_croatian(self, request, queryset):
        """Auto-translate English to Croatian"""
        try:
            for obj in queryset:
                obj.set_current_language('en')
                
                question_hr = translator.translate(obj.question, src='en', dest='hr').text
                time.sleep(1)
                answer_hr = translator.translate(obj.answer, src='en', dest='hr').text
                time.sleep(1)
                
                obj.set_current_language('hr', initialize=True)
                obj.question = question_hr
                obj.answer = answer_hr
                obj.save()
            
            messages.success(request, f'✓ Translated {queryset.count()} FAQ(s) to Croatian')
        except Exception as e:
            messages.error(request, f'✗ Translation error: {e}')
    
    auto_translate_to_croatian.short_description = "🇭🇷 Auto-translate to Croatian"